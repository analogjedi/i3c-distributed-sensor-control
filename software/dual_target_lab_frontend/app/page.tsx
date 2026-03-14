"use client";

import { useEffect, useRef, useState } from "react";

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

type CccCommand = {
  id: string;
  label: string;
  mode: "direct" | "broadcast";
  code: number;
  target_required: boolean;
  arg_required: boolean;
  arg_default: number;
  arg_label?: string;
  description: string;
};

type CccResult = {
  command: CccCommand;
  target: number | null;
  arg: number;
  arg_hex: string;
  response_len: number;
  response_hex: string;
  response_bytes: number[];
  decoded: Record<string, string | number>;
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
  const [polling, setPolling] = useState(true);
  const [pollIntervalMs, setPollIntervalMs] = useState(2000);
  const [activeTab, setActiveTab] = useState<"operations" | "ccc">("operations");
  const [cccCatalog, setCccCatalog] = useState<CccCommand[]>([]);
  const [cccCommandId, setCccCommandId] = useState("");
  const [cccTarget, setCccTarget] = useState<0 | 1>(0);
  const [cccArg, setCccArg] = useState("0x00");
  const [cccResult, setCccResult] = useState<CccResult | null>(null);
  const [cccHistory, setCccHistory] = useState<CccResult[]>([]);

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

  async function loadCatalog() {
    const next = await fetchJson("/api/ccc/catalog");
    const commands = next.commands as CccCommand[];
    setCccCatalog(commands);
    if (!cccCommandId && commands.length > 0) {
      setCccCommandId(commands[0].id);
      setCccArg(`0x${commands[0].arg_default.toString(16).toUpperCase().padStart(2, "0")}`);
    }
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

  async function executeCcc() {
    const command = cccCatalog.find((item) => item.id === cccCommandId);
    if (!command) {
      return;
    }
    await runAction(async () => {
      const result = await fetchJson("/api/ccc/execute", {
        method: "POST",
        body: JSON.stringify({
          command_id: command.id,
          target: command.target_required ? cccTarget : null,
          arg: command.arg_required ? Number(cccArg) : command.arg_default,
        }),
      });
      setCccResult(result);
      setCccHistory((prev) => [result, ...prev].slice(0, 8));
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
    loadCatalog().catch((nextError) => {
      setError(nextError instanceof Error ? nextError.message : String(nextError));
    });
  }, []);

  useEffect(() => {
    if (!polling) {
      return;
    }
    const id = window.setInterval(() => {
      refresh().catch(() => undefined);
    }, pollIntervalMs);
    return () => window.clearInterval(id);
  }, [polling, pollIntervalMs]);

  useEffect(() => {
    const command = cccCatalog.find((item) => item.id === cccCommandId);
    if (command) {
      setCccArg(`0x${command.arg_default.toString(16).toUpperCase().padStart(2, "0")}`);
    }
  }, [cccCommandId, cccCatalog]);

  const selectedCommand = cccCatalog.find((item) => item.id === cccCommandId) ?? null;

  return (
    <main style={pageStyle}>
      <section style={heroStyle}>
        <div>
          <p style={eyebrowStyle}>CMOD S7 / I3C / Dual Target Lab</p>
          <h1 style={titleStyle}>Controller Dashboard</h1>
          <p style={ledeStyle}>
            One tab runs the operational demo. The other tab is a CCC lab so you can exercise
            controller-issued read-only management commands without stuffing protocol experiments
            into the same surface as the live payload view.
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
          <button
            onClick={() => setPolling((p) => !p)}
            style={buttonStyle(polling ? "#c53030" : "#2f855a", "#f0f4f8")}
          >
            {polling ? "Pause Polling" : "Resume Polling"}
          </button>
          <div style={sliderWrapStyle}>
            <label style={sliderLabelStyle}>
              Poll: {pollIntervalMs >= 1000
                ? `${(pollIntervalMs / 1000).toFixed(1)}s`
                : `${pollIntervalMs}ms`}
            </label>
            <input
              type="range"
              min={100}
              max={2000}
              step={100}
              value={pollIntervalMs}
              onChange={(event) => setPollIntervalMs(Number(event.target.value))}
              style={sliderStyle}
            />
            <div style={sliderTicksStyle}>
              <span>0.1s</span>
              <span>2.0s</span>
            </div>
          </div>
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

      <section style={tabRowStyle}>
        <button
          onClick={() => setActiveTab("operations")}
          style={tabButtonStyle(activeTab === "operations")}
        >
          Operations
        </button>
        <button
          onClick={() => setActiveTab("ccc")}
          style={tabButtonStyle(activeTab === "ccc")}
        >
          CCC Lab
        </button>
      </section>

      {activeTab === "operations" ? (
        <>
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
        </>
      ) : (
        <CccLab
          busy={busy}
          commands={cccCatalog}
          selectedCommand={selectedCommand}
          selectedCommandId={cccCommandId}
          selectedTarget={cccTarget}
          argValue={cccArg}
          result={cccResult}
          history={cccHistory}
          onCommandChange={setCccCommandId}
          onTargetChange={(value) => setCccTarget(value as 0 | 1)}
          onArgChange={setCccArg}
          onExecute={() => void executeCcc()}
        />
      )}
    </main>
  );
}

function CccLab({
  busy,
  commands,
  selectedCommand,
  selectedCommandId,
  selectedTarget,
  argValue,
  result,
  history,
  onCommandChange,
  onTargetChange,
  onArgChange,
  onExecute,
}: {
  busy: boolean;
  commands: CccCommand[];
  selectedCommand: CccCommand | null;
  selectedCommandId: string;
  selectedTarget: 0 | 1;
  argValue: string;
  result: CccResult | null;
  history: CccResult[];
  onCommandChange: (value: string) => void;
  onTargetChange: (value: number) => void;
  onArgChange: (value: string) => void;
  onExecute: () => void;
}) {
  return (
    <section style={cccGridStyle}>
      <article style={panelStyle}>
        <h2 style={panelTitleStyle}>CCC Command Runner</h2>
        <p style={smallCopyStyle}>
          This pane exercises safe read-only management CCCs through the real controller path. It
          is intentionally biased toward identity, capability, and status commands instead of
          address-destructive chaos.
        </p>

        <div style={formGridStyle}>
          <label style={labelStyle}>
            Command
            <select
              value={selectedCommandId}
              onChange={(event) => onCommandChange(event.target.value)}
              style={inputStyle}
            >
              {commands.map((command) => (
                <option key={command.id} value={command.id}>
                  {command.label}
                </option>
              ))}
            </select>
          </label>

          <label style={labelStyle}>
            Mode
            <input
              readOnly
              value={selectedCommand ? selectedCommand.mode : "n/a"}
              style={inputStyle}
            />
          </label>

          <label style={labelStyle}>
            Target
            <select
              value={selectedTarget}
              onChange={(event) => onTargetChange(Number(event.target.value))}
              style={inputStyle}
              disabled={!selectedCommand?.target_required}
            >
              <option value={0}>Target A</option>
              <option value={1}>Target B</option>
            </select>
          </label>

          <label style={labelStyle}>
            {selectedCommand?.arg_label ?? "Argument"}
            <input
              value={argValue}
              onChange={(event) => onArgChange(event.target.value)}
              style={inputStyle}
              disabled={!selectedCommand?.arg_required}
            />
          </label>
        </div>

        <div style={buttonRowStyle}>
          <button onClick={onExecute} disabled={busy || !selectedCommand} style={buttonStyle("#1f4b99", "#eff6ff")}>
            Execute CCC
          </button>
        </div>

        {selectedCommand ? (
          <div style={sectionBlockStyle}>
            <h3 style={sectionTitleStyle}>Selected Command</h3>
            <dl style={detailListStyle}>
              <DetailRow label="Code" value={`0x${selectedCommand.code.toString(16).toUpperCase().padStart(2, "0")}`} />
              <DetailRow label="Description" value={selectedCommand.description} />
              <DetailRow label="Target required" value={selectedCommand.target_required ? "Yes" : "No"} />
              <DetailRow label="Argument required" value={selectedCommand.arg_required ? "Yes" : "No"} />
            </dl>
          </div>
        ) : null}
      </article>

      <article style={panelStyle}>
        <h2 style={panelTitleStyle}>Result</h2>
        {result ? (
          <>
            <dl style={detailListStyle}>
              <DetailRow label="Command" value={result.command.label} />
              <DetailRow label="Mode" value={result.command.mode} />
              <DetailRow
                label="Target"
                value={result.target === null ? "Broadcast" : TARGET_NAMES[result.target]}
              />
              <DetailRow label="Argument" value={result.arg_hex} />
              <DetailRow label="Response length" value={String(result.response_len)} />
              <DetailRow label="Response hex" value={result.response_hex || "(none)"} />
            </dl>
            <div style={sectionBlockStyle}>
              <h3 style={sectionTitleStyle}>Decoded</h3>
              <pre style={resultStyle}>{JSON.stringify(result.decoded, null, 2)}</pre>
            </div>
          </>
        ) : (
          <p style={smallCopyStyle}>No CCC command executed yet.</p>
        )}
      </article>

      <article style={panelStyle}>
        <h2 style={panelTitleStyle}>Recent CCC History</h2>
        {history.length === 0 ? (
          <p style={smallCopyStyle}>No history yet.</p>
        ) : (
          <div style={{ display: "grid", gap: 10 }}>
            {history.map((entry, index) => (
              <div key={`${entry.command.id}-${index}`} style={historyItemStyle}>
                <div style={{ display: "flex", justifyContent: "space-between", gap: 12, flexWrap: "wrap" as const }}>
                  <strong>{entry.command.label}</strong>
                  <span style={monoStyle}>
                    {entry.target === null ? "Broadcast" : TARGET_NAMES[entry.target]}
                  </span>
                </div>
                <div style={{ display: "flex", justifyContent: "space-between", gap: 12, flexWrap: "wrap" as const }}>
                  <span style={monoStyle}>arg {entry.arg_hex}</span>
                  <span style={monoStyle}>{entry.response_hex || "(no data)"}</span>
                </div>
              </div>
            ))}
          </div>
        )}
      </article>
    </section>
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
          value={target.parsed_payload.channels[0] != null
            ? `0x${extractFc8(target.parsed_payload.channels[0], target.target).toString(16).toUpperCase().padStart(2, "0")}`
            : "n/a"}
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
          <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
            <h3 style={{ ...sectionTitleStyle, margin: 0 }}>Sensor Payload</h3>
            <PayloadInfoButton target={target} />
          </div>
          <div style={{ display: "flex", gap: 16, alignItems: "center", flexWrap: "wrap" as const }}>
            <code style={monoStyle}>{target.sample_payload}</code>
            <span style={{ ...monoStyle, color: "#f0b429" }}>
              fc[7:0]: {target.parsed_payload.channels[0] != null
                ? `0x${extractFc8(target.parsed_payload.channels[0], target.target).toString(16).toUpperCase().padStart(2, "0")}`
                : "n/a"}
            </span>
          </div>
        </div>
        <PayloadValidation target={target} />
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

function PayloadInfoButton({ target }: { target: TargetSummary }) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);
  const ch0 = target.parsed_payload.channels[0];
  const fc8 = ch0 != null ? extractFc8(ch0, target.target) : null;
  const offset = target.target << 8;

  useEffect(() => {
    if (!open) {
      return;
    }
    function handleClick(event: MouseEvent) {
      if (ref.current && !ref.current.contains(event.target as Node)) {
        setOpen(false);
      }
    }
    document.addEventListener("mousedown", handleClick);
    return () => document.removeEventListener("mousedown", handleClick);
  }, [open]);

  return (
    <div ref={ref} style={{ position: "relative" as const, display: "inline-block" }}>
      <button onClick={() => setOpen((value) => !value)} style={infoBtnStyle} title="Show payload math">
        ⓘ
      </button>
      {open && fc8 != null ? (
        <div style={popoverStyle}>
          <p style={popoverTitleStyle}>Payload Formula — {target.name}</p>
          <table style={{ ...validationTableStyle, fontSize: 12 }}>
            <thead>
              <tr>
                <th style={thStyle}>Field</th>
                <th style={thStyle}>Formula</th>
                <th style={thStyle}>Value</th>
              </tr>
            </thead>
            <tbody>
              {[
                ["fc[7:0]", `Ch0 − 0x${(0x1000 + offset).toString(16).toUpperCase()}`, `0x${fc8.toString(16).toUpperCase().padStart(2, "0")} (${fc8})`],
                ["Ch 0", `0x${(0x1000 + offset).toString(16).toUpperCase()} + fc`, String(0x1000 + offset + fc8)],
                ["Ch 1", `0x${(0x2000 + offset).toString(16).toUpperCase()} + 3×fc`, String(0x2000 + offset + 3 * fc8)],
                ["Ch 2", `0x${(0x3000 + offset).toString(16).toUpperCase()} + 5×fc`, String(0x3000 + offset + 5 * fc8)],
                ["Ch 3", `0x${(0x4000 + offset).toString(16).toUpperCase()} + 7×fc`, String(0x4000 + offset + 7 * fc8)],
                ["Temp", `0x50 + ${target.target} + fc[3:0]`, String(0x50 + target.target + (fc8 & 0xF))],
                ["Misc", `{idx[2:0], fc[4:0]}`, String(((target.target & 0x7) << 5) | (fc8 & 0x1F))],
              ].map(([field, formula, value]) => (
                <tr key={field}>
                  <td style={{ ...tdStyle, fontWeight: 700 }}>{field}</td>
                  <td style={{ ...tdStyle, fontFamily: "monospace", color: "#9fb3c8" }}>{formula}</td>
                  <td style={{ ...tdStyle, fontFamily: "monospace", color: "#f0b429" }}>{value}</td>
                </tr>
              ))}
            </tbody>
          </table>
          <p style={{ margin: "10px 0 0", fontSize: 11, color: "#9fb3c8" }}>
            TARGET_OFFSET = 0x{offset.toString(16).toUpperCase().padStart(4, "0")} (TARGET_INDEX={target.target})
          </p>
        </div>
      ) : null}
    </div>
  );
}

function extractFc8(ch0: number, targetIndex: number): number {
  const offset = targetIndex << 8;
  return (ch0 - 0x1000 - offset) & 0xff;
}

function computeExpected(targetIndex: number, fc8: number) {
  const fc4 = fc8 & 0x0f;
  const fc5 = fc8 & 0x1f;
  const offset = targetIndex << 8;
  return {
    ch0: 0x1000 + offset + fc8,
    ch1: 0x2000 + offset + 3 * fc8,
    ch2: 0x3000 + offset + 5 * fc8,
    ch3: 0x4000 + offset + 7 * fc8,
    temperature: 0x50 + targetIndex + fc4,
    misc: ((targetIndex & 0x7) << 5) | fc5,
  };
}

function PayloadValidation({ target }: { target: TargetSummary }) {
  const payload = target.parsed_payload;
  const ch0 = payload.channels[0];

  if (ch0 === undefined || ch0 === null) {
    return <p style={{ color: "#9fb3c8", fontSize: 13, margin: "10px 0 0" }}>No payload data yet.</p>;
  }

  const fc8 = extractFc8(ch0, target.target);
  const expected = computeExpected(target.target, fc8);
  const rows: Array<{ label: string; actual: number | null; expected: number; anchor?: boolean }> = [
    { label: "Ch 0", actual: payload.channels[0] ?? null, expected: expected.ch0, anchor: true },
    { label: "Ch 1", actual: payload.channels[1] ?? null, expected: expected.ch1 },
    { label: "Ch 2", actual: payload.channels[2] ?? null, expected: expected.ch2 },
    { label: "Ch 3", actual: payload.channels[3] ?? null, expected: expected.ch3 },
    { label: "Temp", actual: payload.temperature, expected: expected.temperature },
    { label: "Misc", actual: payload.misc, expected: expected.misc },
  ];

  return (
    <div style={{ marginTop: 14, overflowX: "auto" as const }}>
      <table style={validationTableStyle}>
        <thead>
          <tr>
            <th style={thStyle}>Field</th>
            <th style={thStyle}>Expected</th>
            <th style={thStyle}>Actual</th>
            <th style={thStyle}>Match</th>
          </tr>
        </thead>
        <tbody>
          {rows.map(({ label, actual, expected: expectedValue, anchor }) => {
            const match = actual !== null && actual === expectedValue;
            const tone = actual === null ? "neutral" : match ? "good" : "bad";
            return (
              <tr key={label} style={validationRowStyle(tone)}>
                <td style={tdStyle}>
                  {label}
                  {anchor ? <span style={{ color: "#9fb3c8", fontSize: 11 }}> (anchor)</span> : null}
                </td>
                <td style={{ ...tdStyle, fontFamily: "monospace" }}>{expectedValue}</td>
                <td style={{ ...tdStyle, fontFamily: "monospace" }}>{actual ?? "n/a"}</td>
                <td style={{ ...tdStyle, fontSize: 16 }}>{actual === null ? "—" : match ? "✅" : "🔴"}</td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}

function OverviewCard({ title, items }: { title: string; items: Array<[string, string]> }) {
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
  return `0x${value.toString(16).toUpperCase().padStart(2, "0")}`;
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

function tabButtonStyle(active: boolean) {
  return {
    ...buttonStyle(active ? "#f0b429" : "#243b53", active ? "#102a43" : "#f0f4f8"),
    minWidth: 160,
  };
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

const tabRowStyle = {
  display: "flex",
  gap: 12,
  marginTop: 24,
  flexWrap: "wrap" as const,
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

const cccGridStyle = {
  display: "grid",
  gridTemplateColumns: "repeat(auto-fit, minmax(320px, 1fr))",
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

const formGridStyle = {
  display: "grid",
  gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))",
  gap: 14,
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

const historyItemStyle = {
  background: "rgba(16, 42, 67, 0.62)",
  border: "1px solid rgba(148, 163, 184, 0.14)",
  borderRadius: 14,
  padding: 12,
  display: "grid",
  gap: 6,
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

const smallCopyStyle = {
  color: "#9fb3c8",
  lineHeight: 1.6,
  margin: "0 0 14px",
};

const infoBtnStyle = {
  background: "rgba(240,180,41,0.15)",
  border: "1px solid rgba(240,180,41,0.35)",
  color: "#f0b429",
  borderRadius: "50%",
  width: 22,
  height: 22,
  fontSize: 13,
  cursor: "pointer",
  display: "inline-flex",
  alignItems: "center",
  justifyContent: "center",
  padding: 0,
  lineHeight: 1,
} as const;

const popoverStyle = {
  position: "absolute" as const,
  top: 28,
  left: 0,
  zIndex: 100,
  background: "#0b1f33",
  border: "1px solid rgba(240,180,41,0.3)",
  borderRadius: 16,
  padding: 16,
  minWidth: 340,
  boxShadow: "0 12px 40px rgba(0,0,0,0.5)",
};

const popoverTitleStyle = {
  margin: "0 0 10px",
  fontSize: 13,
  fontWeight: 700,
  color: "#f0b429",
  textTransform: "uppercase" as const,
  letterSpacing: "0.08em",
};

const validationTableStyle = {
  width: "100%",
  borderCollapse: "collapse" as const,
  fontSize: 13,
};

const thStyle = {
  textAlign: "left" as const,
  padding: "6px 10px",
  color: "#9fb3c8",
  fontSize: 11,
  textTransform: "uppercase" as const,
  letterSpacing: "0.07em",
  borderBottom: "1px solid rgba(148,163,184,0.15)",
};

const tdStyle = {
  padding: "7px 10px",
  color: "#f0f4f8",
};

const sliderWrapStyle = {
  display: "grid",
  gap: 4,
  alignContent: "center",
  minWidth: 160,
};

const sliderLabelStyle = {
  fontSize: 12,
  color: "#bcccdc",
  textTransform: "uppercase" as const,
  letterSpacing: "0.08em",
  textAlign: "center" as const,
};

const sliderStyle = {
  width: "100%",
  accentColor: "#f0b429",
  cursor: "pointer",
};

const sliderTicksStyle = {
  display: "flex",
  justifyContent: "space-between",
  fontSize: 10,
  color: "#9fb3c8",
};

function validationRowStyle(tone: "good" | "bad" | "neutral") {
  const background =
    tone === "good"
      ? "rgba(47,133,90,0.12)"
      : tone === "bad"
        ? "rgba(197,48,48,0.14)"
        : "transparent";
  return { background };
}
