# Roadmap

Pervigil is built to stay small, native, and quiet while serving everyday Mac workflows, active AI coding agents, and headless Macs.

## Later and under consideration

No release is scheduled. These are ideas, not commitments.

- **Inference server trigger**: Stay awake while Ollama, LM Studio, or `llama-server` is serving, and sleep when idle. Menu telemetry, Prometheus metrics, host alerts, and a GPU wired-memory limit were scoped alongside it and are deferred too.
- **Power draw and energy cost**: Wattage and energy tracking (requires `powermetrics` as root or private APIs, so deferred to avoid macOS update fragility and extra overhead).
- **Fleet view, cluster hold, and remote control**: Multi-Mac status, coordinated keep-awake holds, and authenticated remote control as a dedicated networking release.
- **Bonjour wake on demand**: Tracked as a separate prototype until wake reliability is verified across sleep states.
- **Weak-signal hotspot switching**: Proactive Wi-Fi fallback before a full disconnect, tracked on a separate track.
- **Companion iOS app**: Separate product track.

## Engineering constraints

- **No new dependencies or targets**: New logic lives in pure Swift inside `PervigilCore` so binary size stays minimal and behavior remains unit-tested.
- **Nothing runs unless enabled**: Every sensor, poll, and check is gated on its rule, alert, or an open menu; heavier reads run on slower intervals than the 1-second session ticker.
- **Concise UI copy**: New strings stay short and plain to keep all 15 localizations maintainable.
