from __future__ import annotations

import os
import sys
import threading
from pathlib import Path
from typing import Any

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.dual_target_lab_client import DualTargetLabClient, ProtocolError  # noqa: E402


class RegisterWriteRequest(BaseModel):
    addr: int = Field(ge=0, le=255)
    value: int = Field(ge=0, le=255)


_serial_lock = threading.Lock()

app = FastAPI(title="Dual Target I3C Lab Backend", version="0.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def open_client() -> DualTargetLabClient:
    port = os.environ.get("DUAL_TARGET_LAB_PORT")
    return DualTargetLabClient(port=port)


from contextlib import contextmanager

@contextmanager
def locked_client():
    with _serial_lock:
        with open_client() as client:
            yield client


def parse_sample_payload(sample_bytes: list[int]) -> dict[str, Any]:
    if len(sample_bytes) < 10:
        return {
            "channels": [],
            "temperature": None,
            "misc": None,
        }
    return {
        "channels": [
            sample_bytes[0] | (sample_bytes[1] << 8),
            sample_bytes[2] | (sample_bytes[3] << 8),
            sample_bytes[4] | (sample_bytes[5] << 8),
            sample_bytes[6] | (sample_bytes[7] << 8),
        ],
        "temperature": sample_bytes[8],
        "misc": sample_bytes[9],
    }


def enrich_target_summary(
    client: DualTargetLabClient, target: int, include_registers: bool = True
) -> dict[str, Any]:
    summary = client.summary(target)
    parsed_payload = parse_sample_payload(summary["sample_bytes"])
    result: dict[str, Any] = {
        **summary,
        "name": "Target A" if target == 0 else "Target B",
        "signature_hex": f"0x{summary['signature']:08X}",
        "dynamic_address_hex": f"0x{summary['dynamic_address']:02X}",
        "parsed_payload": parsed_payload,
    }

    if not include_registers:
        return result

    try:
        meta = client.read_reg(target, 0x04, 12)
        if len(meta) < 12:
            raise ProtocolError(f"Short register read: {len(meta)} bytes")
    except (ProtocolError, IndexError):
        result["registers"] = None
        return result

    result["registers"] = {
        "control_reg": meta[0],
        "target_index": meta[1],
        "frame_counter": meta[2] | (meta[3] << 8),
        "local_status": meta[4],
        "last_ccc": meta[5],
        "event_mask": meta[6],
        "rstact_action": meta[7],
        "ccc_status_word": meta[8] | (meta[9] << 8),
        "activity_group_word": meta[10] | (meta[11] << 8),
        "last_ccc_hex": f"0x{meta[5]:02X}",
        "event_mask_hex": f"0x{meta[6]:02X}",
        "rstact_action_hex": f"0x{meta[7]:02X}",
        "ccc_status_word_hex": f"0x{(meta[8] | (meta[9] << 8)):04X}",
        "activity_group_word_hex": f"0x{(meta[10] | (meta[11] << 8)):04X}",
    }
    return result


@app.get("/api/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/api/config")
def config() -> dict[str, Any]:
    return {"serial_port_env": os.environ.get("DUAL_TARGET_LAB_PORT")}


@app.post("/api/start")
def start_demo() -> dict[str, str]:
    try:
        with locked_client() as client:
            client.start()
        return {"status": "started"}
    except ProtocolError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@app.get("/api/status")
def get_status() -> dict[str, Any]:
    try:
        with locked_client() as client:
            status = client.status()
            return {
                **status,
                "verified_targets": [bool(status["verified_bitmap"] & 0x01), bool(status["verified_bitmap"] & 0x02)],
                "sample_valid_targets": [
                    bool(status["sample_valid_bitmap"] & 0x01),
                    bool(status["sample_valid_bitmap"] & 0x02),
                ],
                "target_led_targets": [
                    bool(status["target_led_state"] & 0x01),
                    bool(status["target_led_state"] & 0x02),
                ],
            }
    except ProtocolError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@app.get("/api/dashboard")
def get_dashboard() -> dict[str, Any]:
    try:
        with locked_client() as client:
            status = client.status()
            enriched_status = {
                **status,
                "verified_targets": [bool(status["verified_bitmap"] & 0x01), bool(status["verified_bitmap"] & 0x02)],
                "sample_valid_targets": [
                    bool(status["sample_valid_bitmap"] & 0x01),
                    bool(status["sample_valid_bitmap"] & 0x02),
                ],
                "target_led_targets": [
                    bool(status["target_led_state"] & 0x01),
                    bool(status["target_led_state"] & 0x02),
                ],
            }
            include_registers = bool(status["boot_done"])
            return {
                "status": enriched_status,
                "targets": [
                    enrich_target_summary(client, 0, include_registers=include_registers),
                    enrich_target_summary(client, 1, include_registers=include_registers),
                ],
            }
    except ProtocolError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@app.get("/api/targets/{target}")
def get_target_summary(target: int) -> dict[str, Any]:
    if target not in (0, 1):
        raise HTTPException(status_code=400, detail="target must be 0 or 1")
    try:
        with locked_client() as client:
            return enrich_target_summary(client, target)
    except ProtocolError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@app.get("/api/targets/{target}/registers")
def read_target_registers(target: int, addr: int, length: int) -> dict[str, Any]:
    if target not in (0, 1):
        raise HTTPException(status_code=400, detail="target must be 0 or 1")
    if not (0 <= addr <= 255 and 1 <= length <= 16):
        raise HTTPException(status_code=400, detail="addr must be 0..255 and length must be 1..16")
    try:
        with locked_client() as client:
            data = client.read_reg(target, addr, length)
        return {
            "target": target,
            "addr": addr,
            "length": length,
            "hex": data.hex(),
            "bytes": list(data),
        }
    except ProtocolError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@app.post("/api/targets/{target}/registers")
def write_target_register(target: int, body: RegisterWriteRequest) -> dict[str, Any]:
    if target not in (0, 1):
        raise HTTPException(status_code=400, detail="target must be 0 or 1")
    try:
        with locked_client() as client:
            echoed = client.write_reg(target, body.addr, body.value)
        return {
            "target": target,
            "addr": body.addr,
            "value": body.value,
            "echoed": echoed,
        }
    except ProtocolError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
