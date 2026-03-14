from __future__ import annotations

import os
import sys
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


class BackendConfig(BaseModel):
    serial_port: str | None = None


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


@app.get("/api/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/api/config")
def config() -> dict[str, Any]:
    return {"serial_port_env": os.environ.get("DUAL_TARGET_LAB_PORT")}


@app.post("/api/start")
def start_demo() -> dict[str, str]:
    try:
        with open_client() as client:
            client.start()
        return {"status": "started"}
    except ProtocolError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@app.get("/api/status")
def get_status() -> dict[str, Any]:
    try:
        with open_client() as client:
            return client.status()
    except ProtocolError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@app.get("/api/targets/{target}")
def get_target_summary(target: int) -> dict[str, Any]:
    if target not in (0, 1):
        raise HTTPException(status_code=400, detail="target must be 0 or 1")
    try:
        with open_client() as client:
            return client.summary(target)
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
        with open_client() as client:
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
        with open_client() as client:
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
