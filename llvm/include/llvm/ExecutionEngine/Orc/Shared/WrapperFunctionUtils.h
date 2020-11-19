//===------ WrapperFunctionUtils.h - Shared Core/TPC types ------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// TargetProcessControl types that are used by both the Orc and
// OrcTargetProcess libraries.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_EXECUTIONENGINE_ORC_SHARED_WRAPPERFUNCTIONUTILS_H
#define LLVM_EXECUTIONENGINE_ORC_SHARED_WRAPPERFUNCTIONUTILS_H

#include "llvm/ADT/ArrayRef.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/ExecutionEngine/Orc/Shared/Serialization.h"
#include "llvm/ExecutionEngine/Orc/Shared/VectorRawByteChannel.h"
#include "llvm/Support/BinaryStreamWriter.h"
#include "llvm/Support/BinaryStreamReader.h"
#include "llvm/Support/Debug.h"
#include "llvm/Support/Endian.h"
#include "llvm/Support/Error.h"

#include "llvm-c/OrcShared.h"

namespace llvm {
namespace orc {
namespace shared {

/// C++ wrapper function result: Same as CWrapperFunctionResult but
/// auto-releases memory.
class WrapperFunctionResult {
public:
  /// Create a default WrapperFunctionResult.
  WrapperFunctionResult() { zeroInit(R); }

  /// Create a WrapperFunctionResult from a CWrapperFunctionResult. This
  /// instance takes ownership of the result object and will automatically
  /// call the Destroy member upon destruction.
  WrapperFunctionResult(LLVMOrcSharedCWrapperFunctionResult R) : R(R) {}

  WrapperFunctionResult(const WrapperFunctionResult &) = delete;
  WrapperFunctionResult &operator=(const WrapperFunctionResult &) = delete;

  WrapperFunctionResult(WrapperFunctionResult &&Other) {
    zeroInit(R);
    std::swap(R, Other.R);
  }

  WrapperFunctionResult &operator=(WrapperFunctionResult &&Other) {
    LLVMOrcSharedCWrapperFunctionResult Tmp;
    zeroInit(Tmp);
    std::swap(Tmp, Other.R);
    std::swap(R, Tmp);
    return *this;
  }

  ~WrapperFunctionResult() {
    if (R.Destroy)
      R.Destroy(R.Data, R.Size);
  }

  /// Relinquish ownership of and return the
  /// LLVMOrcSharedCWrapperFunctionResult.
  LLVMOrcSharedCWrapperFunctionResult release() {
    LLVMOrcSharedCWrapperFunctionResult Tmp;
    zeroInit(Tmp);
    std::swap(R, Tmp);
    return Tmp;
  }

  /// Returns true if this value is equivalent to a default-constructed
  /// WrapperFunctionResult.
  bool isEmpty() const {
    return R.Size == 0 && R.Data.ValuePtr == nullptr && R.Destroy == nullptr;
  }

  /// Get an ArrayRef covering the data in the result.
  ArrayRef<uint8_t> getData() const {
    if (R.Size <= sizeof(const uint8_t*))
      return ArrayRef<uint8_t>(R.Data.Value, R.Size);
    return ArrayRef<uint8_t>(R.Data.ValuePtr, R.Size);
  }

  /// Copy from the given ArrayRef.
  static WrapperFunctionResult copyFrom(ArrayRef<uint8_t> Source) {
    LLVMOrcSharedCWrapperFunctionResult R;
    R.Size = Source.size();
    uint8_t *Data;
    if (R.Size > sizeof(const uint8_t*)) {
      Data = new uint8_t[R.Size];
      R.Data.ValuePtr = Data;
      R.Destroy = destroyWithArrayDelete;
    } else {
      Data = R.Data.Value;
      R.Destroy = nullptr;
    }
    memcpy(reinterpret_cast<char*>(Data),
           reinterpret_cast<const char*>(Source.data()), Source.size());
    return R;
  }

  /// Copy from the given StringRef.
  static WrapperFunctionResult copyFrom(StringRef Source) {
    return copyFrom(ArrayRef<uint8_t>(
        reinterpret_cast<const uint8_t*>(Source.data()), Source.size()));
  }

  /// Create a WrapperFunctionResult representing an error value.
  static WrapperFunctionResult fromError(StringRef ErrMsg) {
    uint8_t *Data = new uint8_t[ErrMsg.size() + 1];
    memcpy(reinterpret_cast<uint8_t*>(Data), ErrMsg.data(), ErrMsg.size());
    Data[ErrMsg.size()] = '\0';
    LLVMOrcSharedCWrapperFunctionResult R;
    R.Size = 0;
    R.Data.ValuePtr = Data;
    R.Destroy = &destroyWithArrayDelete;
    return R;
  };

