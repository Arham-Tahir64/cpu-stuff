# Environment verification record

Verified on **2026-10-22** in the existing `Ubuntu` WSL2 distribution.
The Windows checkout is `C:\Users\Arham\Documents\research\cpu-stuff`;
Linux builds ran at `/mnt/c/Users/Arham/Documents/research/cpu-stuff` as the
normal Linux user. Dependencies were installed into Ubuntu with apt.

## Passed checks

`make check` completed with exit status **0** after resolving the simulator
probe's timescale and clock-assignment lint warnings. No lint warning was
globally disabled to pass the build.

| Tool | Observed version | Executed verification |
| --- | --- | --- |
| Ubuntu / WSL | 24.04.4 LTS / WSL2 | Launched installed distribution; kernel `5.15.167.4-microsoft-standard-WSL2` |
| Git | 2.43.0 in Ubuntu | Version/discovery; repository cloned with Windows Git 2.45.1 |
| Host GCC | 13.3.0 | C compiled, linked and executed |
| Make | 4.3 | Complete `make check` orchestration |
| CMake / Ninja | 3.28.3 / 1.11.1 | Configured and built host probe |
| Python | 3.12.3 | ELF validation; imports pyelftools and pyserial |
| RISC-V GCC | 13.2.0 | RV32I/ILP32 assembly and C linked into ELF32 |
| RISC-V binutils | 2.42 | Header/segment/attribute report and instruction disassembly |
| Verilator | 5.020 | Timed SV simulation, assertions, waveform generation |
| GTKWave | 3.3.116 | Version checked; GUI launched through WSLg and parsed VCD |
| Yosys | 0.33 | Generic counter synthesis, zero reported check problems, JSON netlist |
| VS Code | Existing Windows installation | CLI extension inventory; WSL extension already installed; Verilog-HDL 1.29.0 installed |

GTKWave reported waveform start 0 and end 2,630,000 ps. The viewer was closed by
a six-second timeout after loading. This verifies launch/import; the user should
still inspect the signals using `make wave`. No screenshot or visual waveform
review was performed. VS Code's WSL window and Linux-side language extensions
remain user interface steps described in `00-environment.md`; they have not
been claimed as verified by the CLI extension inventory alone.

## Generated evidence

| Artifact (ignored build directory) | Observed result |
| --- | --- |
| `build/host/host_probe` | `PASS native GCC / CMake / Ninja` |
| `build/probe.elf` | ELF32, little endian, ET_EXEC, EM_RISCV, flags 0, entry 0x10000 |
| `build/probe.readelf.txt` | `rv32i2p1`, 16-byte stack ABI alignment; RX text and RW data/BSS PT_LOAD |
| `build/probe.dis` | Actual startup/C instruction disassembly |
| `build/rtl/tool_probe` | Reset, 260 cycles, wraparound and second reset assertions passed |
| `build/smoke.vcd` | Nonempty simulator waveform loaded by GTKWave |
| `build/yosys.log` | Zero `check` problems; counter mapped to 24 generic cells, including 8 resettable flops |
| `build/probe-netlist.json` | Generic synthesized counter netlist |
| `build/tool-versions.txt` | Complete tested apt/tool version manifest |

The test ELF has an RX segment at 0x10000 (140 bytes) and an RW segment at
0x1008c (4 initialized bytes, 8 memory bytes including BSS). The RV32I/ILP32
libgcc selected by the compiler is under
`/usr/lib/gcc/riscv64-unknown-elf/13.2.0/rv32i/ilp32/`.

## Deferred or not yet implemented

- No CPU RTL, instruction execution, ELF memory loader or UART boot monitor yet.
- The probe ELF is compiled/inspected, not executed on a custom core.
- No FPGA board is required or selected for purchase; ULX3S 85F is a planning baseline.
- nextpnr-ecp5, ecppack and openFPGALoader are not installed. The optional dated
  installer and upstream SHA-256 are prepared; the large download/extraction
  has not been executed or verified locally.
- No board pins, FPGA timing/utilization, USB/JTAG, physical UART or hardware
  execution has been tested.
- CI workflow is provided; remote CI results must be checked after publication.

The M0 automated gate is passed. The next learning exercise is the independent
ALU and testbench specified in `02-milestones.md`.
