// RUN: mlir-opt -linalg-bufferize -split-input-file %s | FileCheck %s

#map0 = affine_map<(d0) -> (d0)>

// In-depth checking of a basic case, this is testing
// - tensor_to_memref / tensor_load materializations are properly inserted
// - payload is correctly carried over
// - affine maps are correctly carried over
// Later tests will not check all these details.

// CHECK: #map = affine_map<(d0) -> (d0)>
// CHECK-LABEL:   func @basic(
// CHECK-SAME:                %[[TENSOR:.*]]: tensor<4xf32>) -> tensor<4xf32> {
// CHECK:           %[[MEMREF:.*]] = tensor_to_memref %[[TENSOR]] : memref<4xf32>
// CHECK:           %[[RESULT_MEMREF:.*]] = alloc() : memref<4xf32>
// CHECK:           linalg.generic {indexing_maps = [#map, #map], iterator_types = ["parallel"]}
// CHECK-SAME:      ins(%[[MEMREF]] : memref<4xf32>)
// CHECK-SAME:      outs(%[[RESULT_MEMREF]] : memref<4xf32>) {
// CHECK:           ^bb0(%[[RESULT1:.*]]: f32, %[[UNUSED:.*]]: f32):
// CHECK:             %[[DIM1:.*]] = exp %[[RESULT1]] : f32
// CHECK:             linalg.yield %[[DIM1]] : f32
// CHECK:           }
// CHECK:           %[[RESULT:.*]] = tensor_load %[[RESULT_MEMREF]] : memref<4xf32>
// CHECK:           return %[[RESULT]] : tensor<4xf32>
func @basic(%arg0: tensor<4xf32>) -> tensor<4xf32> {
    %0 = linalg.generic {
      indexing_maps = [#map0, #map0],
      iterator_types = ["parallel"]
    } ins(%arg0 : tensor<4xf32>) {
      ^bb0(%gen_arg1: f32):
        %tmp1 = exp %gen_arg1 : f32
        linalg.yield %tmp1 : f32
    } -> tensor<4xf32>
    return %0 : tensor<4xf32>
}


// -----

#map0 = affine_map<(d0) -> (d0)>

// CHECK-LABEL:   func @multiple_results
// CHECK:           %[[RESULT0:.*]] = alloc() : memref<4xf32>
// CHECK:           %[[RESULT1:.*]] = alloc() : memref<4xf32>
// CHECK:           linalg.generic
// CHECK-SAME:      ins(%{{.*}} : memref<4xf32>)
// CHECK-SAME:      outs(%[[RESULT0]], %[[RESULT1]] : memref<4xf32>, memref<4xf32>)
func @multiple_results(%arg0: tensor<4xf32>) -> (tensor<4xf32>, tensor<4xf32>) {
    %0, %1 = linalg.generic {
      indexing_maps = [#map0, #map0, #map0],
      iterator_types = ["parallel"]
    } ins(%arg0 : tensor<4xf32>) {
      ^bb0(%gen_arg1: f32):
        %tmp1 = exp %gen_arg1 : f32
        linalg.yield %tmp1, %tmp1 : f32, f32
    } -> tensor<4xf32>, tensor<4xf32>
    return %0, %1 : tensor<4xf32>, tensor<4xf32>
}

// -----

#map_2d = affine_map<(d0, d1) -> (d0, d1)>
#map_2d_inv = affine_map<(d0, d1) -> (d1, d0)>

// Check that the allocs properly consider the different shapes of the output
// operands. The permuted indexing maps translate to different output shapes.

// CHECK: #map0 = affine_map<(d0, d1) -> (d0, d1)>
// CHECK: #map1 = affine_map<(d0, d1) -> (d1, d0)>
// CHECK-LABEL:   func @dynamic_results(
// CHECK-SAME:                          %[[ARG:.*]]: tensor<?x?xf32>
// CHECK:           %[[MEMREF_ARG:.*]] = tensor_to_memref %[[ARG]] : memref<?x?xf32>
// CHECK:           %[[C0:.*]] = constant 0 : index
// CHECK:           %[[DIM0:.*]] = dim %[[ARG]], %[[C0]] : tensor<?x?xf32>
// CHECK:           %[[C1:.*]] = constant 1 : index
// CHECK:           %[[DIM1:.*]] = dim %[[ARG]], %[[C1]] : tensor<?x?xf32>
// CHECK:           %[[RESULT0:.*]] = alloc(%[[DIM0]], %[[DIM1]]) : memref<?x?xf32>
// CHECK:           %[[RESULT1:.*]] = alloc(%[[DIM1]], %[[DIM0]]) : memref<?x?xf32>
// CHECK:           linalg.generic {indexing_maps = [#map0, #map0, #map1]
// CHECK-SAME:      ins(%[[MEMREF_ARG]] : memref<?x?xf32>)
// CHECK-SAME:      outs(%[[RESULT0]], %[[RESULT1]] : memref<?x?xf32>, memref<?x?xf32>)
func @dynamic_results(%arg0: tensor<?x?xf32>)
         -> (tensor<?x?xf32>, tensor<?x?xf32>) {
    %0, %1 = linalg.generic {
      indexing_maps = [#map_2d, #map_2d, #map_2d_inv],
      iterator_types = ["parallel", "parallel"]
    } ins(%arg0 : tensor<?x?xf32>) {
      ^bb0(%gen_arg1: f32):
        %tmp1 = exp %gen_arg1 : f32
        linalg.yield %tmp1, %tmp1 : f32, f32
    } -> tensor<?x?xf32>, tensor<?x?xf32>
    return %0, %1 : tensor<?x?xf32>, tensor<?x?xf32>
}

// -----

// Check lowering of tensor-valued std.constant's
// TODO: Move this to std-bufferize.

// CHECK-LABEL:   func @constant() -> tensor<2x3xf32> {
// CHECK:           %[[VECTOR_MEMREF:.*]] = alloc() : memref<vector<6xf32>>
// CHECK:           %[[VECTOR_CONST:.*]] = constant dense<[0.000000e+00, 1.000000e+00, 2.000000e+00, 3.000000e+00, 4.000000e+00, 5.000000e+00]> : vector<6xf32>
// CHECK:           store %[[VECTOR_CONST]], %[[VECTOR_MEMREF]][] : memref<vector<6xf32>>
// CHECK:           %[[MEMREF:.*]] = vector.type_cast %[[VECTOR_MEMREF]] : memref<vector<6xf32>> to memref<6xf32>
// CHECK:           %[[FINAL_SHAPE:.*]] = linalg.reshape %[[MEMREF]] [#map] : memref<6xf32> into memref<2x3xf32>
// CHECK:           %[[RESULT:.*]] = tensor_load %[[FINAL_SHAPE]] : memref<2x3xf32>
// CHECK:           return %[[RESULT]] : tensor<2x3xf32>
func @constant() -> tensor<2x3xf32> {
  %0 = constant dense<[[0.0, 1.0, 2.0], [3.0, 4.0, 5.0]]> : tensor<2x3xf32>
  return %0: tensor<2x3xf32>
}

// -----

#accesses = [
  affine_map<(i, j, k) -> (j, i, k)>,
  affine_map<(i, j, k) -> (i, j)>
]

#trait = {
  indexing_maps = #accesses,
  iterator_types = ["parallel", "parallel", "reduction"]
}

// Check the bufferization of init tensors.

// CHECK-LABEL:   func @generic_with_init_tensor(
// CHECK-SAME:                                   %[[ARG0_TENSOR:.*]]: tensor<2x3x4xvector<3x4xi4>>,
// CHECK-SAME:                                   %[[ARG1_TENSOR:.*]]: tensor<3x2xf32>) -> tensor<3x2xf32> {
// CHECK:           %[[ARG0_MEMREF:.*]] = tensor_to_memref %[[ARG0_TENSOR]] : memref<2x3x4xvector<3x4xi4>>
// CHECK:           %[[ARG1_MEMREF:.*]] = tensor_to_memref %[[ARG1_TENSOR]] : memref<3x2xf32>
// CHECK:           %[[INIT_BUFFER:.*]] = alloc() : memref<3x2xf32>
// CHECK:           linalg.copy(%[[ARG1_MEMREF]], %[[INIT_BUFFER]]) : memref<3x2xf32>, memref<3x2xf32>
// CHECK:           linalg.generic
// CHECK-SAME:      ins(%[[ARG0_MEMREF]] : memref<2x3x4xvector<3x4xi4>>)
// CHECK-SAME:      outs(%[[INIT_BUFFER]] : memref<3x2xf32>) {
func @generic_with_init_tensor(%arg0: tensor<2x3x4xvector<3x4xi4>>,
  %arg1: tensor<3x2xf32>) -> (tensor<3x2xf32>) {

  %0 = linalg.generic #trait
    ins(%arg0 : tensor<2x3x4xvector<3x4xi4>>)
   init(%arg1 : tensor<3x2xf32>) {
    ^bb(%v0: vector<3x4xi4>, %v1: f32) :
      %f0 = constant 0.0 : f32
      linalg.yield %f0 : f32
  } -> tensor<3x2xf32>

  return %0 : tensor<3x2xf32>
}

// -----

// CHECK-DAG: #[[$MAP0:[0-9a-z]*]] = affine_map<(d0, d1)[s0, s1] -> (d0 * s1 + s0 + d1)>
// CHECK-DAG: #[[$MAP1:[0-9a-z]*]] = affine_map<(d0, d1)[s0, s1] -> (d0 * s1 + s0 + d1 * 2)>

func @make_index() -> index

// CHECK-LABEL: func @bufferize_subtensor(
//  CHECK-SAME:   %[[T:[0-9a-z]*]]: tensor<?x?xf32>
func @bufferize_subtensor(%t : tensor<?x?xf32>) -> (tensor<2x3xf32>, tensor<2x?xf32>) {
  //      CHECK: %[[IDX:.*]] = call @make_index() : () -> index
  %i0 = call @make_index() : () -> index

  //      CHECK: %[[M0:.*]] = tensor_to_memref %[[T]] : memref<?x?xf32>
  // CHECK-NEXT: %[[A0:.*]] = alloc() : memref<2x3xf32>
  // CHECK-NEXT: %[[SM0:.*]] = subview %[[M0]][0, 0] [2, 3] [1, 1]
  // CHECK-SAME:   memref<?x?xf32> to memref<2x3xf32, #[[$MAP0]]>
  // CHECK-NEXT: linalg.copy(%[[SM0]], %[[A0]]) : memref<2x3xf32, #[[$MAP0]]>, memref<2x3xf32>
  // CHECK-NEXT: %[[RT0:.*]] = tensor_load %[[A0]] : memref<2x3xf32>
  %st0 = subtensor %t[0, 0][2, 3][1, 1] : tensor<?x?xf32> to tensor<2x3xf32>

  //      CHECK: %[[M1:.*]] = tensor_to_memref %[[T]] : memref<?x?xf32>
  // CHECK-NEXT: %[[A1:.*]] = alloc(%[[IDX]]) : memref<2x?xf32>
  // CHECK-NEXT: %[[SM1:.*]] = subview %[[M1]][0, %[[IDX]]] [2, %[[IDX]]] [1, 2]
  // CHECK-SAME:   memref<?x?xf32> to memref<2x?xf32, #[[$MAP1]]>
  // CHECK-NEXT: linalg.copy(%[[SM1]], %[[A1]]) : memref<2x?xf32, #[[$MAP1]]>, memref<2x?xf32>
  // CHECK-NEXT: %[[RT1:.*]] = tensor_load %[[A1]] : memref<2x?xf32>
  %st1 = subtensor %t[0, %i0][2, %i0][1, 2] : tensor<?x?xf32> to tensor<2x?xf32>

  // CHECK-NEXT: return %[[RT0]], %[[RT1]]
  return %st0, %st1 : tensor<2x3xf32>, tensor<2x?xf32>
}

// -----

// CHECK-DAG: #[[$MAP0:[0-9a-z]*]] = affine_map<(d0, d1)[s0, s1] -> (d0 * s1 + s0 + d1)>
// CHECK-DAG: #[[$MAP1:[0-9a-z]*]] = affine_map<(d0, d1)[s0, s1] -> (d0 * s1 + s0 + d1 * 2)>

func @make_index() -> index

// CHECK-LABEL: func @bufferize_subtensor_insert(
//  CHECK-SAME:   %[[T:[0-9a-z]*]]: tensor<?x?xf32>
//  CHECK-SAME:   %[[ST0:[0-9a-z]*]]: tensor<2x3xf32>
//  CHECK-SAME:   %[[ST1:[0-9a-z]*]]: tensor<2x?xf32>
func @bufferize_subtensor_insert(%t : tensor<?x?xf32>, %st0 : tensor<2x3xf32>, %st1 : tensor<2x?xf32>) ->
    (tensor<?x?xf32>, tensor<?x?xf32>) {
  %c0 = constant 0 : index
  %c1 = constant 1 : index
  //      CHECK: %[[IDX:.*]] = call @make_index() : () -> index
  %i0 = call @make_index() : () -> index


  //  CHECK-DAG: %[[M0:.*]] = tensor_to_memref %[[T]] : memref<?x?xf32>
  //  CHECK-DAG: %[[SM0:.*]] = tensor_to_memref %[[ST0]] : memref<2x3xf32>
  // CHECK-NEXT: %[[C0:.*]] = constant 0 : index
  // CHECK-NEXT: %[[DIM0:.*]] = dim %[[M0]], %[[C0]] : memref<?x?xf32>
  // CHECK-NEXT: %[[C1:.*]] = constant 1 : index
  // CHECK-NEXT: %[[DIM1:.*]] = dim %[[M0]], %[[C1]] : memref<?x?xf32>
  // CHECK-NEXT: %[[M0_COPY:.*]] = alloc(%[[DIM0]], %[[DIM1]]) : memref<?x?xf32>
  // CHECK-NEXT: linalg.copy(%[[M0]], %[[M0_COPY]]) : memref<?x?xf32>, memref<?x?xf32>
  // CHECK-NEXT: %[[SUBVIEW0:.*]] = subview %[[M0_COPY]][0, 0] [2, 3] [1, 1]
  // CHECK-SAME:   memref<?x?xf32> to memref<2x3xf32, #[[$MAP0]]>
  // CHECK-NEXT: linalg.copy(%[[SM0]], %[[SUBVIEW0]]) : memref<2x3xf32>, memref<2x3xf32, #[[$MAP0]]>
  // CHECK-NEXT: %[[RT0:.*]] = tensor_load %[[M0_COPY]] : memref<?x?xf32>
  %t0 = subtensor_insert %st0 into %t[0, 0][2, 3][1, 1] : tensor<2x3xf32> into tensor<?x?xf32>

  //  CHECK-DAG: %[[M1:.*]] = tensor_to_memref %[[T]] : memref<?x?xf32>
  //  CHECK-DAG: %[[SM1:.*]] = tensor_to_memref %[[ST1]] : memref<2x?xf32>
  // CHECK-NEXT: %[[C0:.*]] = constant 0 : index
  // CHECK-NEXT: %[[DIM0:.*]] = dim %[[M1]], %[[C0]] : memref<?x?xf32>
  // CHECK-NEXT: %[[C1:.*]] = constant 1 : index
  // CHECK-NEXT: %[[DIM1:.*]] = dim %[[M1]], %[[C1]] : memref<?x?xf32>
  // CHECK-NEXT: %[[M1_COPY:.*]] = alloc(%[[DIM0]], %[[DIM1]]) : memref<?x?xf32>
  // CHECK-NEXT: linalg.copy(%[[M1]], %[[M1_COPY]]) : memref<?x?xf32>, memref<?x?xf32>
  // CHECK-NEXT: %[[SUBVIEW1:.*]] = subview %[[M1_COPY]][0, %[[IDX]]] [2, %[[IDX]]] [1, 2]
  // CHECK-SAME:   memref<?x?xf32> to memref<2x?xf32, #[[$MAP1]]>
  // CHECK-NEXT: linalg.copy(%[[SM1]], %[[SUBVIEW1]]) : memref<2x?xf32>, memref<2x?xf32, #[[$MAP1]]>
  // CHECK-NEXT: %[[RT1:.*]] = tensor_load %[[M1_COPY]] : memref<?x?xf32>
  %t1 = subtensor_insert %st1 into %t[0, %i0][2, %i0][1, 2] : tensor<2x?xf32> into tensor<?x?xf32>

  //     CHECK: return %[[RT0]], %[[RT1]]
  return %t0, %t1: tensor<?x?xf32>, tensor<?x?xf32>
}
