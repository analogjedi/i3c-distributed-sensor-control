"use client";

import { useEffect, useState } from "react";

type SystemStatus = {
  boot_done: boolean;
  boot_error: boolean;
  capture_error: boolean;
  recovery_active: boolean;
  verified_bitmap: number;
  sample_valid_bitmap: number;
  target_led_state: number;
  verified_targets: boolean[];
  sample_valid_targets: boolean[];
  target_led_targets: boolean[];
};

type ParsedPayload = {
  channels: number[];
  temperature: number | null;
  misc: number | null;
};

type TargetRegisters = {
  control_reg: number;
  target_index: number;
  frame_counter: number;
  local_status: number;
  last_ccc: number;
  event_mask: number;
  rstact_action: number;
  ccc_status_word: number;
  activity_group_word: number;
  last_ccc_hex: string;
  event_mask_hex: string;
  rstact_action_hex: string;
  ccc_status_word_hex: string;
  activity_group_word_hex: string;
};

type TargetSummary = {
  target: number;
  name: string;
  dynamic_address: number;
  dynamic_address_hex: string;
  verified: boolean;
  led_state: number;
  signature: number;
  signature_hex: string;
  sample_payload: string;
  sample_bytes: number[];
  parsed_payload: ParsedPayload;
  registers: TargetRegisters | null;
};

type DashboardData = {
  status: SystemStatus;
  targets: TargetSummary[];
};

type RegisterToolState = {
  readAddr: string;
  readLength: string;
  writeAddr: string;
  writeValue: string;
  readResult: string;
  writeResult: string;
};

const API = process.env.NEXT_PUBLIC_API_BASE ?? "http://localhost:8000";
const TARGET_NAMES = ["Target A", "Target B"];

function initialToolState(): RegisterToolState {
  return {
    readAddr: "0x10",
    readLength: "10",
    writeAddr: "0x04",
    writeValue: "0x01",
    readResult: "",
    writeResult: "",
  };
}

