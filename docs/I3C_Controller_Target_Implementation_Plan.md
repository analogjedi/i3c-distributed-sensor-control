# I3C Controller and Target Implementation Plan

## 1. Purpose
This document translates the architecture baseline and compatibility contract into an implementation plan for the Hub Controller RTL and endpoint Target RTL.

It is intentionally practical:
- what must exist in the controller
- what must exist in the target
- what order to implement it in
- what tests must pass before moving on

## 2. Required Feature Baseline
The closed-system profile for Phase 1 requires:

- SDR transfers for normal control and telemetry traffic
- boot-time address assignment with `ENTDAA` support
- optional static-assisted address flows with `SETDASA` or `SETAASA`
- required CCC subset for discovery, event policy, status/control, and reset handling
- selective IBI support for urgent endpoint events
- reset and SDR error-recovery behavior
- deterministic multi-endpoint operation for a six-endpoint baseline

Deferred beyond Phase 1:
- HDR modes
- secondary controller support
- multi-lane
- broad I2C coexistence

## 2.1 Current Implementation Status
Implemented and regression-backed:

- SDR controller transport stack refactor
- synthesizable SDR target transport
- controller-side DAA bookkeeping state
- target-side dynamic/static address state
- broadcast CCC support for:
  - `RSTDAA`
  - `SETAASA`
- controller-side direct CCC framing with repeated-start sequencing for:
  - direct write transactions
  - direct read transactions
- target-side direct CCC decode/response for:
  - `SETDASA`
  - `GETPID`
  - `GETBCR`
  - `GETDCR`
  - `GETSTATUS`
  - `RSTACT`
  - `ENEC`
  - `DISEC`
- multi-target `ENTDAA` controller/target baseline with:
  - PID/BCR/DCR capture
  - controller-side DAA address assignment
  - controller-side PID/BCR/DCR inventory retention
  - arbitration-driven target ordering
- controller-side inventory bridge that auto-populates policy records from DAA results
- controller-side endpoint policy table with per-address:
  - class
  - default enable state
  - event-mask
  - reset action
  - last status
  - basic health bits
- first round-robin scheduler stub that consumes integrated policy state

Not yet implemented:

- additional reset/status CCCs beyond the current addressing and event-control subset
- scheduler-to-transaction integration and richer controller service state beyond current class/enable/health/status bookkeeping
- IBI
- reset/recovery protocol flow beyond basic address-state control

## 3. Responsibility Split

### 3.1 Controller Must Own
- bus timing and SDR framing
- transaction issue and response capture
- address assignment orchestration
- CCC issue sequencing
- endpoint inventory table and policy state
- telemetry polling schedule
- IBI accept/NACK policy
- reset and recovery escalation

### 3.2 Target Must Own
- address match and SDR target transport
- address assignment participation data path
- supported CCC decoding and response generation
- local event source to IBI request path
- target-local reset/error state handling
- register/data access for the attached sensor logic

## 4. Proposed RTL Architecture

### 4.1 Controller RTL Partition
Recommended controller file/module breakdown:

1. `rtl/i3c_bus_engine.v`
   - low-level START/STOP generation
   - bit/byte transmit and receive
   - ACK/NACK and bus-turnaround handling
   - replaces or absorbs the current `i3c_sdr_controller.v`

2. `rtl/i3c_ctrl_txn_layer.v`
   - composes bus-engine operations into framed transfers
   - supports multi-byte read/write transactions
   - owns transaction status reporting and timeout hooks

3. `rtl/i3c_ctrl_daa.v`
   - runs `ENTDAA`
   - supports optional static-assisted assignment path
   - updates endpoint inventory table with assigned dynamic addresses plus retained PID/BCR/DCR metadata

4. `rtl/i3c_ctrl_ccc.v`
   - emits supported CCC transactions
   - decodes returned status where needed
   - central place for CCC enumeration and policy wiring

5. `rtl/i3c_ctrl_policy.v`
   - retains per-endpoint policy state beyond raw discovery inventory
   - tracks event-enable masks, reset action, and last known status by dynamic address
   - provides a clean landing point for scheduler and recovery policy growth

6. `rtl/i3c_ctrl_ibi.v`
   - monitors and services IBI flow
   - implements event acceptance policy and software-visible status

7. `rtl/i3c_ctrl_scheduler.v`
   - round-robin or weighted polling of known endpoints
   - supports per-endpoint polling period and transaction template
   - reserves headroom for urgent event handling

8. `rtl/i3c_ctrl_recovery.v`
   - transaction retry policy
   - stuck-bus detection hooks
   - reset escalation sequencing, including `RSTACT`-driven flows adopted by the profile

9. `rtl/i3c_ctrl_top.v`
   - integrates all controller blocks
   - exposes a clean host-side control/status interface
   - owns boot state machine

### 4.2 Target RTL Partition
Recommended target file/module breakdown:

