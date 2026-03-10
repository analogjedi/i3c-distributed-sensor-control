# I3C Distributed Sensor Control Baseline

This repository is the RTL, verification, and architecture baseline for a closed-system I3C sensor-control platform.

The intended end-to-end system is:

1. one hub controller that owns bus policy, address assignment, polling, recovery, and long-term event handling
2. multiple target endpoints that expose sensor or actuator-facing register/data behavior behind a common I3C transport shell
3. a deterministic boot and service flow built around CCCs, dynamic addressing, scheduled traffic, and bounded recovery behavior

The repository therefore serves three linked purposes:

1. define the controller/target architecture for the full distributed sensor system
2. provide executable RTL and regression tests for the bus-management features being implemented phase by phase
3. use Spartan-7 only as a practical hardware validation platform for SDR bring-up and signal-level verification

## Protocol Status

This is the fastest map of what each I3C feature does in this system and how far the repo has gotten with it.

| Feature / Command | Purpose in the System | Status | Current repo baseline |
| --- | --- | --- | --- |
| SDR private read/write | Normal controller-to-target telemetry and configuration traffic once addressing is stable. | Implemented | Controller and target transport path is regression-backed. |
| Broadcast CCC `RSTDAA` | Clear dynamic addresses so the controller can recover or restart discovery from a known state. | Implemented | Target address-state reset is wired and tested. |
| Broadcast CCC `SETAASA` | Let a target use its static address as the active dynamic address during static-assisted boot. | Implemented | Static-assisted address activation is wired and tested. |
| Direct CCC framing | Required controller transaction shape for target-specific CCC commands that use repeated start. | Implemented | Controller-side direct write/read framing is in place. |
| Direct CCC `SETDASA` | Assign a chosen dynamic address to a specific target that can still be reached by static address. | Implemented | Target-side decode updates the active dynamic address and suppresses normal transport during the command. |
| Direct CCC `GETPID` | Read a target provisional ID so the controller can identify it before or alongside address policy. | Implemented | Target returns PID through the direct CCC read path. |
| Direct CCC `GETBCR` / `GETDCR` | Read capability/class metadata over direct CCC instead of relying only on discovery-time capture. | Implemented | Target returns BCR and DCR through dedicated direct CCC read regressions. |
| Direct CCC `GETSTATUS` | Read current target status so controller policy can observe address/policy/reset-related state. | Implemented | Target returns a compact 16-bit status word and regression covers direct readback. |
| Direct CCC `RSTACT` | Program target reset action policy so later recovery flows have an explicit target-side action selection. | Implemented | Direct write path updates target reset-action state and is mirrored into controller policy tracking. |
| `ENTDAA` single-target baseline | Discover one unassigned target, capture identity fields, and assign a dynamic address. | Implemented | PID/BCR/DCR capture plus controller-side assignment is regression-backed. |
| `ENTDAA` multi-target sequencing | Enumerate multiple unassigned targets in deterministic PID order and assign addresses across repeated discovery passes. | Implemented | Two-target and six-target regressions cover arbitration ordering, BCR/DCR inventory retention, repeated assignment, full-table population, and exhaustion/NACK behavior. |
| Event-control CCCs `ENEC` / `DISEC` | Enable or disable target-side event classes so future IBI/event policy has explicit controller ownership. | Implemented | Broadcast and direct event-mask updates are wired into target state and regression-backed. |
| Broader CCC subset | Add additional management commands for policy, status, and recovery. | In Progress | Repo now covers `RSTDAA`, `SETAASA`, `SETDASA`, `GETPID`, `GETBCR`, `GETDCR`, `GETSTATUS`, `RSTACT`, `ENEC`, `DISEC`, and `ENTDAA`, including recovery/status regressions across reset-related address-state transitions. |
| Controller endpoint policy state | Turn discovered endpoints into a managed inventory with per-target policy, class, cadence, service history, and health state. | In Progress | DAA now auto-populates policy records with PID/BCR/DCR, derived class, enable state, event-mask, reset-action, status, service period, due state, last service tag, success/error counters, and recovery sequencing state. |
| Per-endpoint cadence and service statistics | Let the controller schedule each endpoint at a useful rate and retain enough history to make real policy decisions. | Implemented | Controller policy now tracks service period, due-now eligibility, service count, success count, error count, consecutive failures, and last service tag per endpoint. |
| Scheduler-driven multi-endpoint service | Poll and service known targets deterministically once the address map is stable. | In Progress | A cadence-aware round-robin scheduler now walks integrated policy state, issues class-specific write-then-read service templates, performs class-sized multi-byte reads, skips disabled or faulted endpoints, and captures success/NACK results. |
| Reset and recovery policy | Escalate from transaction failures or stale bus state into targeted recovery instead of blind reboot behavior. | In Progress | Repeated scheduled-service NACKs now drive `RSTACT`-keyed controller recovery sequencing with timed retry windows, reset-style cooldown, forced-disable escalation, and explicit clear; recovery/status regressions also cover `GETSTATUS`, `RSTDAA`, and `SETAASA`. |
| In-band interrupts (IBI) | Allow rare urgent target-originated events without turning routine traffic into asynchronous chaos. | Future | Intentionally deferred until addressing, CCCs, and scheduling are stable. |
| HDR modes | Higher-performance optional transfer modes beyond current SDR scope. | Future | Explicitly out of current project scope. |

