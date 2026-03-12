# UART Command Interface

The unified demo (`spartan7_i3c_unified_demo_top`) includes a UART command interface for controlling the I3C demo and reading sensor data from a host PC.

## Physical Interface

| Parameter | Value |
| --- | --- |
| Baud rate | 115200 |
| Data bits | 8 |
| Parity | None |
| Stop bits | 1 |
| FPGA TX pin | L12 (FT2232H Channel B) |
| FPGA RX pin | K15 (FT2232H Channel B) |
| USB bridge | FT2232H on CMOD S7 |

The CMOD S7's FT2232H provides the USB-UART bridge. The UART port typically appears as `/dev/ttyUSB1` on Linux or `COM3`+ on Windows (the second FTDI interface — the first is used for JTAG).

## Command Protocol

Commands are single ASCII bytes sent from host to FPGA. Each command produces a response terminated by `\r\n`.

| Command | Byte | Description | Response |
| --- | --- | --- | --- |
| Start | `S` (0x53) | Assert `soft_start` pulse, triggering I3C boot | `OK\r\n` (4 bytes) |
| Read | `R` (0x52) | Dump all 5 targets' sensor payloads | 50 data bytes + `\r\n` (52 bytes total) |
| Check status | `C` (0x43) | Read controller status flags | 1 status byte + `\r\n` (3 bytes total) |
| Unknown | any other | Error response | `ERR\r\n` (5 bytes) |

### Start Command (`S`)

Asserts the `soft_start` signal for one clock cycle. This releases the demo core from reset, allowing the I3C controller to begin the SETDASA boot sequence. The demo holds in reset until this command is received, so the host can set up monitoring before bus activity begins.

Response: `OK\r\n`

### Status Command (`C`)

Returns a single binary status byte followed by `\r\n`:

| Bit | Name | Meaning |
| --- | --- | --- |
| 0 | `boot_done` | I3C SETDASA addressing complete for all 5 targets |
| 1 | `boot_error` | Fatal error during boot (e.g., target NACK) |
| 2 | `capture_error` | Error during payload capture |
| 3–7 | Reserved | Always 0 |

Example status values:
- `0x01` — boot complete, no errors
- `0x02` — boot error (targets not responding)
- `0x05` — boot complete but capture error occurred

### Read Command (`R`)

Returns 50 raw bytes (5 targets x 10 bytes each) followed by `\r\n`.

#### Payload Layout

Each target contributes 10 bytes in order (Target 0 first, Target 4 last):

| Byte Offset | Size | Format | Content |
| --- | --- | --- | --- |
| 0–1 | 2 | uint16 LE | Sensor sample 0 |
| 2–3 | 2 | uint16 LE | Sensor sample 1 |
| 4–5 | 2 | uint16 LE | Sensor sample 2 |
| 6–7 | 2 | uint16 LE | Sensor sample 3 |
| 8 | 1 | uint8 | Temperature |
| 9 | 1 | uint8 | Status/misc |

The full 50-byte payload maps as:

| Byte Range | Target |
| --- | --- |
| 0–9 | Target 0 (static addr 0x30, dynamic addr 0x10) |
| 10–19 | Target 1 (static addr 0x31, dynamic addr 0x11) |
| 20–29 | Target 2 (static addr 0x32, dynamic addr 0x12) |
| 30–39 | Target 3 (static addr 0x33, dynamic addr 0x13) |
| 40–49 | Target 4 (static addr 0x34, dynamic addr 0x14) |

#### Interpreting Sensor Samples

In the demo, `i3c_sensor_frame_gen` generates deterministic synthetic samples that encode the target identity and frame progression:

- Sample values increment with each frame, offset by target index
- The temperature byte encodes a fixed offset per target
- The status byte includes frame-sequence information

For real sensor integration, replace `i3c_sensor_frame_gen` with actual ADC/sensor interface logic; the 10-byte payload format remains the same.

## Python Host Tool

`tools/uart_interface.py` provides a command-line interface for all UART operations.

### Requirements

```bash
pip install pyserial
```

### Usage

