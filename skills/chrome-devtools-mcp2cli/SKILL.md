---
name: chrome-devtools-mcp2cli
description: Drive Chrome DevTools MCP through mcp2cli from terminal-first agents. Use for browser smoke tests, app checks, diagnostics, and scripted browser actions when native MCP mounting is unavailable.
---
# Chrome DevTools MCP through mcp2cli

Use this skill to run browser checks through `mcp2cli`.

Use direct Chrome DevTools MCP when your runtime already provides native MCP tools.

## Requirements

- `uvx`
- Node.js
- `npx`
- Google Chrome or Chrome for Testing available to `chrome-devtools-mcp`

Default MCP server command:

```bash
npx -y chrome-devtools-mcp@latest --isolated
```

Override with `MCP_SERVER_CMD` when needed.

## Preflight

From the skill root:

```bash
bash scripts/preflight.sh
```

Optional target check:

```bash
bash scripts/preflight.sh <target-url> [session-name]
```

## Core workflow

Keep one session per app and reuse it.

```bash
bash scripts/browser-session.sh session-list
bash scripts/browser-session.sh ensure-session browserverify
bash scripts/browser-session.sh navigate browserverify http://localhost:8000/docs/index.html
bash scripts/browser-session.sh snapshot browserverify
bash scripts/browser-session.sh click-selector browserverify '#leaderboard tbody tr'
bash scripts/browser-session.sh fill-selector browserverify '#search' 'queen'
bash scripts/browser-session.sh get-selector-text browserverify '#cost-per-elo'
bash scripts/browser-session.sh assert-selector-contains browserverify '#cost-per-elo' 'Cost/Elo:'
bash scripts/browser-session.sh wait-for-text browserverify 'Leaderboard'
```

Stop session when done:

```bash
bash scripts/browser-session.sh stop-session browserverify
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

Lighthouse and performance trace:

```bash
bash scripts/browser-session.sh lighthouse browserverify snapshot desktop
bash scripts/browser-session.sh trace-start browserverify --reload --auto-stop
bash scripts/browser-session.sh trace-insight browserverify NAVIGATION_0 RenderBlocking
bash scripts/browser-session.sh trace-stop browserverify
```

Tool discovery and passthrough:

```bash
bash scripts/browser-session.sh tools-list --session browserverify
bash scripts/browser-session.sh tools-list --session browserverify performance
bash scripts/browser-session.sh tool-help --session browserverify performance-start-trace
bash scripts/browser-session.sh run-tool --session browserverify list-console-messages --types '["warn","error"]'
```

## Page targeting

Current `chrome-devtools-mcp` tools require `--page-id`. Wrappers resolve it automatically:

1. `PAGE_ID` env if set
2. else the `list-pages` entry marked `[selected]`
3. else the first open page

```bash
bash scripts/browser-session.sh list-pages browserverify
bash scripts/browser-session.sh new-page browserverify https://example.com
bash scripts/browser-session.sh select-page browserverify 2
PAGE_ID=2 bash scripts/browser-session.sh snapshot browserverify
```

`navigate` also passes `--type url` required by current schemas.

When wrappers fail with schema errors, use `tool-help` then `run-tool` with explicit flags.

## Behavior notes

- `wait-for-text` prints one-line success output by default.
  - Set `WAIT_FOR_VERBOSE=1` for full output.
- `ensure-session` and `start-session` use `MCP_SERVER_CMD` when provided.
- Wrapper commands fail fast when MCP returns tool-level errors.
- Prefer `run-tool` for brand-new MCP tools or flags the wrappers do not know yet.

## Failure handling

- If click/fill fails, take a fresh snapshot and retry.
- If selectors are unstable, use `eval` or raw `run-tool` fallback.
- If navigation fails, report command output as evidence.
- If a run is interrupted, use `session-list` and stop leaked sessions.

## Security

Do not use this workflow on pages with secrets or personal data you do not want in transcripts.

Do not pass secrets directly in command arguments; prefer environment variables or files.
