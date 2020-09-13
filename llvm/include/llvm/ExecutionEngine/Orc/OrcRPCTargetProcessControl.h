//===--- OrcRPCTargetProcessControl.h - Remote target control ---*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Utilities for interacting with target processes.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_EXECUTIONENGINE_ORC_ORCRPCTARGETPROCESSCONTROL_H
#define LLVM_EXECUTIONENGINE_ORC_ORCRPCTARGETPROCESSCONTROL_H

#include "llvm/ExecutionEngine/Orc/RPC/RPCUtils.h"
#include "llvm/ExecutionEngine/Orc/RPC/RawByteChannel.h"
#include "llvm/ExecutionEngine/Orc/TargetProcess/OrcRPCTPCServer.h"
#include "llvm/ExecutionEngine/Orc/TargetProcessControl.h"
#include "llvm/Support/MSVCErrorWorkarounds.h"

namespace llvm {
namespace orc {

/// JITLinkMemoryManager implementation for a process connected via an ORC RPC
/// endpoint.
template <typename OrcRPCTPCImplT>
class OrcRPCTPCJITLinkMemoryManager : public jitlink::JITLinkMemoryManager {
private:
  struct HostAlloc {
    std::unique_ptr<char[]> Mem;
    uint64_t Size;
  };

  struct TargetAlloc {
    JITTargetAddress Address = 0;
    uint64_t AllocatedSize = 0;
  };

  using HostAllocMap = DenseMap<int, HostAlloc>;
  using TargetAllocMap = DenseMap<int, TargetAlloc>;

public:
  class OrcRPCAllocation : public Allocation {
  public:
    OrcRPCAllocation(OrcRPCTPCJITLinkMemoryManager<OrcRPCTPCImplT> &Parent,
                     HostAllocMap HostAllocs, TargetAllocMap TargetAllocs)
        : Parent(Parent), HostAllocs(std::move(HostAllocs)),
          TargetAllocs(std::move(TargetAllocs)) {
      // dbgs() << "Adding alloc:\n";
      // for (auto &KV : this->HostAllocs) {
      //  dbgs() << "  Alloc: " << (void*)KV.second.Mem.get() << "\n";
      //}
      assert(HostAllocs.size() == TargetAllocs.size() &&
             "HostAllocs size should match TargetAllocs");
    }

    ~OrcRPCAllocation() override {
      assert(TargetAllocs.empty() && "failed to deallocate");
    }

    MutableArrayRef<char> getWorkingMemory(ProtectionFlags Seg) override {
      auto I = HostAllocs.find(Seg);
      assert(I != HostAllocs.end() && "No host allocation for segment");
      auto &HA = I->second;
      return {HA.Mem.get(), HA.Size};
    }

    JITTargetAddress getTargetMemory(ProtectionFlags Seg) override {
      auto I = TargetAllocs.find(Seg);
      assert(I != TargetAllocs.end() && "No target allocation for segment");
      return I->second.Address;
    }

    void finalizeAsync(FinalizeContinuation OnFinalize) override {

      std::vector<tpctypes::BufferWrite> BufferWrites;
      orcrpctpc::ReleaseOrFinalizeMemRequest FMR;

      // dbgs() << "Writing...\n";
      for (auto &KV : HostAllocs) {
        assert(TargetAllocs.count(KV.first) &&
               "No target allocation for buffer");
        auto &HA = KV.second;
        auto &TA = TargetAllocs[KV.first];
        BufferWrites.push_back({TA.Address, StringRef(HA.Mem.get(), HA.Size)});
        FMR.push_back({orcrpctpc::toWireProtectionFlags(
                           static_cast<sys::Memory::ProtectionFlags>(KV.first)),
                       TA.Address, TA.AllocatedSize});
      }

      if (auto Err =
              Parent.Parent.getMemoryAccess().writeBuffers(BufferWrites)) {
        OnFinalize(std::move(Err));
        return;
      }

      // dbgs() << "Finalizing...\n";
      if (auto Err =
              Parent.getEndpoint().template callAsync<orcrpctpc::FinalizeMem>(
                  [OF = std::move(OnFinalize)](Error Err2) {
                    // FIXME: Dispatch to work queue.
                    std::thread([OF = std::move(OF),
                                 Err3 = std::move(Err2)]() mutable {
                      OF(std::move(Err3));
                    }).detach();
                    return Error::success();
                  },
                  FMR)) {
        // dbgs() << "finalizing failed.\n";
        Parent.getEndpoint().abandonPendingResponses();
        Parent.reportError(std::move(Err));
      }
      // dbgs() << "finalized.\n";
    }

