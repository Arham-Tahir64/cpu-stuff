SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

CROSS ?= riscv64-unknown-elf-
RVFLAGS := -march=rv32i -mabi=ilp32 -O1 -g -ffreestanding -fno-builtin \
           -fno-pic -fno-pie -fno-stack-protector -msmall-data-limit=0 -mno-relax
RTL_SOURCES := $(shell cat rtl/files.f)
ALU_SEED ?= 0x1badf00d
ALU_RANDOM_PAIRS ?= 10000

.PHONY: help setup doctor check smoke-host smoke-elf smoke-rtl smoke-synth wave manifest \
        unit unit-alu alu-vectors lint synth-alu wave-alu
help:
	@echo 'M0: make setup | doctor | check | wave | manifest'
	@echo 'M1 ALU: make unit-alu | lint | synth-alu | wave-alu'
	@echo 'Individual checks: smoke-host | smoke-elf | smoke-rtl | smoke-synth'

setup:
	bash scripts/bootstrap_ubuntu.sh

doctor:
	bash scripts/check_tools.sh

check: doctor smoke-host smoke-elf smoke-rtl smoke-synth manifest lint unit synth-alu

lint:
	verilator --lint-only -Wall --top-module alu -f rtl/files.f

unit: unit-alu
	python3 tests/unit/test_alu_harness.py

alu-vectors:
	python3 scripts/gen_alu_vectors.py --seed "$(ALU_SEED)" \
		--random-pairs "$(ALU_RANDOM_PAIRS)" --output build/alu/vectors.txt

build/alu/obj/alu_test: $(RTL_SOURCES) rtl/files.f tests/unit/tb_alu.sv Makefile
	mkdir -p build/alu/obj
	verilator --binary --timing --assert --trace -Wall -j 2 \
		--top-module tb_alu --Mdir build/alu/obj -o alu_test \
		-f rtl/files.f tests/unit/tb_alu.sv

unit-alu: alu-vectors build/alu/obj/alu_test
	./build/alu/obj/alu_test +vectors=build/alu/vectors.txt

synth-alu:
	mkdir -p build/alu
	yosys -Q -T -p 'read_verilog -sv $(RTL_SOURCES); hierarchy -check -top alu; proc; select -assert-none t:$$dlatch* t:$$*ff*; synth -top alu; check -assert; stat; write_json build/alu/netlist.json' > build/alu/yosys.log
	test -s build/alu/netlist.json
	@echo 'PASS ALU synthesis; no inferred latches or flip-flops (build/alu/yosys.log)'

wave-alu: alu-vectors build/alu/obj/alu_test
	./build/alu/obj/alu_test +vectors=build/alu/vectors.txt +trace +limit=256
	gtkwave build/alu/alu.vcd

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
