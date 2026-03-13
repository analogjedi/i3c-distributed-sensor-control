# I3C Full Controller Roadmap

This roadmap turns the current SDR-centric controller baseline into a broader I3C Basic
controller implementation in staged waves.

## Goals

1. Preserve the working FPGA static-assisted boot and scheduled service path.
2. Expand CCC support in controller/target RTL with regression-backed behavior.
3. Avoid broad architectural churn while the repo is still serving as a hardware validation
   platform.

## Branch Priorities

### Wave 1: Missing Direct / Length / Capability CCCs

Status: complete on `codex/full-controller`

Add:

- `SETNEWDA`
- `SETMWL`
- `SETMRL`
- `GETMWL`
- `GETMRL`
- `GETMXDS`
- `GETCAPS`

Expected deliverables:

- target-side state for max read/write length, speed, capability bytes, and direct dynamic-address
  update
- grouped regressions for direct and broadcast length/capability flows
- README / matrix updates

### Wave 2: Addressing / Discovery Hardening

Status: complete on `codex/full-controller`

Add or fix:

- restore `ENTDAA` simulation closure
- keep existing `SETDASA`, `SETAASA`, `RSTDAA`, `GETPID`, `GETBCR`, `GETDCR`,
  `GETSTATUS`, `RSTACT` coherent with the synchronous target rewrite

Expected deliverables:

- no `ENTDAA` regressions failing in the full suite
- no regression of the working FPGA `SETDASA`-based boot flow
- repaired mixed-controller bench muxing so the active controller is the only one driving the simulated bus during `SETDASA` and `ENTDAA` flows

### Wave 3: Activity State and Group Address Control

Status: complete for target-side `ENTAS0..3`, `SETGRPA`, and `RSTGRPA`; `DEFGRPA` remains a future secondary-controller-oriented extension

Add:

- `ENTAS0`
- `ENTAS1`
- `ENTAS2`
- `ENTAS3`
- `SETGRPA`
- `RSTGRPA`
- `DEFGRPA`

Expected deliverables:

- target-side activity-state register
- target-side group-address state
- grouped regressions for activity-state broadcast/direct flows and group-address management
- transport-level alternate-address support so group-address private transfers are real, not bookkeeping theater

## Explicit Deferrals

These remain outside Waves 1-3, or only partially addressed:

- `DEFTGTS`
- `GETACCCR`
- `SETBUSCON`
- `SETBRGTGT`
- `SETROUTE`
- `SETXTIME`
- `GETXTIME`
- `ENDXFER`
- `ENTHDR0..7`
- `MLANE`
- `D2DXFER`
- `ENTTM`
- dedicated `DEFGRPA` consumer behavior for secondary-controller-style targets

## Verification Policy

For each wave:

1. add focused regressions for the new CCC families
2. rerun existing adjacent regressions
3. rerun `make test`
4. avoid changing the FPGA demo tops unless the wave explicitly requires it

## Risk Management

The biggest technical risk at branch start was that the synchronous target-side rewrite improved FPGA
synthesis behavior while regressing the `ENTDAA` simulation path. That risk is now addressed for the
current regression suite; the remaining risk is broader CCC-family completion outside the first three
waves, not basic address-path instability.
