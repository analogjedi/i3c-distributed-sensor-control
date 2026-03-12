# FPGA Synthesis Notes

Technical notes for synthesizing the I3C demo on Xilinx 7-series FPGAs (specifically the Digilent CMOD S7, XC7S25-1CSGA225).

## Critical Fix: Async-to-Synchronous Target RTL Rewrite

### The Problem

The original `i3c_target_transport.v` and `i3c_target_ccc.v` used multiple `always` blocks triggered by different asynchronous edges of the bus signals:

```verilog
// ORIGINAL (broken for synthesis) — conceptual example
always @(negedge scl) begin
    sda_drive_low <= ... ;  // drive SDA on falling SCL
end

always @(posedge scl) begin
    sda_drive_low <= ... ;  // sample data on rising SCL
    rx_shift      <= ... ;
end

always @(negedge sda) begin
    if (scl) ...           // START condition
end

always @(posedge sda) begin
    if (scl) ...           // STOP condition
end
```

This pattern works perfectly in simulation (Icarus Verilog, VCS, etc.) because simulators evaluate event-driven `always` blocks independently. Each edge triggers its own procedural block, and the simulator maintains consistent state across them.

### Why It Breaks in Vivado

Xilinx Vivado (and all FPGA synthesis tools) must map registers to physical flip-flops. A flip-flop has exactly **one clock input**. When Vivado sees the same register (`sda_drive_low`) assigned in multiple `always` blocks with different sensitivity lists, it cannot determine which clock should drive that flip-flop.

The result is Vivado's **Synth 8-6858** critical warning:

```
CRITICAL WARNING: [Synth 8-6858] multi-driven net Q on instance 'sda_drive_low_reg'
  with 1st driver pin '...' tied to GND constant driver [...], 2nd driver pin '...'
```

Vivado resolves the conflict by tying the multi-driven net to GND, which means:
- `sda_drive_low` is stuck at 0
- `sda_oe` (derived from `sda_drive_low`) is stuck at 0
- Targets never drive SDA, so they never ACK any address
- The controller sees NACK on every transaction, sets `boot_error` immediately

### Diagnosis

The failure mode on hardware was:
1. Program FPGA, observe RGB LED goes red immediately (boot_error)
2. No ACK activity visible on SDA with logic analyzer
3. Vivado synthesis log contains the CRITICAL WARNING above
4. Searching the log for "multi-driven" reveals the affected registers

### The Fix

Both `i3c_target_transport.v` and `i3c_target_ccc.v` were rewritten as **fully synchronous** state machines clocked by the 100 MHz system clock, with explicit edge detectors:

```verilog
// Edge detection — single-cycle delay registers
reg scl_d, sda_d;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        scl_d <= 1'b1;
        sda_d <= 1'b1;
    end else begin
        scl_d <= scl;
        sda_d <= sda;
    end
end

wire scl_rising  = ~scl_d &  scl;
wire scl_falling =  scl_d & ~scl;
wire sda_falling =  sda_d & ~sda;
wire sda_rising  = ~sda_d &  sda;
```

The entire state machine now runs in a single `always @(posedge clk or negedge rst_n)` block with priority-ordered conditions:

1. **Reset** (async active-low)
2. **START condition**: `sda_falling && scl` — SDA falls while SCL is high
3. **STOP condition**: `sda_rising && scl` — SDA rises while SCL is high
4. **SCL falling edge**: drive SDA for ACK or read data
5. **SCL rising edge**: sample SDA data, advance state machine

This priority order is critical — START/STOP detection must take precedence over normal SCL-edge processing, since START/STOP are defined by SDA transitions while SCL is high.

### Impact on Module Interfaces

The rewrite added a `clk` input to both `i3c_target_transport` and `i3c_target_ccc`. This propagated up through:

- `i3c_target_top.v` — already had `clk`, now passes it to transport and CCC submodules
- `i3c_sensor_target_demo.v` — already had `clk` from the frame generator, now passes it through to `i3c_target_top`

No interface changes were needed at the demo-top level.

### Timing Considerations

The synchronous approach introduces up to 1 system clock cycle (10 ns at 100 MHz) of latency for edge detection. At the I3C SDR rate of 12.5 MHz (80 ns per SCL half-period), this 10 ns detection delay is well within the timing budget — the edge detector fires within the first 12.5% of each SCL phase.

