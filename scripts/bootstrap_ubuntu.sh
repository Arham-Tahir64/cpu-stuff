#!/usr/bin/env bash
set -euo pipefail
source /etc/os-release
if [[ ${ID:-} != ubuntu || ${VERSION_ID:-} != 24.04 ]]; then
    echo 'This baseline is tested on Ubuntu 24.04 LTS. Review package names for your release.' >&2
    exit 1
fi
elevate=()
if (( EUID != 0 )); then elevate=(sudo); fi
"${elevate[@]}" apt-get update
"${elevate[@]}" env DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential git make cmake ninja-build pkg-config \
    python3 python3-venv python3-pip python3-serial python3-pyelftools \
    gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf \
    verilator gtkwave yosys curl ca-certificates xz-utils unzip \
    usbutils libusb-1.0-0 libftdi1-2
echo 'Dependencies installed. Run make check as your normal Linux user.'
