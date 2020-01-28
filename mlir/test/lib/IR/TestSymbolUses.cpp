//===- TestSymbolUses.cpp - Pass to test symbol uselists ------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "TestDialect.h"
#include "mlir/IR/Function.h"
#include "mlir/Pass/Pass.h"

using namespace mlir;

namespace {
/// This is a symbol test pass that tests the symbol uselist functionality
/// provided by the symbol table along with erasing from the symbol table.
struct SymbolUsesPass : public ModulePass<SymbolUsesPass> {
  WalkResult operateOnSymbol(Operation *symbol, ModuleOp module,
                             SmallVectorImpl<FuncOp> &deadFunctions) {
    // Test computing uses on a non symboltable op.
    Optional<SymbolTable::UseRange> symbolUses =
        SymbolTable::getSymbolUses(symbol);

    // Test the conservative failure case.
    if (!symbolUses) {
      symbol->emitRemark()
          << "symbol contains an unknown nested operation that "
             "'may' define a new symbol table";
      return WalkResult::interrupt();
    }
    if (unsigned numUses = llvm::size(*symbolUses))
      symbol->emitRemark() << "symbol contains " << numUses
                           << " nested references";

    // Test the functionality of symbolKnownUseEmpty.
    if (SymbolTable::symbolKnownUseEmpty(symbol, &module.getBodyRegion())) {
      FuncOp funcSymbol = dyn_cast<FuncOp>(symbol);
      if (funcSymbol && funcSymbol.isExternal())
        deadFunctions.push_back(funcSymbol);

      symbol->emitRemark() << "symbol has no uses";
      return WalkResult::advance();
    }

    // Test the functionality of getSymbolUses.
    symbolUses = SymbolTable::getSymbolUses(symbol, &module.getBodyRegion());
    assert(symbolUses.hasValue() && "expected no unknown operations");
    for (SymbolTable::SymbolUse symbolUse : *symbolUses) {
      // Check that we can resolve back to our symbol.
      if (SymbolTable::lookupNearestSymbolFrom(
              symbolUse.getUser()->getParentOp(), symbolUse.getSymbolRef())) {
        symbolUse.getUser()->emitRemark()
            << "found use of symbol : " << symbolUse.getSymbolRef() << " : "
            << symbol->getAttr(SymbolTable::getSymbolAttrName());
      }
    }
    symbol->emitRemark() << "symbol has " << llvm::size(*symbolUses) << " uses";
    return WalkResult::advance();
  }

  void runOnModule() override {
    auto module = getModule();

    // Walk nested symbols.
    SmallVector<FuncOp, 4> deadFunctions;
    module.getBodyRegion().walk([&](Operation *nestedOp) {
      if (SymbolTable::isSymbol(nestedOp))
        return operateOnSymbol(nestedOp, module, deadFunctions);
      return WalkResult::advance();
    });

    SymbolTable table(module);
    for (Operation *op : deadFunctions) {
      // In order to test the SymbolTable::erase method, also erase completely
      // useless functions.
      auto name = SymbolTable::getSymbolName(op);
      assert(table.lookup(name) && "expected no unknown operations");
      table.erase(op);
      assert(!table.lookup(name) &&
             "expected erased operation to be unknown now");
      module.emitRemark() << name << " function successfully erased";
    }
  }
};

/// This is a symbol test pass that tests the symbol use replacement
/// functionality provided by the symbol table.
struct SymbolReplacementPass : public ModulePass<SymbolReplacementPass> {
  void runOnModule() override {
    auto module = getModule();

    // Walk nested functions and modules.
    module.getBodyRegion().walk([&](Operation *nestedOp) {
      StringAttr newName = nestedOp->getAttrOfType<StringAttr>("sym.new_name");
      if (!newName)
        return;
      if (succeeded(SymbolTable::replaceAllSymbolUses(
              nestedOp, newName.getValue(), &module.getBodyRegion())))
        SymbolTable::setSymbolName(nestedOp, newName.getValue());
    });
  }
};
} // end anonymous namespace

static PassRegistration<SymbolUsesPass> pass("test-symbol-uses",
                                             "Test detection of symbol uses");

static PassRegistration<SymbolReplacementPass>
    rauwPass("test-symbol-rauw", "Test replacement of symbol uses");
