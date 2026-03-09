# I3C Architecture Baseline

## 1. Purpose
This document consolidates the current project direction into a single baseline for architecture, implementation scope, and repository intent.

The immediate goal is to build a closed-system I3C bus for a custom chipset:

- one Hub Controller
- three motor endpoints
- three touch endpoints
- scalable to eight total endpoints

The current repository already contains a Phase 0 Spartan-7 SDR starter. This document defines how that starter maps to the larger program.

## 2. Program Decisions Locked In

### 2.1 System Profile
- Closed ecosystem only: Hub, Motor, and Touch devices are all project-owned.
- Static product topology: no production hot-plug requirement.
- Steady-state traffic is predominantly read-driven.
- Primary success criterion is custom-to-custom interoperability and verification, not broad third-party device compatibility.

### 2.2 Spec and IP Baseline
- Normative baseline: I3C Basic v1.2 public edition.
- Primary Hub-side starting point for a fuller controller path: `chipsalliance/i3c-core`.
- Current local code baseline remains a small custom SDR controller for fast FPGA bring-up and waveform debugging.

### 2.3 FPGA Baseline
- Near-term hardware target: Spartan-7, including fit awareness for `XC7S25-1CSGA225C`.
- Expected feasible prototype scope on Spartan-7:
  - SDR transfers
  - address assignment support
  - CCC subset
  - IBI support where justified
  - reset/error recovery
- Defer resource-heavy optional features until justified by measured need.

## 3. Baseline Architecture

### 3.1 Hub Layering
The Hub implementation should be treated as three separable layers:

1. Physical bus engine
   - bit-level bus timing
   - SDR transmit/receive
   - START/STOP framing
   - ACK/NACK detection

2. Protocol management
   - address assignment flow
   - CCC execution
   - IBI acceptance/policy
   - reset and recovery sequencing

3. Product policy wrapper
   - known endpoint inventory
   - boot sequencing
   - telemetry polling schedule
   - fault escalation policy

The current `rtl/i3c_sdr_controller.v` only covers the first layer for a narrow SDR transaction shape. That is intentional for Phase 0.

### 3.2 Endpoint Layering
Each endpoint class should share a common transport shell and expose class-specific register/data behavior above it.

Common endpoint responsibilities:
- dynamic/static-assisted address assignment participation
- selected CCC response handling
- read/write framing
- IBI generation where enabled
- reset/error state handling

Device-specific responsibilities:
- motor telemetry/status register map
- touch telemetry/event register map
- class-specific fault/event semantics

## 4. Feature Baseline by Phase

### 4.1 Phase 0: Existing Repo Baseline
Implemented now:
- single-controller SDR transfer engine
- single-byte write
- single-byte read
- ACK/NACK handling
- simple behavioral target model
- Spartan-7 top-level wiring with `IOBUF`

Purpose:
- validate signal integrity and transaction framing quickly
- establish a simulation and hardware bring-up harness
- keep logic small enough for early Spartan-7 experiments

### 4.2 Phase 1: Closed-System Operational Minimum
Required next:
- `ENTDAA` path and chosen static-assisted address flow
- required CCC subset for boot, event control, and reset policy
- target reset and selected SDR recovery flows
- multi-endpoint scheduling for six-target topology
- selective IBI support for fault-class events

### 4.3 Phase 2: Verification and Hardening
- six-target and eight-target integration regressions
- randomized stress and error injection
- deterministic boot/address assignment testing
- hardware-in-loop validation across two separate FPGA or silicon nodes

### 4.4 Deferred
- HDR modes
- secondary controller support
- multi-lane
- broad I2C coexistence
- features added only for external interoperability

## 5. Traffic and Scheduling Assumptions
- Baseline planning profile is six active targets.
- The worksheet analysis currently indicates about 62.23% bus utilization at 8 Mb/s effective SDR throughput for the six-target profile.
- Remaining headroom is acceptable for baseline planning, but not generous enough to tolerate sloppy arbitration or uncontrolled event traffic.

Implication:
- periodic telemetry should stay scheduler-driven
- IBI should be reserved for urgent events, especially motor fault conditions
- verification should include utilization margin checks, not just functional pass/fail

## 6. Verification Strategy

### 6.1 Test Levels
- L0: controller and endpoint unit tests
- L1: shared-bus integration tests
- L2: compatibility-contract compliance tests
- L3: hardware/system validation

### 6.2 Hardware Test Progression
Recommended progression:

1. single FPGA with controller plus behavioral target model
2. single FPGA with controller plus simple external target
3. two separate FPGA boards for realistic bus turn-around, pull-up, and reset timing validation

Single-board bring-up is faster. Two-board validation is required before treating the interface as integration-ready.

## 7. Repository Mapping

Current repository roles:
- `rtl/`: Phase 0 transport-level RTL
- `tb/`: simulation collateral and behavioral target models
- `constraints/`: FPGA pin/timing scaffolding
- `scripts/`: build helpers
- `tools/`: traffic-planning worksheet
- `docs/`: architecture, planning, and contract artifacts

## 8. Immediate Deliverables
The next repo-level deliverables should be:

1. compatibility contract v0.1
2. candidate-IP gap matrix against the v1.2 profile
3. expanded controller/target regression suite
4. Phase 1 Hub wrapper and endpoint-profile RTL

## 9. Acceptance Criteria for the Current Baseline
The current baseline is considered healthy if it can demonstrate:

- successful SDR write/read transactions in simulation
- explicit NACK-path behavior in simulation
- repeatable FPGA waveform bring-up on Spartan-7
- a documented path from Phase 0 transport RTL to Phase 1 protocol/profile work
