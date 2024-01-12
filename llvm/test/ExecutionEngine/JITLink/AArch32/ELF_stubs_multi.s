# RUN: rm -rf %t && mkdir -p %t
# RUN: llvm-mc -triple=thumbv7-linux-gnueabi -arm-add-build-attributes \
# RUN:         -filetype=obj -filetype=obj -o %t/elf_stubs.o %s
# RUN: llvm-jitlink -noexec -slab-address 0x76ff0000 \
# RUN:              -slab-allocate 10Kb -slab-page-size 4096 \
# RUN:              -abs external_func=0x76bbe880 \
# RUN:              -check %s %t/elf_stubs.o

	.text
	.syntax unified

# Check support for multiple stubs for a single symbol

# jitlink-check: decode_operand(test_avoid_thumb, 0)  = stub_addr(elf_stubs.o, external_func, 0) - (test_avoid_thumb + 8)
# jitlink-check: decode_operand(test_prefer_thumb, 2) = stub_addr(elf_stubs.o, external_func, 0) - next_pc(test_prefer_thumb)
# jitlink-check: decode_operand(test_force_thumb, 0)  = stub_addr(elf_stubs.o, external_func, 1) - next_pc(test_force_thumb)

# Arm call will create an Arm stub first
	.globl  test_avoid_thumb
	.type	test_avoid_thumb,%function
	.p2align	2
	.code	32
test_avoid_thumb:
	bl	external_func
	.size test_avoid_thumb, .-test_avoid_thumb

# Thumb call would create a Thumb stub if there was non at all, but it can be
# rewritten to BLX and reuse the existing Arm stub.
# TODO: Should we reconsider during relaxation?
	.globl  test_prefer_thumb
	.type	test_prefer_thumb,%function
	.p2align	1
	.code	16
	.thumb_func
test_prefer_thumb:
	bl	external_func
	.size test_prefer_thumb, .-test_prefer_thumb

# Thumb jump requires a Thumb stub, so it creates one in addition to the
# existing Arm stub.
	.globl  test_force_thumb
	.type	test_force_thumb,%function
	.p2align	1
	.code	16
	.thumb_func
test_force_thumb:
	b	external_func
	.size test_force_thumb, .-test_force_thumb

# Empty main function for jitlink to be happy
	.globl	main
	.type	main,%function
	.p2align	2
main:
	bx	lr
	.size	main,	.-main
