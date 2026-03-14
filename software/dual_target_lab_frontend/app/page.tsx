"use client";

import { useEffect, useState } from "react";

type SystemStatus = {
  boot_done: boolean;
  boot_error: boolean;
  capture_error: boolean;
  verified_bitmap: number;
  sample_valid_bitmap: number;
  target_led_state: number;
};

type TargetSummary = {
  target: number;
  dynamic_address: number;
  verified: boolean;
  led_state: number;
  signature: number;
  sample_payload: string;
  sample_bytes: number[];
};

const API = process.env.NEXT_PUBLIC_API_BASE ?? "http://localhost:8000";

function targetName(target: number) {
  return target === 0 ? "Target A" : "Target B";
}

export default function Page() {
  const [status, setStatus] = useState<SystemStatus | null>(null);
  const [targets, setTargets] = useState<Record<number, TargetSummary | null>>({
    0: null,
    1: null,
  });
  const [busy, setBusy] = useState(false);

  async function fetchJson(path: string, init?: RequestInit) {
    const response = await fetch(`${API}${path}`, {
      ...init,
      headers: {
        "Content-Type": "application/json",
        ...(init?.headers ?? {}),
      },
    });
    if (!response.ok) {
      throw new Error(await response.text());
    }
    return response.json();
  }

  async function refresh() {
    const [nextStatus, targetA, targetB] = await Promise.all([
      fetchJson("/api/status"),
      fetchJson("/api/targets/0"),
      fetchJson("/api/targets/1"),
    ]);
    setStatus(nextStatus);
    setTargets({ 0: targetA, 1: targetB });
  }

  async function startDemo() {
    setBusy(true);
    try {
      await fetchJson("/api/start", { method: "POST" });
      await refresh();
    } finally {
      setBusy(false);
    }
  }

  async function setLed(target: number, on: boolean) {
    setBusy(true);
    try {
      await fetchJson(`/api/targets/${target}/registers`, {
        method: "POST",
        body: JSON.stringify({ addr: 0x04, value: on ? 1 : 0 }),
      });
      await refresh();
    } finally {
      setBusy(false);
    }
  }

  useEffect(() => {
    refresh().catch(() => undefined);
    const id = window.setInterval(() => {
      refresh().catch(() => undefined);
    }, 1500);
    return () => window.clearInterval(id);
  }, []);

  return (
    <main style={{ maxWidth: 1100, margin: "0 auto", padding: 32 }}>
      <section style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 40, margin: 0 }}>Dual-Target I3C Lab Dashboard</h1>
        <p style={{ maxWidth: 780, lineHeight: 1.5, color: "#cbd2d9" }}>
          CMOD S7 controller talking to two internal I3C sensor targets. Each target exposes a
          deterministic sensor frame, a readable signature, and one writable LED-control register.
        </p>
        <div style={{ display: "flex", gap: 12 }}>
          <button onClick={startDemo} disabled={busy} style={buttonStyle("#d9e2ec", "#102a43")}>
            Start Demo
          </button>
          <button onClick={() => refresh()} disabled={busy} style={buttonStyle("#486581", "#f0f4f8")}>
            Refresh
          </button>
        </div>
      </section>

      <section style={panelStyle}>
        <h2 style={{ marginTop: 0 }}>System Status</h2>
        <pre style={preStyle}>{JSON.stringify(status, null, 2)}</pre>
      </section>

      <section
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fit, minmax(320px, 1fr))",
          gap: 18,
          marginTop: 24,
        }}
      >
        {[0, 1].map((target) => {
          const summary = targets[target];
          return (
            <article key={target} style={panelStyle}>
              <h2 style={{ marginTop: 0 }}>{targetName(target)}</h2>
              <div style={{ display: "flex", gap: 10, marginBottom: 12 }}>
                <button
                  onClick={() => setLed(target, true)}
                  disabled={busy}
                  style={buttonStyle("#f0b429", "#102a43")}
                >
                  LED On
                </button>
                <button
                  onClick={() => setLed(target, false)}
                  disabled={busy}
                  style={buttonStyle("#7b8794", "#f0f4f8")}
                >
                  LED Off
                </button>
              </div>
              <pre style={preStyle}>{JSON.stringify(summary, null, 2)}</pre>
            </article>
          );
        })}
      </section>
    </main>
  );
}

function buttonStyle(background: string, color: string) {
  return {
    background,
    color,
    border: "none",
    padding: "10px 16px",
    borderRadius: 999,
    cursor: "pointer",
    fontWeight: 700,
  } as const;
}

const panelStyle = {
  background: "rgba(16, 42, 67, 0.82)",
  border: "1px solid rgba(240, 244, 248, 0.12)",
  borderRadius: 18,
  padding: 20,
  boxShadow: "0 18px 40px rgba(0, 0, 0, 0.18)",
};

const preStyle = {
  margin: 0,
  background: "rgba(11, 31, 51, 0.9)",
  borderRadius: 12,
  padding: 14,
  overflowX: "auto" as const,
  fontSize: 13,
  lineHeight: 1.45,
};
