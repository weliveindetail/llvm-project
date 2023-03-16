// REQUIRES: objc-gnustep && system-windows
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
@interface NSObject<NSCoding> {
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

// RUN: %lldb -b -o "b objc-gnustep-print-pdb.m:67" -o "run" -o "p ptr" -o "p *ptr" -- %t | FileCheck %s
//
// CHECK: (lldb) b objc-gnustep-print-pdb.m:67
// CHECK: Breakpoint {{.*}} at objc-gnustep-print-pdb.m:67
//
// CHECK: (lldb) run
// CHECK: Process {{[0-9]+}} stopped
// CHECK: frame #0: {{.*}}`main  at objc-gnustep-print-pdb.m:67
//
// CHECK: (lldb) p ptr
// CHECK: (TestObj *) $0 = 0x{{[0-9]+}}
//
// CHECK: (lldb) p *ptr
// CHECK: (TestObj) $1 = {
// CHECK:   _int
// CHECK:   _float
// CHECK:   _char
// CHECK:   _ptr_void
// CHECK:   _ptr_nsobject
// CHECK:   _id_objc
// CHECK: }

int main() {
  TestObj *ptr = [TestObj new];
  return [ptr ok];
}
