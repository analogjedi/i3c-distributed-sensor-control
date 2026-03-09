# Chat Thread Summary 1

## Overview
This thread focused on evaluating I3C for a closed custom chipset, building a traffic-planning worksheet, assessing available open IP, and judging whether a prototype-capable controller would fit in a Xilinx Spartan-7 `XC7S25-1CSGA225C`.

## I3C Architecture Discussion
- The target system is a closed bus with one Hub Controller and multiple fixed endpoints.
- Endpoint count is static per application, with expected range from 1 to 8 and a more realistic current target of 6:
  - 3 motor-controller endpoints
  - 3 touch-sensor endpoints
- Because the system is closed and only custom devices need to interoperate, strict third-party interoperability matters less than reliable communication and verification across the custom hub/motor/touch devices.
- Relevant I3C Basic features for this use case were identified as:
  - SDR operation
  - Dynamic addressing / bus initialization
  - CCC support
  - IBI where useful
  - Target reset and SDR error recovery
- Features considered lower priority or deferrable:
  - Hot-Join in production use
  - Secondary controller
  - HDR modes
  - Multi-lane
  - Legacy I2C coexistence, unless required later

## Worksheet UI Work
- A local worksheet GUI was created in:
  - `tools/i3c_worksheet.html`
- The worksheet supports:
  - Fixed endpoint count selection from 1 to 8
  - Per-target traffic modeling
  - Shared-bus topology visualization
  - Aggregate bandwidth/utilization estimates
  - Feature-alignment guidance
  - JSON export/import
- README documentation was updated to mention the worksheet.

## Worksheet Fixes and Updates
- Fixed a UI bug where increasing target count above 4 did not re-enable rows `T5` to `T8`.
- Added safe HTML escaping for free-form names in the worksheet UI.
- Clarified the bus-rate field so it is understood as effective throughput, not clock frequency:
  - Label changed to `Effective I3C SDR Throughput (Mb/s, not MHz)`
  - Added helper text
  - Added SDR guardrail clamp with max `12.5`
- Reset default worksheet bus rate to `8`.

## Traffic Modeling Discussion
- The user exported a worksheet JSON profile and asked whether it made sense for:
  - 3 motor closed-loop torque measurement endpoints
  - each reading 3 current channels + 1 temperature channel
  - additional touch-sensor endpoints
- The worksheet payload fields `Read Payload (B)` and `Write Payload (B)` were confirmed to be in **bytes**.
- The saved JSON profile was refined:
  - `T1` read payload adjusted to match `T2` and `T3`
  - steady-state writes set to zero because operation after initialization is read-only
  - later reduced from 8 enabled endpoints to 6 enabled endpoints
- Resulting updated profile:
  - `targetCount = 6`
  - `busRate = 8 Mb/s`
  - 3 high-rate motor endpoints
  - 3 touch endpoints at `2200 Hz`
- Estimated steady-state traffic for the updated 6-target profile:
  - about `4.9786 Mb/s`
  - about `62.23%` utilization at `8 Mb/s`
  - about `7.77%` remaining headroom against a `70%` planning ceiling

## Open I3C Basic IP Discussion
- Existing GitHub IP options were reviewed at a high level.
- The strongest open candidate identified for the Hub side was:
  - `chipsalliance/i3c-core`
- Other public references noted:
  - NXP target/slave design
  - ADI controller-oriented HDL
- The conclusion was that `chipsalliance/i3c-core` is the best primary candidate for the Hub Controller, with the important caveat that public claims are centered on I3C Basic v1.1.1 while the user’s local spec baseline is I3C Basic v1.2.

## MIPI Spec Use
- The local PDF:
  - `docs/MIPI-I3C-Basic-Specification-v1-2-public-edition.pdf`
  was examined after Poppler tools were installed.
- Relevant spec sections were extracted and used to ground planning around:
  - Required Elements
  - Dynamic Address Assignment
  - CCC behavior
  - IBI behavior
  - SDR error detection/recovery
  - Target reset
  - electrical considerations
- The extracted text reinforced that for this project it makes sense to implement a **profiled subset** of I3C Basic required behavior and verify the closed-system contract end-to-end.

## Planning Document Created
- A project plan document was created:
  - `docs/I3C_Closed_System_IP_Plan.md`
- That plan recommends:
  - using `chipsalliance/i3c-core` as the Hub-side starting point
  - implementing lightweight target-side logic tailored to the project’s closed-system requirements
  - defining an explicit compatibility contract between Hub, Motor, and Touch devices
  - prioritizing verification of the closed profile over broad external compliance
- The plan also laid out phased work:
  - feasibility and gap analysis
  - Hub/endpoint RTL adaptation
  - verification closure
  - FPGA/system bring-up

## FPGA Fit Discussion
- The user asked whether a fully featured I3C controller would fit in:
  - Xilinx Spartan-7 `XC7S25-1CSGA225C`
- Conclusion:
  - A **prototype-grade I3C Basic controller** is likely to fit.
  - A **truly full-featured full-I3C implementation** with many optional features is much less certain and may be a poor fit if significant surrounding logic is also present.
- Practical fit guidance:
  - Likely fits:
    - SDR
    - DAA
    - CCC handling
    - IBI
    - reset/error recovery
    - moderate FIFOs/CSRs/wrapper logic
  - Risky on `XC7S25`:
    - HDR modes
    - secondary-controller support
    - multi-lane
    - large debug instrumentation
    - soft CPU + firmware stack
    - multiple endpoint emulators
    - heavy AXI/DMA infrastructure
- Final recommendation:
  - closed-system I3C Basic hub prototype on `XC7S25`: likely feasible
  - broad, near-complete I3C feature set: not safe to assume on this device without careful budgeting

## Key Files Created or Updated During the Thread
- `tools/i3c_worksheet.html`
- `tools/profiles/platform_a_i3c_worksheet.json`
- `README.md`
- `docs/I3C_Closed_System_IP_Plan.md`
