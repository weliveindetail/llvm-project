#ifndef LLVM_TOOLS_LLVM_JITLINK_JITLINKGDBLOADERPLUGIN_H
#define LLVM_TOOLS_LLVM_JITLINK_JITLINKGDBLOADERPLUGIN_H

#include "llvm/ExecutionEngine/Orc/ObjectLinkingLayer.h"

#include "llvm/ADT/DenseMap.h"
#include "llvm/ExecutionEngine/Orc/Core.h"
#include "llvm/ExecutionEngine/Orc/ObjectLinkingLayer.h"
#include "llvm/Object/ObjectFile.h"
#include "llvm/Support/MemoryBuffer.h"

#include <memory>

namespace llvm {

struct jit_code_entry;

class JITLinkGDBLoaderPlugin : public orc::ObjectLinkingLayer::Plugin {

  struct RegisteredObjectInfo {
    jit_code_entry *Entry;
    std::unique_ptr<MemoryBuffer> ObjBuffer;
  };

  using RegisteredObjectsList = std::vector<RegisteredObjectInfo>;
  using GetDebugObjCallback = orc::ObjectLinkingLayer::GetDebugObjCallback;

public:
  void notifyLoaded(orc::MaterializationResponsibility &MR,
                    GetDebugObjCallback GetDebugObj) override;

  Error notifyFailed(orc::MaterializationResponsibility &MR) override {
    return Error::success();
  }
  Error notifyRemovingResources(orc::ResourceKey K) override {
    return Error::success();
  }
  void notifyTransferringResources(orc::ResourceKey DstKey,
                                   orc::ResourceKey SrcKey) override {}

private:
  DenseMap<orc::ResourceKey, RegisteredObjectsList> RegisteredObjectsMap;
};

} // namespace llvm

#endif // LLVM_TOOLS_LLVM_JITLINK_JITLINKGDBLOADERPLUGIN_H
