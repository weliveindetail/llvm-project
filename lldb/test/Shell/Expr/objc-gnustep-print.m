// REQUIRES: objc-gnustep
// XFAIL: system-windows
//
// RUN: %build %s --compiler=clang --objc-gnustep --output=%t
// RUN: %lldb -b -o "b objc-gnustep-print.m:35" -o "run" -o "p self" -o "p *self" -- %t | FileCheck %s

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
@interface TestObj : NSObject {}
- (int)ok;
@end
@implementation TestObj
- (int)ok {
	return self ? 0 : 1;
}
@end

// CHECK: (lldb) b objc-gnustep-print.m:35
// CHECK: Breakpoint {{.*}} at objc-gnustep-print.m
//
// CHECK: (lldb) run
// CHECK: Process {{[0-9]+}} stopped
// CHECK: -[TestObj ok](self=[[SELF_PTR:0x[0-9]+]]{{.*}}) at objc-gnustep-print.m:35
//
// CHECK: (lldb) p self
// CHECK: (TestObj *) $0 = [[SELF_PTR]]
//
// CHECK: (lldb) p *self
// CHECK: (TestObj) $1 = {
// CHECK:   NSObject = {
// CHECK:     isa
// CHECK:     refcount
// CHECK:   }
// CHECK: }

int main() {
	TestObj *testObj = [TestObj new];
	return [testObj ok];
}
