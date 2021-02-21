//===----------- DebugSupport.cpp - JITLink debug utils ---------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "llvm/ExecutionEngine/JITLink/DebugSupport.h"

#include "llvm/ADT/ArrayRef.h"
#include "llvm/ADT/StringMap.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/BinaryFormat/ELF.h"
#include "llvm/ExecutionEngine/JITLink/JITLinkDylib.h"
#include "llvm/ExecutionEngine/JITLink/JITLinkMemoryManager.h"
#include "llvm/ExecutionEngine/JITSymbol.h"
#include "llvm/Object/ELFObjectFile.h"
#include "llvm/Object/ObjectFile.h"
#include "llvm/Support/Process.h"
#include "llvm/Support/raw_ostream.h"

#include <set>

#define DEBUG_TYPE "jitlink"

using namespace llvm::object;

namespace llvm {
namespace jitlink {

static constexpr sys::Memory::ProtectionFlags ReadOnlyFlag =
    static_cast<sys::Memory::ProtectionFlags>(sys::Memory::MF_READ);

static const std::set<StringRef> DwarfSectionNames = {
#define HANDLE_DWARF_SECTION(ENUM_NAME, ELF_NAME, CMDLINE_NAME, OPTION)        \
  ELF_NAME,
#include "llvm/BinaryFormat/Dwarf.def"
#undef HANDLE_DWARF_SECTION
};

static bool isDwarfSection(StringRef SectionName) {
  return DwarfSectionNames.count(SectionName) == 1;
}

class ReadOnlySegment {
  using Allocation = JITLinkMemoryManager::Allocation;

public:
  ReadOnlySegment(JITLinkMemoryManager &MemMgr, const JITLinkDylib *JD)
      : MemMgr(MemMgr), JD(JD), Alloc(nullptr) {}

  Error initialize(std::unique_ptr<WritableMemoryBuffer> DebugObj) {
    // TODO: This works, but what actual alignment requirements do we have?
    unsigned Alignment = sys::Process::getPageSizeEstimate();
    size_t Size = DebugObj->getBufferSize();

    // Allocate working memory for debug object in read-only segment.
    // TODO: Could we use the given buffer as working memory directly
    // and avoid the unnecessary copy below?
    Expected<std::unique_ptr<Allocation>> AllocOrErr =
        MemMgr.allocate(JD, {{ReadOnlyFlag, {Alignment, Size, 0}}});
    if (!AllocOrErr)
      return AllocOrErr.takeError();
    Alloc = std::move(*AllocOrErr);

    // Initialize working memory with a copy of the debug object.
    MutableArrayRef<char> DebugObjMem = Alloc->getWorkingMemory(ReadOnlyFlag);
    memcpy(DebugObjMem.data(), DebugObj->getBufferStart(), Size);

    return Error::success();
  }

  void finalizeAsync(Allocation::FinalizeContinuation OnFinalize) {
    Alloc->finalizeAsync(std::move(OnFinalize));
  }

  sys::MemoryBlock getTargetMemBlock() const {
    return sys::MemoryBlock(
        jitTargetAddressToPointer<void *>(Alloc->getTargetMemory(ReadOnlyFlag)),
        Alloc->getWorkingMemory(ReadOnlyFlag).size());
  }

private:
  JITLinkMemoryManager &MemMgr;
  const JITLinkDylib *JD;
  std::unique_ptr<Allocation> Alloc;
};

class DebugObjectSection {
public:
  virtual void setTargetMemoryRange(SectionRange Range) = 0;
  virtual void dump(raw_ostream &OS, StringRef Name) {}
  virtual ~DebugObjectSection() {}
};

template <typename ELFT>
class ELFDebugObjectSection : public DebugObjectSection {
public:
  // BinaryFormat ELF is not meant as a mutable format. We can only make changes
  // that don't invalidate the file structure.
  ELFDebugObjectSection(const typename ELFT::Shdr *Header)
      : Header(const_cast<typename ELFT::Shdr *>(Header)) {}

  void setTargetMemoryRange(SectionRange Range) override {
    // Only patch load-addresses for executable and data sections.
    if (isTextOrDataSection()) {
      Header->sh_addr = static_cast<typename ELFT::uint>(Range.getStart());
    }
  }

  void dump(raw_ostream &OS, StringRef Name) override {
    if (auto Addr = static_cast<JITTargetAddress>(Header->sh_addr)) {
      OS << formatv("  {0:x16} {1}\n", Addr, Name);
    } else {
      OS << formatv("                     {0}\n", Name);
    }
  }

private:
  typename ELFT::Shdr *Header;

