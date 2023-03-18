// RUN: llvm-mc -triple=thumbv7-none-linux-gnueabi -arm-add-build-attributes -filetype=obj -o %t.o %s
// RUN: llvm-jitlink -noexec %t.o

	.globl	main
	.p2align	2
	.type	main,%function
	.code	16
	.thumb_func
main:
	.fnstart
	.save	{r7, lr}
	push	{r7, lr}
	.setfp	r7, sp
	mov	r7, sp
	.pad	#8
	sub	sp, #8
	movs	r0, #0
	str	r0, [sp]
	str	r0, [sp, #4]
	ldr	r0, .LCPI0_0
.LPC0_0:
	add	r0, pc
	bl	printf
	ldr	r0, [sp]
	add	sp, #8
	pop	{r7, pc}

	.p2align	2
.LCPI0_0:
	.long	.L.str-(.LPC0_0+4)

	.size	main, .-main
	.cantunwind
	.fnend

	.type	.L.str,%object
	.section	.rodata.str1.1,"aMS",%progbits,1
.L.str:
	.asciz	"Hello AArch32!\n"
	.size	.L.str, 12
