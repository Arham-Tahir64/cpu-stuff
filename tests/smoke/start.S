/* Provisional startup for the compiler probe, not the future boot ROM. */
.section .text.start,"ax",@progbits
.globl _start
.type _start,@function
_start:
    .option push
    .option norelax
    la gp, __global_pointer$
    .option pop
    la sp, __stack_top
    la t0, __bss_start
    la t1, __bss_end
1:
    bgeu t0, t1, 2f
    sw zero, 0(t0)
    addi t0, t0, 4
    j 1b
2:
    call main
    la t0, result
    sw a0, 0(t0)
3:
    j 3b
.size _start, .-_start