export default function Page() {
  const [dashboard, setDashboard] = useState<DashboardData | null>(null);
  const [toolState, setToolState] = useState<Record<number, RegisterToolState>>({
    0: initialToolState(),
    1: initialToolState(),
  });
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [lastUpdated, setLastUpdated] = useState<string | null>(null);

  async function fetchJson(path: string, init?: RequestInit) {
    const response = await fetch(`${API}${path}`, {
      ...init,
      headers: {
        "Content-Type": "application/json",
        ...(init?.headers ?? {}),
      },
    });

    if (!response.ok) {
      let detail = response.statusText;
      try {
        const body = await response.json();
        detail = body.detail ?? JSON.stringify(body);
      } catch {
        detail = await response.text();
      }
      throw new Error(detail || `Request failed: ${response.status}`);
    }
    return response.json();
  }

  async function refresh() {
    const next = await fetchJson("/api/dashboard");
    setDashboard(next);
    setLastUpdated(new Date().toLocaleTimeString());
    setError(null);
  }

  async function runAction(action: () => Promise<void>) {
    setBusy(true);
    try {
      await action();
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : String(nextError));
    } finally {
      setBusy(false);
    }
  }

  async function startDemo() {
    await runAction(async () => {
      await fetchJson("/api/start", { method: "POST" });
      await refresh();
    });
  }

  async function setLed(target: number, on: boolean) {
    await runAction(async () => {
      await fetchJson(`/api/targets/${target}/registers`, {
        method: "POST",
        body: JSON.stringify({ addr: 0x04, value: on ? 1 : 0 }),
      });
      await refresh();
    });
  }

  async function readRegisters(target: number) {
    const state = toolState[target];
    await runAction(async () => {
      const addr = Number(state.readAddr);
      const length = Number(state.readLength);
      const result = await fetchJson(
        `/api/targets/${target}/registers?addr=${addr}&length=${length}`,
      );
      setToolState((prev) => ({
        ...prev,
        [target]: {
          ...prev[target],
          readResult: `${result.hex}  [${result.bytes.join(", ")}]`,
        },
      }));
    });
  }

  async function writeRegister(target: number) {
    const state = toolState[target];
    await runAction(async () => {
      const addr = Number(state.writeAddr);
      const value = Number(state.writeValue);
      const result = await fetchJson(`/api/targets/${target}/registers`, {
        method: "POST",
        body: JSON.stringify({ addr, value }),
      });
      setToolState((prev) => ({
        ...prev,
        [target]: {
          ...prev[target],
          writeResult: `echoed 0x${Number(result.echoed).toString(16).padStart(2, "0").toUpperCase()}`,
        },
      }));
      await refresh();
    });
  }

  function updateTool(target: number, patch: Partial<RegisterToolState>) {
    setToolState((prev) => ({
      ...prev,
      [target]: { ...prev[target], ...patch },
    }));
  }

  useEffect(() => {
    refresh().catch((nextError) => {
      setError(nextError instanceof Error ? nextError.message : String(nextError));
    });
    const id = window.setInterval(() => {
      refresh().catch(() => undefined);
    }, 1500);
    return () => window.clearInterval(id);
  }, []);

  return (
    <main style={pageStyle}>
      <section style={heroStyle}>
        <div>
          <p style={eyebrowStyle}>CMOD S7 / I3C / Dual Target Lab</p>
          <h1 style={titleStyle}>Controller Dashboard</h1>
          <p style={ledeStyle}>
            FastAPI is the bridge to the FPGA UART. This page is the operator surface: boot the
            demo, inspect both targets, read payload windows, and toggle each target output LED
            through the real controller-to-target path.
          </p>
        </div>
        <div style={heroActionsStyle}>
          <button
            onClick={startDemo}
            disabled={busy}
            style={buttonStyle("#f0b429", "#102a43")}
          >
            Start Demo
          </button>
          <button
            onClick={() => runAction(refresh)}
            disabled={busy}
            style={buttonStyle("#486581", "#f0f4f8")}
          >
            Refresh Now
          </button>
        </div>
      </section>

      <section style={statusBarStyle}>
        <StatusChip label="Backend" value={error ? "Degraded" : "Connected"} tone={error ? "bad" : "good"} />
        <StatusChip
          label="Boot"
          value={dashboard?.status.boot_done ? "Complete" : "Waiting"}
          tone={dashboard?.status.boot_done ? "good" : "neutral"}
        />
        <StatusChip
          label="Recovery"
          value={dashboard?.status.recovery_active ? "Active" : "Idle"}
          tone={dashboard?.status.recovery_active ? "warn" : "neutral"}
        />
        <StatusChip
          label="Errors"
          value={
            dashboard?.status.boot_error || dashboard?.status.capture_error ? "Present" : "Clear"
          }
          tone={
            dashboard?.status.boot_error || dashboard?.status.capture_error ? "bad" : "good"
          }
        />
        <div style={subtleMetaStyle}>
          <span>API: {API}</span>
          <span>{lastUpdated ? `Last update ${lastUpdated}` : "Waiting for first poll"}</span>
        </div>
      </section>

      {error ? <section style={errorStyle}>{error}</section> : null}

      <section style={overviewGridStyle}>
        <OverviewCard
          title="Controller Status"
          items={[
            ["Verified bitmap", bitmapString(dashboard?.status.verified_bitmap)],
            ["Sample-valid bitmap", bitmapString(dashboard?.status.sample_valid_bitmap)],
            ["Target LED bitmap", bitmapString(dashboard?.status.target_led_state)],
            ["Recovery active", yesNo(dashboard?.status.recovery_active)],
          ]}
        />
        <OverviewCard
          title="Dual-Target Board LEDs"
          items={[
            ["LED0", "Target A output state"],
            ["LED1", "Target B output state"],
            ["LED2", "Target A sample-valid"],
            ["LED3", "Target B sample-valid"],
            ["RGB blue", "Recovery active"],
            ["RGB green", "Boot done"],
            ["RGB red", "Boot or capture error"],
          ]}
        />
      </section>

      <section style={targetGridStyle}>
        {(dashboard?.targets ?? []).map((target) => (
          <TargetPanel
            key={target.target}
            target={target}
            toolState={toolState[target.target]}
            busy={busy}
            onSetLed={setLed}
            onRead={() => readRegisters(target.target)}
            onWrite={() => writeRegister(target.target)}
            onToolChange={(patch) => updateTool(target.target, patch)}
          />
        ))}
      </section>
    </main>
  );
}

