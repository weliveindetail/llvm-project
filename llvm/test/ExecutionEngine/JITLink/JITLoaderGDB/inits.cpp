#include <iostream>

class Foo {
public:
  Foo() { std::cout << "Foo::Foo()\n"; }
  ~Foo() { std::cout << "Foo::~Foo()\n"; }
  void foo() { std::cout << "Foo::foo()\n"; }
};

Foo F;

int main(int argc, char *argv[]) {
  F.foo();
  return 0;
}
