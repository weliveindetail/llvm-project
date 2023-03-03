//===-- LogChannelPDB.cpp -------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "LogChannelPDB.h"

using namespace lldb_private;

static constexpr Log::Category g_categories[] = {
    {{"lookups"},
     {"log any lookups that happen by name or address"},
     PDBLog::Lookups},
};

static Log::Channel g_channel(g_categories, PDBLog::Lookups);

template <> Log::Channel &lldb_private::LogChannelFor<PDBLog>() {
  return g_channel;
}

void LogChannelPDB::Initialize() {
  Log::Register("pdb", g_channel);
}

void LogChannelPDB::Terminate() { Log::Unregister("pdb"); }