## Current Code and Planning Artifacts

- `rtl/i3c_bus_engine.v`: Low-level SDR bus engine for START/STOP, byte transfer, and ACK/NACK handling.
- `rtl/i3c_ctrl_txn_layer.v`: Transaction layer wrapper above the bus engine.
- `rtl/i3c_sdr_controller.v`: Compatibility wrapper preserving the original simple controller interface.
- `rtl/i3c_ctrl_ccc.v`: Broadcast CCC issue path built on the transaction layer.
- `rtl/i3c_ctrl_direct_ccc.v`: Controller-side direct CCC framing engine with repeated-start support for direct write/read command flows.
- `rtl/i3c_ctrl_entdaa.v`: Controller-side `ENTDAA` sequencer baseline for PID/BCR/DCR capture and dynamic-address assignment.
- `rtl/i3c_ctrl_daa.v`: Controller-side dynamic-address assignment and endpoint-inventory state for PID/BCR/DCR retention.
- `rtl/i3c_ctrl_inventory.v`: Controller-side bridge that feeds DAA discovery results directly into endpoint policy state.
- `rtl/i3c_ctrl_policy.v`: Controller-side endpoint policy table for per-address class, enable, cadence, event-mask, reset-action, status, health, service statistics, and reset-action-keyed recovery sequencing.
- `rtl/i3c_ctrl_scheduler.v`: Cadence-aware round-robin scheduler that scans policy state and emits service requests only for enabled, healthy, due endpoints.
- `rtl/i3c_ctrl_top.v`: Controller integration wrapper that connects inventory, scheduler, and transaction issue into real scheduled write-then-read service templates with class-sized multi-byte reads.
- `rtl/i3c_target_transport.v`: Synthesizable SDR target transport block.
- `rtl/i3c_target_ccc.v`: Target-side CCC decode block for event-control, status/reset, metadata, addressing CCCs, and `ENTDAA` participation with arbitration handling.
- `rtl/i3c_target_daa.v`: Target-side dynamic-address state block.
- `rtl/i3c_target_top.v`: Target integration wrapper joining transport, DAA state, CCC decode, and a latched register-selector shell for scheduled write templates.
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
- `tb/tb_i3c_getbcrdcr.v`: Integration regression for direct CCC `GETBCR` and `GETDCR` readback.
- `tb/tb_i3c_getstatus.v`: Integration regression for direct CCC `GETSTATUS` readback.
- `tb/tb_i3c_entdaa.v`: First real controller/target `ENTDAA` regression with automatic controller inventory/policy population.
- `tb/tb_i3c_entdaa_multi.v`: Multi-target `ENTDAA` regression covering ordering, repeated assignment, automatic policy population, and exhaustion/NACK behavior.
- `tb/tb_i3c_entdaa_stress.v`: Six-target `ENTDAA` stress regression covering PID ordering, BCR/DCR inventory capture, automatic policy population, exact-fit table population, and exhaustion/NACK behavior.
- `tb/tb_i3c_scheduler.v`: Scheduler regression proving cadence-aware round-robin service selection from policy state, including service-period gating, repeated-failure fault latching, recovery clear, skip-on-disable, and skip-on-fault behavior.
- `tb/tb_i3c_ctrl_top_service.v`: End-to-end controller/target regression proving scheduled policy entries turn into real class-specific write-then-read service templates, multi-byte read capture, selector writes, success/NACK service statistics, and recovery clear after repeated service failures.
- `tb/tb_i3c_event_policy_ccc.v`: Integration regression for `ENEC`/`DISEC` target policy updates and mirrored controller-side event-mask state.
- `tb/tb_i3c_reset_status_policy.v`: Integration regression for direct `RSTACT`/`GETSTATUS`, broadcast `RSTDAA`/`SETAASA`, and mirrored controller-side reset/status policy tracking across recovery transitions.
- `tb/tb_i3c_recovery_sequence.v`: Focused controller-policy regression for timed retry, reset-style cooldown, forced-disable escalation, and explicit recovery clear behavior.
- `constraints/spartan7_i3c_demo.xdc`: Constraint template to adapt to your board.
- `Makefile`: Simulation runner (`iverilog` + `vvp`).
- `docs/I3C_Closed_System_IP_Plan.md`: original program plan.
- `docs/I3C_Architecture_Baseline.md`: consolidated architecture and phase baseline.
- `docs/I3C_Compatibility_Contract_v0_1.md`: initial closed-system interoperability contract.
- `docs/I3C_Controller_Target_Implementation_Plan.md`: detailed controller/target RTL implementation plan.
- `docs/chat_summaries/`: archived markdown summaries from the earlier project threads.

