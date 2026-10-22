# M1, step 4: the RV32I instruction decoder

`rtl/core/decoder.sv` classifies the 40 RV32I instruction types, checks their
encoding constraints and produces deterministic datapath controls. It is
combinational, with no clock, register writes, bus requests or execution of its
own. M1 still needs the load/store unit; a complete CPU and control FSM remain
later integration work.

Encoding references are the [RV32I 2.1 manual](https://docs.riscv.org/reference/isa/v20260120/unpriv/rv32.html),
and the official [rv_i](https://github.com/riscv/riscv-opcodes/blob/master/extensions/rv_i)
and [rv32_i](https://github.com/riscv/riscv-opcodes/blob/master/extensions/rv32_i)
encoding tables, checked 2026-10-22. No reference CPU or existing CPU RTL is used.

## Interface contract

The input is `instr_i[31:0]`. Register addresses are always the raw fields:
`rs1_addr_o=instr[19:15]`, `rs2_addr_o=instr[24:20]`, and
`rd_addr_o=instr[11:7]`. Even an illegal word exposes those bits; this does not
authorize their use. The flags below qualify consumption and side effects.

| Control output | Meaning |
| --- | --- |
| `illegal_o` | No supported RV32I encoding matched |
| `reg_write_o` | Instruction has a destination write intent, including when rd=x0 |
| `rs1_used_o`, `rs2_used_o` | Whether each field denotes a consumed register operand; still true for an operand that names x0 |
| `alu_op_o[3:0]` | Existing ADD/SUB/logic/shift/comparison selector |
| `alu_a_sel_o[1:0]` | RS1=0, instruction PC=1, zero=2 |
| `alu_b_imm_o` | Select the generated immediate when 1, RS2 when 0 |
| `imm_format_o[2:0]` | Existing NONE/I/S/B/U/J selector |
| `wb_sel_o[1:0]` | ALU result=0, load result=1, instruction PC+4=2 |
| `mem_read_o`, `mem_write_o` | Load/store intent; never simultaneously true |
| `mem_size_o[1:0]` | Byte=0, halfword=1, word=2; meaningful for memory operations |
| `load_unsigned_o` | Zero extension for LBU/LHU; otherwise zero |
| `branch_o[2:0]` | NONE=0, EQ=1, NE=2, LT=3, GE=4, LTU=5, GEU=6 |
| `jump_o[1:0]` | NONE=0, JAL=1, JALR=2 |
| `fence_o` | Conservative full FENCE intent |
| `system_o[1:0]` | NONE=0, ECALL=1, EBREAK=2; these are internal kinds, not trap-cause numbers |

`rv32_pkg.sv` names these controls with enums. Module ports remain bit vectors.
The future core must gate actual memory requests and register writes with its
FSM phase, instruction validity, reset, completion and fault state. Directly
connecting a combinational write intent to a bus request would repeat effects
across multicycle states. Decoding explains **what** the instruction requests;
the clocked control unit decides **when** it may happen.

## How the controls connect

| Instruction group | ALU operands / use | Writeback / extra control |
| --- | --- | --- |
| LUI | Zero + U immediate | ALU result |
| AUIPC | Instruction PC + U immediate | ALU result |
| JAL | Instruction PC + J offset | PC+4; jump kind JAL |
| JALR | Old RS1 + I offset | PC+4; jump kind JALR |
| Conditional branches | Instruction PC + B offset for target | No register write; separate branch condition kind compares RS1/RS2 |
| Loads | RS1 + I offset for address | Load result; size and sign/zero extension controls |
| Stores | RS1 + S offset for address; RS2 supplies data | No register write; store size |
| Register-immediate ALU | RS1 and I immediate | Selected ALU result |
| Register-register ALU | RS1 and RS2 | Selected ALU result |
| FENCE | No operands consumed | Ordering flag, no register/memory write |
| ECALL / EBREAK | No ISA source operands consumed | Recognized system trap intent, not illegal |

Branch comparison, PC updates, JALR bit0 clearing, target alignment, load
completion, precise traps and register writeback are not performed here.
The immediate generator already inserts the B/J low zero bit. The core must
use the instruction's saved PC, not an incremented fetch PC, for relative
arithmetic. JALR must use the old RS1 when rd and rs1 name the same register.

## Legality and safe defaults

The RTL begins each combinational evaluation with illegal=1 and all controls
neutral. It checks all seven opcode bits. Each family validates funct3 and,
where required, all seven funct7 bits before enabling common controls. There
is no `casex`, partial funct7 comparison or previous-control retention.

For OP instructions, funct7=0 selects the ordinary operations; funct7=0x20 is
valid only for SUB and SRA. For shift-immediate instructions, SLLI/SRLI require
funct7=0, and SRAI requires 0x20. Non-shift I immediates are unrestricted data.
Unsupported M, RV64-only, CSR, privileged, compressed and FENCE.I encodings
outside the accepted base patterns are rejected. Reserved branch/load/store
funct3 values and malformed SYSTEM words are rejected too.

Every illegal instruction produces the same neutral control word: illegal=1,
all flags zero, ADD/RS1/RS2/NONE/ALU/byte default selectors. Raw register fields
still reflect the input. The core must convert illegal into a precise trap;
the decoder cannot halt a CPU itself.

Two important exceptions to overly strict decoding are deliberate:

- A load with rd=x0 still enables the memory operation and load handling.
  Register-file x0 suppression must not remove its exceptions or MMIO effects.
  Other legal rd=x0 operations, including base HINT encodings, keep their normal
  controls and naturally discard the register result.
- Base FENCE ignores rd/rs1 and treats reserved mode configurations as ordinary
  fences. This decoder accepts every `opcode=0x0f, funct3=0` word and requests a
  conservative full fence, including FENCE.TSO and hint-overlapping patterns.
  FENCE.I has a different funct3 and remains unsupported. This behavior does
  not claim implementation of additional extension semantics.

Only exact words 0x00000073 and 0x00100073 select ECALL and EBREAK. Other SYSTEM
words are illegal under this project's no-CSR/no-privileged-instruction policy.
The defined EEI will stop on their recognized traps; no syscall runtime is
provided by this decoder.

## Independent verification

`tests/reference/decoder_model.py` is a flat mask/match table with independently
declared semantic controls. It does not read RTL or duplicate the RTL's nested
opcode decision tree. It verifies that the 40 patterns are mutually exclusive.
`scripts/gen_decoder_vectors.py` uses it to generate expected controls and raw
register fields. GNU tools separately assemble `decoder_cases.S`, which has
one real instruction per type, including a load to x0.

The default seed is `0xdec0321`. The default **215,000 vectors** comprise:

| Group | Count / coverage |
| --- | --- |
| Assembled fixtures | 40, covering each RV32I instruction type |
| Pattern boundaries and single-bit mutations | 80 + 2,560 |
| Opcode/funct3/funct7 matrix | All 131,072 combinations, with fixed nonzero register fields |
| Shift-immediate fields | All 8,192 words for the two shift funct3 values and 4096 immediate fields |
| SYSTEM fields/register restrictions | 32,768 funct3/immediate combinations + 2,048 ECALL/EBREAK register combinations |
| FENCE fields/registers | All 4,096 mode/pred/succ settings + 1,024 rd/rs1 pairs |
| Random legal patterns | 256 free-field variants per instruction, 10,240 total |
| Random full words | 10,000 |
| Interleaved illegal transitions | 12,880, checking that legal controls clear on the next bad word |

The testbench compares all 29 control bits and 15 raw register-field bits. It
also independently asserts the illegal neutral-control invariant, mutual
exclusion of load/store intents and safe store controls. Complete runs require
all 40 instruction kinds and illegal cases; failures print row, instruction,
actual/expected control words and register fields. Nine harness tests check the
checker itself, including wrong expectations, damaged input, missing coverage
and an out-of-range coverage ID.

The control serialization used only by tests is MSB first:

```text
28       illegal
27       reg_write
26:25    rs1_used, rs2_used
24:21    alu_op
20:19    alu_a_sel
18       alu_b_imm
17:15    imm_format
14:13    wb_sel
12:11    mem_read, mem_write
10:9     mem_size
8        load_unsigned
7:5      branch
4:3      jump
2        fence
1:0      system
```

These checks cover the named field spaces, not all 2^32 instruction words or
four-state X/Z behavior. Recognition of all instructions is not proof of a
complete executing CPU. PC/operand-dependent execution faults need later core
tests. No FPGA timing or hardware execution is claimed.

## Run and inspect

Inside Ubuntu, from the repository root:

```bash
make unit-decoder
make lint synth-decoder
make check
make wave-decoder
```

Optional stimulus controls are `DECODER_SEED=0x12345678`,
`DECODER_RANDOM_PER_INSTRUCTION=256` and `DECODER_RANDOM_WORDS=10000`.
Reducing random counts is useful for debugging but is not the default gate.
The waveform target runs a limited 256-vector sample including the 40 assembled
examples. Add `instr_i`, `illegal_o`, operand/ALU/immediate/writeback selectors,
read/write intents, branch/jump and system outputs in GTKWave. Compare
the store examples and illegal words: memory-write intent is disabled for
illegal instructions.

Ignored evidence lives under `build/decoder/`: fixture ELF/binary/disassembly,
vectors and seed/coverage JSON, simulator, VCD, synthesis log and JSON netlist.
The combined local regression log is `build/decoder/check.log`.

Verified on 2026-10-22 with Ubuntu 24.04, Verilator 5.020, Yosys 0.33 and
RISC-V GCC 13.2.0/binutils 2.42:

| Check | Observed result |
| --- | --- |
| Decoder vectors | 215,000 passed, including 191,239 illegal words |
| Assembled fixtures | All 40 instruction types matched |
| Decoder harness | All nine tests passed, including eight rejection cases |
| Complete `make check` | Passed: compiler/environment, all four datapath units and 23 total harness checks |
| Warning-fatal lint | Passed for all four modules |
| Generic synthesis | Zero check problems; 300 combinational cells; no latches or flip-flops |

Generic cell counts are not post-route FPGA LUT/timing measurements.

Next implement the **load/store unit**: effective-address alignment, byte write
masks and data placement, signed/unsigned load extraction, and suppression of
memory effects for unsupported or misaligned requests.
