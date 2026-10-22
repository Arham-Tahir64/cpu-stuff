SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

CROSS ?= riscv64-unknown-elf-
RVFLAGS := -march=rv32i -mabi=ilp32 -O1 -g -ffreestanding -fno-builtin \
           -fno-pic -fno-pie -fno-stack-protector -msmall-data-limit=0 -mno-relax

.PHONY: help setup doctor check smoke-host smoke-elf smoke-rtl smoke-synth wave manifest
help:
	@echo 'M0: make setup | doctor | check | wave | manifest'
	@echo 'Individual checks: smoke-host | smoke-elf | smoke-rtl | smoke-synth'

setup:
	bash scripts/bootstrap_ubuntu.sh

doctor:
	bash scripts/check_tools.sh

check: doctor smoke-host smoke-elf smoke-rtl smoke-synth manifest

smoke-host:
	cmake -S tests/smoke/host -B build/host -G Ninja
	cmake --build build/host
	./build/host/host_probe

build/probe.elf: tests/smoke/start.S tests/smoke/probe.c tests/smoke/probe.ld
	mkdir -p build
	$(CROSS)gcc $(RVFLAGS) -nostdlib -nostartfiles -static -no-pie \
		-Wl,--no-relax,--build-id=none,-Map,build/probe.map \
		-T tests/smoke/probe.ld tests/smoke/start.S tests/smoke/probe.c -o $@

smoke-elf: build/probe.elf
	$(CROSS)readelf -h -l -A $< > build/probe.readelf.txt
	$(CROSS)objdump -d -M no-aliases $< > build/probe.dis
	python3 scripts/check_elf.py $<

smoke-rtl:
	mkdir -p build/rtl
	verilator --binary --timing --assert --trace -Wall -j 2 \
		--top-module tb_tool_probe --Mdir build/rtl -o tool_probe \
		tests/smoke/tool_probe.sv tests/smoke/tb_tool_probe.sv
	./build/rtl/tool_probe
	test -s build/smoke.vcd

smoke-synth:
	mkdir -p build
	yosys -Q -T -p 'read_verilog -sv tests/smoke/tool_probe.sv; synth -top tool_probe; check -assert; stat; write_json build/probe-netlist.json' > build/yosys.log
	test -s build/probe-netlist.json
	@echo 'PASS generic RTL synthesis (see build/yosys.log)'

wave: smoke-rtl
	gtkwave build/smoke.vcd

manifest:
	mkdir -p build
	bash scripts/tool_manifest.sh > build/tool-versions.txt
	@echo 'Tool versions: build/tool-versions.txt'
