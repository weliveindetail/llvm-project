//===----- TPCDebugObjectRegistrar.cpp - TPC-based debug registration -----===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "llvm/ExecutionEngine/Orc/TPCDebugObjectRegistrar.h"

#include "llvm/ExecutionEngine/Orc/Core.h"
#include "llvm/ExecutionEngine/Orc/TargetProcess/JITLoaderGDB.h"
#include "llvm/Support/BinaryStreamWriter.h"

namespace llvm {
namespace orc {

Expected<std::unique_ptr<TPCDebugObjectRegistrar>>
createJITLoaderGDBRegistrar(ExecutionSession &ES) {
  auto &TPC = ES.getTargetProcessControl();
  auto ProcessHandle = TPC.loadDylib(nullptr);
  if (!ProcessHandle)
    return ProcessHandle.takeError();

  SymbolStringPtr RegisterFn =
      TPC.getTargetTriple().isOSBinFormatMachO()
          ? TPC.intern("_llvm_orc_registerJITLoaderGDBWrapper")
          : TPC.intern("llvm_orc_registerJITLoaderGDBWrapper");

  SymbolLookupSet RegistrationSymbols;
  RegistrationSymbols.add(RegisterFn);

  auto Result = TPC.lookupSymbols({{*ProcessHandle, RegistrationSymbols}});
  if (!Result)
    return Result.takeError();

  assert(Result->size() == 1 && "Unexpected number of dylibs in result");
  assert((*Result)[0].size() == 1 &&
         "Unexpected number of addresses in result");

  return std::make_unique<TPCDebugObjectRegistrar>(ES, (*Result)[0][0]);
}

Error TPCDebugObjectRegistrar::registerDebugObject(sys::MemoryBlock TargetMem) {
  return WrapperFunction<void(SPSTargetAddress, uint64_t)>::call(
      TPCCaller(ES.getTargetProcessControl(), RegisterFn),
      pointerToJITTargetAddress(TargetMem.base()),
      static_cast<uint64_t>(TargetMem.allocatedSize()));
}

} // namespace orc
} // namespace llvm
