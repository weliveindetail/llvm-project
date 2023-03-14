// REQUIRES: objc-gnustep
// XFAIL: system-windows
//
// RUN: %build %s --compiler=clang --objc-gnustep --output=%t
// RUN: %lldb -b -o "b objc-gnustep-print.m:53" -o "run" -o "p self" -o "p *self" -- %t | FileCheck %s

#import "objc/runtime.h"

@protocol NSCoding
@end

#ifdef __has_attribute
#if __has_attribute(objc_root_class)
__attribute__((objc_root_class))
#endif
#endif
@interface NSObject <NSCoding>
{
	id isa;
	int refcount;
}
@end
@implementation NSObject
- (id)class
{
	return object_getClass(self);
}
+ (id)class
{
	return self;
}
+ (id)new
{
	return class_createInstance(self, 0);
}
- (void)release
{
	if (refcount == 0) {
		object_dispose(self);
	}
	refcount--;
}
- (id)retain
{
	refcount++;
	return self;
}
@end
@implementation TestObj : NSObject
+ (Class)class {
	return self;
}
- (int)ok {
	return self ? 0 : 1;
}
@end

// CHECK: (lldb) b objc-gnustep-print.m:53
// CHECK: Breakpoint {{.*}} at objc-gnustep-print.m
//
// CHECK: (lldb) run
// CHECK: Process {{[0-9]+}} stopped
// CHECK: -[TestObj ok](self=[[SELF_PTR:0x[0-9]+]]{{.*}}) at objc-gnustep-print.m
//
// CHECK: (lldb) p self
// CHECK: (TestObj *) $0 = [[SELF_PTR]]
//
// CHECK: (lldb) p *self
// CHECK: (TestObj) ${{[0-9]+}} = {
// CHECK:   NSObject = {
// CHECK:     isa
// CHECK:     refcount
// CHECK:   }
// CHECK: }

int main() {
	TestObj *testObj = [TestObj new];
	return [testObj ok];
}
