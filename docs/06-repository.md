# Proposed complete repository structure

M0 tool checks, documents, and M1's ALU/package/vector generator/testbench are
implemented. The tree below is the target organization as milestones are
completed, not a list of files claimed to exist today. Use `git ls-files` for
the actual tracked contents.

```text
cpu-stuff/
  README.md
  Makefile                       # stable entrypoints, fails for missing stages
  .gitattributes                 # LF endings
  .gitignore
  .github/workflows/
    m0.yml                       # implemented: environment + ALU CI
    regression.yml               # later: CPU and loader regression
  .vscode/
    extensions.json
    settings.json
    tasks.json
  docs/
    00-environment.md
    01-architecture.md
    02-milestones.md
    03-software-and-boot.md
    04-fpga.md
    05-verification.md
    06-repository.md
    07-references.md
    environment-verified.md
    08-alu.md                    # implemented: ALU contract, walkthrough/results
    decisions/                   # later: rationale for architecture changes
  rtl/
    core/
      rv32_pkg.sv                # implemented: shared ALU control constants
      alu.sv                     # implemented
      regfile.sv
      immediate.sv
      decoder.sv
      lsu.sv
      core.sv
    soc/
      interconnect.sv
      bram.sv
      boot_rom.sv
      uart.sv
      gpio.sv
      soc.sv
    files.f                      # implemented: package before ALU
  tests/
    smoke/                       # implemented: M0 probes, not CPU modules
      host/{CMakeLists.txt,main.c}
      {tool_probe.sv,tb_tool_probe.sv,start.S,probe.c,probe.ld}
    unit/
      tb_alu.sv                  # implemented
      test_alu_harness.py         # implemented: assertion/reader failure checks
      tb_regfile.sv
      tb_immediate.sv
      tb_decoder.sv
      tb_lsu.sv
      tb_uart.sv
    isa/                         # handwritten directed RV32I assembly
    programs/                    # assembly integration programs
    loader/                      # synthetic/malformed ELF and serial packets
    reference/                   # independent model and comparison tests
    fixtures/
  sim/
    tb_core.sv
    tb_soc.sv
    main.cpp                     # later C++ harness for controlled stepping
    memory_model.cpp
    trace.cpp
    uart_host.cpp
  sw/
    runtime/
      crt0.S
      linker.ld
      platform.h
      uart.c
      memory.c                   # memcpy/memset as needed; no hidden libc
    boot/
      boot_start.S
      boot.ld
      monitor.c
    examples/
      arithmetic.c
      loops.c
      functions.c
      memory.c
      hello_uart.c
    Makefile
  scripts/
    bootstrap_ubuntu.sh          # implemented
    check_tools.sh               # implemented
    check_elf.py                 # implemented: controlled M0 probe check only
    tool_manifest.sh             # implemented
    gen_alu_vectors.py           # implemented: independent Python oracle
    install_fpga_tools.sh        # implemented: optional pinned installer
    elf2mem.py                   # M4: validated PT_LOAD conversion
    load_uart.py                 # M5: validated ELF -> boot protocol
    compare_trace.py
    run_regression.py
  fpga/
    ulx3s/
      ulx3s_top.sv
      pins.lpf
      Makefile
      README.md                  # exact board revision and USB steps
  formal/                        # optional RVFI proof integration
  third_party/                   # pinned test/reference revisions, no CPU IP
  tools/
    oss-cad-suite.lock.json       # implemented: release and digest
    downloads/                   # ignored
    oss-cad-suite/               # ignored; optional tool installation
  build/                         # ignored: ELF, images, sims, logs, waves, P&R
```

`make unit`, `make unit-alu`, `make lint`, `make synth-alu` and `make wave-alu`
are available for the ALU step. Future stable commands: `make isa`, `make firmware APP=loops`,
`make sim APP=loops`, `make regression`, `make fpga BOARD=ulx3s`,
`make program`, and `make load APP=hello_uart PORT=/dev/ttyUSB0`.
Add them only when they perform their named work. Keep board-dependent commands
outside CPU modules; no Linux absolute path should be embedded in synthesizable
RTL. Store generated images under build and pass paths explicitly.
