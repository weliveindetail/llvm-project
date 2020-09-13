//===-- OrcRPCTPCServer.h -- OrcRPCTargetProcessControl Server --*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// OrcRPCTargetProcessControl server class.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_EXECUTIONENGINE_ORC_TARGETPROCESS_ORCRPCTPCSERVER_H
#define LLVM_EXECUTIONENGINE_ORC_TARGETPROCESS_ORCRPCTPCSERVER_H

#include "llvm/ADT/BitmaskEnum.h"
#include "llvm/ExecutionEngine/Orc/RPC/RPCUtils.h"
#include "llvm/ExecutionEngine/Orc/RPC/RawByteChannel.h"
#include "llvm/ExecutionEngine/Orc/Shared/TargetProcessControlTypes.h"
#include "llvm/ExecutionEngine/Orc/TargetProcess/TargetExecutionUtils.h"
#include "llvm/ExecutionEngine/Orc/TargetProcessControl.h"
#include "llvm/Support/DynamicLibrary.h"
#include "llvm/Support/FormatVariadic.h"
#include "llvm/Support/Host.h"
#include "llvm/Support/MathExtras.h"
#include "llvm/Support/Memory.h"
#include "llvm/Support/Process.h"

#include <atomic>

namespace llvm {
namespace orc {

namespace orcrpctpc {

enum WireProtectionFlags : uint8_t {
  WPF_None = 0,
  WPF_Read = 1U << 0,
  WPF_Write = 1U << 1,
  WPF_Exec = 1U << 2,
  LLVM_MARK_AS_BITMASK_ENUM(WPF_Exec)
};

/// Convert from sys::Memory::ProtectionFlags
inline WireProtectionFlags
toWireProtectionFlags(sys::Memory::ProtectionFlags PF) {
  WireProtectionFlags WPF = WPF_None;
  if (PF & sys::Memory::MF_READ)
    WPF |= WPF_Read;
  if (PF & sys::Memory::MF_WRITE)
    WPF |= WPF_Write;
  if (PF & sys::Memory::MF_EXEC)
    WPF |= WPF_Exec;
  return WPF;
}

inline sys::Memory::ProtectionFlags
fromWireProtectionFlags(WireProtectionFlags WPF) {
  int PF = 0;
  if (WPF & WPF_Read)
    PF |= sys::Memory::MF_READ;
  if (WPF & WPF_Write)
    PF |= sys::Memory::MF_WRITE;
  if (WPF & WPF_Exec)
    PF |= sys::Memory::MF_EXEC;
  return static_cast<sys::Memory::ProtectionFlags>(PF);
}

struct ReserveMemRequestElement {
  WireProtectionFlags Prot = WPF_None;
  uint64_t Size = 0;
  uint64_t Alignment = 0;
};

using ReserveMemRequest = std::vector<ReserveMemRequestElement>;

struct ReserveMemResultElement {
  WireProtectionFlags Prot = WPF_None;
  JITTargetAddress Address = 0;
  uint64_t AllocatedSize = 0;
};

using ReserveMemResult = std::vector<ReserveMemResultElement>;

struct ReleaseOrFinalizeMemRequestElement {
  WireProtectionFlags Prot = WPF_None;
  JITTargetAddress Address = 0;
  uint64_t Size = 0;
};

using ReleaseOrFinalizeMemRequest =
    std::vector<ReleaseOrFinalizeMemRequestElement>;

} // end namespace orcrpctpc

namespace rpc {

template <> class RPCTypeName<tpctypes::UInt8Write> {
public:
  static const char *getName() { return "UInt8Write"; }
};

template <> class RPCTypeName<tpctypes::UInt16Write> {
public:
  static const char *getName() { return "UInt16Write"; }
};

template <> class RPCTypeName<tpctypes::UInt32Write> {
public:
  static const char *getName() { return "UInt32Write"; }
};

template <> class RPCTypeName<tpctypes::UInt64Write> {
public:
  static const char *getName() { return "UInt64Write"; }
};

template <> class RPCTypeName<tpctypes::BufferWrite> {
public:
  static const char *getName() { return "BufferWrite"; }
};

template <> class RPCTypeName<orcrpctpc::ReserveMemRequestElement> {
public:
  static const char *getName() { return "ReserveMemRequestElement"; }
};

template <> class RPCTypeName<orcrpctpc::ReserveMemResultElement> {
public:
  static const char *getName() { return "ReserveMemResultElement"; }
};

template <> class RPCTypeName<orcrpctpc::ReleaseOrFinalizeMemRequestElement> {
public:
  static const char *getName() { return "ReleaseOrFinalizeMemRequestElement"; }
};

template <> class RPCTypeName<tpctypes::WrapperFunctionResult> {
public:
  static const char *getName() { return "WrapperFunctionResult"; }
};

template <typename ChannelT, typename WriteT>
class SerializationTraits<
    ChannelT, WriteT, WriteT,
    std::enable_if_t<std::is_same<WriteT, tpctypes::UInt8Write>::value ||
                     std::is_same<WriteT, tpctypes::UInt16Write>::value ||
                     std::is_same<WriteT, tpctypes::UInt32Write>::value ||
                     std::is_same<WriteT, tpctypes::UInt64Write>::value>> {
public:
  static Error serialize(ChannelT &C, const WriteT &W) {
    return serializeSeq(C, W.Address, W.Value);
  }
  static Error deserialize(ChannelT &C, WriteT &W) {
    return deserializeSeq(C, W.Address, W.Value);
  }
};

template <typename ChannelT>
class SerializationTraits<
    ChannelT, tpctypes::BufferWrite, tpctypes::BufferWrite,
    std::enable_if_t<std::is_base_of<RawByteChannel, ChannelT>::value>> {
public:
  static Error serialize(ChannelT &C, const tpctypes::BufferWrite &W) {
    uint64_t Size = W.Buffer.size();
    if (auto Err = serializeSeq(C, W.Address, Size))
      return Err;

    return C.appendBytes(W.Buffer.data(), Size);
  }
  static Error deserialize(ChannelT &C, tpctypes::BufferWrite &W) {
    JITTargetAddress Address;
    uint64_t Size;

    if (auto Err = deserializeSeq(C, Address, Size))
      return Err;

    char *Buffer = jitTargetAddressToPointer<char *>(Address);

    if (auto Err = C.readBytes(Buffer, Size))
      return Err;

    W = {Address, StringRef(Buffer, Size)};
    return Error::success();
  }
};

template <typename ChannelT>
class SerializationTraits<ChannelT, orcrpctpc::ReserveMemRequestElement> {
public:
  static Error serialize(ChannelT &C,
                         const orcrpctpc::ReserveMemRequestElement &E) {
    return serializeSeq(C, static_cast<uint8_t>(E.Prot), E.Size, E.Alignment);
  }

