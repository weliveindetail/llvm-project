//===-- MachOPlatformTypes.h - MachOP types shared with runtime -*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// MachO types shared with the Orc Runtime.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_EXECUTIONENGINE_ORC_SHARED_MACHOPLATFORMTYPES_H
#define LLVM_EXECUTIONENGINE_ORC_SHARED_MACHOPLATFORMTYPES_H

#include "llvm/ExecutionEngine/Orc/Shared/Serialization.h"
#include "llvm/Support/Endian.h"

#include <string>
#include <vector>

namespace llvm {

// FIXME: Break JITTargetAddress out of JITSymbol to avoid this.
using JITTargetAddress = uint64_t;

namespace orc {
namespace shared {

class MachOJITDylibInitializers {

  template <typename ChannelT, typename WireType,
          typename ConcreteType, typename _>
  friend class SerializationTraits;

public:
  struct SectionExtent {
    SectionExtent() = default;
    SectionExtent(JITTargetAddress Address, uint64_t NumPtrs)
        : Address(Address), NumPtrs(NumPtrs) {}
    JITTargetAddress Address = 0;
    uint64_t NumPtrs = 0;
  };

  using RawPointerSectionList = std::vector<SectionExtent>;

  /// Default constructor for an empty initialezrs struct.
  /// This is intended for use by deserializers who will overwrite the value
  /// later.
  MachOJITDylibInitializers() = default;

  /// Create a MachOJITDylibInitializers struct for a JITDylib with the given
  /// name.
  MachOJITDylibInitializers(std::string Name, JITTargetAddress MachOHeader)
    : Name(std::move(Name)), MachOHeader(MachOHeader) {}

  std::string &getName() { return Name; }

  JITTargetAddress getMachOHeader() { return MachOHeader; }

  void setObjCImageInfoAddr(JITTargetAddress ObjCImageInfoAddr) {
    this->ObjCImageInfoAddr = ObjCImageInfoAddr;
  }

  JITTargetAddress getObjCImageInfoAddr() const {
    return ObjCImageInfoAddr;
  }

  void addObjCSelRefsSection(SectionExtent ObjCSelRefs) {
    ObjCSelRefsSections.push_back(std::move(ObjCSelRefs));
  }

  const RawPointerSectionList &getObjCSelRefsSections() const {
    return ObjCSelRefsSections;
  }

  void addObjCClassListSection(SectionExtent ObjCClassList) {
    ObjCClassListSections.push_back(std::move(ObjCClassList));
  }

  const RawPointerSectionList &getObjCClassListSections() const {
    return ObjCClassListSections;
  }

  void addModInitsSection(SectionExtent ModInit) {
    ModInitSections.push_back(std::move(ModInit));
  }

  const RawPointerSectionList &getModInitsSections() const {
    return ModInitSections;
  }

private:

  std::string Name;
  JITTargetAddress MachOHeader;
  JITTargetAddress ObjCImageInfoAddr;
  RawPointerSectionList ModInitSections;
  RawPointerSectionList ObjCSelRefsSections;
  RawPointerSectionList ObjCClassListSections;
};

class MachOJITDylibDeinitializers {};

using MachOPlatformInitializerSequence =
  std::vector<MachOJITDylibInitializers>;

using MachOPlatformDeinitializerSequence =
  std::vector<MachOJITDylibDeinitializers>;

template <typename ChannelT>
class SerializationTraits<ChannelT, MachOJITDylibInitializers::SectionExtent> {
public:

  static Error serialize(ChannelT &C,
                         const MachOJITDylibInitializers::SectionExtent &SE) {
    return serializeSeq(C, SE.Address, SE.NumPtrs);
  }

  static Error deserialize(ChannelT &C,
                           MachOJITDylibInitializers::SectionExtent &SE) {
    return deserializeSeq(C, SE.Address, SE.NumPtrs);

  }
};

template <typename ChannelT>
class SerializationTraits<ChannelT, MachOJITDylibInitializers> {
public:

  static Error serialize(ChannelT &C, const MachOJITDylibInitializers &Inits) {
    return serializeSeq(C, Inits.Name, Inits.MachOHeader,
                        Inits.ObjCImageInfoAddr, Inits.ModInitSections,
                        Inits.ObjCSelRefsSections, Inits.ObjCClassListSections);
  }

  static Error deserialize(ChannelT &C, MachOJITDylibInitializers &Inits) {
    return deserializeSeq(C, Inits.Name, Inits.MachOHeader,
                          Inits.ObjCImageInfoAddr, Inits.ModInitSections,
                          Inits.ObjCSelRefsSections, Inits.ObjCClassListSections);
  }
};

} // end namespace shared
} // end namespace orc
} // end namespace llvm

#endif // LLVM_EXECUTIONENGINE_ORC_SHARED_MACHOPLATFORMTYPES_H
