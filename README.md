# Chrome DevTools MCP through mcp2cli

A skill for driving Chrome from terminal-first agents through `mcp2cli`.

Use this when your runtime can run shell commands but does not expose native MCP tools directly.

## Field note

This skill came out of a small Copilot CLI experiment comparing direct Chrome DevTools MCP with a CLI-wrapper path over the same 9-step browser smoke test (3 runs per variant).

| Path | Fresh context | Completed-run message growth | Runtime notes |
|---|---:|---:|---|
| CLI skill through `mcp2cli` | 19k total, `MCP Tools` 155 | about 18-21k | 9/9 passes; slower in one run, steadier context growth |
| Direct Chrome DevTools MCP | 24k total, `MCP Tools` 4.9k | about 16-56k | 9/9 passes; fastest single run, more variance |

Direct MCP is richer; the CLI skill has basic set of MCP tools exposed and is useful when you want a shell-native path with progressive discovery and lower upfront tool-surface load.

[pi](https://pi.dev) is a good example of the target shape: a lean coding agent that can run commands but may not come with MCP mounted in the runtime. For that kind of agent, `mcp2cli` is less about replacing MCP and more about reaching MCP servers from the interface the agent already has.

## Install

```bash
npx skills add maxim-saplin/chrome-devtools-mcp2cli
```

Manual install: copy `skills/chrome-devtools-mcp2cli/` into your agent skills directory.

## Requirements

- `uvx`
- Node.js
- `npx`
- Google Chrome or Chrome for Testing available to `chrome-devtools-mcp`

Default MCP server command:

```bash
npx -y chrome-devtools-mcp@latest --isolated
```

Set `MCP_SERVER_CMD` to override.

## Quick preflight

```bash
bash scripts/preflight.sh
```

Optional target check:

```bash
bash scripts/preflight.sh http://localhost:8501 browser-preflight
```

## Core workflow

```bash
bash scripts/browser-session.sh session-list
bash scripts/browser-session.sh ensure-session browserverify
bash scripts/browser-session.sh navigate browserverify http://localhost:8000/docs/index.html
bash scripts/browser-session.sh snapshot browserverify
bash scripts/browser-session.sh click-selector browserverify '#leaderboard tbody tr'
bash scripts/browser-session.sh get-selector-text browserverify '#cost-per-elo'
bash scripts/browser-session.sh assert-selector-contains browserverify '#cost-per-elo' 'Cost/Elo:'
bash scripts/browser-session.sh wait-for-text browserverify 'Leaderboard'
bash scripts/browser-session.sh stop-session browserverify
```

If a run is interrupted, recover with:

```bash
bash scripts/browser-session.sh session-list
bash scripts/browser-session.sh stop-session <session-name>
```

## Diagnostics commands

Console:

```bash
bash scripts/browser-session.sh console-errors browserverify
bash scripts/browser-session.sh console-list browserverify --types-json '["warn","error"]' --page-size 50
bash scripts/browser-session.sh console-message browserverify <msgid>
```

Network:

```bash
bash scripts/browser-session.sh network-failures browserverify
bash scripts/browser-session.sh network-list browserverify --page-size 100
bash scripts/browser-session.sh network-request browserverify <reqid>
```

## Advanced commands

```bash
bash scripts/browser-session.sh lighthouse browserverify snapshot desktop
bash scripts/browser-session.sh trace-start browserverify --reload --auto-stop
bash scripts/browser-session.sh trace-insight browserverify NAVIGATION_0 RenderBlocking
bash scripts/browser-session.sh trace-stop browserverify
```

Discovery and passthrough:

```bash
bash scripts/browser-session.sh tools-list --session browserverify
bash scripts/browser-session.sh tools-list --session browserverify performance
bash scripts/browser-session.sh tool-help --session browserverify performance-start-trace
bash scripts/browser-session.sh run-tool --session browserverify list-console-messages --types '["warn","error"]'
```

## Notes

- `wait-for-text` is concise by default.
  - Set `WAIT_FOR_VERBOSE=1` for full output.
- `ensure-session` and `start-session` honor `MCP_SERVER_CMD` when `server-cmd` is omitted.

## Repository layout

```text
README.md
LICENSE
.gitattributes

skills/
  chrome-devtools-mcp2cli/
    SKILL.md
    scripts/
      preflight.sh
      browser-session.sh
```

## Security and privacy

Do not use this skill on pages containing secrets or personal data you do not want in transcripts.

When credentials are required, use environment variables or files rather than literal command-line values.
