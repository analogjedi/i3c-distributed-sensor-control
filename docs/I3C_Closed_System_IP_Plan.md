# I3C Closed-System IP Plan

## 1. Goal
Build a complete, closed chipset where a custom Hub Controller communicates reliably with custom Motor and Touch endpoints over one shared I3C bus, prioritizing **system interoperability verification** over broad third-party interoperability.

## 2. Executive Recommendation
`chipsalliance/i3c-core` is the best starting point for the Hub-side controller IP.

Why:
- Open implementation with significant verification collateral (SystemVerilog + cocotb/UVM infrastructure).
- Explicitly targets I3C Basic feature scope.
- Better long-term maintainability than one-off custom RTL from scratch.

What to keep in mind:
- Public repo statements are centered on I3C Basic v1.1.1; your spec baseline is I3C Basic v1.2 (public edition, 16-Dec-2024 / board-adopted 17-Apr-2025). Plan a v1.2 delta review instead of assuming 1:1 closure.

## 3. Program Constraints (Your Use Case)
- Closed ecosystem: only your Hub + your endpoints.
- Static topology by product: no runtime hot-plug requirement.
- Typical endpoint count: 6 (3 motor ICs + 3 touch ICs), scalable up to 8.
- Steady-state traffic is read-dominant (writes mainly at init/config time).
- Interop priority: custom-to-custom compatibility first, external vendor compatibility second.

## 4. Spec Baseline and Interpretation for This Program
Primary normative baseline:
- `/Users/jhaas/Development/Digital_Design/docs/MIPI-I3C-Basic-Specification-v1-2-public-edition.pdf`

Important extracted anchors from the spec text:
- Required core behavior is organized in Section 4 `Required Elements`.
- Dynamic Address Assignment remains core/essential (`ENTDAA` path), even if alternate address-assignment methods are used when appropriate (`SETDASA`/`SETAASA`).
- IBI is a required mechanism in Required Elements, with priority behavior tied to dynamic address ordering.
- SDR error detection/recovery and Target Reset behavior are explicit required mechanisms (including `RSTACT` + Target Reset Pattern sequencing).
- I3C Basic v1.2 is primarily clarifications/fixes vs v1.1.1, not a major new feature expansion.

Planning implication:
- Treat this project as a **profiled subset implementation** of I3C Basic required elements plus selected options, then prove profile correctness end-to-end across your own devices.

## 5. IP Strategy

## 5.1 Hub Controller (Primary Candidate)
- Base on `chipsalliance/i3c-core` for controller/bus management foundation.
- Implement a thin product-specific wrapper:
  - Boot sequencing.
  - Static endpoint inventory and policy.
  - Periodic polling scheduler for motor/touch telemetry.
  - Optional IBI service path.

## 5.2 Endpoint Target IP (Motor + Touch)
For endpoint RTL, use a lightweight target architecture focused on:
- SDR target transactions.
- Address assignment participation (`ENTDAA`, and optionally static-assisted flows).
- Required CCC handling subset used by your Hub profile.
- Reset/error handling defined in your compatibility contract.

Reference options:
- Reuse/adapt concepts from open target RTL (e.g., NXP target design), but expect integration and version-gap work.
- If area/power are strict, consider a custom minimal target peripheral with only required contract features.

## 5.3 Optional/Fallback Controller IP
- ADI I3C controller IP can be a fallback/reference controller path, but its command-descriptor architecture is oriented to specific FPGA integration flows and may require more adaptation for your full chipset control model.

## 6. Closed-System Feature Profile (What to Implement First)

## 6.1 Mandatory for Phase 1 (Bring-Up + Product Operation)
- SDR transfers.
- Bus initialization and dynamic addressing:
  - `ENTDAA` supported and verified.
  - `SETDASA`/`SETAASA` supported if used in your boot policy.
- Required CCC subset for your flow (at minimum those needed for discovery, status, addressing, event control, and reset policy).
- Error detection/recovery behavior required for SDR in your selected transaction patterns.
- Target Reset mechanism including `RSTACT` usage and required sequencing.
- Electrical/timing closure for your board loading and voltage domain.

## 6.2 Enabled but Policy-Limited
- Hot-Join capability can exist in logic but be disabled by policy after boot (`DISEC/ENEC` policy gating).
- IBI support can be enabled selectively:
  - Motor faults/critical events: enable.
  - High-rate periodic data: prefer scheduled reads unless latency needs dictate IBI.

