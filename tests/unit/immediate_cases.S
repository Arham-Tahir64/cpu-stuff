/* Assembler oracle only; these instructions are not executed on a CPU yet.
 * Keep instruction order synchronized with ASSEMBLED_CASES in the generator.
 */
.option norvc
.option norelax
.section .text,"ax",@progbits
.balign 4
.globl _start
_start:
    addi  x5, x0, -1
    addi  x1, x2, -2048
    addi  x3, x4, 2047
    sltiu x1, x2, -1
    lw    x5, -16(x6)
    jalr  x1, 1(x2)
    srai  x5, x6, 31
    sw    x11, -4(x12)
    sh    x3, -2048(x4)
    sb    x5, 2047(x6)
    beq   x1, x2, .+4
    bne   x1, x2, .-4
    blt   x3, x4, .+2048
    bgeu  x3, x4, .-4096
    lui   x5, 0xabcde
    auipc x6, 0x80000
    lui   x7, 0x7ffff
    jal   x1, .+8
    jal   x1, .-4
    jal   x1, .+1048574
    jal   x1, .-1048576
    beq   x1, x2, .+4094
    jal   x5, .+2048