    Error deallocate() override {
      orcrpctpc::ReleaseOrFinalizeMemRequest RMR;
      for (auto &KV : TargetAllocs)
        RMR.push_back({orcrpctpc::toWireProtectionFlags(
                           static_cast<sys::Memory::ProtectionFlags>(KV.first)),
                       KV.second.Address, KV.second.AllocatedSize});
      TargetAllocs.clear();

      return Parent.getEndpoint().template callB<orcrpctpc::ReleaseMem>(RMR);
    }

  private:
    OrcRPCTPCJITLinkMemoryManager<OrcRPCTPCImplT> &Parent;
    HostAllocMap HostAllocs;
    TargetAllocMap TargetAllocs;
  };

  OrcRPCTPCJITLinkMemoryManager(OrcRPCTPCImplT &Parent) : Parent(Parent) {}

  Expected<std::unique_ptr<Allocation>>
  allocate(const SegmentsRequestMap &Request) override {
    orcrpctpc::ReserveMemRequest RMR;
    HostAllocMap HostAllocs;

    for (auto &KV : Request) {
      RMR.push_back({orcrpctpc::toWireProtectionFlags(
                         static_cast<sys::Memory::ProtectionFlags>(KV.first)),
                     KV.second.getContentSize() + KV.second.getZeroFillSize(),
                     KV.second.getAlignment()});
      HostAllocs[KV.first] = {
          std::make_unique<char[]>(KV.second.getContentSize()),
          KV.second.getContentSize()};
    }

    // FIXME: LLVM RPC needs to be fixed to support alt
    // serialization/deserialization on return types. For now just
    // translate from std::map to DenseMap manually.
    auto TmpTargetAllocs =
        Parent.getEndpoint().template callB<orcrpctpc::ReserveMem>(RMR);
    if (!TmpTargetAllocs)
      return TmpTargetAllocs.takeError();

    if (TmpTargetAllocs->size() != RMR.size())
      return make_error<StringError>(
          "Number of target allocations does not match request",
          inconvertibleErrorCode());

    TargetAllocMap TargetAllocs;
    for (auto &E : *TmpTargetAllocs)
      TargetAllocs[orcrpctpc::fromWireProtectionFlags(E.Prot)] = {
          E.Address, E.AllocatedSize};

    return std::make_unique<OrcRPCAllocation>(*this, std::move(HostAllocs),
                                              std::move(TargetAllocs));
  }

private:
  void reportError(Error Err) { Parent.reportError(std::move(Err)); }

  decltype(std::declval<OrcRPCTPCImplT>().getEndpoint()) getEndpoint() {
    return Parent.getEndpoint();
  }

  OrcRPCTPCImplT &Parent;
};

/// TargetProcessControl::MemoryAccess implementation for a process connected
/// via an ORC RPC endpoint.
template <typename OrcRPCTPCImplT>
class OrcRPCTPCMemoryAccess : public TargetProcessControl::MemoryAccess {
public:
  OrcRPCTPCMemoryAccess(OrcRPCTPCImplT &Parent) : Parent(Parent) {}

  void writeUInt8s(ArrayRef<tpctypes::UInt8Write> Ws,
                   WriteResultFn OnWriteComplete) override {
    writeViaRPC<orcrpctpc::WriteUInt8s>(Ws, std::move(OnWriteComplete));
  }

  void writeUInt16s(ArrayRef<tpctypes::UInt16Write> Ws,
                    WriteResultFn OnWriteComplete) override {
    writeViaRPC<orcrpctpc::WriteUInt16s>(Ws, std::move(OnWriteComplete));
  }

  void writeUInt32s(ArrayRef<tpctypes::UInt32Write> Ws,
                    WriteResultFn OnWriteComplete) override {
    writeViaRPC<orcrpctpc::WriteUInt32s>(Ws, std::move(OnWriteComplete));
  }

  void writeUInt64s(ArrayRef<tpctypes::UInt64Write> Ws,
                    WriteResultFn OnWriteComplete) override {
    writeViaRPC<orcrpctpc::WriteUInt64s>(Ws, std::move(OnWriteComplete));
  }

