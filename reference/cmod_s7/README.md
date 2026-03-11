# CMOD S7 Bring-Up Reference

This directory contains the board-specific adaptations needed to build and deploy
the I3C controller demo on a **Digilent CMOD S7 (XC7S25-1CSGA225)**.

## Files

| File | Description |
|------|-------------|
| `spartan7_i3c_demo.xdc` | Complete pin constraints for CMOD S7 — replaces the generic template |
| `spartan7_i3c_controller_demo_top.v` | Updated board top — adds MMCM (12→100 MHz), active-high reset, correct LED mapping |
| `vivado_build.tcl` | Updated build script — defaults to CMOD S7 part, includes fpga_test RTL, correct top module |
| `program_cmod_s7.tcl` | New JTAG programming script for Vivado hardware manager |

## What Changed and Why

### Constraints (`spartan7_i3c_demo.xdc`)
The repo shipped a generic commented-out template. Replaced with real CMOD S7 pin assignments:
- 12 MHz clock on `M9` (MRCC-capable)
- `BTN0` reset on `D2`
- 4 discrete LEDs (`E2`, `K1`, `J1`, `E1`) + RGB LED (`F1`/`D3`/`F2`)
- I3C SCL/SDA on Pmod JA pins 1/2 (`J2`, `H2`) with internal pull-ups + fast slew
- `CFGBVS`, `CONFIG_VOLTAGE`, bitstream compression properties

### Board Top (`spartan7_i3c_controller_demo_top.v`)
Original assumed a 100 MHz input clock and active-low reset. CMOD S7 provides 12 MHz:
- Added `MMCME2_BASE + BUFG` to upconvert 12 MHz → 100 MHz (VCO @ 750 MHz, CLKOUT0 ÷ 7.5)
- Reset held asserted until MMCM locks: `sys_rst_n = mmcm_locked & ~btn_reset`
- Remapped LED ports to match the board (4 discrete + RGB split)

### Build Script (`vivado_build.tcl`)
- Set `xc7s25csga225-1` and `i3c_demo` as no-arg defaults
- Added `rtl/fpga_test/*.v` to the source list (was missing — would have failed to find the demo top)
- Changed top module from `spartan7_i3c_top` → `spartan7_i3c_controller_demo_top`
- Added synthesis and implementation status checks with clean error exits

### Programming Script (`program_cmod_s7.tcl`) — new
The repo had no JTAG programming script. This uses Vivado's `open_hw_manager` flow to
program the CMOD S7 via USB/JTAG after a successful build.

## Quick Start

```bash
# Build
source /opt/Xilinx/2025.2/Vivado/2025.2/settings64.sh
vivado -mode batch -source scripts/vivado_build.tcl

# Program (board connected via USB)
vivado -mode batch -source scripts/program_cmod_s7.tcl
```

## Hardware Connections

- **I3C SCL** → Pmod JA Pin 1
- **I3C SDA** → Pmod JA Pin 2
- Add **1k–4.7k pull-ups to 3.3V** on both lines for real bus operation
- `led_boot_done` (RGB green) lights when SETDASA bring-up completes across all 5 targets
- `led_sample_valid[0–3]` (discrete LEDs) show per-endpoint sample capture activity
- `led_error` (RGB red) indicates boot or capture fault
