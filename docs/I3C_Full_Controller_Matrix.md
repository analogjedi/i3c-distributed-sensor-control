# I3C Full Controller Matrix

This branch tracks controller-oriented Common Command Code (CCC) coverage against the
public MIPI I3C Basic v1.2 command set.

Status values:

- `Implemented`: present in RTL with regression coverage
- `In Progress`: partially present, regressed, or missing controller/target closure
- `Planned`: not yet implemented on this branch
- `Out of Scope (Current Wave)`: intentionally deferred to later waves

## Coverage Matrix

| CCC / Family | Type | Current Branch Status | Notes |
| --- | --- | --- | --- |
| `ENEC` | Broadcast + Direct | Implemented | Event-mask control path present |
| `DISEC` | Broadcast + Direct | Implemented | Event-mask control path present |
| `ENTAS0..3` | Broadcast + Direct | Implemented | Wave 3 regression-backed target-side activity-state control |
| `RSTDAA` | Broadcast | Implemented | Current target/controller baseline |
| `ENTDAA` | Broadcast | Implemented | Controller/target path restored; single, multi-target, and stress regressions pass |
| `DEFTGTS` | Broadcast | Planned | Later wave; Secondary Controller oriented |
| `SETMWL` | Broadcast + Direct | Implemented | Wave 1 target-side max-write-length control and readback |
| `SETMRL` | Broadcast + Direct | Implemented | Wave 1 target-side max-read-length and IBI-length control |
| `ENTTM` | Broadcast | Planned | Later wave |
| `SETBUSCON` | Broadcast | Planned | Later wave |
| `ENDXFER` | Broadcast + Direct | Planned | Later wave; HDR-oriented |
| `ENTHDR0..7` | Broadcast | Planned | Later wave; HDR-oriented |
| `SETXTIME` | Broadcast + Direct | Planned | Later wave; timing-control oriented |
| `SETAASA` | Broadcast | Implemented | Current target/controller baseline |
| `RSTACT` | Broadcast + Direct | In Progress | Direct form implemented; broader family still incomplete |
| `DEFGRPA` | Broadcast | In Progress | Wave 3 branch keeps the family on the controller roadmap; ordinary-target RTL does not implement a dedicated secondary-controller consumer |
| `SETGRPA` | Direct | Implemented | Wave 3 target-side group assignment is regression-backed |
| `RSTGRPA` | Broadcast + Direct | Implemented | Wave 3 target-side group reset is regression-backed |
| `MLANE` | Broadcast + Direct | Planned | Later wave; multi-lane oriented |
| `SETDASA` | Direct Set | Implemented | Current static-assisted boot path |
| `SETNEWDA` | Direct Set | Implemented | Wave 1 dynamic-address update path and regression coverage |
| `GETMWL` | Direct Get | Implemented | Wave 1 direct readback path |
| `GETMRL` | Direct Get | Implemented | Wave 1 direct readback path |
| `GETPID` | Direct Get | Implemented | Current target/controller baseline |
| `GETBCR` | Direct Get | Implemented | Current target/controller baseline |
| `GETDCR` | Direct Get | Implemented | Current target/controller baseline |
| `GETSTATUS` | Direct Get | Implemented | Current target/controller baseline |
| `GETACCCR` | Direct Get | Planned | Later wave; Secondary Controller oriented |
| `SETBRGTGT` | Direct Set | Planned | Later wave |
| `GETMXDS` | Direct Get | Implemented | Wave 1 direct capability readback |
| `GETCAPS` | Direct Get | Implemented | Wave 1 direct capability readback |
| `SETROUTE` | Direct | Planned | Later wave |
| `D2DXFER` | Direct | Planned | Later wave |
| Reserved / vendor / HDR-only terminator slots | Mixed | Out of Scope (Current Wave) | Not targeted in Waves 1-3 |

## Wave Summary

- Wave 1:
  `SETNEWDA`, `SETMWL`, `SETMRL`, `GETMWL`, `GETMRL`, `GETMXDS`, `GETCAPS`
- Wave 2:
  restore `ENTDAA` simulation closure and align existing addressing/status coverage
- Wave 3:
  `ENTAS0..3`, `SETGRPA`, `RSTGRPA`, `DEFGRPA`

Wave completion on this branch today:

- Wave 1: implemented with focused regression coverage in `tb/tb_i3c_wave1_ccc.v`
- Wave 2: completed by restoring `SETDASA`/`ENTDAA` harness closure and keeping the synchronous target rewrite simulation-clean
- Wave 3: implemented for `ENTAS0..3`, `SETGRPA`, and `RSTGRPA` with grouped regression coverage in `tb/tb_i3c_wave3_activity_group.v`
- `DEFGRPA`: still roadmap-only for a future secondary-controller-oriented consumer path

## Current Practical Controller Position

The repo is already strong for an SDR static-assisted target profile because it supports:

- `SETDASA`
- `GETPID`
- `GETBCR`
- `GETDCR`
- `GETSTATUS`
- `RSTDAA`
- `SETAASA`
- `ENEC`
- `DISEC`
- `RSTACT` (direct baseline)

This branch expands that baseline toward a more complete controller without destabilizing the
working FPGA validation path.
