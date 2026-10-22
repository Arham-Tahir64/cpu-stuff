# C, ELF, runtime and boot

## Compiler pipeline

GCC's driver orchestrates preprocessing, compilation, assembly and linking:

```text
demo.c -> preprocessed C -> RV32I assembly -> relocatable ELF .o
       + crt0.o + platform.o + linker.ld + optional RV32I libgcc
       -> static ELF executable with entry point, symbols and PT_LOAD segments
```

The M0 probe in `tests/smoke` is a real example of assembly + C + custom linking.
It is compiled and inspected at M0; it is not executed until a core exists.
Use `-S` to inspect assembly, `-c` to stop at objects, `readelf -h -l -S -A` for
ELF metadata and `objdump -dr -M no-aliases` for instructions/relocations.

Recommended initial flags are `-march=rv32i -mabi=ilp32 -ffreestanding
-fno-builtin -fno-pic -fno-pie -fno-stack-protector -msmall-data-limit=0
-mno-relax -nostdlib -nostartfiles`, linked statically with `--no-relax` and
an explicit script. Relaxation is deferred so gp/startup and instruction traces
are easier to inspect. It can be enabled later with correct gp initialization.

RV32I has no hardware multiply/divide. GCC may call `__mulsi3`, `__udivsi3`,
`memcpy`, `memset` or other helpers even for freestanding C. Avoid the operations
at first; then link **RV32I/ILP32** libgcc and provide memory helper routines
yourself. `-ffreestanding` does not supply libc or prevent every helper call.
Do not add M instructions just to make a wrongly linked library work.

LLVM/Clang is an optional alternative (`--target=riscv32-unknown-elf`,
`-march=rv32i -mabi=ilp32` plus a suitable linker/runtime). Keep one compiler
baseline until the core is stable.

## Runtime/linker ownership

