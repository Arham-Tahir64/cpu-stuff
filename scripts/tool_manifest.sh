#!/usr/bin/env bash
set -euo pipefail
source /etc/os-release
printf 'OS: %s\n' "$PRETTY_NAME"
for tool in git gcc make cmake ninja python3 verilator yosys; do
    if [[ $tool == yosys ]]; then "$tool" -V; else "$tool" --version | sed -n '1p'; fi
done
"${CROSS:-riscv64-unknown-elf-}gcc" --version | sed -n '1p'
dpkg-query -W -f='${binary:Package}=${Version}\n' \
    build-essential git make cmake ninja-build python3 python3-venv python3-pip \
    python3-serial python3-pyelftools gcc-riscv64-unknown-elf \
    binutils-riscv64-unknown-elf verilator gtkwave yosys
