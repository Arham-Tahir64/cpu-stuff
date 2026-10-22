# Progressive milestones and acceptance gates

Each milestone produces a reviewable artifact and an executable test. Do not
start the pipeline before the multicycle system has a stable regression suite.
The estimates are engineering planning estimates and include debugging.

Current progress: M0 automated checks pass. M1's ALU and its independent
testbench are implemented; the register file, immediate generator, decoder
and LSU remain. See [the ALU walkthrough](08-alu.md) for its measured results.

| Gate | Work and approximate effort | Acceptance evidence |
| --- | --- | --- |
| M0: environment | WSL, compiler, simulator, viewer, build scripts; 3–8 h | `make check` exits zero; inspect counter waveform; ELF32 RV32I linked; tool versions saved. No CPU execution claimed. |
| M1: datapath units | ALU, register file, immediate generator, legal decoder, LSU; 20–40 h | All directed edge cases pass; at least 10,000 seeded random ALU/immediate cases; every register write/read pair and x0 suppression tested; no lint errors or unintended latches. |
| M2: first running core | PC, FSM, bus model, ADDI/ADD/SUB, LUI, branches, jumps; 20–35 h | Handwritten program reaches known register values; correct trace per instruction; backward branch and rd=rs1 JALR tests pass; 0/1/2/7-cycle bus waits produce the same retirement trace. Clearly label as an ISA subset. |
| M3: complete RV32I | Remaining ALU/branches, all byte/halfword/word accesses, FENCE and traps; 35–65 h | One directed test per legal instruction plus boundary/illegal cases; all address-lane cases; exact trap PCs/causes; no side effects on a fault; at least 100,000 retired instructions across seeded reference comparisons. |
| M4: bare-metal C and ELF | Runtime, linker, validated segment converter/sim loader; 20–40 h | Five C demos run on custom RTL; exact UART/checksum/exit results; initialized data and zero BSS verified; malformed ELF suite rejected; inspect final ISA attributes/disassembly. |
| M5: SoC and boot | Real UART RTL, GPIO, ROM monitor, host loader; 25–45 h | Bit-level UART loopback; load two ELFs consecutively without resynthesis; CRC, bounds and timeout tests; ROM resets cleanly after invalid packet; same CPU/RAM/UART RTL used in simulation. |
| M6: optional FPGA | Board pins/reset, BRAM inference, synthesis, P&R, JTAG, physical UART; 25–50 h | Timing passes at 25 MHz; resource report fits; three reset/reload cycles and all five demos on hardware; UART transcripts/checksums agree with simulation; archived bitstream/ELF hashes and logs. |
| M7: documentation/release | Rebuild instructions and captured evidence; 10–20 h | Fresh checkout reproduces tests; hardware bill of materials and tool versions recorded; limitations explicit; no fabricated hardware results. |
| M8: optional 5-stage core | IF/ID/EX/MEM/WB, hazards, forwarding, stalls, flushes; 80–200+ h | All M3–M5 regressions unchanged architecturally; load-use, wrong-path store, forwarding, branch and bus-backpressure tests; compare CPI and post-route clock against multicycle baseline. |

These ranges are approximate and can exceed the headline estimate. Stop after
M5 for a valid software-only hardware-design project. M6 is needed to satisfy
the original physical-FPGA requirement; simulated operation alone cannot do so.

## Begin M1 after M0 passes

First, write module contracts and reference examples before implementation.
Keep `tests/smoke` as the toolchain check. `rtl/core`, `rtl/files.f` and
`tests/unit` now contain the ALU step. The remaining modules below are the
next exercises; they are not implemented yet.

1. **ALU**: explicit operation input; two 32-bit operands; 32-bit result.
   Implement ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT and SLTU.
   Use an `always_comb` block with default assignment and a complete `case`.
   Use `$signed(a)` for signed comparisons and arithmetic shift, and `b[4:0]`
   for shift amount. Addition truncates to 32 bits; signed overflow does not trap.
2. **`tb_alu.sv`**: assert 0xffffffff+1=0, 0−1=0xffffffff,
   SLT(0x80000000,0)=1, SLTU(0x80000000,0)=0,
   SRA(0x80000000,31)=0xffffffff, SRL(...,31)=1;
   shifts by 32 use shift amount 0, and shifts by 63 use 31.
   Sweep shift counts and alternating-bit patterns, then seeded random cases.
   Compute expected signed comparisons independently rather than repeating
   the DUT's `case` verbatim. Report seed and operands on failure.
