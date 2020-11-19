//===------ MachOPlatform.cpp - Utilities for executing MachO in Orc ------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "llvm/ExecutionEngine/Orc/MachOPlatform.h"

#include "llvm/BinaryFormat/MachO.h"
#include "llvm/ExecutionEngine/Orc/DebugUtils.h"
#include "llvm/Support/BinaryByteStream.h"
#include "llvm/Support/Debug.h"

#define DEBUG_TYPE "orc"

using namespace llvm;
using namespace llvm::orc;

namespace {

struct objc_class;
struct objc_image_info;
struct objc_object;
struct objc_selector;

using Class = objc_class *;
using id = objc_object *;
using SEL = objc_selector *;

using ObjCMsgSendTy = id (*)(id, SEL, ...);
using ObjCReadClassPairTy = Class (*)(Class, const objc_image_info *);
using SelRegisterNameTy = SEL (*)(const char *);

enum class ObjCRegistrationAPI { Uninitialized, Unavailable, Initialized };

ObjCRegistrationAPI ObjCRegistrationAPIState =
    ObjCRegistrationAPI::Uninitialized;
ObjCMsgSendTy objc_msgSend = nullptr;
ObjCReadClassPairTy objc_readClassPair = nullptr;
SelRegisterNameTy sel_registerName = nullptr;

class MachOHeaderMaterializationUnit : public MaterializationUnit {
public:

  MachOHeaderMaterializationUnit(MachOPlatform &MOP,
                                 const SymbolStringPtr &HeaderStartSymbol)
    : MaterializationUnit(createHeaderSymbols(MOP, HeaderStartSymbol),
                          HeaderStartSymbol),
      MOP(MOP) {
  }

  StringRef getName() const override { return "MachOHeaderMU"; }

  void materialize(std::unique_ptr<MaterializationResponsibility> R) override {
    unsigned PointerSize;
    support::endianness Endianness;

    switch (MOP.getTargetTriple().getArch()) {
    case Triple::aarch64:
    case Triple::x86_64:
      PointerSize = 8;
      Endianness = support::endianness::little;
      break;
    default:
      llvm_unreachable("Unrecognized architecture");
    }

    auto G =
      std::make_unique<jitlink::LinkGraph>("<MachOHeaderMU>",
                                           MOP.getTargetTriple(),
                                           PointerSize, Endianness);
    auto &HeaderSection = G->createSection("__header", sys::Memory::MF_READ);
    auto &HeaderBlock = createHeaderBlock(*G, HeaderSection);

    // Init symbol is header-start symbol.
    G->addDefinedSymbol(HeaderBlock, 0, *R->getInitializerSymbol(),
                        HeaderBlock.getSize(), jitlink::Linkage::Strong,
                        jitlink::Scope::Default, false, true);
    for (auto &HS : AdditionalHeaderSymbols)
      G->addDefinedSymbol(HeaderBlock, HS.Offset, HS.Name,
                          HeaderBlock.getSize(), jitlink::Linkage::Strong,
                          jitlink::Scope::Default, false, true);

    MOP.getObjectLinkingLayer().emit(std::move(R), std::move(G));
  }

  void discard(const JITDylib &JD, const SymbolStringPtr &Sym) override {}

private:

  struct HeaderSymbol {
    const char *Name;
    uint64_t Offset;
  };

  static constexpr HeaderSymbol AdditionalHeaderSymbols[] = {
    { "___mh_executable_header", 0 }
  };

  static jitlink::Block &createHeaderBlock(jitlink::LinkGraph &G,
                                           jitlink::Section &HeaderSection) {
    MachO::mach_header_64 Hdr;
    Hdr.magic = MachO::MH_MAGIC_64;
    switch (G.getTargetTriple().getArch()) {
    case Triple::aarch64:
      Hdr.cputype = MachO::CPU_TYPE_ARM64;
      Hdr.cpusubtype = MachO::CPU_SUBTYPE_ARM64_ALL;
      break;
    case Triple::x86_64:
      Hdr.cputype = MachO::CPU_TYPE_X86_64;
      Hdr.cpusubtype = MachO::CPU_SUBTYPE_X86_64_ALL;
      break;
    default:
      llvm_unreachable("Unrecognized architecture");
    }
    Hdr.filetype = MachO::MH_DYLIB; // Custom file type?
    Hdr.ncmds = 0;
    Hdr.sizeofcmds = 0;
    Hdr.flags = 0;
    Hdr.reserved = 0;

    if (G.getEndianness() != support::endian::system_endianness())
      MachO::swapStruct(Hdr);

    auto HeaderContent =
      G.allocateString(StringRef(reinterpret_cast<const char *>(&Hdr),
                                 sizeof(Hdr)));

    return G.createContentBlock(HeaderSection, HeaderContent, 0, 8, 0);
  }

