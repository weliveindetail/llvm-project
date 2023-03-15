// REQUIRES: objc-gnustep
// XFAIL: system-windows
//
// RUN: %build %s --compiler=clang --objc-gnustep --output=%t

#import "objc/runtime.h"

@protocol NSCoding
@end

#ifdef __has_attribute
#if __has_attribute(objc_root_class)
__attribute__((objc_root_class))
#endif
#endif
@interface NSObject <NSCoding> {
  id isa;
  int refcount;
}
@end
@implementation NSObject
- (id)class {
  return object_getClass(self);
}
+ (id)new {
  return class_createInstance(self, 0);
}
@end
@interface TestObj : NSObject {
  int _int;
  float _float;
  char _char;
  void *_ptr_void;
  NSObject *_ptr_nsobject;
  id _id_objc;
}
- (int)ok;
@end
@implementation TestObj
- (int)ok {
  return self ? 0 : 1;
}
@end

// RUN: %lldb -b -o "b objc-gnustep-print.m:41" -o "run" -o "p self" -o "p *self" -- %t | FileCheck %s --check-prefix=SELF
//
// SELF: (lldb) b objc-gnustep-print.m:41
// SELF: Breakpoint {{.*}} at objc-gnustep-print.m
//
// SELF: (lldb) run
// SELF: Process {{[0-9]+}} stopped
// SELF: -[TestObj ok](self=[[SELF_PTR:0x[0-9]+]]{{.*}}) at objc-gnustep-print.m:41
//
// SELF: (lldb) p self
// SELF: (TestObj *) $0 = [[SELF_PTR]]
//
// SELF: (lldb) p *self
// SELF: (TestObj) $1 = {
// SELF:   NSObject = {
// SELF:     isa
// SELF:     refcount
// SELF:   }
// SELF: }

// RUN: %lldb -b -o "b objc-gnustep-print.m:88" -o "run" -o "p t->_int" -o "p t->_float" -o "p t->_char" \
// RUN:          -o "p t->_ptr_void" -o "p t->_ptr_nsobject" -o "p t->_id_objc" -- %t | FileCheck %s --check-prefix=MEMBERS_OUTSIDE
//
// MEMBERS_OUTSIDE: (lldb) p t->_int
// MEMBERS_OUTSIDE: (int) $0 = 0
//
// MEMBERS_OUTSIDE: (lldb) p t->_float
// MEMBERS_OUTSIDE: (float) $1 = 0
//
// MEMBERS_OUTSIDE: (lldb) p t->_char
// MEMBERS_OUTSIDE: (char) $2 = '\0'
//
// MEMBERS_OUTSIDE: (lldb) p t->_ptr_void
// MEMBERS_OUTSIDE: (void *) $3 = 0x0000000000000000
//
// MEMBERS_OUTSIDE: (lldb) p t->_ptr_nsobject
// MEMBERS_OUTSIDE: (NSObject *) $4 = nil
//
// MEMBERS_OUTSIDE: (lldb) p t->_id_objc
// MEMBERS_OUTSIDE: (id) $5 = nil

int main() {
  TestObj *t = [TestObj new];
  return [t ok];
}
