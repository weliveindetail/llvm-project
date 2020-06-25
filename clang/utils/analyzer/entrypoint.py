import argparse
import os

from typing import List, Tuple

from subprocess import check_call


def main():
    settings, rest = parse_arguments()
    if settings.build_llvm or settings.build_llvm_only:
        build_llvm()
    if settings.build_llvm_only:
        return
    test(rest)


def parse_arguments() -> Tuple[argparse.Namespace, List[str]]:
    parser = argparse.ArgumentParser()
    parser.add_argument('--build-llvm', action='store_true')
    parser.add_argument('--build-llvm-only', action='store_true')
    return parser.parse_known_args()


def build_llvm() -> None:
    os.chdir('/build')
    cmake()
    ninja()


CMAKE_COMMAND = "cmake -G Ninja -DCMAKE_BUILD_TYPE=Release " \
    "-DCMAKE_INSTALL_PREFIX=/analyzer -DLLVM_TARGETS_TO_BUILD=X86 " \
    "-DLLVM_ENABLE_PROJECTS=clang -DLLVM_BUILD_RUNTIME=OFF " \
    "-DLLVM_ENABLE_TERMINFO=OFF -DCLANG_ENABLE_ARCMT=OFF " \
    "-DCLANG_ENABLE_STATIC_ANALYZER=ON"


def cmake():
    check_call(CMAKE_COMMAND + ' /llvm-project/llvm', shell=True)


def ninja():
    check_call("ninja install", shell=True)


def test(args: List[str]):
    os.chdir("/projects")
    check_call("/scripts/SATest.py " + " ".join(args), shell=True)


if __name__ == '__main__':
    main()