1. `rtl/i3c_target_transport.v`
   - SDR target receive/transmit engine
   - address match, ACK/NACK, read/write framing
   - evolves from the current `tb/i3c_target_model.v` behavior into synthesizable RTL

2. `rtl/i3c_target_daa.v`
   - provides target identity fields used during `ENTDAA`
   - handles assigned dynamic address capture
   - supports optional static-assisted address initialization

3. `rtl/i3c_target_ccc.v`
   - decodes supported CCCs
   - updates local state for event enable/disable, addressing, and reset policy

4. `rtl/i3c_target_ibi.v`
   - latches local urgent events
   - arbitrates local IBI request generation
   - gates IBI behavior based on CCC-controlled enable state

5. `rtl/i3c_target_recovery.v`
   - target-local error state
   - reset action handling
   - post-reset state restoration policy

6. `rtl/i3c_target_regs.v`
   - register file for telemetry, status, configuration, and event status
   - class-independent access shell

7. `rtl/i3c_target_profile_high_rate.v`
   - profile-specific behavior for high-rate control-sensor endpoints

8. `rtl/i3c_target_profile_hid.v`
   - profile-specific behavior for human-interface sensor endpoints

9. `rtl/i3c_target_top.v`
   - integrates transport, DAA, CCC, IBI, recovery, and profile-specific register logic

## 5. Interface Plan

### 5.1 Controller Internal Interfaces
Standardize these internal interfaces early:

- bus-engine command interface
  - opcode
  - byte count
  - data stream in/out
  - completion status

- endpoint table interface
  - static ID
  - dynamic address
  - PID
  - BCR/DCR
  - class
  - enabled state
  - IBI enable state
  - health/fault status

- scheduler request interface
  - endpoint index
  - operation type
  - register/command selector
  - expected response length

### 5.2 Target Internal Interfaces
Standardize:

- transport-to-register access interface
  - address/command
  - read/write strobe
  - write data
  - read data
  - access-valid/error response

- event interface
  - event source ID
  - event pending
  - event severity
  - IBI eligible flag

- local state interface
  - dynamic address valid
  - CCC enable state
  - reset reason
  - profile mode

## 6. Phase Plan

### Phase 0.5: Refactor the Existing Baseline
Goal:
- keep current passing behavior while reshaping code for growth

Controller tasks:
- move current controller logic behind a bus-engine style interface
- support multi-byte transaction scaffolding even if only one byte is initially exercised
- add explicit comments/TODO anchors for DAA, CCC, IBI, and recovery blocks

Target tasks:
- create synthesizable target transport RTL instead of relying only on a testbench model
- preserve existing address-match, read, write, and NACK behavior

Exit criteria:
- existing happy-path and NACK tests still pass
- module boundaries exist for future features

### Phase 1: Address Assignment
Goal:
- deterministic boot to dynamic-address map

Controller tasks:
- implement boot state machine for discovery and address assignment
- complete the direct CCC support needed for `SETDASA`
- implement `ENTDAA`
- optionally add `SETDASA` or `SETAASA` path if selected for product boot
- populate endpoint table from assignment results

Target tasks:
- implement target identity response for DAA
- capture and retain assigned dynamic address
- support reset-to-unassigned and reset-to-known-state transitions

Current status:

- `SETAASA` path is implemented through broadcast CCC handling
- target address-state reset via `RSTDAA` is implemented
- controller-side direct CCC framing is implemented and regression-backed
- target-side `SETDASA` is implemented and regression-backed
- target-side `GETPID` is implemented and regression-backed
- target-side `GETBCR` and `GETDCR` are implemented and regression-backed
- target-side `GETSTATUS` and direct `RSTACT` are implemented and regression-backed
- target-side `ENEC` and `DISEC` event-mask updates are implemented and regression-backed
- multi-target `ENTDAA` sequencing is implemented and regression-backed
- controller inventory now retains PID/BCR/DCR
- DAA discovery now auto-populates controller policy records
- controller policy now tracks per-address class, default enable state, event-enable masks, reset action, last status, and basic health bits
- a first controller scheduler stub now walks integrated policy state and emits round-robin service requests while skipping disabled or faulted endpoints
- `ENTDAA` stress coverage now reaches a six-endpoint exact-fit baseline

Exit criteria:
- single-target and multi-target DAA tests pass
- repeated boot yields deterministic expected address map

### Phase 2: CCC Subset
Goal:
- enable the closed-system policy contract

Controller tasks:
- implement CCC issue path and response handling
- implement policy hooks for event enable/disable and reset actions

Target tasks:
- implement supported CCC decode and state updates
- reject unsupported CCCs in a defined way

Current status:

