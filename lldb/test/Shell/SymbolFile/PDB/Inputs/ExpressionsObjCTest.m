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
	return self ? 1 : 0;
}
@end

int main() {
	TestObj *testObj = [TestObj new];
	return [testObj ok];
}
