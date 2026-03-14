#!/usr/bin/env python3
"""
UART client for the CMOD S7 dual-target I3C lab demo.

Protocol:
    request  = [0xA5, cmd, target, arg0, arg1]
    response = [0x5A, status, len, payload...]
"""

from __future__ import annotations

import argparse
import dataclasses
import json
import sys
import time
from typing import Any

import serial
import serial.tools.list_ports

BAUD = 115200
TIMEOUT = 2.0
FTDI_VID = 0x0403

REQ_SYNC = 0xA5
RSP_SYNC = 0x5A

CMD_START = 0x01
CMD_STATUS = 0x02
CMD_SUMMARY = 0x10
CMD_READ_REG = 0x11
CMD_WRITE_REG = 0x12


@dataclasses.dataclass
class Response:
    status: int
    payload: bytes


class ProtocolError(RuntimeError):
    pass


def find_cmod_port() -> str | None:
    for port in serial.tools.list_ports.comports():
        if port.vid == FTDI_VID:
            return port.device
    return None


class DualTargetLabClient:
    def __init__(self, port: str | None = None, baud: int = BAUD, timeout: float = TIMEOUT) -> None:
        self.port_name = port or find_cmod_port()
        if self.port_name is None:
            raise RuntimeError("No FTDI UART device found. Use --port to specify the CMOD S7 serial port.")
        self.serial = serial.Serial(self.port_name, baud, timeout=timeout)

    def close(self) -> None:
        self.serial.close()

    def __enter__(self) -> "DualTargetLabClient":
        return self

    def __exit__(self, exc_type, exc, tb) -> None:
        self.close()

    def _exchange(self, cmd: int, target: int = 0, arg0: int = 0, arg1: int = 0) -> Response:
        frame = bytes([REQ_SYNC, cmd & 0xFF, target & 0xFF, arg0 & 0xFF, arg1 & 0xFF])
        self.serial.reset_input_buffer()
        self.serial.write(frame)
        header = self.serial.read(3)
        if len(header) != 3:
            raise ProtocolError(f"Incomplete response header ({len(header)} bytes)")
        if header[0] != RSP_SYNC:
            raise ProtocolError(f"Bad response sync 0x{header[0]:02X}")
        payload_len = header[2]
        payload = self.serial.read(payload_len)
        if len(payload) != payload_len:
            raise ProtocolError(f"Incomplete response payload ({len(payload)} of {payload_len} bytes)")
        return Response(status=header[1], payload=payload)

    def start(self) -> None:
        resp = self._exchange(CMD_START)
        self._require_ok(resp)

    def status(self) -> dict[str, Any]:
        resp = self._exchange(CMD_STATUS)
        self._require_ok(resp)
        if len(resp.payload) != 4:
            raise ProtocolError(f"Unexpected status payload length {len(resp.payload)}")
        flags, verified, sample_valid, led_state = resp.payload
        return {
            "boot_done": bool(flags & 0x01),
            "boot_error": bool(flags & 0x02),
            "capture_error": bool(flags & 0x04),
            "verified_bitmap": verified & 0x03,
            "sample_valid_bitmap": sample_valid & 0x03,
            "target_led_state": led_state & 0x03,
            "raw_flags": flags,
        }

    def summary(self, target: int) -> dict[str, Any]:
        resp = self._exchange(CMD_SUMMARY, target=target)
        self._require_ok(resp)
        if len(resp.payload) != 18:
            raise ProtocolError(f"Unexpected summary payload length {len(resp.payload)}")
        payload = resp.payload
        return {
            "target": payload[0],
            "dynamic_address": payload[1],
            "verified": bool(payload[2]),
            "led_state": payload[3] & 0x01,
            "signature": int.from_bytes(payload[4:8], "little"),
            "sample_payload": payload[8:18].hex(),
            "sample_bytes": list(payload[8:18]),
        }

    def read_reg(self, target: int, addr: int, length: int) -> bytes:
        resp = self._exchange(CMD_READ_REG, target=target, arg0=addr, arg1=length)
        self._require_ok(resp)
        return resp.payload

    def write_reg(self, target: int, addr: int, value: int) -> int:
        resp = self._exchange(CMD_WRITE_REG, target=target, arg0=addr, arg1=value)
        self._require_ok(resp)
        if not resp.payload:
            return value & 0xFF
        return resp.payload[0]

    @staticmethod
    def _require_ok(resp: Response) -> None:
        if resp.status != 0:
            raise ProtocolError(f"FPGA returned status 0x{resp.status:02X}")


def cmd_start(args: argparse.Namespace) -> None:
    with DualTargetLabClient(args.port) as client:
        client.start()
        print("started")


def cmd_status(args: argparse.Namespace) -> None:
    with DualTargetLabClient(args.port) as client:
        print(json.dumps(client.status(), indent=2))


def cmd_summary(args: argparse.Namespace) -> None:
    with DualTargetLabClient(args.port) as client:
        print(json.dumps(client.summary(args.target), indent=2))


def cmd_read(args: argparse.Namespace) -> None:
    with DualTargetLabClient(args.port) as client:
        data = client.read_reg(args.target, args.addr, args.length)
        print(json.dumps({
            "target": args.target,
            "addr": args.addr,
            "length": args.length,
            "hex": data.hex(),
            "bytes": list(data),
        }, indent=2))


def cmd_write(args: argparse.Namespace) -> None:
    with DualTargetLabClient(args.port) as client:
        echoed = client.write_reg(args.target, args.addr, args.value)
        print(json.dumps({
            "target": args.target,
            "addr": args.addr,
            "value": args.value,
            "echoed": echoed,
        }, indent=2))


def cmd_monitor(args: argparse.Namespace) -> None:
    with DualTargetLabClient(args.port) as client:
        print("Monitoring dual-target lab demo (Ctrl+C to stop)...")
        try:
            while True:
                print(json.dumps({
                    "status": client.status(),
                    "target_a": client.summary(0),
                    "target_b": client.summary(1),
                }, indent=2))
                time.sleep(args.interval)
        except KeyboardInterrupt:
            print("stopped")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="CMOD S7 dual-target I3C lab UART client")
    parser.add_argument("--port", default=None, help="Serial port (auto-detect FTDI if omitted)")
    sub = parser.add_subparsers(dest="command", required=True)

    p_start = sub.add_parser("start", help="Start the controller demo")
    p_start.set_defaults(func=cmd_start)

    p_status = sub.add_parser("status", help="Read system status")
    p_status.set_defaults(func=cmd_status)

    p_summary = sub.add_parser("summary", help="Read target summary")
    p_summary.add_argument("target", type=int, choices=[0, 1])
    p_summary.set_defaults(func=cmd_summary)

    p_read = sub.add_parser("read", help="Read target register window")
    p_read.add_argument("target", type=int, choices=[0, 1])
    p_read.add_argument("addr", type=lambda x: int(x, 0))
    p_read.add_argument("length", type=lambda x: int(x, 0))
    p_read.set_defaults(func=cmd_read)

    p_write = sub.add_parser("write", help="Write one target register byte")
    p_write.add_argument("target", type=int, choices=[0, 1])
    p_write.add_argument("addr", type=lambda x: int(x, 0))
    p_write.add_argument("value", type=lambda x: int(x, 0))
    p_write.set_defaults(func=cmd_write)

    p_monitor = sub.add_parser("monitor", help="Monitor status and both targets")
    p_monitor.add_argument("--interval", type=float, default=1.0)
    p_monitor.set_defaults(func=cmd_monitor)

    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