## Important Scope Notes

The RTL in this repo is still a bring-up baseline plus early Phase 1 scaffolding, not a full I3C Basic implementation. It does **not** yet include:

- In-band interrupts (IBI)
- HDR modes

What now exists beyond the original Phase 0 baseline:

- refactored controller transport stack with bus-engine and transaction-layer split
- synthesizable target transport in `rtl/`
- controller-side and target-side dynamic-address state scaffolding
- broadcast CCC issue/decode support for `RSTDAA` and `SETAASA`
- controller-side direct CCC framing with repeated-start sequencing for direct write/read command flows
- target-side direct CCC decode and transport holdoff for `SETDASA`, `RSTACT`, `ENEC`, and `DISEC`
- target-side metadata/status readback for `GETPID`, `GETBCR`, `GETDCR`, and `GETSTATUS`
- controller-side inventory bridge that auto-populates policy state from `ENTDAA` results
- controller-side endpoint policy table for per-target class, default enable, cadence, event-mask, reset-action, status, service statistics, and reset-action-keyed recovery sequencing
- cadence-aware scheduler path that walks integrated policy state, gates service on per-endpoint due state, issues class-specific register-selector writes, and produces round-robin class-sized multi-byte read transactions through a controller top wrapper
- controller-side recovery sequencing with timed retry windows, reset-style cooldown, forced-disable escalation, and explicit clear driven from stored reset-action policy
- multi-target `ENTDAA` controller/target baseline with PID/BCR/DCR capture, controller inventory retention, arbitration, repeated assignment, six-target exact-fit stress coverage, and exhaustion/NACK behavior
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
- `sim-getbcrdcr` prints `PASS` for direct CCC `GETBCR` and `GETDCR`
- `sim-getstatus` prints `PASS` for direct CCC `GETSTATUS`
- `sim-entdaa` prints `PASS` for the single-target `ENTDAA` baseline
- `sim-entdaa-multi` prints `PASS` for the multi-target `ENTDAA` sequencing baseline
- `sim-entdaa-stress` prints `PASS` for the six-target `ENTDAA` inventory stress baseline
- `sim-scheduler` prints `PASS` for cadence-aware round-robin service selection and service-period gating
- `sim-ctrl-top-service` prints `PASS` for end-to-end scheduled write-then-read service templates plus success/NACK service-statistics capture through the controller top integration path
- `sim-event-policy-ccc` prints `PASS` for target-side `ENEC`/`DISEC` plus mirrored controller policy tracking
- `sim-reset-status-policy` prints `PASS` for direct `RSTACT`/`GETSTATUS`, broadcast `RSTDAA`/`SETAASA`, and mirrored controller reset/status policy tracking
- `sim-recovery-sequence` prints `PASS` for reset-action-keyed controller recovery sequencing

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
- Phase 1 now includes DAA state scaffolding, controller-side PID/BCR/DCR inventory retention, automatic DAA-to-policy population, a controller policy table with class/enable/health plus per-endpoint cadence and service statistics, reset-action-keyed recovery sequencing, a cadence-aware scheduler path issuing class-specific write-then-read scheduled service templates with class-sized multi-byte reads, broadcast CCC support (`RSTDAA`, `SETAASA`, `ENEC`, `DISEC`), controller-side direct CCC framing, target-side `SETDASA`/`GETPID`/`GETBCR`/`GETDCR`/`GETSTATUS`/`RSTACT`, and regression-backed multi-target `ENTDAA` baselines through six endpoints.
- The remaining Phase 1 work is controller-driven address-state recovery/rekeying beyond the current policy-local sequencing baseline, plus selective IBI.
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
