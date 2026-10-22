#!/usr/bin/env bash
set -euo pipefail
prefix=${CROSS:-riscv64-unknown-elf-}
required=(git gcc g++ make cmake ninja python3 verilator gtkwave yosys
          "${prefix}gcc" "${prefix}as" "${prefix}ld" "${prefix}objdump"
          "${prefix}objcopy" "${prefix}readelf")
missing=0
for tool in "${required[@]}"; do
    if command -v "$tool" >/dev/null; then
        printf 'OK  %-32s %s\n' "$tool" "$(command -v "$tool")"
    else
        printf 'MISSING %s\n' "$tool" >&2
        missing=1
    fi
done
(( missing == 0 )) || exit 1
python3 -c 'import elftools, serial; print("PASS Python ELF / serial modules")'
"${prefix}gcc" --version | sed -n '1p'
verilator --version
yosys -V
echo 'RV32I libgcc selection (needed later for compiler helper routines):'
"${prefix}gcc" -march=rv32i -mabi=ilp32 -print-libgcc-file-name
for tool in nextpnr-ecp5 ecppack openFPGALoader; do
    if command -v "$tool" >/dev/null; then
        printf 'OPTIONAL FPGA OK: %s\n' "$(command -v "$tool")"
    else
        printf 'OPTIONAL FPGA deferred: %s\n' "$tool"
    fi
done
echo 'PASS tool discovery. make check validates actual compilation and RTL execution.'
