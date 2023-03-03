//===-- LogChannelPDB.h -----------------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLDB_SOURCE_PLUGINS_SYMBOLFILE_PDB_LOGCHANNELPDB_H
#define LLDB_SOURCE_PLUGINS_SYMBOLFILE_PDB_LOGCHANNELPDB_H

#include "lldb/Utility/Log.h"
#include "llvm/ADT/BitmaskEnum.h"

namespace lldb_private {

enum class PDBLog : Log::MaskType {
  Lookups = Log::ChannelFlag<0>,
  LLVM_MARK_AS_BITMASK_ENUM(Lookups)
};
LLVM_ENABLE_BITMASK_ENUMS_IN_NAMESPACE();

class LogChannelPDB {
public:
  static void Initialize();
  static void Terminate();
};

template <> Log::Channel &LogChannelFor<PDBLog>();
} // namespace lldb_private

#endif // LLDB_SOURCE_PLUGINS_SYMBOLFILE_PDB_LOGCHANNELPDB_H