## 6.3 Defer to Later Phases (Unless Proven Necessary)
- Secondary Controller operation.
- HDR modes.
- Multi-lane.
- Group addressing (nice optimization, not required for first silicon unless broadcast config materially reduces overhead).
- Legacy I2C coexistence (if product bus is pure I3C endpoints).

## 7. Compatibility Contract (Key Deliverable)
Create a project-owned `I3C Compatibility Contract` document defining exactly what "works" means across Hub/Motor/Touch devices.

Required sections:
- Supported commands and exact response behavior.
- Addressing policy (boot-time flow, static map expectations, collision handling).
- IBI policy (which endpoints/events may assert, payload format, service latency expectations).
- Reset/error escalation policy (which error type triggers which recovery action).
- Timing budgets (max service latency, bus availability assumptions, polling periods).
- Forbidden behaviors (e.g., runtime hot-join in production mode).

This contract becomes the verification source of truth.

## 8. Verification Plan

## 8.1 Verification Levels
- L0 Unit: standalone Hub RTL and standalone endpoint RTL.
- L1 Bus Integration: Hub + multiple endpoint models on a shared bus.
- L2 Contract Compliance: directed and random tests against your compatibility contract.
- L3 System Validation: firmware-in-loop and hardware-in-loop.

## 8.2 Test Categories
- Bring-up sequence:
  - Power-up to stable dynamic address map.
  - Optional static-assisted assignment path.
- Steady-state traffic:
  - 6-endpoint and 8-endpoint profiles.
  - Read-heavy telemetry at target rates.
- IBI handling:
  - Single and concurrent IBI arbitration.
  - Accepted vs NACKed IBI behavior.
- Error injection:
  - SDR error classes relevant to your message patterns.
  - Recovery without deadlock/stuck bus.
- Reset escalation:
  - `RSTACT` + Target Reset Pattern behavior.
  - Peripheral-only vs whole-target reset outcomes.
- Robustness:
  - Endpoint dropout/rejoin policy handling (even if hot-plug is disabled in production).
  - Long-run soak with randomized timing jitter.

## 8.3 Metrics and Exit Criteria
- Zero unresolved protocol deadlocks across regression suites.
- Deterministic boot address assignment across 1000+ power cycles.
- No contract violations under randomized stress.
- Measured bus utilization within planned budget and margin.
- Recovery from injected faults without full-system reboot (except explicitly allowed escalations).

## 9. Implementation Phases

## Phase A: Feasibility and Gap Analysis (2-3 weeks)
- Integrate/evaluate controller candidate (`chipsalliance/i3c-core`).
- Map controller/target capabilities against your v1.2 profile requirements.
- Produce gap list: missing features, behavior mismatches, verification holes.

Deliverables:
- Gap matrix (candidate IP vs required profile).
- Finalized compatibility contract v0.1.

## Phase B: Hub + Endpoint RTL Adaptation (4-8 weeks)
- Build Hub wrapper and scheduler.
- Implement endpoint target profile logic for motor and touch classes.
- Add reset/error policy implementation hooks.

Deliverables:
- Synthesizable Hub/Target RTL.
- First integrated simulation with 6 endpoints.

## Phase C: Verification Closure (4-6 weeks)
- Build full contract-based regression.
- Add negative/fault-injection and long-run stress.
- Close coverage on agreed behavior set.

Deliverables:
- Regression dashboard and coverage report.
- Sign-off checklist against compatibility contract.

## Phase D: FPGA/System Bring-Up (3-5 weeks)
- Hardware prototype validation of timing and robustness.
- Firmware sequencing validation (boot init, telemetry cadence, fault paths).

Deliverables:
- Hardware validation report.
- Production profile configuration baseline.

## 10. Key Risks and Mitigations
- Risk: Assuming v1.1.1 open IP equals v1.2 behavior.
  - Mitigation: Explicit v1.2 delta checklist and directed tests for all deltas you adopt.
- Risk: Over-implementing optional features and delaying tapeout.
  - Mitigation: Freeze a strict profile and defer non-critical options.
- Risk: Hidden protocol corner cases under high-rate multi-endpoint telemetry.
  - Mitigation: Stress with concurrent arbitration/error/reset scenarios early.
- Risk: Tight bus margin at higher endpoint count.
  - Mitigation: Keep read scheduling deterministic; gate IBI usage; preserve throughput headroom.

## 11. Immediate Next Actions
1. Lock the Phase A feature profile (must/should/defer) in writing.
2. Fork and baseline the controller IP candidate in your internal repo.
3. Write compatibility contract v0.1 before broad RTL edits.
4. Stand up an automated regression harness for 6-target topology first, then 8-target.