The application linker puts `.text`/`.rodata`, initialized `.data`/`.sdata`, then
`.bss`/`.sbss` in RAM starting at 0x10000. Define `_start`, `__bss_start/end`,
`__global_pointer$`, stack bounds and optional heap bounds. Assert the image ends
below 0x1f000, the start of the reserved 4 KiB stack. SP begins at 0x20000 and
remains 16-byte aligned at standard ABI procedure boundaries. Preserve the
callee-saved `s` registers and use the correct argument/return registers.
Follow the [RISC-V psABI](https://riscv-non-isa.github.io/riscv-elf-psabi-doc/).

`_start` sets SP, initializes gp with `.option norelax` around `la gp,
__global_pointer$`, clears the aligned BSS range, calls `main`, and reports its
return through EXIT or a platform exit routine. There is no operating system,
default process stack, argv, syscall provider or printf service.

For a RAM-loaded ELF, initialized data is loaded **at its run address**;
`p_paddr == p_vaddr` is required by our loader policy. No ROM-to-RAM copy is
needed. When later executing an application from flash/ROM, add distinct load
and run addresses and a startup copy from the `.data` load address; do not
silently apply the RAM loader policy to that image. Keep a separate linker
script for the ROM monitor, whose executable code resides in ROM and whose
scratch/stack reside in the reserved RAM region.

## Keep standard ELF

Use ordinary **ELF32 little-endian RISC-V ET_EXEC**, with a documented loading
policy. Preserve debugging symbols and ordinary GCC/binutils compatibility.
A custom ELF format would add tool incompatibility without improving the CPU.
The CPU does not parse ELF instructions: host tooling or the boot monitor
places executable bytes in RAM, then the core fetches them.

The host loader must read **program headers**, specifically `PT_LOAD`.
Sections are useful to developers but are not the loading contract and may be
stripped. `objcopy -O binary` alone loses addresses, entry metadata and holes;
use it only when a fixed, documented flat-image policy is appropriate.

The M4 loader/converter must validate before touching target memory:

1. ELF32, little-endian, EM_RISCV, ET_EXEC; complete file/header tables; bounded
   integer arithmetic. Reject PT_INTERP/PT_DYNAMIC and unsupported ABI flags.
2. Expected ISA attributes and actual build provenance. ELF flags alone do not
   enumerate every ISA extension; inspect the final attribute and disassembly.
3. For each PT_LOAD, `filesz <= memsz`; file offsets/ranges valid; alignment
   power-of-two and file/virtual-address congruence where applicable.
4. Require `p_paddr == p_vaddr`, all segments within application RAM below
   0x1f000, no overflow, ROM/MMIO/stack writes or overlapping destination spans.
5. Entry is 4-byte aligned and inside an executable segment's initialized bytes.
6. Write `filesz` bytes at the segment address, then zero the remainder through
   `memsz`. Zero-fill includes BSS; `_start` also clears BSS defensively.

The M0 `check_elf.py` validates only the controlled compiler probe; it is **not**
the robust M4 loader and uses assertions. Do not use it as a validator for
untrusted ELFs or as evidence that the complete loader is implemented.

Define `elf2mem.py` output as one 32-bit hexadecimal word per RAM word,
little-endian byte packing, base address fixed at 0x10000, exactly 16,384 words
for 64 KiB RAM with holes initialized to zero. Generate a companion manifest
with entry address, segment ranges and image checksum. Make the simulator and
synthesis image initialization consume the same format. Test a synthetic ELF
with separated text/data and `memsz > filesz`, then verify individual bytes.

## Bring-up sequence

**M2–M4: preloaded RAM.** Set the core's configurable reset vector to RAM base.
The simulator initializes RAM from the converted image and the program enters
`_start`. This proves the core, compiler, runtime and memory before a UART boot
monitor is introduced. FPGA BRAM initialization can provide the first physical
demo by rebuilding the bitstream with the program image.

**M5: resident boot ROM.** Final reset PC=0. The ROM monitor sets its stack,
initializes UART, sends a version/prompt, and waits for a host program. The host
parses ELF, validates segments and transmits a small binary protocol. The ROM
independently rechecks ranges and packet integrity; it need not parse ELF.
This is a custom transport carrying a standard ELF's loadable contents, not a
custom executable format. On successful completion the monitor drains writes,
clears stale UART status, resets peripheral policy as documented and jumps to
`e_entry` without a return. `_start` establishes the application runtime anew.

The boot ROM starts as small polling assembly. A C monitor is possible when
the compiler/runtime are proven. Keep its code under the 4 KiB ROM allocation;
measure it. No mutable state may be stored in ROM. Its stack/scratch region
must remain outside application segment destinations throughout loading.

## Proposed serial protocol, freeze and test at M5

115200 baud, 8 data bits, no parity, 1 stop bit; all multibyte fields little-endian.
Use a versioned binary header and packet framing with unambiguous boundaries
(for example COBS-delimited packets). Define HELLO, BEGIN, WRITE, ZERO, EXEC and
ABORT, sequence numbers and CRC-32/ISO-HDLC over the canonical packet bytes.
Cap data packets at 256 bytes to fit the ROM's reserved scratch budget.

Only accept WRITE/ZERO after a valid BEGIN; enforce 0x10000 <= start and
end <= 0x1f000 on every packet with overflow-safe arithmetic. Acknowledge only
after a packet is checked and its memory operation finishes. Duplicate sequence
numbers resend the ACK without applying an operation twice. EXEC validates the
entry against the accepted image's executable ranges and succeeds only after
the full transfer checksum matches. Enforce image size/segment count caps,
timeout/incomplete-transfer handling, RX error checks and a clean ABORT path.
Define resynchronization so a malformed length cannot trap the monitor forever.

At 115200 8-N-1 the theoretical payload ceiling is about 11.5 kB/s; framing and
ACKs reduce throughput. This is enough for small 64 KiB demonstrations.

No OS reboot service exists initially: a physical reset re-enters ROM, and
simulation can reset the SoC. A later application-return monitor needs a
defined reentry contract rather than jumping back with arbitrary machine state.
