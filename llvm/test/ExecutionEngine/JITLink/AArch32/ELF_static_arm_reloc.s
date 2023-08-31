# RUN: llvm-mc -triple=thumbv7-linux-gnueabi -arm-add-build-attributes \
# RUN:		-filetype=obj -o %t.o %s
# RUN: llvm-objdump -r %t.o | FileCheck %s
# RUN: llvm-jitlink -noexec -slab-address 0x76ff0000 -slab-allocate 10Kb \
# RUN:              -slab-page-size 4096 -show-entry-es -check %s %t.o

	.text
	.thumb
	.p2align	1

	.globl	main
	.type	main,%function
	.code	16
	.thumb_func
main:
	bx	lr
	.size	main,	.-main

# CHECK: {{[0-9a-f]+}} R_ARM_THM_CALL call_target
# jitlink-check: decode_operand(call_site, 0) = (call_target - call_site)
	.globl	call_site
	.type	call_site,%function
	.code	16
	.thumb_func
call_site:
	bl	call_target
	.size	call_site,	.-call_site

	.globl	call_target
	.type	call_target,%function
	.code	16
	.thumb_func
call_target:
	bx	lr
	.size	call_target,	.-call_target

# CHECK: {{[0-9a-f]+}} R_ARM_THM_JUMP24 jump24_target
# jitlink-check: decode_operand(jump24_site, 0) = (jump24_target - jump24_site)
	.globl	jump24_site
	.type	jump24_site,%function
	.code	16
	.thumb_func
jump24_site:
	b.w	jump24_target
	.size	jump24_site,	.-jump24_site

	.globl	jump24_target
	.type	jump24_target,%function
	.code	16
	.thumb_func
jump24_target:
	bx	lr
	.size	jump24_target,	.-jump24_target


// jitlink-check: (main + *{4}(main))[31:0] = target_jump24