function TargetPanel({
  target,
  toolState,
  busy,
  onSetLed,
  onRead,
  onWrite,
  onToolChange,
}: {
  target: TargetSummary;
  toolState: RegisterToolState;
  busy: boolean;
  onSetLed: (target: number, on: boolean) => Promise<void>;
  onRead: () => Promise<void>;
  onWrite: () => Promise<void>;
  onToolChange: (patch: Partial<RegisterToolState>) => void;
}) {
  return (
    <article style={panelStyle}>
      <div style={panelHeaderStyle}>
        <div>
          <p style={eyebrowStyle}>{target.name}</p>
          <h2 style={panelTitleStyle}>{TARGET_NAMES[target.target]}</h2>
        </div>
        <div style={badgeRowStyle}>
          <StatusBadge label={target.dynamic_address_hex} tone="good" />
          <StatusBadge label={target.verified ? "Verified" : "Unverified"} tone={target.verified ? "good" : "neutral"} />
          <StatusBadge label={target.led_state ? "LED On" : "LED Off"} tone={target.led_state ? "warn" : "neutral"} />
        </div>
      </div>

      <div style={metricsGridStyle}>
        <MetricCard label="Signature" value={target.signature_hex} />
        <MetricCard
          label="Frame Counter"
          value={target.registers ? String(target.registers.frame_counter) : "n/a"}
        />
        <MetricCard
          label="CCC Status"
          value={target.registers ? target.registers.ccc_status_word_hex : "n/a"}
        />
        <MetricCard
          label="Last CCC"
          value={target.registers ? target.registers.last_ccc_hex : "n/a"}
        />
      </div>

      <div style={samplePanelStyle}>
        <div style={sampleHeaderStyle}>
          <h3 style={sectionTitleStyle}>Sensor Payload</h3>
          <code style={monoStyle}>{target.sample_payload}</code>
        </div>
        <div style={channelGridStyle}>
          {target.parsed_payload.channels.map((channel, index) => (
            <MetricCard key={index} label={`Channel ${index}`} value={String(channel)} />
          ))}
          <MetricCard
            label="Temperature"
            value={target.parsed_payload.temperature?.toString() ?? "n/a"}
          />
          <MetricCard label="Misc" value={target.parsed_payload.misc?.toString() ?? "n/a"} />
        </div>
      </div>

      <div style={sectionBlockStyle}>
        <h3 style={sectionTitleStyle}>Target Output Control</h3>
        <div style={buttonRowStyle}>
          <button
            onClick={() => onSetLed(target.target, true)}
            disabled={busy}
            style={buttonStyle("#f0b429", "#102a43")}
          >
            LED On
          </button>
          <button
            onClick={() => onSetLed(target.target, false)}
            disabled={busy}
            style={buttonStyle("#52606d", "#f0f4f8")}
          >
            LED Off
          </button>
        </div>
      </div>

      <div style={sectionBlockStyle}>
        <h3 style={sectionTitleStyle}>Register Tools</h3>
        <div style={toolGridStyle}>
          <div style={toolCardStyle}>
            <label style={labelStyle}>
              Read Addr
              <input
                value={toolState.readAddr}
                onChange={(event) => onToolChange({ readAddr: event.target.value })}
                style={inputStyle}
              />
            </label>
            <label style={labelStyle}>
              Length
              <input
                value={toolState.readLength}
                onChange={(event) => onToolChange({ readLength: event.target.value })}
                style={inputStyle}
              />
            </label>
            <button onClick={onRead} disabled={busy} style={buttonStyle("#2f855a", "#f0fdf4")}>
              Read Registers
            </button>
            <pre style={resultStyle}>{toolState.readResult || "No register read yet."}</pre>
          </div>

          <div style={toolCardStyle}>
            <label style={labelStyle}>
              Write Addr
              <input
                value={toolState.writeAddr}
                onChange={(event) => onToolChange({ writeAddr: event.target.value })}
                style={inputStyle}
              />
            </label>
            <label style={labelStyle}>
              Write Value
              <input
                value={toolState.writeValue}
                onChange={(event) => onToolChange({ writeValue: event.target.value })}
                style={inputStyle}
              />
            </label>
            <button onClick={onWrite} disabled={busy} style={buttonStyle("#1f4b99", "#eff6ff")}>
              Write Register
            </button>
            <pre style={resultStyle}>{toolState.writeResult || "No register write yet."}</pre>
          </div>
        </div>
      </div>

      <div style={sectionBlockStyle}>
        <h3 style={sectionTitleStyle}>Decoded Register Status</h3>
        <dl style={detailListStyle}>
          <DetailRow label="Event mask" value={target.registers?.event_mask_hex ?? "n/a"} />
          <DetailRow label="RSTACT action" value={target.registers?.rstact_action_hex ?? "n/a"} />
          <DetailRow label="Local status" value={hex8(target.registers?.local_status)} />
          <DetailRow
            label="Activity/group"
            value={target.registers?.activity_group_word_hex ?? "n/a"}
          />
        </dl>
      </div>
    </article>
  );
}

