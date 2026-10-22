# Verification and debugging strategy

## Layers

1. **Unit RTL**: ALU, register file, immediate formats, decoder legality, LSU,
   RAM byte enables, UART serializer/receiver, GPIO and bus completion.
2. **Core directed programs**: each instruction and corner case independently,
   with precisely expected register/memory/trap results.
3. **Instruction retirement comparison**: compare architectural events against
   independent reference behavior under randomized memory wait states.
4. **Bare-metal C**: ABI, stack, globals, BSS and MMIO under several optimization
   levels; exact signatures and output.
5. **SoC/boot**: bit-level UART and full protocol, including faults/timeouts.
6. **Hardware comparison**: identical ELF and initial data; output/signatures
   compared with simulation, plus physical timing/resource evidence.

Verilator simulates the actual custom hardware description. A host program may
provide RAM and tests, but must not decode and execute instructions on behalf
of the DUT. Spike or another ISA model is an **oracle for checking** results,
not the processor being built.

## Instruction coverage

Create a matrix with a test ID for every RV32I instruction: LUI/AUIPC;
JAL/JALR; BEQ/BNE/BLT/BGE/BLTU/BGEU;
LB/LH/LW/LBU/LHU; SB/SH/SW;
ADDI/SLTI/SLTIU/XORI/ORI/ANDI/SLLI/SRLI/SRAI;
ADD/SUB/SLL/SLT/SLTU/XOR/SRL/SRA/OR/AND;
FENCE; ECALL/EBREAK. Treat FENCE ordering and terminal traps as positive
semantic tests, not skipped instructions. ISA/EEI scope excludes CSR/privileged
tests until implemented. Reserved encoding policy must be documented; this
project traps unsupported encodings rather than decoding by partial matches.

Cross each category with x0, overlapping source/destination registers, negative
and boundary immediates, signed extremes, and wait states. Sweep all byte lanes,
halfword alignment and load sign bits. Include jump link hazards, branches
whose target is misaligned only when taken, invalid opcodes and bus errors.
Every test has a bounded cycle count and an unambiguous failure code.

## Retirement interface

Export a debug-only record at each instruction completion:

```text
order, pc_before, instruction, pc_after,
rs1/rs2 addresses and old values,
rd address/write-enable/value,
memory byte address, read/write masks, read/write data
```

Export trap PC/cause/value separately. Keep architectural order independent of
stall cycle count. Compare trace fields and final state; comparing only UART
output can miss many bugs. For loads to x0 the write-enable is false, but memory
access still occurs. Include stores and branches even though no rd is written.
Assertions: x0==0, stalled requests stable, no retirement without completion,
no faulting instruction commits side effects, no ROM/MMIO fetch, aligned PC,
and no duplicate UART pops/stores during waits.

Start with an independent Python RV32I oracle for short pure-compute programs
and manually checked directed vectors; do not copy the RTL's decoder into it.
Later integrate [Spike](https://github.com/riscv-software-src/riscv-isa-sim) or
the architecture-test reference harness, pinning its version/configuration.
Our terminal-trap EEI and MMIO map differ from a typical Spike machine, so
provide a matching platform adapter, compare RAM-only tests first, or stop
comparison before EEI-specific behavior. Running `spike program.elf` by itself
does not automatically validate this SoC.

## Official and formal tests

Study [riscv-arch-test](https://github.com/riscv/riscv-arch-test) and its current
ACT4 documentation. Pin a commit, choose an RV32I configuration matching the
implemented execution environment, provide platform hooks/linker/signature
regions, and archive expected versus actual signatures. Older RISCOF examples
may describe an earlier harness; follow the README for the pinned revision.
Privileged tests require the corresponding CSRs/trap model and cannot simply
be counted as passing when skipped. Report the exact test set and exclusions;
passing selected tests is not a claim of formal RISC-V certification.

[riscv-formal/RVFI](https://github.com/YosysHQ/riscv-formal) is an optional,
valuable next layer. Export RVFI consistently and prove instruction semantics
and invariants with an explicitly bounded/supported configuration. Formal
proofs depend on memory/reset assumptions; they do not verify UART wiring or
post-route timing. Keep counterexample traces and remove unjustified assumptions.

## Debug procedure

On a mismatch, capture seed, ELF hash, first incorrect retirement and recent
bus/FSM history. Minimize the assembly sequence and inspect disassembly before
opening a huge waveform. Display PC, instruction PC, IR, FSM, operands, ALU
result, register writeback and bus valid/ready/error. Trigger a small VCD/FST
window around the first failing instruction, then inspect in GTKWave.

The instruction PC, expected next PC and bus address often diverge before the
visible output fails. A load bug may actually be a request repeated during a
wait, a wrong byte lane, or a response sampled one cycle too early.

## Frequent mistakes and why they hurt

| Mistake | Consequence / prevention |
| --- | --- |
| Asynchronous memory model in simulation, BRAM on FPGA | CPU samples stale data; model synchronous reads from M2 |
| Implicit signedness / unsized constants | Wrong SLT, SRA and branch results; use explicit widths and signed casts |
| Wrong B/J immediate wiring or shifting twice | Incorrect backward branches/calls; independent pack/decode tests |
| Using updated PC or rs1 for JALR/AUIPC | Wrong links/targets; latch instruction PC and old operands |
| Truncating address bits without range checking | ROM/MMIO/out-of-range aliases RAM; check full address first |
| Ignoring strobes / load sign extension | C chars/shorts corrupt neighbors or return wrong values |
| Repeating store when ready is delayed | Duplicate MMIO actions; define exactly one completion event |
| Ignoring loads whose destination is x0 | Missing required memory exceptions or UART side effects |
| Resetting all RAM in RTL | RAM becomes LUT/register storage; initialize via image/startup instead |
| Partial instruction decoding | M/C/illegal instructions execute as valid RV32I; validate all required fields |
| Default GCC ISA or incompatible libgcc | Unexpected multiply/compressed/64-bit instructions; inspect final ELF |
| Wrong gp initialization / linker relaxation | Broken global accesses; use norelax gp setup and initially disable relaxation |
| Missing BSS clear, data load or 16-byte SP alignment | C fails before main or only on reload; dedicated runtime tests |
| Treating `volatile` as a hardware protocol | Lost serial bytes; implement status and completion semantics |
| Starting pipelining before a reference baseline | Multiple new bug classes at once; retain the multicycle model for comparison |
| Unconstrained timing / invented board pins | Simulation passes but hardware fails; use schematic and timing reports |

## Regression policy

Each real functional change adds or updates a meaningful test at the layer that
can expose its failure. Keep directed tests fast; run seeded extended/reference
tests at integration gates. Save failing artifacts on CI. Coverage percentages
and instruction counts support evidence but do not replace testing of corner
cases or a correct reference contract. M0 CI exists now; CPU-specific targets
and tests are future work, not placeholders returning success.
