#include "llvm-jitlink-gdb-loader.h"

#include "llvm/Support/ManagedStatic.h"

#include <cstdint>
#include <mutex>

using namespace llvm::object;
using namespace llvm::orc;

namespace llvm {

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

// Append an entry to the list in the JIT descriptor symbol and call the debug
// trap function. TODO: Implement removal.
void NotifyDebugger(jit_code_entry *JITCodeEntry) {
  __jit_debug_descriptor.action_flag = JIT_REGISTER_FN;

  // Insert this entry at the head of the list.
  JITCodeEntry->prev_entry = nullptr;
  jit_code_entry *NextEntry = __jit_debug_descriptor.first_entry;
  JITCodeEntry->next_entry = NextEntry;
  if (NextEntry) {
    NextEntry->prev_entry = JITCodeEntry;
  }
  __jit_debug_descriptor.first_entry = JITCodeEntry;
  __jit_debug_descriptor.relevant_entry = JITCodeEntry;
  __jit_debug_register_code();
}

// JIT registration modifies global variables. Serialize them.
ManagedStatic<std::mutex> JITDebugLock;

void JITLinkGDBLoaderPlugin::notifyLoaded(MaterializationResponsibility &MR,
                                          GetDebugObjCallback GetDebugObj) {
  // Not all object types support debugging (yet).
  if (!GetDebugObj)
    return;

  // Obtain an object buffer with patched load addresses for all sections.
  Expected<std::unique_ptr<MemoryBuffer>> DebugObj = GetDebugObj();
  if (!DebugObj) {
    MR.getExecutionSession().reportError(DebugObj.takeError());
    return;
  }

  StringRef MemRange = (**DebugObj).getBuffer();
  jit_code_entry *JITCodeEntry =
      new jit_code_entry{nullptr, nullptr, MemRange.data(), MemRange.size()};

  orc::ResourceKey Key;
  if (auto Err = MR.withResourceKeyDo([&](orc::ResourceKey K) { Key = K; })) {
    MR.getExecutionSession().reportError(std::move(Err));
    return;
  }

  // Cover registry as well. A second mutex wouldn't pay off.
  std::lock_guard<std::mutex> Lock(*JITDebugLock);
  RegisteredObjectsMap[Key].push_back({JITCodeEntry, std::move(*DebugObj)});
  NotifyDebugger(JITCodeEntry);
}

} // namespace llvm
