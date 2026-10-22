# M0: Ubuntu / WSL2 development environment

Use Ubuntu 24.04 LTS for this baseline. Your existing distribution named
`Ubuntu` was detected as Ubuntu 24.04.4 on WSL2 on 2026-10-22; do not reinstall it.
The commands below also document how to reproduce the setup on another PC.

## 1. Windows installation and launch

For a PC with no WSL installed, run in **Administrator PowerShell**, then restart
if Windows requests it:

```powershell
wsl --install -d Ubuntu-24.04
```

Complete the first-launch Linux username/password prompts. For an existing
installation, inspect and launch it in ordinary PowerShell:

```powershell
wsl --list --verbose
wsl -d Ubuntu
```

Use the distribution name actually listed (`Ubuntu-24.04` on some PCs).
`VERSION` must be 2. Only if it is 1, use `wsl --set-version Ubuntu 2`.
Do not unregister a distribution: that deletes its Linux filesystem.

In Ubuntu:

```bash
cat /etc/os-release
uname -r
```

Expect `VERSION_ID="24.04"` and a Microsoft WSL2 kernel. Official guidance:
[Microsoft WSL installation](https://learn.microsoft.com/en-us/windows/wsl/install),
[Ubuntu on WSL](https://documentation.ubuntu.com/wsl/latest/howto/install-ubuntu-wsl2/).

## 2. Dependencies

From this repository in Ubuntu:

```bash
bash scripts/bootstrap_ubuntu.sh
make doctor
make check
```

The script installs Git, host GCC/G++, Make, CMake, Ninja, pkg-config, Python,
venv/pip, pyelftools, pyserial, the bare-metal RISC-V GNU toolchain, Verilator,
GTKWave, Yosys, and USB/download utilities. It performs no distribution upgrade
and does not install a CPU core. `sudo` uses your Linux account password; do not
send that password in chat. It can be rerun after an interrupted installation.

The compiler is **`gcc-riscv64-unknown-elf`**, not the Linux-targeting
`gcc-riscv64-linux-gnu`. The prefix is a tool name; architecture flags select
the output. Always supply:

```bash
riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 --print-multi-lib
riscv64-unknown-elf-readelf -h -l -A build/probe.elf
riscv64-unknown-elf-objdump -d -M no-aliases build/probe.elf
```

`make smoke-elf` actually links a freestanding program, checks ELF32 / RISC-V /
RV32I / soft-float flags and memory segments, and saves the disassembly. Merely
running `gcc --version` does not establish correct target code generation.
Use `-ffreestanding -nostdlib -nostartfiles`, our linker script, and no libc for
the first programs. Later link compatible `-lgcc` helpers when needed.

If a different cross-compiler prefix is used, pass `make CROSS=riscv32-unknown-elf- check`.
Do not mix objects or runtime libraries built for different ISAs or ABIs.
The [official GNU toolchain instructions](https://github.com/riscv-collab/riscv-gnu-toolchain)
describe an optional source build using `--with-arch=rv32i --with-abi=ilp32`;
building GCC from source is unnecessary for this baseline.

## 3. Verify function, not just installation

`make check` must exit zero and show all of these:

| Check | Evidence |
| --- | --- |
| Git / GCC / Make / CMake / Python | Tool discovery, host C program built through CMake/Ninja and executed |
| Python dependencies | Import `elftools` and `serial` |
| Cross GCC / assembler / linker | Static RV32I ELF linked from `.S` and `.c` |
| Binutils | ELF headers and segment report; real disassembly |
| Verilator | Reset, 260 counted cycles, wraparound and second reset assertions pass |
| Wave generation | Nonempty `build/smoke.vcd` |
| Yosys | Counter synthesized, `check -assert` passes, JSON netlist produced |
| Versions | `build/tool-versions.txt` records package and tool versions |

Then run `make wave`. GTKWave should show `clk`, `rst`, and `count`; expand
`tb_tool_probe.dut` and insert the signals. On a WSLg-enabled Windows machine
the Linux GUI opens directly. A headless version check or VCD file alone does
not prove the GUI works. If no display is available, keep the waveform and
inspect it with a Windows waveform viewer, or enable/update WSLg following
[Microsoft's GUI-app guide](https://learn.microsoft.com/en-us/windows/wsl/tutorials/gui-apps).

## 4. Project location and VS Code

The session checkout is `/mnt/c/Users/Arham/Documents/research/cpu-stuff` and is
usable now. Verilator builds many small C++ files, so an independent checkout
on the Linux filesystem (`~/projects/cpu-stuff`) is preferable for long builds.
After the initial files have been published to GitHub, you can use:

```bash
mkdir -p ~/projects
cd ~/projects
git clone https://github.com/Arham-Tahir64/cpu-stuff.git
cd cpu-stuff
code .
```

Keep one authoritative checkout while learning; do not casually edit both.
Keep Linux builds out of OneDrive-synchronized directories. `.gitattributes`
enforces LF endings for shell scripts, assembly and RTL.

Install VS Code **on Windows** and its WSL extension. Your Windows installation
already has `ms-vscode-remote.remote-wsl`; Verilog-HDL support was added for this
project. In VS Code, use **WSL: Reopen Folder in WSL** and check the lower-left
indicator says `WSL: Ubuntu`. Accept the repository's extension recommendations
and install the language extensions **in WSL** when offered. Set the C/C++
compiler path to `/usr/bin/riscv64-unknown-elf-gcc` for embedded sources.
`.S` files have assembly association; the disassembler is the authority on
generated RISC-V encodings. A terminal opened there must report Linux paths:

```bash
which gcc verilator riscv64-unknown-elf-gcc
make check
```

See [VS Code's WSL instructions](https://code.visualstudio.com/docs/remote/wsl).

## 5. Optional FPGA software, deferred until a board is chosen

For simulation-first work, the installed Yosys can check generic synthesis.
**nextpnr, ecppack and a programmer are not required for M0–M5.**

For the proposed ECP5 board, use a Linux x64 OSS CAD Suite bundle containing
Yosys, nextpnr-ecp5, Project Trellis and openFPGALoader. A dated, checksum-pinned
installer is supplied:

```bash
bash scripts/install_fpga_tools.sh
source tools/oss-cad-suite/environment
nextpnr-ecp5 --version
ecppack --help
openFPGALoader --version
```

It installs only under `tools/` in this checkout, does not change your shell
startup files, and refuses to overwrite an existing installation. The bundle
is large (about 748 MB compressed for the pinned build). Sourcing its environment
also changes Python and simulator/tool resolution; rerun `make check` and
`make manifest` and record the changed tools. Do not silently combine tools from
different bundles. [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build)
documents WSL support and bundled tools.

## 6. What runs where

| Task | WSL2 Ubuntu | Native Windows |
| --- | --- | --- |
| GCC, ELF/Python utilities, Verilator | Recommended | Possible, but not this baseline |
| GTKWave | WSLg, if GUI available | Alternative viewer installation |
| Yosys / nextpnr / Trellis | Recommended for ECP5 | Available through suitable bundles |
| FPGA USB/JTAG programming | Requires USB forwarding + device permissions | Often simpler initial hardware bring-up |
| UART terminal | `/dev/ttyUSB*` after forwarding | COM port through native terminal / Python |
| AMD Vivado / Intel Quartus | Linux versions exist; check supported OS for chosen release | Vendor-supported route on matching Windows versions |

WSL is not automatically a vendor-supported Linux environment. A vendor board
changes the synthesis, constraints and programming flow; it does not require
changing the CPU architecture. Do not install Vivado/Quartus without a board.

For WSL USB, follow the [official usbipd guide](https://learn.microsoft.com/en-us/windows/wsl/connect-usb).
When hardware is present, inspect the actual bus ID. In Administrator PowerShell:

```powershell
winget install --interactive --exact dorssel.usbipd-win
usbipd list
# Replace <busid> with the board's actual ID, not an example from a tutorial.
usbipd bind --busid <busid>
```

Then in normal PowerShell while Ubuntu is open:

```powershell
usbipd attach --wsl --busid <busid>
```

In Ubuntu, verify `lsusb`, install board-specific udev rules and reconnect the
device if needed. Forwarding gives the device to WSL; Windows cannot use it
simultaneously. Use `usbipd detach --busid <busid>` to return it. ULX3S programming
and UART share its USB device, so close serial sessions before programming.
An alternative is to build in WSL and invoke a native Windows programmer with
the bitstream on a Windows-accessible path. JTAG loads the FPGA configuration;
the later UART loader loads CPU programs into RAM. They are separate operations.

## 7. Reproducibility boundary

`make` commands, RV32I flags, source files and memory layout are versioned.
Ubuntu 24.04 is the package baseline, and installed package versions are recorded
by `make manifest`. Ubuntu repositories and hosted CI images can change: this
is a reproducible procedure, **not a bit-identical historical environment**.
For a release, archive tool manifests, source commit, ELF/bitstream checksums,
logs, constraints and FPGA bundle digest; use a pinned container or package
snapshot if bit-identical reproduction is a requirement. Never commit compiled
toolchains, generated waveforms or download archives.
