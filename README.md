# Spartan-7 I3C Starter and Closed-System I3C Baseline

This repository now serves two purposes:

1. a practical Spartan-7 SDR bring-up baseline
2. the seed repository for a larger closed-system I3C Hub/Motor/Touch architecture

Current code and planning artifacts:

- `rtl/i3c_sdr_controller.v`: Synthesizable controller for single-byte SDR-style transfers.
- `rtl/spartan7_i3c_top.v`: Example top-level wrapper for Spartan-7 (includes Xilinx `IOBUF` usage).
- `tb/i3c_target_model.v`: Simple behavioral target model for simulation.
- `tb/tb_i3c_sdr_controller.v`: Happy-path testbench that runs one write + one read transaction.
- `tb/tb_i3c_sdr_nack.v`: Negative-path testbench that verifies address-miss NACK handling.
- `constraints/spartan7_i3c_demo.xdc`: Constraint template to adapt to your board.
- `Makefile`: Simulation runner (`iverilog` + `vvp`).
- `docs/I3C_Closed_System_IP_Plan.md`: original program plan.
- `docs/I3C_Architecture_Baseline.md`: consolidated architecture and phase baseline.
- `docs/I3C_Compatibility_Contract_v0_1.md`: initial closed-system interoperability contract.
- `docs/chat_summaries/`: archived markdown summaries from the earlier project threads.

## Important Scope Notes

The RTL in this repo is still a bring-up baseline, not a full I3C Basic implementation. It does **not** yet include:

- Dynamic Address Assignment (`ENTDAA`)
- Common Command Codes (CCC)
- In-band interrupts (IBI)
- HDR modes

It gives you a clean path to:

1. Verify timing/state-machine behavior in simulation
2. Synthesize for Spartan-7
3. Probe `SCL`/`SDA` on hardware and confirm protocol framing

## Quick Start (Simulation)

```bash
make test
```

Expected result:

- `sim-rw` prints `PASS` after a write and a read
- `sim-nack` prints `PASS` after an address-miss NACK case

If you only want the original happy-path test:

```bash
make sim-rw
```

## Architecture Baseline

Use these docs as the current source of truth for the larger project direction:

- `docs/I3C_Architecture_Baseline.md`
- `docs/I3C_Compatibility_Contract_v0_1.md`
- `docs/I3C_Closed_System_IP_Plan.md`

In short:

- Phase 0 in this repo is a minimal SDR transport bring-up path for Spartan-7.
- Phase 1 expands toward the closed-system profile: DAA, CCC subset, reset/error policy, scheduler-driven six-endpoint operation, and selective IBI.
- The current recommended long-term Hub-side IP candidate remains `chipsalliance/i3c-core`, with this repo acting as the planning and baseline-validation anchor.

## Vivado Bring-up

1. Create a new Vivado RTL project targeting your Spartan-7 part/board.
2. Add:
   - `rtl/i3c_sdr_controller.v`
   - `rtl/spartan7_i3c_top.v`
   - `constraints/spartan7_i3c_demo.xdc`
3. Set `spartan7_i3c_top` as top module.
4. Edit `constraints/spartan7_i3c_demo.xdc` pin locations for your exact board.
5. Build bitstream and program the FPGA.
6. Connect external pull-ups on `SCL`/`SDA` if your board/peripheral setup does not already provide them.
7. Use an LA/scope to verify START/address/data/STOP waveforms.

### Optional Batch Build

```bash
vivado -mode batch -source scripts/vivado_build.tcl -tclargs <spartan7_part> i3c_demo
```

Example part for Arty S7-50: `xc7s50csga324-1`.

## Hardware Validation Flow

1. Start with only FPGA + pull-ups + scope/LA.
2. Confirm periodic traffic is generated on `SCL`/`SDA`.
3. Attach a target device (or known-good target FPGA model) and confirm ACK behavior.
4. Tune `I3C_SDR_HZ` in `rtl/spartan7_i3c_top.v` if needed.

## I3C Planning Worksheet (GUI)

For bus-capacity planning with fixed endpoint counts (1-8 targets), open:

- `tools/i3c_worksheet.html`

The worksheet includes:

- Per-target traffic inputs (read/write/IBI rates + payload sizes)
- Aggregate utilization and headroom estimation for effective SDR Mbps
- Feature-alignment guidance for fixed-topology sensor hub architectures
- JSON export/import for per-application static endpoint profiles

Example saved worksheet profile:

- `tools/profiles/platform_a_i3c_worksheet.json`
