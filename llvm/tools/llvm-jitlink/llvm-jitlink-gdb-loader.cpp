#include "llvm-jitlink-gdb-loader.h"

#include "llvm/Support/ManagedStatic.h"

#include <cstdint>
#include <mutex>

#define DEBUG_TYPE "llvm_jitlink"

using namespace llvm::object;

// This must be kept in sync with gdb/gdb/jit.h .
extern "C" {

typedef enum {
  JIT_NOACTION = 0,
  JIT_REGISTER_FN,
  JIT_UNREGISTER_FN
} jit_actions_t;

struct jit_code_entry {
  struct jit_code_entry *next_entry;
  struct jit_code_entry *prev_entry;
  const char *symfile_addr;
  uint64_t symfile_size;
};

struct jit_descriptor {
  uint32_t version;
  // This should be jit_actions_t, but we want to be specific about the
  // bit-width.
  uint32_t action_flag;
  struct jit_code_entry *relevant_entry;
  struct jit_code_entry *first_entry;
};

// We put information about the JITed function in this global, which the
// debugger reads.  Make sure to specify the version statically, because the
// debugger checks the version before we can set it during runtime.
struct jit_descriptor __jit_debug_descriptor = {1, 0, nullptr, nullptr};

// Debuggers that implement the GDB JIT interface put a special breakpoint in
// this function.
LLVM_ATTRIBUTE_NOINLINE void __jit_debug_register_code() {
  // The noinline and the asm prevent calls to this function from being
  // optimized out.
#if !defined(_MSC_VER)
  asm volatile("" ::: "memory");
#endif
}
}

