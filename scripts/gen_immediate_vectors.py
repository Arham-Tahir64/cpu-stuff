"""Encode logical immediates into instruction words; keep original values as oracle.

This does not decode instructions or read the RTL. Explicit bit-position maps
place payload bits in instruction words, while expected values come from the
signed logical payload and its byte scale. Real GNU-assembled words provide a
second, independent encoding source.
"""

import argparse
import json
import random
import struct
from pathlib import Path


MASK = (1 << 32) - 1
# Selector -> name, instruction positions in increasing payload-bit order, scale.
# B/J payloads omit the implicit low zero bit; multiplying by two restores bytes.
SPECS = {
    1: ("I", tuple(range(20, 32)), 1),
    2: ("S", tuple(range(7, 12)) + tuple(range(25, 32)), 1),
    3: ("B", (8, 9, 10, 11, *range(25, 31), 7, 31), 2),
    4: ("U", tuple(range(12, 32)), 4096),
    5: ("J", (*range(21, 31), 20, *range(12, 20), 31), 2),
}
ASSEMBLED_CASES = [
    (1, -1), (1, -2048), (1, 2047), (1, -1), (1, -16), (1, 1),
    (1, 0x41f),  # SRAI's raw I field includes funct7, not just shamt.
    (2, -4), (2, -2048), (2, 2047),
    (3, 4), (3, -4), (3, 2048), (3, -4096),
    (4, 0xabcde000), (4, 0x80000000), (4, 0x7ffff000),
    (5, 8), (5, -4), (5, 1048574), (5, -1048576), (3, 4094), (5, 2048),
]


def encode(selector: int, payload: int, background: int) -> tuple[int, int]:
    _, positions, scale = SPECS[selector]
    width = len(positions)
    if not 0 <= payload < (1 << width):
        raise ValueError("payload outside format width")
    field_mask = sum(1 << position for position in positions)
    instruction = background & (MASK ^ field_mask)
    for bit, position in enumerate(positions):
        instruction |= ((payload >> bit) & 1) << position
    value = payload if payload < (1 << (width - 1)) else payload - (1 << width)
    return instruction, (value * scale) & MASK


def assembled_vectors(binary: Path):
    data = binary.read_bytes()
    if len(data) != 4 * len(ASSEMBLED_CASES):
        raise ValueError(f"expected {len(ASSEMBLED_CASES)} four-byte fixture instructions, got {len(data)} bytes")
    for (selector, expected), (word,) in zip(ASSEMBLED_CASES, struct.iter_unpack("<I", data)):
        # Cross-check the independent packer against actual assembled fields.
        _, positions, scale = SPECS[selector]
        payload = (expected // scale) % (1 << len(positions))
        reconstructed, oracle_value = encode(selector, payload, word)
        if reconstructed != word or oracle_value != (expected & MASK):
            raise RuntimeError(f"assembler/packer disagreement: format={selector} word={word:08x}")
        yield selector, word, expected & MASK, 0


def directed_vectors():
    # Fixed words/answers add anchors independent of either generated bit map.
    yield from [
        (1, 0xfff00293, 0xffffffff, 0),
        (1, 0x80010093, 0xfffff800, 0),
        (2, 0xfeb62e23, 0xfffffffc, 0),
        (3, 0x00208263, 4, 0),
        (3, 0xfe208ee3, 0xfffffffc, 0),
        (3, 0x00000163, 2, 0),
        (4, 0xabcde2b7, 0xabcde000, 0),
        (5, 0x008000ef, 8, 0),
        (5, 0xffdff0ef, 0xfffffffc, 0),
        (5, 0x0020006f, 2, 0),
    ]
    for selector in (1, 2, 3):
        # Exhaust every I/S/B payload with opposite non-immediate backgrounds.
        for payload in range(4096):
            for background in (0, MASK):
                instruction, expected = encode(selector, payload, background)
                yield selector, instruction, expected, 0
    for selector, (_, positions, _) in SPECS.items():
        width = len(positions)
        field_mask = (1 << width) - 1
        payloads = sorted({0, 1, field_mask, field_mask - 1,
                           (1 << (width - 1)) - 1, 1 << (width - 1),
                           *(1 << bit for bit in range(width)),
                           *(field_mask ^ (1 << bit) for bit in range(width))})
        for payload in payloads:
            instruction, expected = encode(selector, payload, 0)
            yield selector, instruction, expected, 0
            # Individually flip every ignored bit, including opcode bits.
            for bit in sorted(set(range(32)) - set(positions)):
                yield selector, instruction ^ (1 << bit), expected, 0
    for selector in (0, 6, 7):
        for word in (0, MASK, 0x80000000, 0xaaaaaaaa, 0x55555555):
            yield selector, word, 0, int(selector != 0)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=lambda s: int(s, 0), default=0x1a2b3c4d)
    parser.add_argument("--random-cases", type=int, default=10000)
    parser.add_argument("--assembled", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.random_cases < 0:
        parser.error("--random-cases must be nonnegative")
    rng = random.Random(args.seed)
    counts = [0] * 8
    assembled = directed = 0
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="ascii", newline="\n") as stream:
        def emit(vector):
            selector, instruction, expected, invalid = vector
            stream.write(f"{selector:x} {instruction:08x} {expected:08x} {invalid:x}\n")
            counts[selector] += 1

        for vector in assembled_vectors(args.assembled):
            emit(vector)
            assembled += 1
        for vector in directed_vectors():
            emit(vector)
            directed += 1
        for _ in range(args.random_cases):
            for selector, (_, positions, _) in SPECS.items():
                payload = rng.getrandbits(len(positions))
                # Same logical value, independently varied ignored fields.
                for background in (rng.getrandbits(32), rng.getrandbits(32)):
                    instruction, expected = encode(selector, payload, background)
                    emit((selector, instruction, expected, 0))
            for selector in (0, 6, 7):
                emit((selector, rng.getrandbits(32), 0, int(selector != 0)))
    summary = {
        "seed": args.seed, "assembled_vectors": assembled, "directed_vectors": directed,
        "random_cases_per_format": args.random_cases, "random_vectors": args.random_cases * 13,
        "total_vectors": sum(counts), "vectors_per_selector": counts,
    }
    args.output.with_suffix(".json").write_text(json.dumps(summary, indent=2) + "\n")
    print(f"Immediate vectors: seed=0x{args.seed:x}, assembled={assembled}, "
          f"directed={directed}, random={args.random_cases * 13}, total={sum(counts)}")


if __name__ == "__main__":
    main()
