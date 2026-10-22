# Optional physical implementation

## Board recommendation

Start without hardware. Verilator and GTKWave cover design and functional
verification at no additional cost on your existing PC. Choose a board near M5
when CPU size and memory needs are measured.

For a later purchase, the proposed baseline is **Radiona ULX3S 85F**:

| Property | Why it helps |
| --- | --- |
| ECP5 LFE5U-85F, approximately 84K LUT capacity | Comfortable space for a small multicycle core and later pipeline/debug logic |
| 3744 Kbit embedded memory on 85F | About 468 KiB raw capacity; enough for 64 KiB RAM + 4 KiB ROM, allowing for port/width packing |
| 25 MHz onboard oscillator | Begin at 25 MHz with a real clock constraint and no PLL |
| FT231X USB programming/serial, buttons and LEDs | Useful program loading and visible output without extra peripherals |
| 32 MB external SDRAM | Future option; not needed initially and requires a controller |
| Open hardware, Yosys/nextpnr/Trellis support | Avoid large proprietary tool installations for the baseline |

The [manufacturer campaign/store listing](https://www.crowdsupply.com/radiona/ulx3s)
checked 2026-10-22 lists the 85F at **US$275**, in stock, and worldwide shipping
at US$18. Stock, prices and dates can change. Budget roughly US$300–350 before
location-specific variations for board, data-capable USB cable, shipping/tax;
optional USB logic analyzer might add US$15–50. Tools require no paid license
for this flow. The page's old comparison table contains historical prices;
use its purchasing section, not that table. Confirm the exact board revision,
device/speed/package and cable before ordering.

Alternatives: an iCE40 UP5K board offers a smaller open-tool design with much
tighter LUT/embedded-memory budgets and possibly single-port SPRAM constraints;
it would need a revised memory/timing plan. A Gowin Tang board can reduce cost
but changes device support, RAM inference, programming and timing validation.
An existing AMD/Xilinx Artix-7 or Intel board is perfectly usable with its
vendor tools and a board-specific wrapper. No alternative's current price or
availability has been established here; verify before purchasing. The preferred
low-cost route now is simulation, not an unverified board purchase.

## Implementation flow

```text
SystemVerilog -> Yosys synth_ecp5 -> JSON netlist
             -> nextpnr-ecp5 + exact device + LPF constraints -> text configuration
             -> Trellis ecppack -> bitstream -> openFPGALoader -> FPGA
```

The optional `scripts/install_fpga_tools.sh` pins a Linux x64 OSS CAD Suite
release and SHA-256. It is deferred in simulation-only mode. A generic Yosys
smoke check is available now; the CPU synthesis target will be implemented at
M6. Use an explicit source list; if Yosys rejects an SV construct, simplify it
or deliberately choose a supported SV frontend rather than changing semantics.

Illustrative commands **after** M6 sources/constraints exist:

```bash
yosys -p 'read_verilog -sv <ordered-synthesizable-source-list>; synth_ecp5 -top ulx3s_top -json build/soc.json'
nextpnr-ecp5 --85k --package CABGA381 --speed 6 \
  --json build/soc.json --lpf fpga/ulx3s/pins.lpf \
  --freq 25 --textcfg build/soc.config
ecppack build/soc.config build/soc.bit
openFPGALoader -b ulx3s build/soc.bit
```

The angle-bracket source list is a placeholder, not an executable target today.
Confirm package spelling/device flags with the installed nextpnr version.
Use an upstream board LPF as pin-reference data, match your board revision,
and verify clock/UART/LED/reset pin polarity and bank voltages against the
schematic. Do not invent pin numbers. `--freq 25` is the initial target; also
declare the 25 MHz primary clock in the timing constraints supported by the
chosen flow and constrain external interfaces where required. Do not use
`--timing-allow-fail` to make a failing build appear successful.

First load FPGA configuration into volatile configuration SRAM, so a mistaken
bitstream can be cleared by power cycling. Nonvolatile flash programming and
power-on flash boot are later explicit steps, not required for the first demo.
FPGA programming configures the hardware; UART ELF loading writes application
RAM afterward. No prebuilt CPU participates in either path.

## Resource and timing goals

At M6, require post-route timing success at **25 MHz**, zero unconstrained
internal synchronous paths, no unexplained latches or combinational loops, and
verified block RAM inference. The exact LUT count and achievable Fmax cannot be
known before implementation. An early planning envelope is under 10K LUTs for
the core/SoC without large debug instrumentation, leaving ample space; treat
this as a goal, not a synthesized result.

ECP5 EBRs contain 18,432 bits. Using the geometries in the
[Lattice memory guide](https://www.latticesemi.com/-/media/LatticeSemi/Documents/ApplicationNotes/EH/FPGA-TN-02204-1-6-ECP5-and-ECP5-5G-Memory-Usage-Guide.ashx?document_id=50466),
a 16K x 32-bit RAM can be budgeted as **32 EBRs**: four independent byte lanes,
each using eight depth slices of 2048 x 9. A 4 KiB ROM can fit in another two
blocks with suitable packing. These are geometry estimates, not measured
utilization; raw bit-count division alone misses width/port overhead. Inspect
actual synthesis and P&R reports.
The 85F device has room for this baseline, but multiport register files and
traces can consume extra LUTs/RAM. Record the tool's own resource categories,
clock report, failing/critical path, memory geometry and device utilization.

Keep a single clock domain. Use clock enables, not logic-generated slow clocks.
Synchronize asynchronous button/reset release and UART RX, and debounce user
buttons separately. For the CPU, use a synchronous reset generated by a small
board wrapper; an external asynchronous reset may assert asynchronously in the
synchronizer but must release synchronously. Hold reset during FPGA startup.
Model real synchronous BRAM latency in simulation before synthesis.

## Physical acceptance sequence

1. Board-only blinker proves clock/reset/pins, before the CPU is connected.
2. BRAM read/write self-test proves actual byte enables and read latency.
3. UART TX/RX loopback verifies baud rate, polarity and serial connectivity.
4. Preloaded assembly program blinks LEDs and sends a known trace marker.
5. Preloaded C executes, including data/BSS/stack and UART.
6. ROM monitor accepts the same validated ELF used in simulation over UART.
7. All five C demos agree with simulation, after at least three resets/reloads.

Save build commit, tool manifest, constraints, timing/utilization reports,
ELF/bitstream SHA-256, load transcript and serial output. A physical UART result
plus timing/resource reports is stronger evidence than an LED video alone.
An FPGA-internal trace buffer or vendor logic analyzer may be added when a
physical-only mismatch appears; they are not prerequisites for the first core.
