//===-- RemoteJITUtils.h - Utilities for remote-JITing ----------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Utilities for ExecutorProcessControl-based remote JITing with Orc and
// JITLink.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_EXAMPLES_ORCV2EXAMPLES_LLJITWITHREMOTEDEBUGGING_REMOTEJITUTILS_H
#define LLVM_EXAMPLES_ORCV2EXAMPLES_LLJITWITHREMOTEDEBUGGING_REMOTEJITUTILS_H

#include "llvm/ADT/FunctionExtras.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/ExecutionEngine/Orc/Core.h"
#include "llvm/Support/Error.h"

#include <memory>
#include <string>

namespace llvm {
namespace orc {

Expected<std::string> getLocalExecutor(std::string Hint, const char *HostArgv0);

Expected<std::unique_ptr<ExecutorProcessControl>>
launchSubprocess(StringRef ExecutablePath,
                 unique_function<void(Error)> ErrorReporter, int &ProcessID);

Expected<std::unique_ptr<ExecutorProcessControl>>
connectTCPSocket(StringRef NetworkAddress,
                 unique_function<void(Error)> ErrorReporter);

} // namespace orc
} // namespace llvm

#endif