- broadcast CCC issue/decode path is implemented
- supported broadcast CCCs today are `RSTDAA`, `SETAASA`, `ENEC`, and `DISEC`
- controller-side direct CCC framing is implemented in a standalone sequencer
- target-side direct CCC decode now supports `SETDASA`, `GETPID`, `GETBCR`, `GETDCR`, `GETSTATUS`, `RSTACT`, `ENEC`, and `DISEC`
- controller-side policy tracking now covers event masks, reset action, and last-known status
- the next CCC milestone is additional recovery/status coverage beyond the current baseline

Minimum CCC set to lock before coding:
- addressing support needed for chosen boot flow
- event enable/disable commands used by policy
- status/control commands required by boot and service flow
- reset-related commands required by the recovery plan

Recommended near-term CCC order:

1. any additional direct CCCs needed by the boot/profile contract
2. any broadcast CCCs needed before broader recovery/policy work
3. event-control CCCs needed before IBI work
4. reset-policy CCCs beyond `RSTDAA`

Exit criteria:
- directed CCC tests pass for every supported command
- controller and target state updates match contract expectations

### Phase 3: Multi-Byte Data Path and Register Access
Goal:
- move past the one-byte demo and support realistic telemetry/control payloads

Controller tasks:
- support variable-length reads and writes
- add transaction timeout and framing error detection

Target tasks:
- implement structured register access shell
- expose profile-specific telemetry/configuration registers

Exit criteria:
- multi-byte read/write regressions pass
- malformed access cases produce defined NACK/error behavior

### Phase 4: IBI
Goal:
- support urgent event delivery without turning the bus into chaos

Controller tasks:
- detect and arbitrate IBI service
- decide accept/NACK based on policy and current bus state
- surface event source and payload status

Target tasks:
- generate IBI requests from qualified local urgent events
- honor controller event enable state
- clear/retry latched events according to contract

Exit criteria:
- single-source and concurrent IBI tests pass
- non-urgent traffic remains scheduler-driven

### Phase 5: Reset and Recovery
Goal:
- recover from faults without deadlock or unnecessary full reboot

Controller tasks:
- classify transaction failures
- implement retry, targeted reset, and escalation sequencing
- support `RSTACT`-based flows adopted by the profile

Target tasks:
- distinguish protocol fault, local fault, and reset cause
- implement reset action handling and post-reset state policy

Exit criteria:
- injected fault tests recover without stuck bus
- reset behavior matches the contract for both recoverable and escalated cases

### Phase 6: Scheduler and Six-Endpoint System Integration
Goal:
- demonstrate useful system behavior under the intended traffic model

Controller tasks:
- implement endpoint polling schedule
- reserve bandwidth for urgent event servicing
- maintain endpoint health and service statistics

Target tasks:
- profile-specific data production at representative rates
- event generation patterns representative of the product class

Exit criteria:
- six-endpoint integration regression passes
- measured traffic remains within planning budget

## 7. Verification Plan by Feature

### 7.1 Controller Unit Tests
- transaction success and NACK handling
- multi-byte framing
- DAA state sequencing
- CCC issue/response handling
- IBI acceptance and service ordering
- recovery escalation paths

### 7.2 Target Unit Tests
- address match and data transfer
- DAA identity response and address capture
- CCC decode and state update
- IBI event latch/clear behavior
- reset/recovery transitions

### 7.3 Integration Tests
- one controller plus one target
- one controller plus six mixed-profile targets
- one controller plus eight targets under stress
- boot, steady-state, event burst, and recovery sequences

### 7.4 Hardware Tests
- single-FPGA loopback or controller-plus-simple-target bring-up
- two-board validation for bus turn-around and pull-up realism
- long-run soak at representative traffic rates

## 8. Coding Order Recommendation
Recommended order of actual implementation:

1. refactor bus engine and create synthesizable target transport
2. add direct CCC framing support
3. add DAA and direct target-side CCC support
4. add broader CCC subset
5. add register shell and profile data model
6. add IBI
7. add reset/recovery
8. add scheduler and six-endpoint integration

This order reduces risk because it keeps the data path and addressing stable before introducing event-driven behavior and recovery complexity.

## 9. Open Decisions to Lock Before Heavy RTL Work
- exact Phase 1 CCC command list
- whether the first boot flow is pure `ENTDAA` or static-assisted
- target identity field format and product inventory mapping
- host-side controller control/status interface shape
- which urgent events are allowed to trigger IBI
- per-endpoint polling budgets and maximum acceptable service latency

## 10. Immediate Repo Tasks
The next concrete repository tasks should be:

1. replace the current controller with a bus-engine plus transaction-layer split
2. create synthesizable target transport RTL under `rtl/`
3. add a controller-target multi-byte integration testbench
4. add DAA-focused directed tests before implementing CCC and IBI
5. create a simple endpoint table package or include file used consistently across controller blocks

Updated next concrete repository tasks:

1. connect scheduler service requests into real controller transaction issue
2. add richer scheduler-facing service statistics and per-endpoint cadence control
3. add additional recovery/status CCC coverage beyond the current baseline
4. only then expand into reset-policy CCCs and IBI control
