# NotchMeter

A Dynamic-Island-style overlay that lives in your MacBook notch and shows how much of your AI subscriptions you've burned — at a glance.

- **Collapsed**: a pill in the notch area showing your most-consumed provider (`Cursor 88%`).
- **Hover**: expands into a panel with every provider — per-window usage bars, reset countdowns, plan badges, credit balances.
- Polls every 60s. Runs as a background agent (no Dock icon).

## Supported providers

| Provider | Credential source | Endpoint |
|---|---|---|
| Claude (Pro/Max/Code) | `Claude Code-credentials` entry in macOS Keychain (created by Claude Code) | `api.anthropic.com/api/oauth/usage` → 5h + 7d windows |
| ChatGPT (Plus/Pro via Codex CLI) | `~/.codex/auth.json` | `chatgpt.com/backend-api/wham/usage` → primary + secondary windows, credits |
| Cursor | session token in Cursor's `state.vscdb` | `cursor.com/api/usage-summary` → billing-cycle usage |

All endpoints are the unofficial/internal ones the providers' own apps and dashboards use — same approach as opencode-quota and openusage. They can break without notice; the app degrades to an error row per provider rather than crashing.

No credentials exist? NotchMeter shows demo data so the UI is always previewable.

## Build & run

```sh
swift build
swift run NotchMeter          # real data from whatever AI tools you're logged into
swift run NotchMeter --demo   # forced demo data
```

## Roadmap

- GitHub Copilot, Gemini, Grok providers
- macOS notifications at 80%/95% thresholds
- OAuth token refresh for expired Claude/Codex sessions
- Burn-rate forecast ("at this pace you hit the limit ~3pm")
- `.app` bundle packaging + LaunchAgent autostart