3. **Register file and `tb_regfile.sv`**: synchronous reset/write, two read
   ports, x0 fixed zero. Verify every address and both ports, write disable,
   x0 writes, reset during activity, and the chosen read-during-write behavior.
   Drive inputs on a negative edge and check after the positive edge settles.
4. **Immediate generator and `tb_immediate.sv`**: reconstruct I/S/B/U/J
   formats. Check positive and negative limits, bit positions and unused-bit
   invariance. Independently pack random immediates into instruction words,
   then compare decoded values. B and J immediates already include their low 0.
5. **Decoder and `tb_decoder.sv`**: enumerate opcode/funct3/funct7 combinations
   and invalid shift encodings. Default every control signal to inactive and
   illegal to true. A recognized legal instruction explicitly enables controls.
   Do not use simulation `casex` to turn unknowns into legal instructions.
6. **LSU and `tb_lsu.sv`**: test each byte lane, both aligned halfword positions,
   signed loads, preserved neighboring bytes, misaligned traps and bus errors.

The ALU commands available now:

```bash
make unit-alu
make lint synth-alu
make wave-alu
```

Use assertions with `$fatal` and a cycle/time limit so a broken core fails,
instead of hanging CI. Introduce a source-list file when packages are added;
package order must be explicit. Test simple modules before wiring a core.

## Required C demonstrations (M4 onward)

| Program | Architectural coverage | Required result |
| --- | --- | --- |
| `arithmetic.c` | Signed/unsigned adds, shifts, bit operations; optional software multiply | Fixed signature calculated independently on host |
| `loops.c` | Counted/backward loops, conditional branches | Sum 1 through 100 = 5050 |
| `functions.c` | Non-inlined nested calls, callee-saved registers, stack | Factorial(6) = 720, using RV32I-compatible helper if compiler emits multiply |
| `memory.c` | Byte/halfword/word accesses, arrays, initialized data, BSS | Exact checksum; BSS zero on each reload; adjacent bytes preserved |
| `hello_uart.c` | Real MMIO polling and string data | Exact `Hello from my RV32I CPU!\n` UART stream and zero exit code |

Use `__attribute__((noinline))`, volatile test buffers or compiler flags where
needed so optimization does not erase the behavior being tested. Run `-O0`,
`-O1` and `-O2` builds later: optimized code often exposes ISA bugs that simple
assembly tests miss. The CPU must execute program instructions in RTL; host
code may model peripherals and check results, never substitute for the CPU.

## Essential versus optional

Essential: correct RV32I, traps as defined by the EEI, stalls on memory latency,
valid C ABI/runtime, RAM, UART/GPIO, deterministic reset/boot, ELF validation,
independent tests, documentation, and physical bring-up if pursuing M6.

Optional and separately gated: five-stage pipeline, M extension, compressed
instructions, machine-mode CSRs/interrupts/timers, debug interface, external
SDRAM, caches, DMA, standard buses, an RTOS, or a Unix-like OS. General-purpose
Linux is far beyond the baseline: a typical port needs privileged architecture,
interrupt/timer infrastructure, substantial memory, and usually Sv32/MMU
support. An MMU-less Linux configuration is a distinct advanced port, not a
shortcut available from RV32I alone.

## Pipeline exploration

Keep IF/ID, ID/EX, EX/MEM and MEM/WB registers with valid bits. Add EX/MEM and
MEM/WB forwarding with nearest producer priority, x0 exclusion, and separate
store-data and branch-operand paths. Forward a load result only when available;
stall for load-use dependencies and inject a bubble without dropping the held
instruction. Resolve branches in EX initially, predict not taken, and kill all
younger instructions on a taken branch/trap. Wrong-path stores and MMIO reads
must never happen. Data-memory waits must propagate backpressure through every
affected stage. One shared RAM port also creates fetch/data structural hazards:
arbitrate and stall correctly, then consider dual-port RAM. Specify reset,
flush and stall priority, and test their simultaneous occurrence.
