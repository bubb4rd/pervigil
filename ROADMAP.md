# Roadmap

Pervigil is built to stay small, native, and quiet while serving everyday Mac workflows, active AI coding agents, headless Macs, and local Apple Silicon inference hosts.

## Next release: Inference Host

This release adds local inference and unattended-host capabilities on top of Pervigil's existing architecture, with no new targets, no external dependencies, no open network ports, and no always-on polling.

| Feature | Scope | Design and footprint |
| --- | --- | --- |
| **Inference server trigger** | Keep the Mac awake while **Ollama**, **LM Studio**, or **llama-server** is actively serving, and let it sleep when idle | Polls a loopback HTTP endpoint every few seconds only when the rule is enabled and the server process is running (checked via the existing process list) |
| **Menu telemetry** | Live GPU utilization, memory pressure, swap usage, and temperatures directly in the menu | Uses IORegistry, `sysctl`, and existing SMC reads with no root access; sampled every 5 seconds only while the menu is open or an alert needs it |
| **CLI and Prometheus metrics** | Extended telemetry in `pervigil status --json` plus `pervigil metrics --prometheus` | CLI only; Prometheus output feeds `node_exporter`'s textfile collector for Grafana and scripts without opening a port |
| **Host health alerts** | Alerts for thermal throttling, memory pressure or swap growth, and inference server outages | Reuses Pervigil's existing notification and webhook system |
| **Persistent GPU wired-memory limit** | Configure and persist Apple Silicon wired-memory limits for large local models | Adds one versioned command to the existing privileged helper with a safe cap and explicit warning |
| **Headless Setup checks** | Verify restart after power failure and unattended auto-update restart settings | Adds read-only checks to the existing Headless Setup checklist |

## Later and under consideration

- **Power draw and energy cost**: Wattage and energy tracking (requires `powermetrics` as root or private APIs, so deferred to avoid macOS update fragility and extra overhead).
- **Fleet view, cluster hold, and remote control**: Multi-Mac status, coordinated keep-awake holds, and authenticated remote control as a dedicated networking release.
- **Bonjour wake on demand**: Tracked as a separate prototype until wake reliability is verified across sleep states.
- **Weak-signal hotspot switching**: Proactive Wi-Fi fallback before a full disconnect, tracked on a separate track.
- **Companion iOS app**: Separate product track.

> [!NOTE]
> A built-in Prometheus HTTP endpoint is intentionally left out. The CLI `pervigil metrics --prometheus` output supports Grafana and monitoring pipelines without opening a listening network port.

## Engineering constraints

- **No new dependencies or targets**: New logic lives in pure Swift inside `PervigilCore` so binary size stays minimal and behavior remains unit-tested.
- **Nothing runs unless enabled**: Every sensor, poll, and check is gated on its rule, alert, or an open menu; heavier reads run on slower intervals than the 1-second session ticker.
- **Concise UI copy**: New strings stay short and plain to keep all 15 localizations maintainable.
