//#include <stdio.h>
extern int puts(const char *str);

void FooCtor() {
  puts("Foo::Foo()\n");
}

void FooFoo() {
  puts("Foo::foo()\n");
}

void FooDtor() {
  puts("Foo::~Foo()\n");
}

int main(int argc, char *argv[]) {
  FooCtor();
  FooFoo();
  FooDtor();
  return 0;
}
