# RUN: rm -rf %t && mkdir -p %t
# RUN: llvm-mc -triple=armv7-linux-gnueabi -arm-add-build-attributes \
# RUN:         -filetype=obj -filetype=obj -o %t/elf_stubs.o %s
# RUN: llvm-jitlink -noexec -slab-address 0x76ff0000 \
# RUN:              -slab-allocate 10Kb -slab-page-size 4096 \
# RUN:              -abs ext_arm=0x76bbe880 \
# RUN:              -check %s %t/elf_stubs.o

	.text
	.syntax unified

# Check that calls/jumps to external functions trigger the generation of
# branch-range extension stubs. These stubs don't follow the default PLT model
# where the branch-target address is loaded from a GOT entry. Instead, they
# hard-code it in the immediate field.
#
# jitlink-check: decode_operand(test_external_call, 0) = stub_addr(elf_stubs.o, ext_arm) - (test_external_call + 8)
# jitlink-check: decode_operand(test_external_jump, 0) = stub_addr(elf_stubs.o, ext_arm) - (test_external_jump + 8)
	.globl  test_external_call
	.type	test_external_call,%function
	.p2align	2
test_external_call:
	bl	ext_arm
	.size test_external_call, .-test_external_call

	.globl  test_external_jump
	.type	test_external_jump,%function
	.p2align	2
test_external_jump:
	b	ext_arm
	.size test_external_jump, .-test_external_jump

# Empty main function for jitlink to be happy
	.globl	main
	.type	main,%function
	.p2align	2
main:
	bx	lr
	.size	main,	.-main
