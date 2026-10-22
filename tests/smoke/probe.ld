OUTPUT_ARCH(riscv)
ENTRY(_start)
MEMORY { RAM (rwx) : ORIGIN = 0x00010000, LENGTH = 64K }
PHDRS {
    text PT_LOAD FLAGS(5);
    data PT_LOAD FLAGS(6);
}
SECTIONS {
    .text : { KEEP(*(.text.start)) *(.text .text.*) } > RAM :text
    .rodata : { *(.rodata .rodata.*) } > RAM :text
    . = ALIGN(4);
    .data : { *(.sdata .sdata.*) *(.data .data.*) } > RAM :data
    .bss (NOLOAD) : {
        . = ALIGN(4);
        __bss_start = .;
        *(.sbss .sbss.*) *(.bss .bss.*) *(COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > RAM :data
    __global_pointer$ = ADDR(.data) + 0x800;
    __heap_start = ALIGN(__bss_end, 16);
    __stack_top = ORIGIN(RAM) + LENGTH(RAM);
    __stack_bottom = __stack_top - 4096;
    __heap_end = __stack_bottom;
    ASSERT(__heap_start <= __stack_bottom, "program collides with reserved 4 KiB stack")
    /DISCARD/ : { *(.comment) *(.note*) *(.eh_frame*) }
}
