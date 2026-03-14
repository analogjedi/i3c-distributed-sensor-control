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


class CccExecuteRequest(BaseModel):
    command_id: str
    target: int | None = Field(default=None, ge=0, le=1)
    arg: int | None = Field(default=None, ge=0, le=255)


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


CCC_COMMANDS: list[dict[str, Any]] = [
    {
        "id": "getpid",
        "label": "GETPID",
        "mode": "direct",
        "code": 0x8D,
        "target_required": True,
        "arg_required": False,
        "arg_default": 0,
        "description": "Read the target provisional ID.",
    },
    {
        "id": "getbcr",
        "label": "GETBCR",
        "mode": "direct",
        "code": 0x8E,
        "target_required": True,
        "arg_required": False,
        "arg_default": 0,
        "description": "Read the target bus characteristics register.",
    },
    {
        "id": "getdcr",
        "label": "GETDCR",
        "mode": "direct",
        "code": 0x8F,
        "target_required": True,
        "arg_required": False,
        "arg_default": 0,
        "description": "Read the target device characteristics register.",
    },
    {
        "id": "getstatus",
        "label": "GETSTATUS",
        "mode": "direct",
        "code": 0x90,
        "target_required": True,
        "arg_required": False,
        "arg_default": 0,
        "description": "Read the target CCC status word.",
    },
    {
        "id": "getmrl",
        "label": "GETMRL",
        "mode": "direct",
        "code": 0x8C,
        "target_required": True,
        "arg_required": False,
        "arg_default": 0,
        "description": "Read the target maximum read length.",
    },
    {
        "id": "getmwl",
        "label": "GETMWL",
        "mode": "direct",
        "code": 0x8B,
        "target_required": True,
        "arg_required": False,
        "arg_default": 0,
        "description": "Read the target maximum write length.",
    },
    {
        "id": "getmxds",
        "label": "GETMXDS",
        "mode": "direct",
        "code": 0x94,
        "target_required": True,
        "arg_required": False,
        "arg_default": 0,
        "description": "Read target maximum data speed information.",
    },
    {
        "id": "getcaps",
        "label": "GETCAPS",
        "mode": "direct",
        "code": 0x95,
        "target_required": True,
        "arg_required": False,
        "arg_default": 0,
        "description": "Read target capability bits.",
    },
]

CCC_BY_ID = {item["id"]: item for item in CCC_COMMANDS}


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


def decode_ccc_result(command: dict[str, Any], raw_bytes: list[int]) -> dict[str, Any]:
    code = command["code"]
    if code == 0x8D and len(raw_bytes) == 6:
        pid = int.from_bytes(bytes(raw_bytes), "little")
        return {"pid_hex": f"0x{pid:012X}"}
    if code in (0x8E, 0x8F) and len(raw_bytes) == 1:
        key = "bcr_hex" if code == 0x8E else "dcr_hex"
        return {key: f"0x{raw_bytes[0]:02X}"}
    if code == 0x90 and len(raw_bytes) == 2:
        status_word = raw_bytes[0] | (raw_bytes[1] << 8)
        return {"status_word_hex": f"0x{status_word:04X}"}
    if code == 0x8B and len(raw_bytes) == 2:
        value = raw_bytes[0] | (raw_bytes[1] << 8)
        return {"max_write_len": value}
    if code == 0x8C and len(raw_bytes) == 3:
        value = raw_bytes[0] | (raw_bytes[1] << 8)
        ibi_len = raw_bytes[2]
        return {"max_read_len": value, "ibi_data_len": ibi_len}
    if code == 0x94 and len(raw_bytes) == 2:
        value = raw_bytes[0] | (raw_bytes[1] << 8)
        return {"mxds_hex": f"0x{value:04X}"}
    if code == 0x95 and len(raw_bytes) == 4:
        value = int.from_bytes(bytes(raw_bytes), "little")
        return {"caps_hex": f"0x{value:08X}"}
    return {}


@app.get("/api/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/api/config")
def config() -> dict[str, Any]:
    return {"serial_port_env": os.environ.get("DUAL_TARGET_LAB_PORT")}


@app.get("/api/ccc/catalog")
def ccc_catalog() -> dict[str, Any]:
    return {"commands": CCC_COMMANDS}


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


@app.post("/api/ccc/execute")
def execute_ccc(body: CccExecuteRequest) -> dict[str, Any]:
    command = CCC_BY_ID.get(body.command_id)
    if command is None:
        raise HTTPException(status_code=400, detail="unknown CCC command")
    if command["target_required"] and body.target not in (0, 1):
        raise HTTPException(status_code=400, detail="target must be 0 or 1 for this CCC")
    if not command["target_required"] and body.target is not None:
        raise HTTPException(status_code=400, detail="broadcast CCC does not take a target")

    arg_value = command["arg_default"] if body.arg is None else body.arg

    try:
        with locked_client() as client:
            if command["mode"] == "direct":
                raw = client.direct_ccc(body.target or 0, command["code"], arg_value)
                post_target = enrich_target_summary(client, body.target or 0)
                post_status = client.status()
            else:
                raw = client.broadcast_ccc(command["code"], arg_value)
                post_target = None
                post_status = client.status()
        return {
            "command": command,
            "target": body.target,
            "arg": arg_value,
            "arg_hex": f"0x{arg_value:02X}",
            "response_len": raw["length"],
            "response_hex": raw["hex"],
            "response_bytes": raw["bytes"],
            "decoded": decode_ccc_result(command, raw["bytes"]),
            "post_status": {
                **post_status,
                "verified_targets": [bool(post_status["verified_bitmap"] & 0x01), bool(post_status["verified_bitmap"] & 0x02)],
                "sample_valid_targets": [
                    bool(post_status["sample_valid_bitmap"] & 0x01),
                    bool(post_status["sample_valid_bitmap"] & 0x02),
                ],
                "target_led_targets": [
                    bool(post_status["target_led_state"] & 0x01),
                    bool(post_status["target_led_state"] & 0x02),
                ],
            },
            "post_target": post_target,
        }
    except ProtocolError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
