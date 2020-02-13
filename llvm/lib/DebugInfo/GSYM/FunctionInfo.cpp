//===- FunctionInfo.cpp ---------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "llvm/DebugInfo/GSYM/FunctionInfo.h"
#include "llvm/DebugInfo/GSYM/FileWriter.h"
#include "llvm/DebugInfo/GSYM/GsymReader.h"
#include "llvm/DebugInfo/GSYM/LineTable.h"
#include "llvm/DebugInfo/GSYM/InlineInfo.h"
#include "llvm/Support/DataExtractor.h"

using namespace llvm;
using namespace gsym;

/// FunctionInfo information type that is used to encode the optional data
/// that is associated with a FunctionInfo object.
enum InfoType : uint32_t {
  EndOfList = 0u,
  LineTableInfo = 1u,
  InlineInfo = 2u
};

raw_ostream &llvm::gsym::operator<<(raw_ostream &OS, const FunctionInfo &FI) {
  OS << FI.Range << ": " << "Name=" << HEX32(FI.Name) << '\n';
  if (FI.OptLineTable)
    OS << FI.OptLineTable << '\n';
  if (FI.Inline)
    OS << FI.Inline << '\n';
  return OS;
}

llvm::Expected<FunctionInfo> FunctionInfo::decode(DataExtractor &Data,
                                                  uint64_t BaseAddr) {
  FunctionInfo FI;
  FI.Range.Start = BaseAddr;
  uint64_t Offset = 0;
  if (!Data.isValidOffsetForDataOfSize(Offset, 4))
    return createStringError(std::errc::io_error,
        "0x%8.8" PRIx64 ": missing FunctionInfo Size", Offset);
  FI.Range.End = FI.Range.Start + Data.getU32(&Offset);
  if (!Data.isValidOffsetForDataOfSize(Offset, 4))
    return createStringError(std::errc::io_error,
        "0x%8.8" PRIx64 ": missing FunctionInfo Name", Offset);
  FI.Name = Data.getU32(&Offset);
  if (FI.Name == 0)
    return createStringError(std::errc::io_error,
        "0x%8.8" PRIx64 ": invalid FunctionInfo Name value 0x%8.8x",
        Offset - 4, FI.Name);
  bool Done = false;
  while (!Done) {
    if (!Data.isValidOffsetForDataOfSize(Offset, 4))
      return createStringError(std::errc::io_error,
          "0x%8.8" PRIx64 ": missing FunctionInfo InfoType value", Offset);
    const uint32_t IT = Data.getU32(&Offset);
    if (!Data.isValidOffsetForDataOfSize(Offset, 4))
      return createStringError(std::errc::io_error,
          "0x%8.8" PRIx64 ": missing FunctionInfo InfoType length", Offset);
    const uint32_t InfoLength = Data.getU32(&Offset);
    if (!Data.isValidOffsetForDataOfSize(Offset, InfoLength))
      return createStringError(std::errc::io_error,
          "0x%8.8" PRIx64 ": missing FunctionInfo data for InfoType %u",
          Offset, IT);
    DataExtractor InfoData(Data.getData().substr(Offset, InfoLength),
                           Data.isLittleEndian(),
                           Data.getAddressSize());
    switch (IT) {
      case InfoType::EndOfList:
        Done = true;
        break;

      case InfoType::LineTableInfo:
        if (Expected<LineTable> LT = LineTable::decode(InfoData, BaseAddr))
          FI.OptLineTable = std::move(LT.get());
        else
          return LT.takeError();
        break;

      case InfoType::InlineInfo:
        if (Expected<InlineInfo> II = InlineInfo::decode(InfoData, BaseAddr))
          FI.Inline = std::move(II.get());
        else
          return II.takeError();
        break;

      default:
        return createStringError(std::errc::io_error,
                                 "0x%8.8" PRIx64 ": unsupported InfoType %u",
                                 Offset-8, IT);
    }
    Offset += InfoLength;
  }
  return std::move(FI);
}

