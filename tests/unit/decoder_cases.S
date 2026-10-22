/* Exactly one real instruction per row in decoder_reference.patterns().
 * Test encodings only; this sequence is not executed on a custom CPU yet.
 */
.option norvc
.option norelax
.section .text,"ax",@progbits
.balign 4
.globl _start
_start:
    lui   x5, 0xabcde
    auipc x5, 0x80000
    jal   x5, .+8
    jalr  x5, -4(x3)
    beq   x3, x11, .-4
    bne   x3, x11, .+4
    blt   x3, x11, .-8
    bge   x3, x11, .+8
    bltu  x3, x11, .-12
    bgeu  x3, x11, .+12
    lb    x5, -1(x3)
    lh    x5, -2(x3)
    lw    x5, -4(x3)
    lbu   x0, 1(x3)
    lhu   x5, 2(x3)
    sb    x11, -1(x3)
    sh    x11, -2(x3)
    sw    x11, -4(x3)
    addi  x5, x3, -2048
    slti  x5, x3, -1
    sltiu x5, x3, -1
    xori  x5, x3, -1
    ori   x5, x3, 2047
    andi  x5, x3, 255
    slli  x5, x3, 31
    srli  x5, x3, 31
    srai  x5, x3, 31
    add   x5, x3, x11
    sub   x5, x3, x11
    sll   x5, x3, x11
    slt   x5, x3, x11
    sltu  x5, x3, x11
    xor   x5, x3, x11
    srl   x5, x3, x11
    sra   x5, x3, x11
    or    x5, x3, x11
    and   x5, x3, x11
    fence iorw, iorw
    ecall
    ebreak
