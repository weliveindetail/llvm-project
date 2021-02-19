#ifndef LLVM_TOOLS_LLVM_JITLINK_JITLINKGDBLOADERPLUGIN_H
#define LLVM_TOOLS_LLVM_JITLINK_JITLINKGDBLOADERPLUGIN_H

#include "llvm/ExecutionEngine/Orc/ObjectLinkingLayer.h"

#include "llvm/ADT/DenseMap.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/ExecutionEngine/JITLink/JITLink.h"
#include "llvm/ExecutionEngine/JITLink/JITLinkMemoryManager.h"
#include "llvm/ExecutionEngine/JITSymbol.h"
#include "llvm/ExecutionEngine/Orc/Core.h"
#include "llvm/ExecutionEngine/Orc/ObjectLinkingLayer.h"
#include "llvm/Object/ELFObjectFile.h"
#include "llvm/Object/ObjectFile.h"
#include "llvm/Support/Error.h"
#include "llvm/Support/MemoryBuffer.h"

#include <memory>
#include <mutex>

struct jit_code_entry;

namespace llvm {
namespace orc {

class JITLoaderGDBPlugin : public ObjectLinkingLayer::Plugin {
  using DebugAllocation =
      std::unique_ptr<jitlink::JITLinkMemoryManager::Allocation>;

  static constexpr sys::Memory::ProtectionFlags ReadOnlySegment =
      static_cast<sys::Memory::ProtectionFlags>(sys::Memory::MF_READ);

public:
  JITLoaderGDBPlugin(ExecutionSession &ES) : ES(ES) {}

  void notifyMaterializing(MaterializationResponsibility &MR,
                           const jitlink::LinkGraph &G,
                           const jitlink::JITLinkContext &Ctx) override;

  void notifyLoaded(MaterializationResponsibility &MR) override;
  Error notifyFailed(MaterializationResponsibility &MR) override;
  Error notifyRemovingResources(ResourceKey K) override;

  void notifyTransferringResources(ResourceKey DstKey,
                                   ResourceKey SrcKey) override;

  void modifyPassConfig(MaterializationResponsibility &MR, const Triple &TT,
                        jitlink::PassConfiguration &PassConfig) override;

private:
  ExecutionSession &ES;
  std::mutex DebugAllocLock;
  DenseMap<ResourceKey, std::vector<DebugAllocation>> DebugAllocs;
  DenseMap<ResourceKey, DebugAllocation> PendingDebugAllocs;

  static ResourceKey getResourceKey(MaterializationResponsibility &MR);
};

} // namespace orc
} // namespace llvm

#endif // LLVM_TOOLS_LLVM_JITLINK_JITLINKGDBLOADERPLUGIN_H
