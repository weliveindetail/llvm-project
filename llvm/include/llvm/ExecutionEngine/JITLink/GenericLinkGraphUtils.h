//===-- GenericLinkGraphUtils.h - Generic LinkGraph utilities --*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Useful JITLink passes.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_EXECUTIONENGINE_JITLINK_GENERICLINKGRAPHUTILS_H
#define LLVM_EXECUTIONENGINE_JITLINK_GENERICLINKGRAPHUTILS_H

#include "llvm/ExecutionEngine/JITLink/JITLink.h"
#include "llvm/Support/Error.h"

namespace llvm {
namespace jitlink {

/// Returns true if the given symbol is a named callable symbol.
inline bool isNamedCallable(Symbol &Sym) {
  return Sym->hasName() && Sym->isCallable();
}

/// Generates new names by appending the given suffix to input names.
/// New names are allocated on the LinkGraph's allocator.
class GenerateNameByAppending {
public:
  GenerateNameByAppending(LinkGraph &G, StringRef Suffix)
      : G(G), Suffix(Suffix) {}
  StringRef operator()(StringRef InputName) {
    return G.allocateString(InputName + Suffix);
  }

private:
  LinkGraph &G;
  StringRef Suffix;
};

/// For each defined Symbol matching the given predicate: clones the symbol to
/// an equivalent defined symbol with a new name, then makes the original
/// symbol external.
///
/// This operation can be used to support lazy compilation without modifying
/// IR or object level symbols by, e.g. Renaming all function bodies from
/// <name> to <name>$body, then adding lazy reexports for <name> ->
/// <name>$body.
///
/// Pred should be a function that takes a Symbol& and returns true if the
/// symbol should be renamed, false otherwise. Pred should never return true
/// for anonymous symbols.
///
/// Rename should be a function that takes a StringRef and returns a new
/// distinct StringRef.
template <typename NewNameFn, typename PredFn>
class CloneToNewNameAndMakeReferencesExternal {
public:
  CloneToNewNameAndMakeReferencesExternal(NewNameFn NewName, PredFn Pred)
      : NewName(std::move(NewName), Pred(std::move(Pred)) {}

  Error operator()(LinkGraph &G) {
    for (auto *Sym : G.defined_symbols()) {
      if (Pred(*Sym)) {
        assert(Sym->hasName() && "Pred should only allow named symbols");
        G.addDefinedSymbol(Sym->getContent(), Sym->getOffset(),
                           NewName(Sym->getName()), Sym->getSize(),
                           Sym->getLinkage(), Sym->getScope(),
                           Sym->isCallable(), Sym->isLive());
        G.makeExternal(*Sym);
      }
    }
  }
private:
  NewNameFn NewName;
  PredFn Pred;
};

/// Creates a CloneToNewNameAndMakeReferencesExternal object.
template <typename NewNameFn, typename PredFn>
CloneToNewNameAndMakeReferencesExternal<NewNameFn, PredFn>
cloneToNewNameAndMakeReferencesExternal(NewNameFn NewName, PredFn Pred) {
  return CloneToNewNameAndMakeReferencesExternal<NewNameFn, PredFn>(
      std::

} // end namespace jitlink
} // end namespace llvm

#endif // LLVM_EXECUTIONENGINE_JITLINK_GENERICLINKGRAPHUTILS_H
