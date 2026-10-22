# Specifications and study sources

Primary sources checked 2026-10-22. Record exact revisions when importing tests
or building tools. Study designs for reasoning and interfaces, then implement
your own architecture; no existing CPU RTL is imported into this project.

| Source | What to study |
| --- | --- |
| [RISC-V RV32I 2.1, manual release 20260120](https://docs.riscv.org/reference/isa/v20260120/unpriv/rv32.html) | Instruction semantics, encoding, immediates, alignment, branches, memory and base SYSTEM/FENCE behavior; normative source |
| [RISC-V manuals](https://docs.riscv.org/reference/isa/) | Separate unprivileged and privileged requirements; later Zicsr/Zifencei and machine-mode traps |
| [RISC-V ELF psABI](https://riscv-non-isa.github.io/riscv-elf-psabi-doc/) | Register calling conventions, 16-byte stack alignment, ELF flags, gp and relocations |
| [RISC-V GNU toolchain](https://github.com/riscv-collab/riscv-gnu-toolchain) | Bare-metal versus Linux targets, RV32 multilib and ISA/ABI selection |
| [GCC RISC-V options](https://gcc.gnu.org/onlinedocs/gcc/RISC-V-Options.html) | Exact compiler flags; match documentation to installed GCC version |
| [PicoRV32](https://github.com/YosysHQ/picorv32) | Compact FSM tradeoffs, memory valid/ready behavior, tests; do not instantiate/copy its CPU |
| [Ibex pipeline documentation](https://ibex-core.readthedocs.io/en/latest/03_reference/pipeline_details.html) | Real stalls, instruction latency and two-stage/optional writeback design; it is not a five-stage template |
| [riscv-arch-test / ACT4](https://github.com/riscv/riscv-arch-test) | Architectural test configuration, platform adaptation and result signatures |
| [Spike](https://github.com/riscv-software-src/riscv-isa-sim) | Independent ISA execution reference for differential checking |
| [riscv-formal](https://github.com/YosysHQ/riscv-formal) | RVFI retirement interface and optional instruction/invariant proofs |
| [Verilator](https://verilator.org/guide/latest/) | Timing, assertions, tracing, lint and simulator build modes |
| [Yosys](https://yosyshq.readthedocs.io/projects/yosys/en/latest/) | Synthesis, memory inference and reports; check support for chosen SV constructs |
| [nextpnr](https://github.com/YosysHQ/nextpnr) | ECP5 place/route, constraints and timing |
| [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build) | Versioned tool bundles and WSL installation |
| [ULX3S board sources](https://github.com/emard/ulx3s) | Schematics, exact revision/pins and oscillator/USB wiring |
| [ULX3S store/specifications](https://www.crowdsupply.com/radiona/ulx3s) | Actual purchasing options, FPGA capacity, memory and peripherals |
| [WSL installation](https://learn.microsoft.com/en-us/windows/wsl/install) | Windows-side install/launch/version management |
| [WSL USB](https://learn.microsoft.com/en-us/windows/wsl/connect-usb) | usbipd bind/attach and device ownership |
| [VS Code WSL](https://code.visualstudio.com/docs/remote/wsl) | Windows editor and Linux extension/tool execution |

Use specifications for behavior, not another core's implementation as an
accidental definition of the ISA. Where your EEI makes a platform choice, write
it down and test it. Record provenance/license for any third-party test data,
board constraints or utility code used later.
