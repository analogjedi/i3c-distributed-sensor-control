# I3C Compatibility Contract v0.1

## 1. Purpose
This contract defines the minimum interoperable behavior expected between the project Hub Controller and the custom Motor and Touch endpoints on the shared I3C bus.

This is not a general interoperability promise. It is the source of truth for the closed-system profile implemented by this repository and its companion device RTL.

## 2. Scope
Applies to:
- one Hub Controller
- up to eight total endpoints
- current baseline product profile of six endpoints:
  - three motor devices
  - three touch devices

Excludes for v0.1:
- HDR modes
- secondary controller operation
- runtime production hot-join
- general-purpose legacy I2C interoperability

## 3. Topology and Boot Policy
- Endpoint inventory is known by product configuration.
- Dynamic address assignment remains supported as part of the system boot contract.
- Static-assisted flows such as `SETDASA` or `SETAASA` may be used where they simplify deterministic bring-up.
- Production mode assumes no arbitrary endpoint insertion after boot.

## 4. Transaction Profile

### 4.1 Transport Baseline
- SDR is the required data-transfer mode for baseline operation.
- The controller must support addressed write and read transactions for endpoint register/data access.
- Endpoints must ACK only when the address and command context are valid for that device and current state.
- NACK is a valid response and must be handled as a first-class outcome by the Hub.

### 4.2 Traffic Shape
- Steady-state traffic is primarily Hub-initiated reads.
- Writes are concentrated in initialization, configuration, and explicit control operations.
- High-rate telemetry should be scheduled by the Hub rather than emitted as unsolicited traffic.

## 5. CCC Profile
The exact command list will be versioned as the implementation expands, but the baseline contract requires support for the CCC subset needed for:

- discovery and address assignment
- event enable/disable policy
- status/control operations used by the Hub boot flow
- reset sequencing and recovery handling

Each CCC adopted into the implementation must have a documented request/response contract before it is treated as verification complete.

## 6. IBI Policy
- IBI is supported selectively, not as the default path for routine telemetry.
- Motor endpoints may use IBI for urgent fault or protection events.
- Touch endpoints should default to scheduler-driven reporting unless latency analysis proves IBI is necessary.
- The Hub policy layer owns enable/disable decisions for IBI-capable events.

## 7. Reset and Error Recovery Policy
- The Hub must support explicit reset sequencing compatible with the project profile.
- Target reset behavior must distinguish between recoverable transaction faults and conditions requiring stronger reset escalation.
- SDR transaction error handling must avoid stuck-bus or deadlock behavior.
- Full system reboot is a last resort, not the default recovery path.

## 8. Timing and Service Expectations
- The bus schedule must preserve operational headroom for the six-endpoint baseline profile.
- Critical events delivered through IBI must have bounded service latency defined during Phase 1 implementation.
- Boot and address assignment behavior must be deterministic across repeated power cycles.

## 9. Forbidden or Disabled Behaviors
- Runtime hot-join in production mode
- Optional features enabled without verification collateral
- device-specific behavior that is not documented in this contract or an attached interface definition

## 10. Verification Obligations
The implementation is not contract-complete until it has:

- unit tests for controller and target behaviors
- integration tests for six-endpoint baseline traffic
- explicit negative tests for NACK/error handling
- directed tests for boot/address assignment policy
- reset and recovery tests matching the adopted policy

## 11. Near-Term Open Items
These decisions should be finalized next and then folded back into this contract:

1. exact CCC subset for Phase 1
2. chosen boot-time address assignment sequence
3. which motor faults are allowed to raise IBI
4. whether any touch events justify IBI
5. concrete latency and polling-period budgets per endpoint class
