"""Independent mask/match oracle -> decoder control and register-field vectors."""

import argparse
import collections
import json
import random
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tests" / "reference"))
from decoder_model import PATTERNS, decode, registers, validate_table


MASK = (1 << 32) - 1


def directed_words():
    # Opposite free-field settings and every single instruction-bit mutation.
    for item in PATTERNS:
        for background in (0, MASK):
            word = item.match | (background & (MASK ^ item.mask))
            yield word, "pattern_boundaries"
            yield 0, "illegal_transitions"
            for bit in range(32):
                yield word ^ (1 << bit), "single_bit_mutations"
                yield 0, "illegal_transitions"

    # Every opcode/funct3/funct7 combination, including non-32-bit suffixes.
    register_fields = (3 << 15) | (11 << 20) | (5 << 7)
    for opcode in range(128):
        for funct3 in range(8):
            for funct7 in range(128):
                yield register_fields | (funct7 << 25) | (funct3 << 12) | opcode, "opcode_matrix"
    for funct3 in (1, 5):
        for immediate in range(4096):
            yield (immediate << 20) | (3 << 15) | (funct3 << 12) | (5 << 7) | 0x13, "shift_fields"
    for immediate in range(4096):
        for funct3 in range(8):
            yield (immediate << 20) | (funct3 << 12) | 0x73, "system_fields"
    for immediate in (0, 1):
        for rs1 in range(32):
            for rd in range(32):
                yield (immediate << 20) | (rs1 << 15) | (rd << 7) | 0x73, "system_registers"
    for fields in range(4096):
        yield (fields << 20) | (31 << 15) | (31 << 7) | 0x0f, "fence_fields"
    for rs1 in range(32):
        for rd in range(32):
            yield 0x8330000f | (rs1 << 15) | (rd << 7), "fence_registers"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=lambda s: int(s, 0), default=0xdec0321)
    parser.add_argument("--random-per-instruction", type=int, default=256)
    parser.add_argument("--random-words", type=int, default=10000)
    parser.add_argument("--assembled", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if min(args.random_per_instruction, args.random_words) < 0:
        parser.error("random counts must be nonnegative")
    validate_table()
    rng = random.Random(args.seed)
    data = args.assembled.read_bytes()
    if len(data) != 4 * len(PATTERNS):
        raise ValueError(f"expected {len(PATTERNS)} four-byte assembled instructions, got {len(data)} bytes")
    groups = collections.Counter()
    kinds = [0] * 41
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="ascii", newline="\n") as stream:
        def emit(word, group):
            controls, kind = decode(word)
            stream.write(f"{word:08x} {controls:08x} {registers(word):04x} {kind:02x}\n")
            groups[group] += 1
            kinds[kind] += 1

        # Instruction order is independently written in decoder_cases.S.
        for index, (word,) in enumerate(struct.iter_unpack("<I", data)):
            _, kind = decode(word)
            if kind != index:
                raise RuntimeError(f"assembler/reference disagreement at {PATTERNS[index].name}: {word:08x}")
            emit(word, "assembled")
        for word, group in directed_words():
            emit(word, group)
        invalid_examples = (0, MASK, 0x02000033, 0x0000100f, 0x30001073, 0x0000003b)
        for word in invalid_examples:
            if decode(word)[1] != 40:
                raise RuntimeError("bad negative fixture")
        for item in PATTERNS:
            for _ in range(args.random_per_instruction):
                word = item.match | (rng.getrandbits(32) & (MASK ^ item.mask))
                emit(word, "random_legal")
                emit(rng.choice(invalid_examples), "illegal_transitions")
        for _ in range(args.random_words):
            emit(rng.getrandbits(32), "random_words")
    summary = {
        "seed": args.seed, "total_vectors": sum(groups.values()), "groups": dict(groups),
        "random_per_instruction": args.random_per_instruction, "random_words": args.random_words,
        "per_instruction": {item.name: kinds[index] for index, item in enumerate(PATTERNS)},
        "illegal_vectors": kinds[40],
    }
    if not all(kinds):
        raise RuntimeError("missing instruction/illegal coverage in reference vectors")
    args.output.with_suffix(".json").write_text(json.dumps(summary, indent=2) + "\n")
    print(f"Decoder vectors: seed=0x{args.seed:x}, total={sum(groups.values())}, "
          f"all 40 instructions + illegal, assembled={groups['assembled']}")


if __name__ == "__main__":
    main()