  /// Create a WrapperFunctionResult from a constant string. Does not copy or
  /// free the input string.
  static WrapperFunctionResult fromStringLiteral(const char *Msg) {
    LLVMOrcSharedCWrapperFunctionResult R;
    R.Size = strlen(Msg) + 1;
    R.Destroy = nullptr;
    if (R.Size > sizeof(uint8_t*))
      R.Data.ValuePtr = reinterpret_cast<const uint8_t*>(Msg);
    else
      memcpy(reinterpret_cast<char*>(R.Data.Value), Msg, R.Size);
    return R;
  }

  /// Converts this WrapperFunctionResult to a StringError if it is in the
  /// out-of-band-error state. Otherwise returns Error::success().
  Error getAnyOutOfBandError() {
    if (R.Size == 0 && R.Data.ValuePtr != 0) {
      std::string ErrMsg(reinterpret_cast<const char*>(R.Data.ValuePtr));
      R.Destroy(R.Data, R.Size);
      return make_error<StringError>(std::move(ErrMsg),
                                     inconvertibleErrorCode());
    }
    return Error::success();
  }

  /// Always free Data.ValuePtr by calling delete[] on it.
  static void
  destroyWithArrayDelete(LLVMOrcSharedCWrapperFunctionResultData Data,
                         uint64_t Size) {
    delete[] Data.ValuePtr;
  }

private:
  static void zeroInit(LLVMOrcSharedCWrapperFunctionResult &R) {
    R.Size = 0;
    R.Data.ValuePtr = nullptr;
    R.Destroy = nullptr;
  }

  LLVMOrcSharedCWrapperFunctionResult R;
};

template <> class SerializationTypeName<WrapperFunctionResult> {
public:
  static const char *getName() { return "WrapperFunctionResult"; }
};

template <typename ChannelT>
class SerializationTraits<
    ChannelT, WrapperFunctionResult, WrapperFunctionResult,
    std::enable_if_t<std::is_base_of<RawByteChannel, ChannelT>::value>> {
public:
  static Error serialize(ChannelT &C, const WrapperFunctionResult &E) {
    auto Data = E.getData();
    if (auto Err = serializeSeq(C, static_cast<uint64_t>(Data.size())))
      return Err;
    if (Data.size() == 0)
      return Error::success();
    return C.appendBytes(reinterpret_cast<const char*>(Data.data()),
                         Data.size());
  }

  static Error deserialize(ChannelT &C, WrapperFunctionResult &E) {
    LLVMOrcSharedCWrapperFunctionResult R;

    R.Size = 0;
    R.Data.ValuePtr = nullptr;
    R.Destroy = nullptr;

    if (auto Err = deserializeSeq(C, R.Size))
      return Err;
    if (R.Size == 0)
      return Error::success();

    uint8_t *Data;

    if (R.Size > sizeof(decltype(R.Data.Value))) {
      Data = new uint8_t[R.Size];
      R.Data.ValuePtr = Data;
      R.Destroy = WrapperFunctionResult::destroyWithArrayDelete;
    } else
      Data = &R.Data.Value[0];

    // Assign to E -- this ensures cleanup in the case that the call below
    // fails.
    E = WrapperFunctionResult(R);

    if (auto Err = C.readBytes(reinterpret_cast<char*>(Data), R.Size))
      return Err;

    // Re-assign to E -- this ensures that data is copied in the small-data
    // case.
    E = WrapperFunctionResult(R);

    return Error::success();
  }
};

template <typename... ArgTs>
WrapperFunctionResult toWrapperFunctionBlob(const ArgTs &... Args) {
  VectorRawByteChannel C;
  cantFail(serializeSeq(C, Args...));
  return WrapperFunctionResult::copyFrom(C.getVector());
}

template <typename... ArgTs>
Error fromWrapperFunctionBlob(ArrayRef<uint8_t> Blob, ArgTs &... Args) {
  // FIXME: Create an ArrayRef input channel once we decouple input and output
  //        for serialization.
  VectorRawByteChannel C(Blob.vec());
  return deserializeSeq(C, Args...);
}

} // end namespace shared
} // end namespace orc
} // end namespace llvm

#endif // LLVM_EXECUTIONENGINE_ORC_SHARED_WRAPPERFUNCTIONUTILS_H