  static Error deserialize(ChannelT &C,
                           orcrpctpc::ReserveMemRequestElement &E) {
    return deserializeSeq(C, *reinterpret_cast<uint8_t *>(&E.Prot), E.Size,
                          E.Alignment);
  }
};

template <typename ChannelT>
class SerializationTraits<ChannelT, orcrpctpc::ReserveMemResultElement> {
public:
  static Error serialize(ChannelT &C,
                         const orcrpctpc::ReserveMemResultElement &E) {
    return serializeSeq(C, static_cast<uint8_t>(E.Prot), E.Address,
                        E.AllocatedSize);
  }

  static Error deserialize(ChannelT &C, orcrpctpc::ReserveMemResultElement &E) {
    return deserializeSeq(C, *reinterpret_cast<uint8_t *>(&E.Prot), E.Address,
                          E.AllocatedSize);
  }
};

template <typename ChannelT>
class SerializationTraits<ChannelT,
                          orcrpctpc::ReleaseOrFinalizeMemRequestElement> {
public:
  static Error
  serialize(ChannelT &C,
            const orcrpctpc::ReleaseOrFinalizeMemRequestElement &E) {
    return serializeSeq(C, static_cast<uint8_t>(E.Prot), E.Address, E.Size);
  }

  static Error deserialize(ChannelT &C,
                           orcrpctpc::ReleaseOrFinalizeMemRequestElement &E) {
    return deserializeSeq(C, *reinterpret_cast<uint8_t *>(&E.Prot), E.Address,
                          E.Size);
  }
};

template <typename ChannelT>
class SerializationTraits<
    ChannelT, tpctypes::WrapperFunctionResult, tpctypes::WrapperFunctionResult,
    std::enable_if_t<std::is_base_of<RawByteChannel, ChannelT>::value>> {
public:
  static Error serialize(ChannelT &C,
                         const tpctypes::WrapperFunctionResult &E) {
    auto Data = E.getData();
    if (auto Err = serializeSeq(C, static_cast<uint64_t>(Data.size())))
      return Err;
    if (Data.size() == 0)
      return Error::success();
    return C.appendBytes(reinterpret_cast<const char *>(Data.data()),
                         Data.size());
  }

  static Error deserialize(ChannelT &C, tpctypes::WrapperFunctionResult &E) {
    tpctypes::CWrapperFunctionResult R = {0, {.ValuePtr = 0}, nullptr};
    if (auto Err = deserializeSeq(C, R.Size))
      return Err;
    if (R.Size == 0)
      return Error::success();
    R.Data.ValuePtr = new uint8_t[R.Size];
    if (auto Err =
            C.readBytes(reinterpret_cast<char *>(R.Data.ValuePtr), R.Size)) {
      R.Destroy = tpctypes::WrapperFunctionResult::destroyWithDeleteArray;
      return Err;
    }

    E = tpctypes::WrapperFunctionResult(R);
    return Error::success();
  }
};

} // end namespace rpc

namespace orcrpctpc {

using RemoteSymbolLookupSet = std::vector<std::pair<std::string, bool>>;
using RemoteLookupRequest =
    std::pair<tpctypes::DylibHandle, RemoteSymbolLookupSet>;

class GetTargetTriple : public rpc::Function<GetTargetTriple, std::string()> {
public:
  static const char *getName() { return "GetTargetTriple"; }
};

class GetPageSize : public rpc::Function<GetPageSize, uint64_t()> {
public:
  static const char *getName() { return "GetPageSize"; }
};

class ReserveMem : public rpc::Function<ReserveMem, Expected<ReserveMemResult>(
                                                        ReserveMemRequest)> {
public:
  static const char *getName() { return "ReserveMem"; }
};

class FinalizeMem
    : public rpc::Function<FinalizeMem, Error(ReleaseOrFinalizeMemRequest)> {
public:
  static const char *getName() { return "FinalizeMem"; }
};

class ReleaseMem
    : public rpc::Function<ReleaseMem, Error(ReleaseOrFinalizeMemRequest)> {
public:
  static const char *getName() { return "ReleaseMem"; }
};

class WriteUInt8s
    : public rpc::Function<WriteUInt8s,
                           Error(std::vector<tpctypes::UInt8Write>)> {
public:
  static const char *getName() { return "WriteUInt8s"; }
};

class WriteUInt16s
    : public rpc::Function<WriteUInt16s,
                           Error(std::vector<tpctypes::UInt16Write>)> {
public:
  static const char *getName() { return "WriteUInt16s"; }
};

class WriteUInt32s
    : public rpc::Function<WriteUInt32s,
                           Error(std::vector<tpctypes::UInt32Write>)> {
public:
  static const char *getName() { return "WriteUInt32s"; }
};

class WriteUInt64s
    : public rpc::Function<WriteUInt64s,
                           Error(std::vector<tpctypes::UInt64Write>)> {
public:
  static const char *getName() { return "WriteUInt64s"; }
};

class WriteBuffers
    : public rpc::Function<WriteBuffers,
                           Error(std::vector<tpctypes::BufferWrite>)> {
public:
  static const char *getName() { return "WriteBuffers"; }
};

class LoadDylib
    : public rpc::Function<LoadDylib, Expected<tpctypes::DylibHandle>(
                                          std::string DylibPath)> {
public:
  static const char *getName() { return "LoadDylib"; }
};

class LookupSymbols
    : public rpc::Function<LookupSymbols,
                           Expected<std::vector<tpctypes::LookupResult>>(
                               std::vector<RemoteLookupRequest>)> {
public:
  static const char *getName() { return "LookupSymbols"; }
};

class RunMain
    : public rpc::Function<RunMain, int32_t(JITTargetAddress MainAddr,
                                            std::vector<std::string> Args)> {
public:
  static const char *getName() { return "RunMain"; }
};

class RunWrapper
    : public rpc::Function<RunWrapper,
                           tpctypes::WrapperFunctionResult(
                               JITTargetAddress, std::vector<uint8_t>)> {
public:
  static const char *getName() { return "RunWrapper"; }
};

class CloseConnection : public rpc::Function<CloseConnection, void()> {
public:
  static const char *getName() { return "CloseConnection"; }
};

} // end namespace orcrpctpc

// TargetProcessControl for a process connected via an ORC RPC Endpoint.
template <typename RPCEndpointT> class OrcRPCTPCServer {
public:
  OrcRPCTPCServer(RPCEndpointT &EP) : EP(EP) {
    using ThisT = OrcRPCTPCServer<RPCEndpointT>;

    TripleStr = sys::getProcessTriple();
    PageSize = sys::Process::getPageSizeEstimate();

    EP.template addHandler<orcrpctpc::GetTargetTriple>(*this,
                                                       &ThisT::getTargetTriple);
    EP.template addHandler<orcrpctpc::GetPageSize>(*this, &ThisT::getPageSize);

    EP.template addHandler<orcrpctpc::ReserveMem>(*this, &ThisT::reserveMemory);
    EP.template addHandler<orcrpctpc::FinalizeMem>(*this,
                                                   &ThisT::finalizeMemory);
    EP.template addHandler<orcrpctpc::ReleaseMem>(*this, &ThisT::releaseMemory);

    EP.template addHandler<orcrpctpc::WriteUInt8s>(
        handleWriteUInt<tpctypes::UInt8Write>);
    EP.template addHandler<orcrpctpc::WriteUInt16s>(
        handleWriteUInt<tpctypes::UInt16Write>);
    EP.template addHandler<orcrpctpc::WriteUInt32s>(
        handleWriteUInt<tpctypes::UInt32Write>);
    EP.template addHandler<orcrpctpc::WriteUInt64s>(
        handleWriteUInt<tpctypes::UInt64Write>);
    EP.template addHandler<orcrpctpc::WriteBuffers>(handleWriteBuffer);

    EP.template addHandler<orcrpctpc::LoadDylib>(*this, &ThisT::loadDylib);
    EP.template addHandler<orcrpctpc::LookupSymbols>(*this,
                                                     &ThisT::lookupSymbols);

    EP.template addHandler<orcrpctpc::RunMain>(*this, &ThisT::runMain);
    EP.template addHandler<orcrpctpc::RunWrapper>(*this, &ThisT::runWrapper);

    EP.template addHandler<orcrpctpc::CloseConnection>(*this,
                                                       &ThisT::closeConnection);
  }

  RPCEndpointT &getEndpoint() { return EP; }

  Error run() {
    while (!Finished) {
      if (auto Err = EP.handleOne())
        return Err;
    }
    return Error::success();
  }

private:
  std::string getTargetTriple() { return TripleStr; }
  uint64_t getPageSize() { return PageSize; }

  template <typename WriteT>
  static void handleWriteUInt(const std::vector<WriteT> &Ws) {
    using ValueT = decltype(std::declval<WriteT>().Value);
    for (auto &W : Ws)
      *jitTargetAddressToPointer<ValueT *>(W.Address) = W.Value;
  }

  std::string getProtStr(orcrpctpc::WireProtectionFlags WPF) {
    std::string Result;
    Result += (WPF & orcrpctpc::WPF_Read) ? 'R' : '-';
    Result += (WPF & orcrpctpc::WPF_Write) ? 'W' : '-';
    Result += (WPF & orcrpctpc::WPF_Exec) ? 'X' : '-';
    return Result;
  }

  static void handleWriteBuffer(const std::vector<tpctypes::BufferWrite> &Ws) {
    for (auto &W : Ws) {
      memcpy(jitTargetAddressToPointer<char *>(W.Address), W.Buffer.data(),
             W.Buffer.size());
    }
  }

  Expected<orcrpctpc::ReserveMemResult>
  reserveMemory(const orcrpctpc::ReserveMemRequest &Request) {
    orcrpctpc::ReserveMemResult Allocs;
    auto PF = sys::Memory::MF_READ | sys::Memory::MF_WRITE;

    for (auto &E : Request) {
      uint64_t Size = alignTo(E.Size, PageSize);
      uint16_t Align = E.Alignment;

      if ((Align > PageSize) || (PageSize % Align))
        return make_error<StringError>(
            "Page alignmen does not satisfy requested alignment",
            inconvertibleErrorCode());

      std::error_code EC;
      auto MB = sys::Memory::allocateMappedMemory(Size, nullptr, PF, EC);
      if (EC)
        return make_error<StringError>("Unable to allocate memory: " +
                                           EC.message(),
                                       inconvertibleErrorCode());

      memset(MB.base(), 0, MB.allocatedSize());

      //      dbgs() << "Reserve: size = " << formatv("{0:x16}", E.Size)
      //             << ", align = " << formatv("{0:x8}", E.Alignment)
      //             << " --> [ " << MB.base() << " -- "
      //             << (void*)((char*)MB.base() + MB.allocatedSize()) << "
      //             ]\n";

      Allocs.push_back(
          {E.Prot, pointerToJITTargetAddress(MB.base()), MB.allocatedSize()});
    }

    return Allocs;
  }

  Error finalizeMemory(const orcrpctpc::ReleaseOrFinalizeMemRequest &FMR) {
    for (auto &E : FMR) {
      sys::MemoryBlock MB(jitTargetAddressToPointer<void *>(E.Address), E.Size);

      //      dbgs() << "Finalize: prot = " << getProtStr(E.Prot)
      //             << ", range = [ " << MB.base() << " -- "
      //             << (void*)((char*)MB.base() + MB.allocatedSize()) << "
      //             ]\n";

      auto PF = orcrpctpc::fromWireProtectionFlags(E.Prot);
      if (auto EC =
              sys::Memory::protectMappedMemory(MB, static_cast<unsigned>(PF)))
        return make_error<StringError>("error protecting memory: " +
                                           EC.message(),
                                       inconvertibleErrorCode());
    }
    return Error::success();
  }

  Error releaseMemory(const orcrpctpc::ReleaseOrFinalizeMemRequest &RMR) {
    for (auto &E : RMR) {
      sys::MemoryBlock MB(jitTargetAddressToPointer<void *>(E.Address), E.Size);

      //      dbgs() << "Release: [ " << MB.base() << " -- "
      //             << (void*)((char*)MB.base() + MB.allocatedSize()) << "
      //             ]\n";

      if (auto EC = sys::Memory::releaseMappedMemory(MB))
        return make_error<StringError>("error release memory: " + EC.message(),
                                       inconvertibleErrorCode());
    }
    return Error::success();
  }

  Expected<tpctypes::DylibHandle> loadDylib(const std::string &Path) {
    // dbgs() << "Opening dylib \"" << Path << "\".\n";
    std::string ErrMsg;
    const char *DLPath = !Path.empty() ? Path.c_str() : nullptr;
    auto DL = sys::DynamicLibrary::getPermanentLibrary(DLPath, &ErrMsg);
    if (!DL.isValid())
      return make_error<StringError>(std::move(ErrMsg),
                                     inconvertibleErrorCode());

    tpctypes::DylibHandle H = Dylibs.size();
    Dylibs[H] = std::move(DL);
    return H;
  }

  Expected<std::vector<tpctypes::LookupResult>>
  lookupSymbols(const std::vector<orcrpctpc::RemoteLookupRequest> &Request) {
    std::vector<tpctypes::LookupResult> Result;

    // dbgs() << "Looking up:\n";
    for (auto &E : Request) {
      auto I = Dylibs.find(E.first);
      if (I == Dylibs.end())
        return make_error<StringError>("Unrecognized handle",
                                       inconvertibleErrorCode());
      auto &DL = I->second;
      Result.push_back({});

      for (auto &KV : E.second) {
        auto &SymString = KV.first;
        bool WeakReference = KV.second;

        const char *Sym = SymString.c_str();
#ifdef __APPLE__
        if (*Sym != '\0')
          ++Sym;
#endif

        void *Addr = DL.getAddressOfSymbol(Sym);
        if (!Addr && !WeakReference)
          return make_error<StringError>(Twine("Missing definition for ") + Sym,
                                         inconvertibleErrorCode());

        Result.back().push_back(pointerToJITTargetAddress(Addr));

        // dbgs() << "  " << SymString << " -> " << Addr << "\n";
      }
    }

    return Result;
  }

  int32_t runMain(JITTargetAddress MainFnAddr,
                  const std::vector<std::string> &Args) {
    return runAsMain(
        jitTargetAddressToFunction<int (*)(int, char *[])>(MainFnAddr), Args,
        None);
  }

  tpctypes::WrapperFunctionResult
  runWrapper(JITTargetAddress WrapperFnAddr,
             const std::vector<uint8_t> &ArgBuffer) {
    // dbgs() << "Calling wrapper function "
    //       << formatv("{0:x16}", WrapperFnAddr) << "...\n";
    using WrapperFnTy = tpctypes::CWrapperFunctionResult (*)(
        const uint8_t *Data, uint64_t Size);
    auto *WrapperFn = jitTargetAddressToFunction<WrapperFnTy>(WrapperFnAddr);
    return WrapperFn(ArgBuffer.data(), ArgBuffer.size());
  }

  void closeConnection() { Finished = true; }

  std::string TripleStr;
  uint64_t PageSize = 0;
  RPCEndpointT &EP;
  std::atomic<bool> Finished{false};
  DenseMap<tpctypes::DylibHandle, sys::DynamicLibrary> Dylibs;
};

} // end namespace orc
} // end namespace llvm

#endif // LLVM_EXECUTIONENGINE_ORC_TARGETPROCESS_ORCRPCTPCSERVER_H
