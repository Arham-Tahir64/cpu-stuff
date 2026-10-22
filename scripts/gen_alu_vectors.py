"""Independent integer oracle -> text vectors for the actual SystemVerilog ALU.

This script never reads the RTL. Operation numbers are the public module
contract in docs/08-alu.md; signed conversion uses Python integers, and SRA
uses floor division instead of SystemVerilog signed shifts.
"""

import argparse
import json
import random
from pathlib import Path


MASK = (1 << 32) - 1
OPS = {
    "ADD": 0x0, "SUB": 0x1, "AND": 0x2, "OR": 0x3, "XOR": 0x4,
    "SLL": 0x5, "SRL": 0x6, "SRA": 0x7, "SLT": 0x8, "SLTU": 0x9,
}


def signed(value: int) -> int:
    return value if value < (1 << 31) else value - (1 << 32)


def expected(op: int, a: int, b: int) -> tuple[int, int]:
    shift = b % 32
    operations = {
        0x0: lambda: a + b,
        0x1: lambda: a - b,
        0x2: lambda: a & b,
        0x3: lambda: a | b,
        0x4: lambda: a ^ b,
        0x5: lambda: a * (1 << shift),
        0x6: lambda: a // (1 << shift),
        0x7: lambda: signed(a) // (1 << shift),
        0x8: lambda: int(signed(a) < signed(b)),
        0x9: lambda: int(a < b),
    }
    if op not in operations:
        return 0, 1
    return operations[op]() & MASK, 0


def directed_vectors():
    # Literal examples cross-check the Python oracle before the SV run.
    known = [
        ("ADD", 0xffffffff, 1, 0),
        ("ADD", 0x7fffffff, 1, 0x80000000),
        ("ADD", 0x80000000, 0x80000000, 0),
        ("SUB", 0, 1, 0xffffffff),
        ("SUB", 0x80000000, 1, 0x7fffffff),
        ("AND", 0xaaaaaaaa, 0x55555555, 0),
        ("OR", 0xaaaaaaaa, 0x55555555, 0xffffffff),
        ("XOR", 0xaaaaaaaa, 0xffffffff, 0x55555555),
        ("SLL", 1, 31, 0x80000000),
        ("SLL", 0x89abcdef, 32, 0x89abcdef),
        ("SRL", 0x80000000, 31, 1),
        ("SRL", 0xffffffff, 0xffffffff, 1),
        ("SRA", 0x80000000, 31, 0xffffffff),
        ("SRA", 0x80000000, 0, 0x80000000),
        ("SRA", 0xfffffffd, 1, 0xfffffffe),  # -3 / 2 rounds down to -2
        ("SRA", 0x80000000, 63, 0xffffffff),
        ("SRA", 0x80000000, 32, 0x80000000),
        ("SLT", 0x80000000, 0, 1),
        ("SLTU", 0x80000000, 0, 0),
        ("SLT", 0xffffffff, 1, 1),
        ("SLTU", 0xffffffff, 1, 0),
        ("SLT", 0x7fffffff, 0x80000000, 0),
        ("SLTU", 0x7fffffff, 0x80000000, 1),
        ("SLT", 0x80000000, 0x80000000, 0),
    ]
    for name, a, b, literal in known:
        op = OPS[name]
        if expected(op, a, b) != (literal, 0):
            raise RuntimeError(f"Python oracle failed literal example: {name} {a:x} {b:x}")
        yield op, a, b, literal, 0

    edges = (0, 1, 2, 31, 32, 63, 0x7ffffffe, 0x7fffffff,
             0x80000000, 0x80000001, 0xfffffffe, 0xffffffff,
             0xaaaaaaaa, 0x55555555)
    for a in edges:
        for b in edges:
            for op in range(16):
                yield op, a, b, *expected(op, a, b)

    # Every shift count, including masked upper bits, against both signs.
    for a in edges:
        for shift in range(32):
            for b in (shift, shift + 32, 0xffffffe0 | shift):
                for op in (OPS["SLL"], OPS["SRL"], OPS["SRA"]):
                    yield op, a, b, *expected(op, a, b)

    # Walking bits, carry/borrow chains and comparisons around each bit.
    for bit in range(32):
        for a, b in ((1 << bit, 1), ((1 << bit) - 1, 1),
                     (MASK ^ (1 << bit), 1 << bit)):
            for op in range(16):
                yield op, a, b, *expected(op, a, b)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=lambda s: int(s, 0), default=0x1badf00d)
    parser.add_argument("--random-pairs", type=int, default=10000)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.random_pairs < 0:
        parser.error("--random-pairs must be nonnegative")
    rng = random.Random(args.seed)
    counts = [0] * 16
    directed = 0
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="ascii", newline="\n") as stream:
        def emit(vector):
            op, a, b, result, invalid = vector
            stream.write(f"{op:x} {a:08x} {b:08x} {result:08x} {invalid:x}\n")
            counts[op] += 1

        for vector in directed_vectors():
            emit(vector)
            directed += 1
        for _ in range(args.random_pairs):
            a, b = rng.getrandbits(32), rng.getrandbits(32)
            order = list(range(16))
            rng.shuffle(order)
            for op in order:
                emit((op, a, b, *expected(op, a, b)))
    summary = {
        "seed": args.seed, "directed_vectors": directed,
        "random_pairs": args.random_pairs, "random_vectors": args.random_pairs * 16,
        "total_vectors": sum(counts), "vectors_per_control": counts,
    }
    args.output.with_suffix(".json").write_text(json.dumps(summary, indent=2) + "\n")
    print(f"ALU vectors: seed=0x{args.seed:x}, directed={directed}, "
          f"random={args.random_pairs * 16}, total={sum(counts)}")


if __name__ == "__main__":
    main()