function OverviewCard({
  title,
  items,
}: {
  title: string;
  items: Array<[string, string]>;
}) {
  return (
    <article style={panelStyle}>
      <h2 style={panelTitleStyle}>{title}</h2>
      <dl style={detailListStyle}>
        {items.map(([label, value]) => (
          <DetailRow key={label} label={label} value={value} />
        ))}
      </dl>
    </article>
  );
}

function StatusChip({
  label,
  value,
  tone,
}: {
  label: string;
  value: string;
  tone: "good" | "warn" | "bad" | "neutral";
}) {
  return (
    <div style={{ ...chipStyle, ...toneStyle(tone) }}>
      <span style={chipLabelStyle}>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

function StatusBadge({ label, tone }: { label: string; tone: "good" | "warn" | "neutral" }) {
  return <span style={{ ...badgeStyle, ...toneStyle(tone) }}>{label}</span>;
}

function MetricCard({ label, value }: { label: string; value: string }) {
  return (
    <div style={metricCardStyle}>
      <span style={metricLabelStyle}>{label}</span>
      <strong style={metricValueStyle}>{value}</strong>
    </div>
  );
}

function DetailRow({ label, value }: { label: string; value: string }) {
  return (
    <>
      <dt style={detailTermStyle}>{label}</dt>
      <dd style={detailValueStyle}>{value}</dd>
    </>
  );
}

function yesNo(value: boolean | undefined) {
  return value ? "Yes" : "No";
}

function bitmapString(value: number | undefined) {
  if (value === undefined) {
    return "n/a";
  }
  return `0b${value.toString(2).padStart(2, "0")}`;
}

function hex8(value: number | undefined) {
  if (value === undefined) {
    return "n/a";
  }
  return `0x${value.toString(16).padStart(2, "0").toUpperCase()}`;
}

function toneStyle(tone: "good" | "warn" | "bad" | "neutral") {
  switch (tone) {
    case "good":
      return { background: "rgba(47, 133, 90, 0.16)", borderColor: "rgba(72, 187, 120, 0.4)" };
    case "warn":
      return { background: "rgba(221, 107, 32, 0.14)", borderColor: "rgba(245, 158, 11, 0.42)" };
    case "bad":
      return { background: "rgba(197, 48, 48, 0.14)", borderColor: "rgba(252, 129, 129, 0.38)" };
    default:
      return { background: "rgba(72, 101, 129, 0.16)", borderColor: "rgba(148, 163, 184, 0.24)" };
  }
}

function buttonStyle(background: string, color: string) {
  return {
    background,
    color,
    border: "none",
    padding: "11px 16px",
    borderRadius: 999,
    cursor: "pointer",
    fontWeight: 700,
  } as const;
}

const pageStyle = {
  maxWidth: 1280,
  margin: "0 auto",
  padding: "32px 24px 64px",
};

const heroStyle = {
  display: "grid",
  gridTemplateColumns: "1.4fr 0.8fr",
  gap: 20,
  alignItems: "end",
};

const heroActionsStyle = {
  display: "flex",
  justifyContent: "flex-end",
  gap: 12,
  flexWrap: "wrap" as const,
};

const eyebrowStyle = {
  margin: 0,
  color: "#f0b429",
  textTransform: "uppercase" as const,
  letterSpacing: "0.12em",
  fontSize: 12,
  fontWeight: 700,
};

const titleStyle = {
  fontSize: 48,
  lineHeight: 1,
  margin: "10px 0 14px",
};

const ledeStyle = {
  maxWidth: 760,
  lineHeight: 1.6,
  color: "#d9e2ec",
  margin: 0,
};

const statusBarStyle = {
  display: "grid",
  gridTemplateColumns: "repeat(auto-fit, minmax(170px, 1fr))",
  gap: 12,
  marginTop: 28,
  alignItems: "center",
};

const chipStyle = {
  border: "1px solid",
  borderRadius: 18,
  padding: "12px 14px",
  display: "grid",
  gap: 4,
};

const chipLabelStyle = {
  fontSize: 12,
  color: "#bcccdc",
  textTransform: "uppercase" as const,
  letterSpacing: "0.08em",
};

const subtleMetaStyle = {
  display: "grid",
  gap: 4,
  color: "#9fb3c8",
  fontSize: 13,
  alignContent: "center",
};

const errorStyle = {
  marginTop: 18,
  border: "1px solid rgba(252, 129, 129, 0.35)",
  background: "rgba(197, 48, 48, 0.16)",
  color: "#fed7d7",
  borderRadius: 16,
  padding: 14,
};

const overviewGridStyle = {
  display: "grid",
  gridTemplateColumns: "repeat(auto-fit, minmax(320px, 1fr))",
  gap: 18,
  marginTop: 24,
};

const targetGridStyle = {
  display: "grid",
  gridTemplateColumns: "repeat(auto-fit, minmax(420px, 1fr))",
  gap: 18,
  marginTop: 24,
};

const panelStyle = {
  background: "rgba(11, 31, 51, 0.82)",
  border: "1px solid rgba(240, 244, 248, 0.08)",
  borderRadius: 24,
  padding: 20,
  boxShadow: "0 20px 48px rgba(0, 0, 0, 0.22)",
  backdropFilter: "blur(12px)",
};

const panelHeaderStyle = {
  display: "flex",
  justifyContent: "space-between",
  gap: 12,
  alignItems: "start",
  marginBottom: 18,
};

const panelTitleStyle = {
  margin: "8px 0 0",
  fontSize: 30,
};

const badgeRowStyle = {
  display: "flex",
  gap: 8,
  flexWrap: "wrap" as const,
  justifyContent: "flex-end",
};

const badgeStyle = {
  border: "1px solid",
  borderRadius: 999,
  padding: "6px 10px",
  fontSize: 12,
  fontWeight: 700,
};

const metricsGridStyle = {
  display: "grid",
  gridTemplateColumns: "repeat(auto-fit, minmax(140px, 1fr))",
  gap: 12,
};

const metricCardStyle = {
  padding: 14,
  borderRadius: 16,
  background: "rgba(16, 42, 67, 0.72)",
  border: "1px solid rgba(148, 163, 184, 0.14)",
  display: "grid",
  gap: 6,
};

const metricLabelStyle = {
  fontSize: 12,
  color: "#9fb3c8",
  textTransform: "uppercase" as const,
  letterSpacing: "0.06em",
};

const metricValueStyle = {
  fontSize: 18,
};

const samplePanelStyle = {
  marginTop: 18,
  padding: 16,
  borderRadius: 18,
  background: "linear-gradient(135deg, rgba(31, 78, 121, 0.18), rgba(11, 31, 51, 0.16))",
  border: "1px solid rgba(111, 168, 220, 0.16)",
};

const sampleHeaderStyle = {
  display: "flex",
  justifyContent: "space-between",
  gap: 12,
  alignItems: "center",
  marginBottom: 14,
  flexWrap: "wrap" as const,
};

const sectionBlockStyle = {
  marginTop: 18,
};

const sectionTitleStyle = {
  margin: "0 0 12px",
  fontSize: 18,
};

const channelGridStyle = {
  display: "grid",
  gridTemplateColumns: "repeat(auto-fit, minmax(130px, 1fr))",
  gap: 12,
};

const buttonRowStyle = {
  display: "flex",
  gap: 12,
  flexWrap: "wrap" as const,
};

const toolGridStyle = {
  display: "grid",
  gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))",
  gap: 14,
};

