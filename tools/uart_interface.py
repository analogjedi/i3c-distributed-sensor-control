#!/usr/bin/env python3
"""
UART command interface for I3C sensor controller demo on CMOD S7.

Subcommands:
    start   — Send 'S', trigger I3C boot sequence
    status  — Send 'C', decode status bits
    read    — Send 'R', display 50 payload bytes as table
    monitor — Loop status + read until Ctrl+C
"""

import argparse
import struct
import sys
import time

import serial
import serial.tools.list_ports

BAUD = 115200
TIMEOUT = 2.0
FTDI_VID = 0x0403

NUM_TARGETS = 5
PAYLOAD_BYTES = 10


def find_cmod_port():
    """Auto-detect CMOD S7 by FTDI VID."""
    for p in serial.tools.list_ports.comports():
        if p.vid == FTDI_VID:
            return p.device
    return None


def open_port(port_arg):
    """Open serial port, auto-detecting if not specified."""
    port = port_arg or find_cmod_port()
    if port is None:
        print("ERROR: No FTDI device found. Use --port to specify.", file=sys.stderr)
        sys.exit(1)
    return serial.Serial(port, BAUD, timeout=TIMEOUT)


def cmd_start(ser):
    """Send 'S' command, print response."""
    ser.reset_input_buffer()
    ser.write(b"S")
    resp = ser.read_until(b"\r\n")
    print(resp.decode(errors="replace").strip())


def cmd_status(ser):
    """Send 'C' command, decode and print status bits."""
    ser.reset_input_buffer()
    ser.write(b"C")
    resp = ser.read(3)  # status_byte + \r + \n
    if len(resp) < 1:
        print("ERROR: No response", file=sys.stderr)
        return
    status = resp[0]
    boot_done = bool(status & 0x01)
    boot_error = bool(status & 0x02)
    capture_error = bool(status & 0x04)
    print(f"boot_done={boot_done}  boot_error={boot_error}  capture_error={capture_error}  (raw=0x{status:02X})")


def cmd_read(ser):
    """Send 'R' command, receive 50 bytes, print formatted table."""
    ser.reset_input_buffer()
    ser.write(b"R")
    data = ser.read(52)  # 50 payload bytes + \r\n
    if len(data) < 50:
        print(f"ERROR: Expected 50 bytes, got {len(data)}", file=sys.stderr)
        return

    payload = data[:50]
    print(f"{'Target':<8} {'Hex':<32} {'Sample0':>8} {'Sample1':>8} {'Sample2':>8} {'Sample3':>8} {'Temp':>6} {'Status':>6}")
    print("-" * 96)

    for t in range(NUM_TARGETS):
        chunk = payload[t * PAYLOAD_BYTES : (t + 1) * PAYLOAD_BYTES]
        hex_str = " ".join(f"{b:02X}" for b in chunk)

        # Interpret first 8 bytes as four 16-bit little-endian samples
        samples = struct.unpack_from("<HHHH", chunk, 0)
        # Byte 8 = temperature, Byte 9 = status
        temp = chunk[8]
        status = chunk[9]

        print(f"{t:<8} {hex_str:<32} {samples[0]:>8} {samples[1]:>8} {samples[2]:>8} {samples[3]:>8} {temp:>6} {status:>6}")


def cmd_monitor(ser):
    """Loop: status every 2s, read every 5s, until Ctrl+C."""
    print("Monitoring (Ctrl+C to stop)...")
    last_read = 0
    try:
        while True:
            cmd_status(ser)
            now = time.time()
            if now - last_read >= 5.0:
                cmd_read(ser)
                last_read = now
            time.sleep(2.0)
    except KeyboardInterrupt:
        print("\nStopped.")


def main():
    parser = argparse.ArgumentParser(description="CMOD S7 I3C sensor demo UART interface")
    parser.add_argument("--port", default=None, help="Serial port (auto-detect FTDI if omitted)")
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("start", help="Send start command")
    sub.add_parser("status", help="Read status")
    sub.add_parser("read", help="Read sensor payloads")
    sub.add_parser("monitor", help="Continuous monitoring")

    args = parser.parse_args()
    ser = open_port(args.port)

    try:
        {"start": cmd_start, "status": cmd_status, "read": cmd_read, "monitor": cmd_monitor}[args.command](ser)
    finally:
        ser.close()


if __name__ == "__main__":
    main()