namespace llvm {
namespace orc {

// Serialize rendezvous as well as access to shared data globally.
ManagedStatic<std::mutex> JITDebugLock;

// Append an entry to the list in the JIT descriptor symbol and call the debug
// trap function. TODO: Implement removal.
void AppendJITCodeEntry(const char *DebugObj, uint64_t DebugObjSize) {
  std::lock_guard<std::mutex> Lock(*JITDebugLock);

  jit_code_entry *JITCodeEntry = new jit_code_entry;
  JITCodeEntry->symfile_addr = DebugObj;
  JITCodeEntry->symfile_size = DebugObjSize;

  // Insert this entry at the head of the list.
  JITCodeEntry->prev_entry = nullptr;
  jit_code_entry *NextEntry = __jit_debug_descriptor.first_entry;
  JITCodeEntry->next_entry = NextEntry;
  if (NextEntry) {
    NextEntry->prev_entry = JITCodeEntry;
  }

  __jit_debug_descriptor.first_entry = JITCodeEntry;
  __jit_debug_descriptor.relevant_entry = JITCodeEntry;
}

void NotifyDebugger(jit_actions_t Action) {
  std::lock_guard<std::mutex> Lock(*JITDebugLock);
  __jit_debug_descriptor.action_flag = Action;
  __jit_debug_register_code();
}

class LoadedObjectView {
public:
  virtual ~LoadedObjectView(){};
  virtual void
  submitSectionLoadAddress(StringRef Name,
                           JITTargetAddress AddrInTargetMemory) = 0;
  virtual void dumpSectionLoadAddresses(raw_ostream &OS) = 0;
};

template <typename ELFT> class ELFLoadedObjectView : public LoadedObjectView {
  using SectionHeader = typename ELFT::Shdr;

  static bool isSectionTextOrData(unsigned Type, unsigned Flags) {
    switch (Type) {
    case ELF::SHT_PROGBITS:
    case ELF::SHT_X86_64_UNWIND:
      return Flags & (ELF::SHF_EXECINSTR | ELF::SHF_ALLOC);
    }
    return false;
  }

public:
  static Expected<std::unique_ptr<ELFLoadedObjectView<ELFT>>>
  Create(MutableArrayRef<char> Buffer) {
    Expected<std::unique_ptr<ObjectFile>> ObjFile =
        object::ObjectFile::createELFObjectFile(MemoryBufferRef(
            StringRef(Buffer.data(), Buffer.size()), "ELFLoadedObjectView"));
    if (!ObjFile)
      return ObjFile.takeError();

    auto &ELFObjFile = cast<object::ELFObjectFile<ELFT>>(**ObjFile);
    const ELFFile<ELFT> &ELFFile = ELFObjFile.getELFFile();

    Expected<ArrayRef<SectionHeader>> Sections = ELFFile.sections();
    if (!Sections)
      return Sections.takeError();

    auto ObjView = std::make_unique<ELFLoadedObjectView<ELFT>>();
    for (const SectionHeader &Section : *Sections) {
      Expected<StringRef> Name = ELFFile.getSectionName(Section);
      if (!Name)
        consumeError(Name.takeError());
      if (!Name || Name->empty())
        continue;
      if (!isSectionTextOrData(Section.sh_type, Section.sh_flags))
        continue;

      assert((const char *)&Section >= Buffer.data() &&
             (const char *)&Section < Buffer.data() + Buffer.size() &&
             "Section header outside memory range of given buffer");
      ObjView->SectionHeaders[*Name] = const_cast<SectionHeader *>(&Section);
    }

    return std::move(ObjView);
  }

  void submitSectionLoadAddress(StringRef Name,
                                JITTargetAddress AddrInTargetMemory) override {
    auto It = SectionHeaders.find(Name);
    if (It != SectionHeaders.end()) {
      SectionHeader *Section = It->second;
      Section->sh_addr = static_cast<typename ELFT::uint>(AddrInTargetMemory);
    }
  }

  void dumpSectionLoadAddresses(raw_ostream &OS) override {
    for (const auto &KV : SectionHeaders) {
      if (auto Addr = static_cast<JITTargetAddress>(KV.second->sh_addr)) {
        OS << formatv("  {0:x16} {1}\n", Addr, KV.first());
      } else {
        OS << formatv("                     {0}\n", KV.first());
      }
    }
  }

private:
  StringMap<SectionHeader *> SectionHeaders;
};

static Expected<std::unique_ptr<LoadedObjectView>>
createLoadedObjectELF(unsigned char Class, unsigned char Endian,
                      MutableArrayRef<char> Buffer) {
  if (Class == ELF::ELFCLASS32) {
    if (Endian == ELF::ELFDATA2LSB)
      return ELFLoadedObjectView<ELF32LE>::Create(Buffer);
    if (Endian == ELF::ELFDATA2MSB)
      return ELFLoadedObjectView<ELF32BE>::Create(Buffer);
    return nullptr;
  }
  if (Class == ELF::ELFCLASS64) {
    if (Endian == ELF::ELFDATA2LSB)
      return ELFLoadedObjectView<ELF64LE>::Create(Buffer);
    if (Endian == ELF::ELFDATA2MSB)
      return ELFLoadedObjectView<ELF64BE>::Create(Buffer);
    return nullptr;
  }
  return nullptr;
}

static Expected<std::unique_ptr<LoadedObjectView>>
createLoadedObject(const Triple &TT, MutableArrayRef<char> Buffer) {
  switch (TT.getObjectFormat()) {
  case Triple::ELF: {
    auto Ident = getElfArchType(StringRef(Buffer.data(), Buffer.size()));
    return createLoadedObjectELF(Ident.first, Ident.second, Buffer);
  }
  default:
    // TODO: Add debug support for other formats.
    return nullptr;
  }
}

ResourceKey
JITLoaderGDBPlugin::getResourceKey(MaterializationResponsibility &MR) {
  ResourceKey Key;
  if (auto Err = MR.withResourceKeyDo([&](ResourceKey K) { Key = K; })) {
    MR.getExecutionSession().reportError(std::move(Err));
    return ResourceKey{};
  }
  assert(Key && "Invalid key value");
  return Key;
}

void JITLoaderGDBPlugin::notifyMaterializing(
    MaterializationResponsibility &MR, const jitlink::LinkGraph &G,
    const jitlink::JITLinkContext &Ctx) {

  std::lock_guard<std::mutex> Lock(DebugAllocLock);

  // We should never have more than one pending debug object.
  ResourceKey Key = getResourceKey(MR);
  auto It = PendingDebugAllocs.find(Key);
  if (It != PendingDebugAllocs.end()) {
    ES.reportError(make_error<StringError>(
        formatv("Materializing new LinkGraph '{0}' for pending resource: {1}",
                G.getName(), Key),
        inconvertibleErrorCode()));
    return;
  }

  Expected<DebugAllocation> Alloc = Ctx.allocateDebugObj(ReadOnlySegment);
  if (!Alloc) {
    ES.reportError(Alloc.takeError());
    return;
  }

  // Not all linker artifacts support debugging.
  if (*Alloc)
    PendingDebugAllocs[Key] = std::move(*Alloc);
}

void JITLoaderGDBPlugin::modifyPassConfig(
    MaterializationResponsibility &MR, const Triple &TT,
    jitlink::PassConfiguration &PassConfig) {

  std::lock_guard<std::mutex> Lock(DebugAllocLock);

  // We allocate debug objects for LinkGraphs built from an object file.
  // We cannot synthesize debug objects for raw LinkGraphs yet.
  auto It = PendingDebugAllocs.find(getResourceKey(MR));
  if (It == PendingDebugAllocs.end())
    return;

  Expected<std::unique_ptr<LoadedObjectView>> ObjView =
      createLoadedObject(TT, It->second->getWorkingMemory(ReadOnlySegment));
  if (!ObjView) {
    ES.reportError(ObjView.takeError());
    return;
  }

  if (*ObjView) {
    PassConfig.PostAllocationPasses.push_back(
        [OV = ObjView->release()](jitlink::LinkGraph &Graph) -> Error {
          std::unique_ptr<LoadedObjectView> ObjView(OV);

          // Enter load addresses in target memory for all executable sections.
          for (const jitlink::Section &Section : Graph.sections()) {
            jitlink::SectionRange TargetMemRange(Section);
            if (!TargetMemRange.isEmpty())
              ObjView->submitSectionLoadAddress(Section.getName(),
                                                TargetMemRange.getStart());
          }

          LLVM_DEBUG({
            dbgs() << formatv("Section load-addresses in debug object {0:x}\n",
                              pointerToJITTargetAddress(ObjView.get()));
            ObjView->dumpSectionLoadAddresses(dbgs());
          });

          return Error::success();
        });
  }
}

Error JITLoaderGDBPlugin::notifyFailed(MaterializationResponsibility &MR) {
  // TODO: Drop DebugAlloc for MR?
  return Error::success();
}

void JITLoaderGDBPlugin::notifyLoaded(MaterializationResponsibility &MR) {
  ResourceKey Key = getResourceKey(MR);
  DebugAllocation Alloc = nullptr;
  {
    std::unique_lock<std::mutex> Lock(DebugAllocLock);
    auto It = PendingDebugAllocs.find(Key);
    if (It != PendingDebugAllocs.end()) {
      Alloc = std::move(It->second);
      PendingDebugAllocs.erase(It);
    }
  }

  if (Alloc)
    Alloc->finalizeAsync([this, Key, RawAlloc = Alloc.release()](Error Unused) {
      DebugAllocation Alloc(RawAlloc);

      // TODO: Move to TargetProcessControl for out-of-process execution.
      uint64_t DebugObjSize = Alloc->getWorkingMemory(ReadOnlySegment).size();
      const char *DebugObjInTargetMemory =
          jitTargetAddressToPointer<const char *>(
              Alloc->getTargetMemory(ReadOnlySegment));

      AppendJITCodeEntry(DebugObjInTargetMemory, DebugObjSize);
      NotifyDebugger(JIT_REGISTER_FN);

      std::lock_guard<std::mutex> Lock(DebugAllocLock);
      DebugAllocs[Key].push_back(std::move(Alloc));

      consumeError(std::move(Unused));
    });
}

void JITLoaderGDBPlugin::notifyTransferringResources(ResourceKey DstKey,
                                                     ResourceKey SrcKey) {
  std::lock_guard<std::mutex> Lock(DebugAllocLock);

  // Transfer registered debug objects.
  auto SrcIt = DebugAllocs.find(SrcKey);
  if (SrcIt != DebugAllocs.end()) {
    auto DstIt = DebugAllocs.find(DstKey);
    if (DstIt == DebugAllocs.end()) {
      bool Inserted;
      std::tie(DstIt, Inserted) = DebugAllocs.try_emplace(DstKey);
    }

    for (DebugAllocation &Alloc : SrcIt->second) {
      DstIt->second.push_back(std::move(Alloc));
    }
  }

  // Transfer pending debug objects.
  auto SrcItPending = PendingDebugAllocs.find(SrcKey);
  if (SrcItPending != PendingDebugAllocs.end()) {
    if (PendingDebugAllocs.count(DstKey)) {
      ES.reportError(make_error<StringError>(
          formatv("Destination '{0}' for transferring pending debug object has "
                  "a pending resource already: {1}",
                  DstKey, SrcKey),
          inconvertibleErrorCode()));
    } else {
      PendingDebugAllocs[DstKey] = std::move(SrcItPending->second);
    }
  }
}

Error JITLoaderGDBPlugin::notifyRemovingResources(ResourceKey K) {
  std::lock_guard<std::mutex> Lock(DebugAllocLock);

  auto It = DebugAllocs.find(K);
  if (It != DebugAllocs.end()) {
    // TODO: Unregister submitted JITCodeEntries.
    DebugAllocs.erase(K);
  }

  if (PendingDebugAllocs.find(K) != PendingDebugAllocs.end())
    PendingDebugAllocs.erase(K);

  return Error::success();
}

} // namespace orc
} // namespace llvm
