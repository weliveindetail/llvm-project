// RUN: %clang_cc1 -D__ARM_FEATURE_SVE -triple aarch64-none-linux-gnu -target-feature +sve -fallow-half-arguments-and-returns -fsyntax-only -verify %s
// RUN: %clang_cc1 -D__ARM_FEATURE_SVE -DSVE_OVERLOADED_FORMS -triple aarch64-none-linux-gnu -target-feature +sve -fallow-half-arguments-and-returns -fsyntax-only -verify %s

#ifdef SVE_OVERLOADED_FORMS
// A simple used,unused... macro, long enough to represent any SVE builtin.
#define SVE_ACLE_FUNC(A1,A2_UNUSED,A3,A4_UNUSED) A1##A3
#else
#define SVE_ACLE_FUNC(A1,A2,A3,A4) A1##A2##A3##A4
#endif

#include <arm_sve.h>

svint32_t test_svdot_lane_s32(svint32_t op1, svint8_t op2, svint8_t op3)
{
  // expected-error-re@+1 {{argument value {{[0-9]+}} is outside the valid range [0, 3]}}
  return SVE_ACLE_FUNC(svdot_lane,_s32,,)(op1, op2, op3, -1);
}

svint32_t test_svdot_lane_s32_1(svint32_t op1, svint8_t op2, svint8_t op3)
{
  // expected-error-re@+1 {{argument value {{[0-9]+}} is outside the valid range [0, 3]}}
  return SVE_ACLE_FUNC(svdot_lane,_s32,,)(op1, op2, op3, 4);
}

svint64_t test_svdot_lane_s64(svint64_t op1, svint16_t op2, svint16_t op3)
{
  // expected-error-re@+1 {{argument value {{[0-9]+}} is outside the valid range [0, 1]}}
  return SVE_ACLE_FUNC(svdot_lane,_s64,,)(op1, op2, op3, -1);
}

svint64_t test_svdot_lane_s64_1(svint64_t op1, svint16_t op2, svint16_t op3)
{
  // expected-error-re@+1 {{argument value {{[0-9]+}} is outside the valid range [0, 1]}}
  return SVE_ACLE_FUNC(svdot_lane,_s64,,)(op1, op2, op3, 2);
}

svuint32_t test_svdot_lane_u32(svuint32_t op1, svuint8_t op2, svuint8_t op3)
{
  // expected-error-re@+1 {{argument value {{[0-9]+}} is outside the valid range [0, 3]}}
  return SVE_ACLE_FUNC(svdot_lane,_u32,,)(op1, op2, op3, 4);
}

svuint64_t test_svdot_lane_u64(svuint64_t op1, svuint16_t op2, svuint16_t op3)
{
  // expected-error-re@+1 {{argument value {{[0-9]+}} is outside the valid range [0, 1]}}
  return SVE_ACLE_FUNC(svdot_lane,_u64,,)(op1, op2, op3, 2);
}