const toolCardStyle = {
  background: "rgba(16, 42, 67, 0.6)",
  border: "1px solid rgba(148, 163, 184, 0.14)",
  borderRadius: 16,
  padding: 14,
  display: "grid",
  gap: 10,
};

const labelStyle = {
  display: "grid",
  gap: 6,
  fontSize: 13,
  color: "#d9e2ec",
};

const inputStyle = {
  borderRadius: 12,
  border: "1px solid rgba(148, 163, 184, 0.22)",
  background: "rgba(11, 31, 51, 0.9)",
  color: "#f0f4f8",
  padding: "10px 12px",
  fontSize: 14,
};

const resultStyle = {
  margin: 0,
  minHeight: 72,
  background: "rgba(6, 17, 28, 0.95)",
  borderRadius: 12,
  padding: 12,
  overflowX: "auto" as const,
  fontSize: 12,
  lineHeight: 1.45,
  color: "#d9e2ec",
};

const detailListStyle = {
  display: "grid",
  gridTemplateColumns: "max-content 1fr",
  gap: "8px 14px",
  margin: 0,
  alignItems: "baseline",
};

const detailTermStyle = {
  color: "#9fb3c8",
  margin: 0,
};

const detailValueStyle = {
  color: "#f0f4f8",
  margin: 0,
};

const monoStyle = {
  fontFamily: "ui-monospace, SFMono-Regular, Menlo, monospace",
  color: "#9fb3c8",
  fontSize: 12,
};