  static SymbolFlagsMap createHeaderSymbols(
      MachOPlatform &MOP, const SymbolStringPtr &HeaderStartSymbol) {
    SymbolFlagsMap HeaderSymbolFlags;

    HeaderSymbolFlags[HeaderStartSymbol] = JITSymbolFlags::Exported;
    for (auto &HS : AdditionalHeaderSymbols)
      HeaderSymbolFlags[MOP.getExecutionSession().intern(HS.Name)] =
        JITSymbolFlags::Exported;

    return HeaderSymbolFlags;
  }

  MachOPlatform &MOP;
};

constexpr MachOHeaderMaterializationUnit::HeaderSymbol
    MachOHeaderMaterializationUnit::AdditionalHeaderSymbols[];

} // end anonymous namespace

namespace llvm {
namespace orc {

template <typename FnTy>
static Error setUpObjCRegAPIFunc(FnTy &Target, sys::DynamicLibrary &LibObjC,
                                 const char *Name) {
  if (void *Addr = LibObjC.getAddressOfSymbol(Name))
    Target = reinterpret_cast<FnTy>(Addr);
  else
    return make_error<StringError>(
        (Twine("Could not find address for ") + Name).str(),
        inconvertibleErrorCode());
  return Error::success();
}

Error enableObjCRegistration(const char *PathToLibObjC) {
  // If we've already tried to initialize then just bail out.
  if (ObjCRegistrationAPIState != ObjCRegistrationAPI::Uninitialized)
    return Error::success();

  ObjCRegistrationAPIState = ObjCRegistrationAPI::Unavailable;

  std::string ErrMsg;
  auto LibObjC =
      sys::DynamicLibrary::getPermanentLibrary(PathToLibObjC, &ErrMsg);

  if (!LibObjC.isValid())
    return make_error<StringError>(std::move(ErrMsg), inconvertibleErrorCode());

  if (auto Err = setUpObjCRegAPIFunc(objc_msgSend, LibObjC, "objc_msgSend"))
    return Err;
  if (auto Err = setUpObjCRegAPIFunc(objc_readClassPair, LibObjC,
                                     "objc_readClassPair"))
    return Err;
  if (auto Err =
          setUpObjCRegAPIFunc(sel_registerName, LibObjC, "sel_registerName"))
    return Err;

  ObjCRegistrationAPIState = ObjCRegistrationAPI::Initialized;
  return Error::success();
}

bool objCRegistrationEnabled() {
  return ObjCRegistrationAPIState == ObjCRegistrationAPI::Initialized;
}

Expected<std::unique_ptr<MachOPlatform>>
MachOPlatform::Create(ExecutionSession &ES, ObjectLinkingLayer &ObjLinkingLayer,
                      Triple TT) {
  if (!supportedTarget(TT))
    return make_error<StringError>("Unsupported MachOPlatform triple: " +
                                   TT.str(),
                                   inconvertibleErrorCode());
  return std::unique_ptr<MachOPlatform>(
    new MachOPlatform(ES, ObjLinkingLayer, std::move(TT)));
}

void MachOPlatform::runModInits(shared::MachOJITDylibInitializers &MOIs) const {
  for (const auto &ModInit : MOIs.getModInitsSections()) {
    for (uint64_t I = 0; I != ModInit.NumPtrs; ++I) {
      auto *InitializerAddr = jitTargetAddressToPointer<uintptr_t *>(
          ModInit.Address + (I * sizeof(uintptr_t)));
      auto *Initializer =
          jitTargetAddressToFunction<void (*)()>(*InitializerAddr);
      Initializer();
    }
  }
}

void MachOPlatform::registerObjCSelectors(
    shared::MachOJITDylibInitializers &MOIs) const {
  assert(objCRegistrationEnabled() && "ObjC registration not enabled.");

  for (const auto &ObjCSelRefs : MOIs.getObjCSelRefsSections()) {
    for (uint64_t I = 0; I != ObjCSelRefs.NumPtrs; ++I) {
      auto SelEntryAddr = ObjCSelRefs.Address + (I * sizeof(uintptr_t));
      const auto *SelName =
          *jitTargetAddressToPointer<const char **>(SelEntryAddr);
      auto Sel = sel_registerName(SelName);
      *jitTargetAddressToPointer<SEL *>(SelEntryAddr) = Sel;
    }
  }
}

Error MachOPlatform::registerObjCClasses(
    shared::MachOJITDylibInitializers &MOIs) const {
  assert(objCRegistrationEnabled() && "ObjC registration not enabled.");

  struct ObjCClassCompiled {
    void *Metaclass;
    void *Parent;
    void *Cache1;
    void *Cache2;
    void *Data;
  };

  auto *ImageInfo =
    jitTargetAddressToPointer<const objc_image_info *>(
        MOIs.getObjCImageInfoAddr());
  auto ClassSelector = sel_registerName("class");

  for (const auto &ObjCClassList : MOIs.getObjCClassListSections()) {
    for (uint64_t I = 0; I != ObjCClassList.NumPtrs; ++I) {
      auto ClassPtrAddr = ObjCClassList.Address + (I * sizeof(uintptr_t));
      auto Cls = *jitTargetAddressToPointer<Class *>(ClassPtrAddr);
      auto *ClassCompiled =
          *jitTargetAddressToPointer<ObjCClassCompiled **>(ClassPtrAddr);
      objc_msgSend(reinterpret_cast<id>(ClassCompiled->Parent), ClassSelector);
      auto Registered = objc_readClassPair(Cls, ImageInfo);

      // FIXME: Improve diagnostic by reporting the failed class's name.
      if (Registered != Cls)
        return make_error<StringError>("Unable to register Objective-C class",
                                       inconvertibleErrorCode());
    }
  }
  return Error::success();
}

Error MachOPlatform::setupJITDylib(JITDylib &JD) {
  return JD.define(std::make_unique<MachOHeaderMaterializationUnit>(*this,
                                                                    MachOHeaderStartSymbol));
}

Error MachOPlatform::notifyAdding(ResourceTracker &RT,
                                  const MaterializationUnit &MU) {
  auto &JD = RT.getJITDylib();
  const auto &InitSym = MU.getInitializerSymbol();
  if (!InitSym)
    return Error::success();

  RegisteredInitSymbols[&JD].add(InitSym,
                                 SymbolLookupFlags::WeaklyReferencedSymbol);
  LLVM_DEBUG({
    dbgs() << "MachOPlatform: Registered init symbol " << *InitSym << " for MU "
           << MU.getName() << "\n";
  });
  return Error::success();
}

Expected<MachOPlatform::InitializerSequence>
MachOPlatform::getInitializerSequence(JITDylib &JD) {

  LLVM_DEBUG({
    dbgs() << "MachOPlatform: Building initializer sequence for "
           << JD.getName() << "\n";
  });

  std::vector<JITDylibSP> DFSLinkOrder;

  while (true) {

    DenseMap<JITDylib *, SymbolLookupSet> NewInitSymbols;

    ES.runSessionLocked([&]() {
      DFSLinkOrder = JD.getDFSLinkOrder();

      for (auto &InitJD : DFSLinkOrder) {
        auto RISItr = RegisteredInitSymbols.find(InitJD.get());
        if (RISItr != RegisteredInitSymbols.end()) {
          NewInitSymbols[InitJD.get()] = std::move(RISItr->second);
          RegisteredInitSymbols.erase(RISItr);
        }
      }
    });

    if (NewInitSymbols.empty())
      break;

    LLVM_DEBUG({
      dbgs() << "MachOPlatform: Issuing lookups for new init symbols: "
                "(lookup may require multiple rounds)\n";
      for (auto &KV : NewInitSymbols)
        dbgs() << "  \"" << KV.first->getName() << "\": " << KV.second << "\n";
    });

    // Outside the lock, issue the lookup.
    if (auto R = lookupInitSymbols(JD.getExecutionSession(), NewInitSymbols))
      ; // Nothing to do in the success case.
    else
      return R.takeError();
  }

  LLVM_DEBUG({
    dbgs() << "MachOPlatform: Init symbol lookup complete, building init "
              "sequence\n";
  });

  // Lock again to collect the initializers.
  InitializerSequence FullInitSeq;
  {
    std::lock_guard<std::mutex> Lock(InitSeqsMutex);
    for (auto &InitJD : reverse(DFSLinkOrder)) {
      LLVM_DEBUG({
        dbgs() << "MachOPlatform: Appending inits for \"" << InitJD->getName()
               << "\" to sequence\n";
      });
      auto ISItr = InitSeqs.find(InitJD.get());
      if (ISItr != InitSeqs.end()) {
        FullInitSeq.push_back(std::move(ISItr->second));
        InitSeqs.erase(ISItr);
      }
    }
  }

  return FullInitSeq;
}

Expected<MachOPlatform::DeinitializerSequence>
MachOPlatform::getDeinitializerSequence(JITDylib &JD) {
  std::vector<JITDylibSP> DFSLinkOrder = JD.getDFSLinkOrder();

  DeinitializerSequence FullDeinitSeq;
  {
    std::lock_guard<std::mutex> Lock(InitSeqsMutex);
    for (auto &DeinitJD : DFSLinkOrder) {
      (void)DeinitJD;
      FullDeinitSeq.push_back(shared::MachOJITDylibDeinitializers());
    }
  }

  return FullDeinitSeq;
}

Expected<JITTargetAddress>
MachOPlatform::dlsymLookup(JITTargetAddress DSOHandle, StringRef Symbol) {
  auto I = HeaderAddrToJITDylib.find(DSOHandle);
  if (I == HeaderAddrToJITDylib.end())
    return make_error<StringError>("handle " + formatv("{0:x}", DSOHandle) +
                                   " not recognized",
                                   inconvertibleErrorCode());

  auto MangledName = ("_" + Symbol).str();
  auto Sym = ES.lookup({I->second}, MangledName);
  if (!Sym)
    return Sym.takeError();
  return Sym->getAddress();
}

static SymbolAliasMap commonMachORuntimeAliases(ExecutionSession &ES) {
  SymbolAliasMap CRA;

  CRA[ES.intern("___orc_rt_run_program")] =
    { ES.intern("___orc_rt_macho_run_program"), JITSymbolFlags::Exported };
  CRA[ES.intern("___orc_rt_log_error")] =
    { ES.intern("___orc_rt_log_error_to_stderr"), JITSymbolFlags::Exported };
  CRA[ES.intern("___cxa_atexit")] =
    { ES.intern("___orc_rt_cxa_atexit"), JITSymbolFlags::Exported };

  return CRA;
}

Error MachOPlatform::addInProcessRuntimeSupport(JITDylib &JD) {
  auto RuntimeAliases = commonMachORuntimeAliases(ES);

  RuntimeAliases[ES.intern("___orc_rt_macho_get_initializers")] =
    { ES.intern("___orc_rt_macho_get_initializers_local"),
      JITSymbolFlags::Exported };

  RuntimeAliases[ES.intern("___orc_rt_macho_symbol_lookup")] =
    { ES.intern("___orc_rt_macho_symbol_lookup_local"), JITSymbolFlags::Exported };

  auto MachOPlatformSym =
    ES.lookup({{&JD, JITDylibLookupFlags::MatchAllSymbols}},
              ES.intern("___macho_platform"));
  if (!MachOPlatformSym)
    return MachOPlatformSym.takeError();

  *jitTargetAddressToPointer<void**>(MachOPlatformSym->getAddress()) = this;

  return JD.define(symbolAliases(std::move(RuntimeAliases)));
}

Error MachOPlatform::addRemoteRuntimeSupport(JITDylib &JD,
                                             WrapperFunctionManager &WFM) {
  auto RuntimeAliases = commonMachORuntimeAliases(ES);

  RuntimeAliases[ES.intern("___orc_rt_macho_get_initializers")] =
    { ES.intern("___orc_rt_macho_get_initializers_remote"),
      JITSymbolFlags::Exported };

  RuntimeAliases[ES.intern("___orc_rt_macho_symbol_lookup")] =
    { ES.intern("___orc_rt_macho_symbol_lookup_remote"),
      JITSymbolFlags::Exported };

  if (auto Err = JD.define(symbolAliases(std::move(RuntimeAliases))))
    return Err;

  RuntimeSupportWrapperFunctionsMap RSWFM;

  RSWFM[ES.intern("___orc_rt_macho_get_initializers_tag")] =
      runtimeSupportMethod(&MachOPlatform::rt_getInitializerSequenceWrapper);
  RSWFM[ES.intern("___orc_rt_macho_symbol_lookup_tag")] =
      runtimeSupportMethod(&MachOPlatform::rt_dlsymLookupWrapper);

  SymbolLookupSet TagSymbols;
  for (auto &KV : RSWFM)
    TagSymbols.add(KV.first);

  auto WrapperFunctionTagAddrs =
      ES.lookup({{&JD, JITDylibLookupFlags::MatchAllSymbols}}, TagSymbols);
  if (!WrapperFunctionTagAddrs)
    return WrapperFunctionTagAddrs.takeError();

  DenseMap<JITTargetAddress, WrapperFunctionManager::WrapperFunction>
      TagToWrapperFunction;
  for (auto &KV : *WrapperFunctionTagAddrs) {
    auto I = RSWFM.find(KV.first);
    assert(I != RSWFM.end() && "Missing WrapperFunctions entry");
    TagToWrapperFunction[KV.second.getAddress()] = std::move(I->second);
  }

  return WFM.associate(std::move(TagToWrapperFunction));
}

extern "C" Expected<MachOPlatform::InitializerSequence>
__llvm_macho_platform_get_initializers(void *VMOP, const char *Path) {
  assert(VMOP && "MachOPlatform instance can not be null");
  assert(Path && "Path can not be null");

  auto &MOP = *static_cast<MachOPlatform*>(VMOP);
  auto *JD = MOP.getExecutionSession().getJITDylibByName(Path);
  if (!JD)
    return make_error<StringError>(Twine("No JITDylib with name ") + Path,
                                   inconvertibleErrorCode());
  return MOP.getInitializerSequence(*JD);
}

extern "C" Expected<JITTargetAddress>
__llvm_macho_platform_symbol_lookup(void *VMOP, void *H, const char *Symbol) {
  assert(VMOP && "MachOPlatform instance can not be null");
  assert(Symbol && "Symbol can not be null");

  auto &MOP = *static_cast<MachOPlatform*>(VMOP);
  return MOP.dlsymLookup(pointerToJITTargetAddress(H), Symbol);
}

shared::WrapperFunctionResult
MachOPlatform::rt_getInitializerSequenceWrapper(ArrayRef<uint8_t> ArgBuffer) {
  std::string JITDylibName;
  if (auto Err = shared::fromWrapperFunctionBlob(ArgBuffer, JITDylibName)) {
    LLVM_DEBUG({
        dbgs() << "Orc MachO runtime support requested initializers but request "
                  "buffer was malformed.\n";
      });
    ES.reportError(std::move(Err));
    return shared::WrapperFunctionResult();
  }

  LLVM_DEBUG({
      dbgs() << "Orc MachO runtime support requested initializers for \""
             << JITDylibName << "\"\n";
    });

  auto *JD = ES.getJITDylibByName(JITDylibName);
  if (!JD) {
    LLVM_DEBUG(dbgs() << "  No such JITDylib exists.\n");
    return shared::WrapperFunctionResult();
  }

  auto Inits = getInitializerSequence(*JD);
  if (!Inits) {
    LLVM_DEBUG(dbgs() << "  Error building initializer sequence.\n");
    ES.reportError(Inits.takeError());
    return shared::WrapperFunctionResult();
  }

  LLVM_DEBUG(dbgs() << "  Success. Returning init sequence.\n");
  return shared::toWrapperFunctionBlob(*Inits);
}

shared::WrapperFunctionResult
MachOPlatform::rt_dlsymLookupWrapper(ArrayRef<uint8_t> ArgBuffer) {
  JITTargetAddress DSOHandle;
  std::string SymbolName;

  if (auto Err = shared::fromWrapperFunctionBlob(ArgBuffer, DSOHandle,
                                                 SymbolName)) {
    LLVM_DEBUG({
        dbgs() << "Orc MachO runtime support requested dlsym lookup but "
                  "request buffer was malformed.\n";
      });
    ES.reportError(std::move(Err));
    return shared::WrapperFunctionResult();
  }

  LLVM_DEBUG({
      dbgs() << "Orc MachO runtime support requested dlsym lookup for \""
             << SymbolName << "\" in " << formatv("{0:x}", DSOHandle) << "\n";
    });

  auto Addr = dlsymLookup(DSOHandle, SymbolName);
  if (!Addr) {
    LLVM_DEBUG(dbgs() << "  Lookup failed.\n");
    ES.reportError(Addr.takeError());
    return shared::WrapperFunctionResult();
  }

  LLVM_DEBUG({
      dbgs() << "  Success. Returning " << formatv("{0:x}", *Addr) << "\n";
    });

  return shared::toWrapperFunctionBlob(*Addr);
}

bool MachOPlatform::supportedTarget(const Triple &TT) {
  switch (TT.getArch()) {
  case Triple::aarch64:
  case Triple::x86_64:
    return true;
  default:
    return false;
  }
}

MachOPlatform::MachOPlatform(
    ExecutionSession &ES, ObjectLinkingLayer &ObjLinkingLayer,
    Triple TT)
    : ES(ES), ObjLinkingLayer(ObjLinkingLayer), TT(std::move(TT)) {
  MachOHeaderStartSymbol = ES.intern("___dso_handle");
  ObjLinkingLayer.addPlugin(std::make_unique<InitScraperPlugin>(*this));
}

Error MachOPlatform::registerInitInfo(
    JITDylib &JD, JITTargetAddress ObjCImageInfoAddr,
    shared::MachOJITDylibInitializers::SectionExtent ModInits,
    shared::MachOJITDylibInitializers::SectionExtent ObjCSelRefs,
    shared::MachOJITDylibInitializers::SectionExtent ObjCClassList) {
  std::lock_guard<std::mutex> Lock(InitSeqsMutex);

  shared::MachOJITDylibInitializers *InitSeq = nullptr;
  {
    auto I = InitSeqs.find(&JD);
    if (I == InitSeqs.end()) {
      auto SearchOrder =
        JD.withLinkOrderDo([](const JITDylibSearchOrder &SO) { return SO; });
      auto JDMachOHeaderAddr = ES.lookup(SearchOrder, MachOHeaderStartSymbol);
      if (!JDMachOHeaderAddr)
        return JDMachOHeaderAddr.takeError();
      I = InitSeqs.insert(
        std::make_pair(&JD,
                       shared::MachOJITDylibInitializers(JD.getName(),
                                                         JDMachOHeaderAddr->getAddress())))
            .first;
    }
    InitSeq = &I->second;
  }

  InitSeq->setObjCImageInfoAddr(ObjCImageInfoAddr);

  if (ModInits.Address)
    InitSeq->addModInitsSection(std::move(ModInits));

  if (ObjCSelRefs.Address)
    InitSeq->addObjCSelRefsSection(std::move(ObjCSelRefs));

  if (ObjCClassList.Address)
    InitSeq->addObjCClassListSection(std::move(ObjCClassList));

  return Error::success();
}

static Expected<shared::MachOJITDylibInitializers::SectionExtent>
getSectionExtent(jitlink::LinkGraph &G, StringRef SectionName) {
  auto *Sec = G.findSectionByName(SectionName);
  if (!Sec)
    return shared::MachOJITDylibInitializers::SectionExtent();
  jitlink::SectionRange R(*Sec);
  if (R.getSize() % G.getPointerSize() != 0)
    return make_error<StringError>(SectionName + " section size is not a "
                                                 "multiple of the pointer size",
                                   inconvertibleErrorCode());
  return shared::MachOJITDylibInitializers::SectionExtent(
      R.getStart(), R.getSize() / G.getPointerSize());
}

void MachOPlatform::InitScraperPlugin::modifyPassConfig(
    MaterializationResponsibility &MR, const Triple &TT,
    jitlink::PassConfiguration &Config) {

  // Don't add the init-scraper plugin for objects with no init symbol, or for
  // the header start symbol.
  if (!MR.getInitializerSymbol())
    return;

  if (MR.getInitializerSymbol() == MP.MachOHeaderStartSymbol) {
    Config.PostAllocationPasses.push_back(
        [this, &JD = MR.getTargetJITDylib()](jitlink::LinkGraph &G) -> Error {
      auto I = llvm::find_if(G.defined_symbols(), [this](jitlink::Symbol *Sym) {
        return Sym->getName() == *MP.MachOHeaderStartSymbol;
      });
      assert(I != G.defined_symbols().end() &&
             "Missing MachO header start symbol");
      {
        std::lock_guard<std::mutex> Lock(MP.InitSeqsMutex);
        MP.HeaderAddrToJITDylib[(*I)->getAddress()] = &JD;
      }
      return Error::success();
    });
    return;
  }

  Config.PrePrunePasses.push_back([this, &MR](jitlink::LinkGraph &G) -> Error {
    JITLinkSymbolVector InitSectionSymbols;
    preserveInitSectionIfPresent(InitSectionSymbols, G, "__mod_init_func");
    preserveInitSectionIfPresent(InitSectionSymbols, G, "__objc_selrefs");
    preserveInitSectionIfPresent(InitSectionSymbols, G, "__objc_classlist");

    if (!InitSectionSymbols.empty()) {
      std::lock_guard<std::mutex> Lock(InitScraperMutex);
      InitSymbolDeps[&MR] = std::move(InitSectionSymbols);
    }

    if (auto Err = processObjCImageInfo(G, MR))
      return Err;

    return Error::success();
  });

  Config.PostFixupPasses.push_back([this, &JD = MR.getTargetJITDylib()](
                                       jitlink::LinkGraph &G) -> Error {
    shared::MachOJITDylibInitializers::SectionExtent ModInits, ObjCSelRefs,
        ObjCClassList;

    JITTargetAddress ObjCImageInfoAddr = 0;
    if (auto *ObjCImageInfoSec = G.findSectionByName("__objc_image_info")) {
      if (auto Addr = jitlink::SectionRange(*ObjCImageInfoSec).getStart())
        ObjCImageInfoAddr = Addr;
    }

    // Record __mod_init_func.
    if (auto ModInitsOrErr = getSectionExtent(G, "__mod_init_func"))
      ModInits = std::move(*ModInitsOrErr);
    else
      return ModInitsOrErr.takeError();

    // Record __objc_selrefs.
    if (auto ObjCSelRefsOrErr = getSectionExtent(G, "__objc_selrefs"))
      ObjCSelRefs = std::move(*ObjCSelRefsOrErr);
    else
      return ObjCSelRefsOrErr.takeError();

    // Record __objc_classlist.
    if (auto ObjCClassListOrErr = getSectionExtent(G, "__objc_classlist"))
      ObjCClassList = std::move(*ObjCClassListOrErr);
    else
      return ObjCClassListOrErr.takeError();

    // Dump the scraped inits.
    LLVM_DEBUG({
      dbgs() << "MachOPlatform: Scraped " << G.getName() << " init sections:\n";
      dbgs() << "  __objc_selrefs: ";
      if (ObjCSelRefs.NumPtrs)
        dbgs() << ObjCSelRefs.NumPtrs << " pointer(s) at "
               << formatv("{0:x16}", ObjCSelRefs.Address) << "\n";
      else
        dbgs() << "none\n";

      dbgs() << "  __objc_classlist: ";
      if (ObjCClassList.NumPtrs)
        dbgs() << ObjCClassList.NumPtrs << " pointer(s) at "
               << formatv("{0:x16}", ObjCClassList.Address) << "\n";
      else
        dbgs() << "none\n";

      dbgs() << "  __mod_init_func: ";
      if (ModInits.NumPtrs)
        dbgs() << ModInits.NumPtrs << " pointer(s) at "
               << formatv("{0:x16}", ModInits.Address) << "\n";
      else
        dbgs() << "none\n";
    });

    return MP.registerInitInfo(JD, ObjCImageInfoAddr, std::move(ModInits),
                               std::move(ObjCSelRefs), std::move(ObjCClassList));
  });
}

ObjectLinkingLayer::Plugin::LocalDependenciesMap
MachOPlatform::InitScraperPlugin::getSyntheticSymbolLocalDependencies(
    MaterializationResponsibility &MR) {
  std::lock_guard<std::mutex> Lock(InitScraperMutex);
  auto I = InitSymbolDeps.find(&MR);
  if (I != InitSymbolDeps.end()) {
    LocalDependenciesMap Result;
    Result[MR.getInitializerSymbol()] = std::move(I->second);
    InitSymbolDeps.erase(&MR);
    return Result;
  }
  return LocalDependenciesMap();
}

void MachOPlatform::InitScraperPlugin::preserveInitSectionIfPresent(
    JITLinkSymbolVector &Symbols, jitlink::LinkGraph &G,
    StringRef SectionName) {
  if (auto *Sec = G.findSectionByName(SectionName)) {
    auto SecBlocks = Sec->blocks();
    if (!llvm::empty(SecBlocks))
      Symbols.push_back(
          &G.addAnonymousSymbol(**SecBlocks.begin(), 0, 0, false, true));
  }
}

Error MachOPlatform::InitScraperPlugin::processObjCImageInfo(
    jitlink::LinkGraph &G, MaterializationResponsibility &MR) {

  // If there's an ObjC imagine info then either
  //   (1) It's the first __objc_imageinfo we've seen in this JITDylib. In
  //       this case we name and record it.
  // OR
  //   (2) We already have a recorded __objc_imageinfo for this JITDylib,
  //       in which case we just verify it.
  auto *ObjCImageInfo = G.findSectionByName("__objc_imageinfo");
  if (!ObjCImageInfo)
    return Error::success();

  auto ObjCImageInfoBlocks = ObjCImageInfo->blocks();

  // Check that the section is not empty if present.
  if (llvm::empty(ObjCImageInfoBlocks))
    return make_error<StringError>("Empty __objc_imageinfo section in " +
                                       G.getName(),
                                   inconvertibleErrorCode());

  // Check that there's only one block in the section.
  if (std::next(ObjCImageInfoBlocks.begin()) != ObjCImageInfoBlocks.end())
    return make_error<StringError>("Multiple blocks in __objc_imageinfo "
                                   "section in " +
                                       G.getName(),
                                   inconvertibleErrorCode());

  // Check that the __objc_imageinfo section is unreferenced.
  // FIXME: We could optimize this check if Symbols had a ref-count.
  for (auto &Sec : G.sections()) {
    if (&Sec != ObjCImageInfo)
      for (auto *B : Sec.blocks())
        for (auto &E : B->edges())
          if (E.getTarget().isDefined() &&
              &E.getTarget().getBlock().getSection() == ObjCImageInfo)
            return make_error<StringError>("__objc_imageinfo is referenced "
                                           "within file " +
                                               G.getName(),
                                           inconvertibleErrorCode());
  }

  auto &ObjCImageInfoBlock = **ObjCImageInfoBlocks.begin();
  auto *ObjCImageInfoData = ObjCImageInfoBlock.getContent().data();
  auto Version = support::endian::read32(ObjCImageInfoData, G.getEndianness());
  auto Flags =
      support::endian::read32(ObjCImageInfoData + 4, G.getEndianness());

  // Lock the mutex while we verify / update the ObjCImageInfos map.
  std::lock_guard<std::mutex> Lock(InitScraperMutex);

  auto ObjCImageInfoItr = ObjCImageInfos.find(&MR.getTargetJITDylib());
  if (ObjCImageInfoItr != ObjCImageInfos.end()) {
    // We've already registered an __objc_imageinfo section. Verify the
    // content of this new section matches, then delete it.
    if (ObjCImageInfoItr->second.first != Version)
      return make_error<StringError>(
          "ObjC version in " + G.getName() +
              " does not match first registered version",
          inconvertibleErrorCode());
    if (ObjCImageInfoItr->second.second != Flags)
      return make_error<StringError>("ObjC flags in " + G.getName() +
                                         " do not match first registered flags",
                                     inconvertibleErrorCode());

    // __objc_imageinfo is valid. Delete the block.
    for (auto *S : ObjCImageInfo->symbols())
      G.removeDefinedSymbol(*S);
    G.removeBlock(ObjCImageInfoBlock);
  } else {
    // We haven't registered an __objc_imageinfo section yet. Register and
    // move on. The section should already be marked no-dead-strip.
    ObjCImageInfos[&MR.getTargetJITDylib()] = std::make_pair(Version, Flags);
  }

  return Error::success();
}

} // End namespace orc.
} // End namespace llvm.
