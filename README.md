# Spartan-7 I3C Starter and Closed-System I3C Baseline

This repository now serves two purposes:

1. a practical Spartan-7 SDR bring-up baseline
2. the seed repository for a larger closed-system I3C distributed sensor architecture

Current code and planning artifacts:

- `rtl/i3c_bus_engine.v`: Low-level SDR bus engine for START/STOP, byte transfer, and ACK/NACK handling.
- `rtl/i3c_ctrl_txn_layer.v`: Transaction layer wrapper above the bus engine.
- `rtl/i3c_sdr_controller.v`: Compatibility wrapper preserving the original simple controller interface.
- `rtl/i3c_ctrl_ccc.v`: Broadcast CCC issue path built on the transaction layer.
- `rtl/i3c_ctrl_direct_ccc.v`: Controller-side direct CCC framing engine with repeated-start support for direct write/read command flows.
- `rtl/i3c_ctrl_entdaa.v`: Controller-side single-target `ENTDAA` sequencer for PID/BCR/DCR capture and dynamic-address assignment.
- `rtl/i3c_ctrl_daa.v`: Controller-side dynamic-address assignment state scaffolding.
- `rtl/i3c_target_transport.v`: Synthesizable SDR target transport block.
- `rtl/i3c_target_ccc.v`: Target-side CCC decode block for broadcast CCCs, direct `SETDASA`/`GETPID`, and single-target `ENTDAA` participation.
- `rtl/i3c_target_daa.v`: Target-side dynamic-address state block.
- `rtl/i3c_target_top.v`: Target integration wrapper joining transport and DAA state.
- `rtl/spartan7_i3c_top.v`: Example top-level wrapper for Spartan-7 (includes Xilinx `IOBUF` usage).
- `tb/i3c_target_model.v`: Simple behavioral target model for simulation.
- `tb/tb_i3c_sdr_controller.v`: Happy-path testbench that runs one write + one read transaction.
- `tb/tb_i3c_sdr_nack.v`: Negative-path testbench that verifies address-miss NACK handling.
- `tb/tb_i3c_target_transport.v`: Regression using the synthesizable target transport in `rtl/`.
- `tb/tb_i3c_daa_state.v`: Regression for controller/target dynamic-address state handling.
- `tb/tb_i3c_broadcast_ccc.v`: Regression for broadcast CCC handling (`RSTDAA`, `SETAASA`).
- `tb/tb_i3c_direct_ccc_write.v`: Regression for controller-side direct CCC write framing with repeated start.
- `tb/tb_i3c_direct_ccc_read.v`: Regression for controller-side direct CCC read framing and response capture.
- `tb/tb_i3c_setdasa.v`: Integration regression for target-side direct CCC decode and `SETDASA` dynamic-address assignment.
- `tb/tb_i3c_getpid.v`: Integration regression for target-side `GETPID` readback.
- `tb/tb_i3c_entdaa.v`: First real controller/target `ENTDAA` regression with controller-side DAA bookkeeping.
- `constraints/spartan7_i3c_demo.xdc`: Constraint template to adapt to your board.
- `Makefile`: Simulation runner (`iverilog` + `vvp`).
- `docs/I3C_Closed_System_IP_Plan.md`: original program plan.
- `docs/I3C_Architecture_Baseline.md`: consolidated architecture and phase baseline.
- `docs/I3C_Compatibility_Contract_v0_1.md`: initial closed-system interoperability contract.
- `docs/I3C_Controller_Target_Implementation_Plan.md`: detailed controller/target RTL implementation plan.
- `docs/chat_summaries/`: archived markdown summaries from the earlier project threads.

## Important Scope Notes

The RTL in this repo is still a bring-up baseline plus early Phase 1 scaffolding, not a full I3C Basic implementation. It does **not** yet include:

- Multi-target `ENTDAA` arbitration/sequencing
- Broad direct-target CCC decode/response beyond `SETDASA` and `GETPID`
- In-band interrupts (IBI)
- HDR modes

What now exists beyond the original Phase 0 baseline:

- refactored controller transport stack with bus-engine and transaction-layer split
- synthesizable target transport in `rtl/`
- controller-side and target-side dynamic-address state scaffolding
- broadcast CCC issue/decode support for `RSTDAA` and `SETAASA`
- controller-side direct CCC framing with repeated-start sequencing for direct write/read command flows
- target-side direct CCC decode and transport holdoff for `SETDASA`
- target-side `GETPID` readback
- single-target `ENTDAA` controller/target baseline with PID/BCR/DCR capture and dynamic-address assignment
- dedicated regressions for target transport and DAA state behavior

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
- `sim-target` prints `PASS` against the synthesizable target transport
- `sim-daa` prints `PASS` for controller/target dynamic-address state handling
- `sim-ccc` prints `PASS` for broadcast CCC-driven address-state changes
- `sim-direct-ccc-write` prints `PASS` for direct CCC write framing
- `sim-direct-ccc-read` prints `PASS` for direct CCC read framing and response capture
- `sim-setdasa` prints `PASS` for direct CCC target decode and dynamic-address takeover
- `sim-getpid` prints `PASS` for direct CCC `GETPID`
- `sim-entdaa` prints `PASS` for the single-target `ENTDAA` baseline

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
- Phase 0.5 is now implemented: controller refactor plus synthesizable target transport.
- Phase 1 now includes DAA state scaffolding, broadcast CCC support (`RSTDAA`, `SETAASA`), controller-side direct CCC framing, target-side `SETDASA`/`GETPID`, and a first real single-target `ENTDAA` path.
- The remaining Phase 1 work is multi-target `ENTDAA`, broader CCC coverage, deeper reset/error policy, scheduler-driven six-endpoint operation, and selective IBI.
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