llvm::Expected<uint64_t> FunctionInfo::encode(FileWriter &O) const {
  if (!isValid())
    return createStringError(std::errc::invalid_argument,
        "attempted to encode invalid FunctionInfo object");
  // Align FunctionInfo data to a 4 byte alignment.
  O.alignTo(4);
  const uint64_t FuncInfoOffset = O.tell();
  // Write the size in bytes of this function as a uint32_t. This can be zero
  // if we just have a symbol from a symbol table and that symbol has no size.
  O.writeU32(size());
  // Write the name of this function as a uint32_t string table offset.
  O.writeU32(Name);

  if (OptLineTable.hasValue()) {
    O.writeU32(InfoType::LineTableInfo);
    // Write a uint32_t length as zero for now, we will fix this up after
    // writing the LineTable out with the number of bytes that were written.
    O.writeU32(0);
    const auto StartOffset = O.tell();
    llvm::Error err = OptLineTable->encode(O, Range.Start);
    if (err)
      return std::move(err);
    const auto Length = O.tell() - StartOffset;
    if (Length > UINT32_MAX)
        return createStringError(std::errc::invalid_argument,
            "LineTable length is greater than UINT32_MAX");
    // Fixup the size of the LineTable data with the correct size.
    O.fixup32(static_cast<uint32_t>(Length), StartOffset - 4);
  }

  // Write out the inline function info if we have any and if it is valid.
  if (Inline.hasValue()) {
    O.writeU32(InfoType::InlineInfo);
    // Write a uint32_t length as zero for now, we will fix this up after
    // writing the LineTable out with the number of bytes that were written.
    O.writeU32(0);
    const auto StartOffset = O.tell();
    llvm::Error err = Inline->encode(O, Range.Start);
    if (err)
      return std::move(err);
    const auto Length = O.tell() - StartOffset;
    if (Length > UINT32_MAX)
        return createStringError(std::errc::invalid_argument,
            "InlineInfo length is greater than UINT32_MAX");
    // Fixup the size of the InlineInfo data with the correct size.
    O.fixup32(static_cast<uint32_t>(Length), StartOffset - 4);
  }

  // Terminate the data chunks with and end of list with zero size
  O.writeU32(InfoType::EndOfList);
  O.writeU32(0);
  return FuncInfoOffset;
}


llvm::Expected<LookupResult> FunctionInfo::lookup(DataExtractor &Data,
                                                  const GsymReader &GR,
                                                  uint64_t FuncAddr,
                                                  uint64_t Addr) {
  LookupResult LR;
  LR.LookupAddr = Addr;
  LR.FuncRange.Start = FuncAddr;
  uint64_t Offset = 0;
  LR.FuncRange.End = FuncAddr + Data.getU32(&Offset);
  uint32_t NameOffset = Data.getU32(&Offset);
  // The "lookup" functions doesn't report errors as accurately as the "decode"
  // function as it is meant to be fast. For more accurage errors we could call
  // "decode".
  if (!Data.isValidOffset(Offset))
    return createStringError(std::errc::io_error,
                              "FunctionInfo data is truncated");
  // This function will be called with the result of a binary search of the
  // address table, we must still make sure the address does not fall into a
  // gap between functions are after the last function.
  if (Addr >= LR.FuncRange.End)
    return createStringError(std::errc::io_error,
        "address 0x%" PRIx64 " is not in GSYM", Addr);

  if (NameOffset == 0)
    return createStringError(std::errc::io_error,
        "0x%8.8" PRIx64 ": invalid FunctionInfo Name value 0x00000000",
        Offset - 4);
  LR.FuncName = GR.getString(NameOffset);
  bool Done = false;
  Optional<LineEntry> LineEntry;
  Optional<DataExtractor> InlineInfoData;
  while (!Done) {
    if (!Data.isValidOffsetForDataOfSize(Offset, 8))
      return createStringError(std::errc::io_error,
                               "FunctionInfo data is truncated");
    const uint32_t IT = Data.getU32(&Offset);
    const uint32_t InfoLength = Data.getU32(&Offset);
    const StringRef InfoBytes = Data.getData().substr(Offset, InfoLength);
    if (InfoLength != InfoBytes.size())
      return createStringError(std::errc::io_error,
                               "FunctionInfo data is truncated");
    DataExtractor InfoData(InfoBytes, Data.isLittleEndian(),
                           Data.getAddressSize());
    switch (IT) {
      case InfoType::EndOfList:
        Done = true;
        break;

      case InfoType::LineTableInfo:
        if (auto ExpectedLE = LineTable::lookup(InfoData, FuncAddr, Addr))
          LineEntry = ExpectedLE.get();
        else
          return ExpectedLE.takeError();
        break;

      case InfoType::InlineInfo:
        // We will parse the inline info after our line table, but only if
        // we have a line entry.
        InlineInfoData = InfoData;
        break;

      default:
        break;
    }
    Offset += InfoLength;
  }

  if (!LineEntry) {
    // We don't have a valid line entry for our address, fill in our source
    // location as best we can and return.
    SourceLocation SrcLoc;
    SrcLoc.Name = LR.FuncName;
    LR.Locations.push_back(SrcLoc);
    return LR;
  }

  Optional<FileEntry> LineEntryFile = GR.getFile(LineEntry->File);
  if (!LineEntryFile)
    return createStringError(std::errc::invalid_argument,
                              "failed to extract file[%" PRIu32 "]",
                              LineEntry->File);

  SourceLocation SrcLoc;
  SrcLoc.Name = LR.FuncName;
  SrcLoc.Dir = GR.getString(LineEntryFile->Dir);
  SrcLoc.Base = GR.getString(LineEntryFile->Base);
  SrcLoc.Line = LineEntry->Line;
  LR.Locations.push_back(SrcLoc);
  // If we don't have inline information, we are done.
  if (!InlineInfoData)
    return LR;
  // We have inline information. Try to augment the lookup result with this
  // data.
  llvm::Error Err = InlineInfo::lookup(GR, *InlineInfoData, FuncAddr, Addr,
                                       LR.Locations);
  if (Err)
    return std::move(Err);
  return LR;
}