```
usage: uart_interface.py [-h] [--port PORT] {start,status,read,monitor} ...

CMOD S7 I3C sensor demo UART interface

positional arguments:
  {start,status,read,monitor}
    start               Send start command
    status              Read status
    read                Read sensor payloads
    monitor             Continuous monitoring

optional arguments:
  -h, --help            show this help message and exit
  --port PORT           Serial port (auto-detect FTDI if omitted)
```

### Port Auto-Detection

The tool auto-detects the CMOD S7 by scanning for USB serial ports with the FTDI vendor ID (`0x0403`). If multiple FTDI devices are connected, use `--port` to specify:

```bash
python tools/uart_interface.py --port /dev/ttyUSB1 status
```

### Subcommand Examples

#### `start` — Trigger I3C Boot

```bash
$ python tools/uart_interface.py start
OK
```

This must be sent once after FPGA programming to start the I3C bus. The demo holds in reset until the start command is received.

#### `status` — Check Controller State

```bash
$ python tools/uart_interface.py status
boot_done=True  boot_error=False  capture_error=False  (raw=0x01)
```

#### `read` — Read Sensor Payloads

```bash
$ python tools/uart_interface.py read
Target   Hex                              Sample0  Sample1  Sample2  Sample3    Temp Status
------------------------------------------------------------------------------------------------
0        01 00 02 00 03 00 04 00 19 00          1        2        3        4      25      0
1        11 00 12 00 13 00 14 00 1A 01         17       18       19       20      26      1
2        21 00 22 00 23 00 24 00 1B 02         33       34       35       36      27      2
3        31 00 32 00 33 00 34 00 1C 03         49       50       51       52      28      3
4        41 00 42 00 43 00 44 00 1D 04         65       66       67       68      29      4
```

The table shows:
- Raw hex bytes for each target's 10-byte payload
- Decoded 16-bit little-endian sensor samples
- Temperature and status bytes

#### `monitor` — Continuous Monitoring

```bash
$ python tools/uart_interface.py monitor
Monitoring (Ctrl+C to stop)...
boot_done=True  boot_error=False  capture_error=False  (raw=0x01)
Target   Hex                              Sample0  Sample1  ...
...
boot_done=True  boot_error=False  capture_error=False  (raw=0x01)
...
^C
Stopped.
```

Monitor mode prints status every 2 seconds and a full payload dump every 5 seconds. Press Ctrl+C to stop.

### Typical Session

```bash
# 1. Program FPGA (if not already done)
vivado -mode batch -source scripts/program_cmod_s7.tcl

# 2. Start the I3C demo
python tools/uart_interface.py start

# 3. Verify boot completed
python tools/uart_interface.py status

# 4. Read payloads
python tools/uart_interface.py read

# 5. Or just monitor continuously
python tools/uart_interface.py monitor
```

## RTL Architecture

### Module Hierarchy

```
spartan7_i3c_unified_demo_top
 +-- uart_rx               — 8N1 UART receiver (double-flop synchronized)
 +-- uart_tx               — 8N1 UART transmitter
 +-- uart_cmd_handler      — Command decode + response state machine
 +-- i3c_sensor_controller_demo  — I3C controller (gated by soft_start)
 +-- i3c_sensor_target_demo x5   — I3C targets (internal bus)
```

### uart_cmd_handler State Machine

```
         rx_valid
IDLE ─────────────> SEND ──> WAIT ──> SEND ──> ... ──> IDLE
 │                   │                                    ^
 │  decode command   │  load byte into tx_data            │
 │  fill resp[]      │  wait for tx_ready to drop         │
 │  set buf_len      │  advance buf_idx                   │
 │                   │  loop until buf_idx == buf_len-1    │
 └───────────────────┴────────────────────────────────────┘
```

The handler maintains a 52-byte response buffer. On receiving a command, it fills the buffer with the appropriate response and sends bytes one at a time through the UART TX.

### Extending the Interface

To add a new command:

1. Add a new case in `uart_cmd_handler.v` under the `rx_valid` decode (the `ST_IDLE` state)
2. Fill `resp[0]` through `resp[N-1]` with your response bytes
3. Set `buf_len` to the total response length (including `\r\n` terminator)
4. Wire any new control/status signals through the module ports
5. Update the unified demo top to connect the new signals
6. Add a corresponding subcommand in `tools/uart_interface.py`

The maximum response length is 52 bytes (set by `BUF_LEN`). Increase this parameter if your new command needs a longer response.