  bool isTextOrDataSection() const {
    switch (Header->sh_type) {
    case ELF::SHT_PROGBITS:
    case ELF::SHT_X86_64_UNWIND:
      return Header->sh_flags & (ELF::SHF_EXECINSTR | ELF::SHF_ALLOC);
    }
    return false;
  }
};

template <typename ELFT> class ELFDebugObject : public DebugObject {
  using SectionHeader = typename ELFT::Shdr;

  ELFDebugObject(std::unique_ptr<llvm::WritableMemoryBuffer> Buffer,
                 ReadOnlySegment TargetSegment)
      : Buffer(std::move(Buffer)), Segment(std::move(TargetSegment)) {}

public:
  static Expected<std::unique_ptr<ELFDebugObject<ELFT>>>

  Create(std::unique_ptr<llvm::WritableMemoryBuffer> Buffer,
         ReadOnlySegment TargetSegment) {

    MutableArrayRef<char> B = Buffer->getBuffer();
    Expected<ELFFile<ELFT>> ObjRef =
        ELFFile<ELFT>::create(StringRef(B.data(), B.size()));
    if (!ObjRef)
      return ObjRef.takeError();

    Expected<ArrayRef<SectionHeader>> Sections = ObjRef->sections();
    if (!Sections)
      return Sections.takeError();

    std::unique_ptr<ELFDebugObject<ELFT>> DebugObj(
        new ELFDebugObject<ELFT>(std::move(Buffer), std::move(TargetSegment)));

    bool HasDwarfSection = false;
    for (const SectionHeader &Header : *Sections) {
      Expected<StringRef> Name = ObjRef->getSectionName(Header);
      if (!Name)
        return Name.takeError();
      if (Name->empty())
        continue;
      HasDwarfSection |= isDwarfSection(*Name);
      if (Error Err = DebugObj->recordSection(*Name, Header))
        return std::move(Err);
    }

    if (!HasDwarfSection) {
      LLVM_DEBUG(dbgs() << "Aborting debug registration for LinkGraph \""
                        << Buffer->getBufferIdentifier() + "\": "
                        << "input object contains no debug info\n");
      return nullptr;
    }

    return std::move(DebugObj);
  }

  Error recordSection(StringRef Name, const SectionHeader &Header) {
    auto WrappedHeader = std::make_unique<ELFDebugObjectSection<ELFT>>(&Header);
    auto ItInserted = Sections.try_emplace(Name, std::move(WrappedHeader));
    if (!ItInserted.second)
      return make_error<StringError>("Duplicate section",
                                     inconvertibleErrorCode());
    return Error::success();
  }

  DebugObjectSection *getSection(StringRef Name) {
    auto It = Sections.find(Name);
    return It == Sections.end() ? nullptr : It->second.get();
  }

  void modifyPassConfig(const Triple &TT,
                        PassConfiguration &PassConfig) override {
    PassConfig.PostAllocationPasses.push_back(
        [this](LinkGraph &Graph) -> Error {
          // Once target memory is allocated, report the final load-addresses
          // for all sections to the debug object.
          for (const Section &GraphSection : Graph.sections())
            if (auto *DebugObjSection = getSection(GraphSection.getName()))
              DebugObjSection->setTargetMemoryRange(GraphSection);

          return Error::success();
        });
  }

  void finalizeAsync(FinalizeContinuation OnFinalize) override {
    LLVM_DEBUG({
      dbgs() << "Section load-addresses in debug object for \""
             << Buffer->getBufferIdentifier() << "\":\n";
      for (const auto &KV : Sections)
        KV.second->dump(dbgs(), KV.first());
    });

    // Allocate target memory for the debug object, start copying over our
    // buffer and pass on the result once we're done.
    if (Error Err = Segment.initialize(std::move(Buffer))) {
      OnFinalize(std::move(Err));
      return;
    }

    Segment.finalizeAsync([this, OnFinalize](Error Err) {
      if (Err)
        OnFinalize(std::move(Err));
      else
        OnFinalize(Segment.getTargetMemBlock());
    });
  }

private:
  StringMap<std::unique_ptr<DebugObjectSection>> Sections;
  std::unique_ptr<llvm::WritableMemoryBuffer> Buffer;
  ReadOnlySegment Segment;
};

static Expected<std::unique_ptr<DebugObject>>
createDebugObjectELF(std::unique_ptr<llvm::WritableMemoryBuffer> Buf,
                     JITLinkContext &Ctx) {
  unsigned char Class, Endian;
  MutableArrayRef<char> B = Buf->getBuffer();
  std::tie(Class, Endian) = getElfArchType(StringRef(B.data(), B.size()));
  ReadOnlySegment Seg(Ctx.getMemoryManager(), Ctx.getJITLinkDylib());

  if (Class == ELF::ELFCLASS32) {
    if (Endian == ELF::ELFDATA2LSB)
      return ELFDebugObject<ELF32LE>::Create(std::move(Buf), std::move(Seg));
    if (Endian == ELF::ELFDATA2MSB)
      return ELFDebugObject<ELF32BE>::Create(std::move(Buf), std::move(Seg));
    return nullptr;
  }
  if (Class == ELF::ELFCLASS64) {
    if (Endian == ELF::ELFDATA2LSB)
      return ELFDebugObject<ELF64LE>::Create(std::move(Buf), std::move(Seg));
    if (Endian == ELF::ELFDATA2MSB)
      return ELFDebugObject<ELF64BE>::Create(std::move(Buf), std::move(Seg));
    return nullptr;
  }
  return nullptr;
}

Expected<std::unique_ptr<DebugObject>>
createDebugObjectFromBuffer(const Triple &TT, JITLinkContext &Ctx,
                            std::unique_ptr<llvm::WritableMemoryBuffer> Buf) {
  switch (TT.getObjectFormat()) {
  case Triple::ELF:
    return createDebugObjectELF(std::move(Buf), Ctx);

  default:
    // TODO: When adding support for other formats, make a new file for each.
    return nullptr;
  }
}

} // namespace jitlink
} // namespace llvm
