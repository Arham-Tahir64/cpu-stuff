"""Independent RV32I mask/match oracle and public control-word contract.

Encoding facts: RISC-V RV32I 2.1 and riscv/riscv-opcodes extensions/rv_i,
extensions/rv32_i (checked 2026-10-22). This hand-authored test table does not
read RTL or implement the DUT's nested opcode/funct decoder.
"""

from dataclasses import dataclass


# MSB first, matching the documented test serialization (29 control bits).
FIELDS = (
    ("illegal", 1), ("reg_write", 1), ("rs1_used", 1), ("rs2_used", 1),
    ("alu_op", 4), ("alu_a_sel", 2), ("alu_b_imm", 1), ("imm_format", 3),
    ("wb_sel", 2), ("mem_read", 1), ("mem_write", 1), ("mem_size", 2),
    ("load_unsigned", 1), ("branch", 3), ("jump", 2), ("fence", 1), ("system", 2),
)


def control(**values):
    unknown = set(values) - {name for name, _ in FIELDS}
    if unknown:
        raise ValueError(f"unknown controls: {unknown}")
    result = 0
    for name, width in FIELDS:
        value = values.get(name, 0)
        if not 0 <= value < (1 << width):
            raise ValueError(f"out-of-range control: {name}={value}")
        result = (result << width) | value
    return result


SAFE_ILLEGAL = control(illegal=1)


@dataclass(frozen=True)
class Pattern:
    name: str
    mask: int
    match: int
    controls: int


def pattern(name, mask, match, **values):
    return Pattern(name, mask, match, control(**values))


R = dict(reg_write=1, rs1_used=1, rs2_used=1)
I = dict(reg_write=1, rs1_used=1, alu_b_imm=1, imm_format=1)
B = dict(rs1_used=1, rs2_used=1, alu_a_sel=1, alu_b_imm=1, imm_format=3)
L = dict(reg_write=1, rs1_used=1, alu_b_imm=1, imm_format=1, wb_sel=1, mem_read=1)
S = dict(rs1_used=1, rs2_used=1, alu_b_imm=1, imm_format=2, mem_write=1)
PATTERNS = (
    pattern("lui",   0x0000007f, 0x00000037, reg_write=1, alu_a_sel=2, alu_b_imm=1, imm_format=4),
    pattern("auipc", 0x0000007f, 0x00000017, reg_write=1, alu_a_sel=1, alu_b_imm=1, imm_format=4),
    pattern("jal",   0x0000007f, 0x0000006f, reg_write=1, alu_a_sel=1, alu_b_imm=1, imm_format=5, wb_sel=2, jump=1),
    pattern("jalr",  0x0000707f, 0x00000067, **I, wb_sel=2, jump=2),
    pattern("beq",   0x0000707f, 0x00000063, **B, branch=1),
    pattern("bne",   0x0000707f, 0x00001063, **B, branch=2),
    pattern("blt",   0x0000707f, 0x00004063, **B, branch=3),
    pattern("bge",   0x0000707f, 0x00005063, **B, branch=4),
    pattern("bltu",  0x0000707f, 0x00006063, **B, branch=5),
    pattern("bgeu",  0x0000707f, 0x00007063, **B, branch=6),
    pattern("lb",    0x0000707f, 0x00000003, **L),
    pattern("lh",    0x0000707f, 0x00001003, **L, mem_size=1),
    pattern("lw",    0x0000707f, 0x00002003, **L, mem_size=2),
    pattern("lbu",   0x0000707f, 0x00004003, **L, load_unsigned=1),
    pattern("lhu",   0x0000707f, 0x00005003, **L, mem_size=1, load_unsigned=1),
    pattern("sb",    0x0000707f, 0x00000023, **S),
    pattern("sh",    0x0000707f, 0x00001023, **S, mem_size=1),
    pattern("sw",    0x0000707f, 0x00002023, **S, mem_size=2),
    pattern("addi",  0x0000707f, 0x00000013, **I),
    pattern("slti",  0x0000707f, 0x00002013, **I, alu_op=8),
    pattern("sltiu", 0x0000707f, 0x00003013, **I, alu_op=9),
    pattern("xori",  0x0000707f, 0x00004013, **I, alu_op=4),
    pattern("ori",   0x0000707f, 0x00006013, **I, alu_op=3),
    pattern("andi",  0x0000707f, 0x00007013, **I, alu_op=2),
    pattern("slli",  0xfe00707f, 0x00001013, **I, alu_op=5),
    pattern("srli",  0xfe00707f, 0x00005013, **I, alu_op=6),
    pattern("srai",  0xfe00707f, 0x40005013, **I, alu_op=7),
    pattern("add",   0xfe00707f, 0x00000033, **R),
    pattern("sub",   0xfe00707f, 0x40000033, **R, alu_op=1),
    pattern("sll",   0xfe00707f, 0x00001033, **R, alu_op=5),
    pattern("slt",   0xfe00707f, 0x00002033, **R, alu_op=8),
    pattern("sltu",  0xfe00707f, 0x00003033, **R, alu_op=9),
    pattern("xor",   0xfe00707f, 0x00004033, **R, alu_op=4),
    pattern("srl",   0xfe00707f, 0x00005033, **R, alu_op=6),
    pattern("sra",   0xfe00707f, 0x40005033, **R, alu_op=7),
    pattern("or",    0xfe00707f, 0x00006033, **R, alu_op=3),
    pattern("and",   0xfe00707f, 0x00007033, **R, alu_op=2),
    pattern("fence", 0x0000707f, 0x0000000f, fence=1),
    pattern("ecall", 0xffffffff, 0x00000073, system=1),
    pattern("ebreak",0xffffffff, 0x00100073, system=2),
)


def validate_table():
    if len(PATTERNS) != 40 or sum(width for _, width in FIELDS) != 29:
        raise RuntimeError("unexpected ISA/control table size")
    for index, item in enumerate(PATTERNS):
        if item.match & item.mask != item.match:
            raise RuntimeError(f"unmasked match bits: {item.name}")
        for other in PATTERNS[index + 1:]:
            if (item.match ^ other.match) & (item.mask & other.mask) == 0:
                raise RuntimeError(f"overlapping ISA patterns: {item.name}/{other.name}")


def decode(word):
    hits = [(index, item) for index, item in enumerate(PATTERNS) if word & item.mask == item.match]
    if len(hits) > 1:
        raise RuntimeError("ambiguous reference decode")
    if hits:
        index, item = hits[0]
        return item.controls, index
    return SAFE_ILLEGAL, 40


def registers(word):
    return (((word >> 15) & 31) << 10) | (((word >> 20) & 31) << 5) | ((word >> 7) & 31)