## Internal Open-Drain Bus (Unified Demo)

The unified demo (`spartan7_i3c_unified_demo_top.v`) implements the I3C open-drain bus entirely internal to the FPGA using explicit wired-AND logic:

```verilog
// SCL: driven by controller only
assign scl_bus = ~(ctrl_scl_oe & ~ctrl_scl_o);

// SDA: driven by controller + 5 targets
assign sda_bus = ~( (ctrl_sda_oe & ~ctrl_sda_o) |
                    tgt0_sda_oe |
                    tgt1_sda_oe |
                    tgt2_sda_oe |
                    tgt3_sda_oe |
                    tgt4_sda_oe );
```

### How It Works

In a real open-drain bus, the line idles high (pulled up by a resistor) and any device can pull it low. The wired-AND behavior means:
- Bus = HIGH only when **no** device is pulling low
- Bus = LOW when **any** device is pulling low

The internal implementation models this:
- Each target's `sda_oe` signal means "I am pulling SDA low" (active-high enable, drives low)
- The controller's drive follows `sda_oe & ~sda_o` — the controller can also drive high for data bits, but only pulls low when `sda_oe=1, sda_o=0`
- All pull-low signals are OR'd together, then inverted to get the bus value

**SCL** is simpler: only the controller drives the clock, so it's just the controller's open-drain output.

This eliminates the need for external I3C wiring, pull-up resistors, and IOBUF primitives, making the unified demo fully self-contained on a single FPGA.

## MMCM Configuration

The CMOD S7 board provides a 12 MHz oscillator on pin M9 (MRCC-capable). The demo uses an MMCME2_BASE primitive to generate the 100 MHz system clock:

| Parameter | Value | Notes |
| --- | --- | --- |
| `CLKIN1_PERIOD` | 83.333 ns | 12 MHz input |
| `DIVCLK_DIVIDE` | 1 | No input divider |
| `CLKFBOUT_MULT_F` | 62.500 | VCO = 12 × 62.5 = 750 MHz |
| `CLKOUT0_DIVIDE_F` | 7.500 | Output = 750 / 7.5 = 100 MHz |
| `STARTUP_WAIT` | FALSE | Don't wait for MMCM lock during config |

The VCO frequency (750 MHz) is within the 7-series MMCM range of 600–1200 MHz.

The MMCM output is buffered through a BUFG before use. System reset (`sys_rst_n`) is held low until the MMCM `LOCKED` output asserts and BTN0 is released:

```verilog
wire sys_rst_n = mmcm_locked & ~btn_reset;
```

## Bitstream Configuration Properties

The XDC files set these configuration properties for the CMOD S7:

```tcl
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
```

| Property | Value | Purpose |
| --- | --- | --- |
| `CFGBVS` | VCCO | Configuration bank voltage source = VCCO |
| `CONFIG_VOLTAGE` | 3.3 | 3.3V configuration I/O |
| `SPI_BUSWIDTH` | 4 | Quad-SPI flash programming (CMOD S7 uses N25Q032A) |
| `COMPRESS` | TRUE | Reduce bitstream size |

## Vivado Build Script

The `scripts/vivado_build.tcl` script automates the full flow:

1. Creates project with the target part (default: `xc7s25csga225-1`)
2. Adds all `rtl/*.v` and `rtl/fpga_test/*.v` source files
3. Adds `constraints/spartan7_i3c_demo.xdc`
4. Sets top module to `spartan7_i3c_controller_demo_top` (update to `spartan7_i3c_unified_demo_top` for the unified build)
5. Runs synthesis (4 jobs), checks for completion
6. Runs implementation through `write_bitstream` (4 jobs), checks for completion
7. Generates timing summary and utilization reports

Output directory: `build/<project_name>/`

## I/O Standards

All CMOD S7 I/O uses LVCMOS33 (3.3V). The I3C bus pins (controller-only mode) additionally set:

- `SLEW FAST` — minimize rise/fall time for I3C SDR signaling
- `DRIVE 8` — 8 mA drive strength
- `PULLUP true` — internal pull-ups as lab fallback (external 1k–4.7k recommended for production)