  void writeBuffers(ArrayRef<tpctypes::BufferWrite> Ws,
                    WriteResultFn OnWriteComplete) override {
    writeViaRPC<orcrpctpc::WriteBuffers>(Ws, std::move(OnWriteComplete));
  }

private:
  template <typename WriteRPCFunction, typename WriteElementT>
  void writeViaRPC(ArrayRef<WriteElementT> Ws, WriteResultFn OnWriteComplete) {
    if (auto Err = Parent.getEndpoint().template callAsync<WriteRPCFunction>(
            [OWC = std::move(OnWriteComplete)](Error Err2) mutable -> Error {
              OWC(std::move(Err2));
              return Error::success();
            },
            Ws)) {
      Parent.reportError(std::move(Err));
      Parent.getEndpoint().abandonPendingResponses();
    }
  }

  OrcRPCTPCImplT &Parent;
};

// TargetProcessControl for a process connected via an ORC RPC Endpoint.
template <typename RPCEndpointT>
class OrcRPCTargetProcessControlBase : public TargetProcessControl {
public:
  using ErrorReporter = unique_function<void(Error)>;

  using OnCloseConnectionFunction = unique_function<Error(Error)>;

  OrcRPCTargetProcessControlBase(std::shared_ptr<SymbolStringPool> SSP,
                                 RPCEndpointT &EP, ErrorReporter ReportError)
      : TargetProcessControl(std::move(SSP)),
        ReportError(std::move(ReportError)), EP(EP) {}

  void reportError(Error Err) { ReportError(std::move(Err)); }

  RPCEndpointT &getEndpoint() { return EP; }

  Expected<tpctypes::DylibHandle> loadDylib(const char *DylibPath) override {
    if (!DylibPath)
      DylibPath = "";
    return EP.template callB<orcrpctpc::LoadDylib>(DylibPath);
  }

  Expected<std::vector<tpctypes::LookupResult>>
  lookupSymbols(ArrayRef<tpctypes::LookupRequest> Request) override {
    std::vector<orcrpctpc::RemoteLookupRequest> RR;
    for (auto &E : Request) {
      RR.push_back({});
      RR.back().first = E.Handle;
      for (auto &KV : E.Symbols)
        RR.back().second.push_back(
            {(*KV.first).str(),
             KV.second == SymbolLookupFlags::WeaklyReferencedSymbol});
    }

    return EP.template callB<orcrpctpc::LookupSymbols>(RR);
  }

  Expected<int32_t> runAsMain(JITTargetAddress MainFnAddr,
                              ArrayRef<std::string> Args) override {
    return EP.template callB<orcrpctpc::RunMain>(MainFnAddr, Args);
  }

  Expected<tpctypes::WrapperFunctionResult>
  runWrapper(JITTargetAddress WrapperFnAddr,
             ArrayRef<uint8_t> ArgBuffer) override {
    // dbgs() << "Calling runWrapper...\n";
    auto Result =
        EP.template callB<orcrpctpc::RunWrapper>(WrapperFnAddr, ArgBuffer);
    // dbgs() << "Returned from runWrapper...\n";
    return Result;
  }

  Error closeConnection(OnCloseConnectionFunction OnCloseConnection) {
    return EP.template callAsync<orcrpctpc::CloseConnection>(
        std::move(OnCloseConnection));
  }

  Error closeConnectionAndWait() {
    std::promise<MSVCPError> P;
    auto F = P.get_future();
    if (auto Err = closeConnection([&](Error Err2) -> Error {
          P.set_value(std::move(Err2));
          return Error::success();
        })) {
      EP.abandonAllPendingResponses();
      return joinErrors(std::move(Err), F.get());
    }
    return F.get();
  }

protected:
  /// Subclasses must call this during construction to initialize the
  /// TargetTriple and PageSize members.
  Error initializeORCRPCTPCBase() {
    if (auto TripleOrErr = EP.template callB<orcrpctpc::GetTargetTriple>())
      TargetTriple = Triple(*TripleOrErr);
    else
      return TripleOrErr.takeError();

    if (auto PageSizeOrErr = EP.template callB<orcrpctpc::GetPageSize>())
      PageSize = *PageSizeOrErr;
    else
      return PageSizeOrErr.takeError();

    return Error::success();
  }

private:
  ErrorReporter ReportError;
  RPCEndpointT &EP;
};

} // end namespace orc
} // end namespace llvm

#endif // LLVM_EXECUTIONENGINE_ORC_ORCRPCTARGETPROCESSCONTROL_H
