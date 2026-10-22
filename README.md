# cpu-stuff: build a RISC-V computer from first principles

Design your own RV32I CPU in SystemVerilog, execute bare-metal C programs in
Verilator, and later run the same system on an FPGA. No existing CPU IP is used.

**Current stage: M1 in progress; ALU, register file, immediate generator and decoder are tested.**
The environment milestone is complete. The repository now contains the first
CPU datapath blocks, tool checks, a tiny bare-metal compiler probe, and the
design/verification plan. A complete CPU is still to come. The RTL counter in
`tests/smoke` remains an environment check, separate from `rtl/core`.

## Start with software only

You do not need to buy a board to design and verify the CPU. Verilator compiles
your RTL into a cycle-based simulator. Eventually the simulated hardware will
fetch and execute your compiled instructions; GTKWave displays its signals.
Software simulation cannot demonstrate physical clock timing or real FPGA I/O.

The full progression is:

```text
C -> RV32I assembly -> objects -> ELF -> validated PT_LOAD segments
  -> simulated RAM -> your SystemVerilog CPU -> UART output + instruction trace
  -> later: FPGA block RAM -> the same CPU RTL -> physical UART / LEDs
```

## Launch and check Ubuntu

In Windows PowerShell:

```powershell
wsl --list --verbose
wsl -d Ubuntu
```

In Ubuntu, using the checkout created for this session:

```bash
cd /mnt/c/Users/Arham/Documents/research/cpu-stuff
bash scripts/bootstrap_ubuntu.sh   # repeatable; sudo may ask for your Linux password
make doctor
make check                       # environment + all implemented datapath checks
make unit-alu                    # focused ALU regression
make unit-regfile                # focused register-file regression
make unit-immediate              # I/S/B/U/J extraction and sign extension
make unit-decoder                # legal encodings, safe controls and rejected encodings
make wave-alu                    # inspect a short ALU waveform in GTKWave
make wave-regfile                # inspect clocked register writes and reset
make wave-immediate              # inspect instruction fields and immediates
make wave-decoder                # inspect instruction-to-control mapping
make wave                        # opens the generated VCD in GTKWave, requires a display
code .                           # choose Reopen Folder in WSL if necessary
```

See [the complete WSL setup](docs/00-environment.md) for a new installation,
Linux-filesystem development, VS Code, USB/JTAG, and optional FPGA tools.
[The verification record](docs/environment-verified.md) distinguishes executed
checks from future work.

## Design decisions

| Item | Initial choice |
| --- | --- |
| Hardware language | Synthesizable SystemVerilog, conservative Yosys-compatible subset |
| ISA / ABI | RV32I 2.1, little-endian, ILP32, 32 registers, 4-byte instruction alignment |
| Microarchitecture | In-order multicycle FSM; one outstanding bus operation |
| Program storage | 64 KiB unified executable RAM; 4 KiB boot ROM |
| I/O | Memory-mapped polling UART and GPIO; simulation exit register |
| Compiler | Ubuntu `riscv64-unknown-elf-gcc`, always `-march=rv32i -mabi=ilp32` |
| Verification | Verilator, SystemVerilog assertions, Python tooling, GTKWave; later reference traces |
| Hardware baseline | Optional ULX3S 85F, Yosys / nextpnr-ecp5 / Trellis / openFPGALoader |

The `riscv64` executable prefix does not force 64-bit output. `make smoke-elf`
verifies that the actual linked file is ELF32 for RISC-V.

## Feasibility and effort

This is an advanced but realistic individual project. Prerequisites are binary
arithmetic and signedness, combinational/sequential logic, clocked RTL and FSMs,
C pointers and memory, basic assembly and calling conventions, Linux/Git/Make,
and the ability to read compiler disassembly. Learn missing topics alongside M1.

Planning estimates, not guarantees: about **180–350 focused hours** for a
documented multicycle system with C, UART, verification and FPGA bring-up when
you already know digital design; roughly 4–9 months at 10 hours/week. A beginner
should allow longer. A verified 5-stage pipeline is a separate 80–200+ hour phase.
The hardest work is correctness at interfaces, not the ALU's arithmetic.

Software-only cost is **US$0** on your existing Windows PC. For optional hardware,
the ULX3S 85F listing checked on 2026-10-22 is US$275 before shipping/tax; budget
roughly US$300–350 total with a USB data cable and shipping, excluding optional
test equipment. See [board tradeoffs](docs/04-fpga.md). No purchase is required now.

## Read in order

1. [Environment and tool verification](docs/00-environment.md)
2. [Architecture, bus contract, block diagram and memory map](docs/01-architecture.md)
3. [Milestones, acceptance criteria and first RTL exercise](docs/02-milestones.md)
4. [Compiler, ELF, runtime and boot design](docs/03-software-and-boot.md)
5. [Optional FPGA implementation](docs/04-fpga.md)
6. [Verification strategy and common mistakes](docs/05-verification.md)
7. [Proposed complete repository layout](docs/06-repository.md)
8. [Primary specifications and study material](docs/07-references.md)
9. [ALU implementation walkthrough and verified results](docs/08-alu.md)
10. [Register file, write timing and verification](docs/09-register-file.md)
11. [Immediate extraction, bit mapping and verification](docs/10-immediate-generator.md)
12. [Instruction legality and decoder controls](docs/11-instruction-decoder.md)

## Build targets available now

| Command | Result |
| --- | --- |
| `make setup` | Install Ubuntu dependencies |
| `make doctor` | Print required tool versions, Python imports and optional FPGA-tool status |
| `make check` | Run environment checks and all implemented datapath lint, unit tests and synthesis |
| `make unit-alu` | Check 168,728 ALU vectors using the default seed and random-pair count |
| `make unit` | Run every implemented datapath and vector-harness test |
| `make unit-regfile` | Check register timing/reset/x0, all read-address pairs, and 10,000 random cycles |
| `make unit-immediate` | Check 157,354 immediate vectors, including 23 GNU-assembled words |
| `make unit-decoder` | Check 215,000 control vectors, including all 40 instruction types |
| `make lint` | Lint all implemented datapath modules with warnings treated as failures |
| `make synth-alu` | Synthesize the ALU and reject inferred latches/flip-flops |
| `make wave-alu` | View a 256-vector ALU sample in GTKWave |
| `make synth-regfile` | Synthesize the register file, reject latches/async reset, assert 992 storage bits |
| `make wave-regfile` | View a limited register-file waveform in GTKWave |
| `make synth-immediate` | Synthesize the immediate generator and reject inferred state |
| `make wave-immediate` | View a 256-vector immediate sample in GTKWave |
| `make synth-decoder` | Synthesize the decoder and reject inferred state |
| `make wave-decoder` | View a 256-vector decoder sample in GTKWave |
| `make smoke-host` | Build and run native C through CMake / Ninja |
| `make smoke-elf` | Build, disassemble and validate a bare-metal RV32I ELF; does not execute it |
| `make smoke-rtl` | Simulate a checked counter and generate `build/smoke.vcd` |
| `make smoke-synth` | Synthesize the counter; this is not FPGA place and route |
| `make wave` | Open GTKWave |
| `make manifest` | Record Ubuntu package/tool versions in `build/tool-versions.txt` |

More CPU unit tests, CPU simulation, ELF loading and FPGA deployment targets
will be added at their milestones, after their tests and interfaces are defined. A
command should never report success for an unimplemented project stage.
