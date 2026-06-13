---
name: chrome-devtools-mcp2cli
description: Use mcp2cli as a CLI shim for Chrome DevTools MCP to drive a live Chrome browser from terminal-first agents. Use when native MCP is unavailable or when you want browser smoke tests, app driving, console/network inspection, or page-state evidence through shell commands with progressive tool discovery.
---
# Chrome DevTools MCP through mcp2cli

Use this skill when you need to drive Chrome from the terminal through `mcp2cli`, especially in agents that can run shell commands but do not have native MCP servers mounted.

Direct Chrome DevTools MCP remains the richer native interface when your agent already has MCP available. This skill packages a terminal-first workflow for smoke tests, app checks, and focused debugging.

## Mental model

Keep browser work small and repeatable:

1. preflight the browser-driving prerequisites
2. check whether a live session already exists
3. start or reuse one named session per app
4. navigate to the target app once
5. use selector-first helpers for normal interaction
6. fall back to raw `mcp2cli` commands only when debugging
7. stop the session once the app checks are finished

Do not turn every browser action into a fresh session. The point of this skill is to keep one app session live across related checks.

## Requirements

The machine needs:

- `uvx`
- Node.js
- `npx`
- Google Chrome or Chrome for Testing available to `chrome-devtools-mcp`

## Platform support

Tested here:

- macOS

Expected, but not verified in this package:

- Linux, assuming `uvx`, Node.js, `npx`, and Chrome/Chrome for Testing are installed and available on `PATH`

Not tested:

- Windows native shells

The included preflight script is Bash. On Windows it may work through Git Bash or WSL if `uvx`, Node.js, `npx`, and Chrome launching all work from that environment, but do not claim Windows support from this package yet.

The default MCP server command is:

```bash
npx -y chrome-devtools-mcp@latest --isolated
```

This follows the Chrome DevTools MCP README recommendation to use `@latest`. If a task needs strict reproducibility, override `MCP_SERVER_CMD` with a pinned version for that run.

## Preflight first

Before browser work, run preflight from the skill root:

```bash
bash scripts/preflight.sh
```

Optional target navigation smoke check:

```bash
bash scripts/preflight.sh <target-url> [session-name]
```

Preflight validates local/browser-driving prerequisites:

- `uvx`, `node`, and `npx` exist
- the Chrome DevTools MCP server can start
- `mcp2cli` can list pages
- the browser can navigate to `about:blank`
- a page snapshot contains `RootWebArea`

Target URL reachability is intentionally optional. App availability should normally be exposed by the real browser-driving command, not hidden inside prerequisite setup.

## Persistent app session workflow

For a live app, keep one named session open across all related checks.

### 1) Check existing sessions

```bash
bash scripts/browser-session.sh session-list
```

If the app session is already alive, reuse it instead of starting a second one.

### 2) Start or reuse the app session

```bash
bash scripts/browser-session.sh ensure-session browserverify
```

Override the session name when another app is already using `browserverify`.

When `server-cmd` is omitted, `ensure-session` and `start-session` use `MCP_SERVER_CMD` if set, otherwise `npx -y chrome-devtools-mcp@latest --isolated`.

### 3) Navigate once

```bash
bash scripts/browser-session.sh navigate browserverify http://localhost:8000/docs/index.html
```

### 4) Use selector-first helpers

Examples:

```bash
bash scripts/browser-session.sh snapshot browserverify
bash scripts/browser-session.sh click-selector browserverify '#leaderboard tbody tr'
bash scripts/browser-session.sh fill-selector browserverify '#search' 'queen'
bash scripts/browser-session.sh get-selector-text browserverify '#cost-per-elo'
bash scripts/browser-session.sh assert-selector-contains browserverify '#cost-per-elo' 'Cost/Elo:'
bash scripts/browser-session.sh wait-for-text browserverify 'Leaderboard'
```

Use raw `mcp2cli` directly only when you need to inspect a lower-level command or debug a failure.

### 5) Stop the session once done

```bash
bash scripts/browser-session.sh stop-session browserverify
```

If a session is left behind after an interrupted run, use `session-list` to find it, then stop it explicitly.

## Raw mcp2cli fallback

The wrapper script is the normal path, but the underlying commands remain available.

Start a session:

```bash
uvx mcp2cli --session-start browser \
  --mcp-stdio "npx -y chrome-devtools-mcp@latest --isolated"
```

Navigate:

```bash
uvx mcp2cli --session browser navigate-page --url "<target-url>" --timeout 60000
```

Inspect current page state:

```bash
uvx mcp2cli --session browser take-snapshot
```

Run a precise DOM assertion:

```bash
uvx mcp2cli --session browser evaluate-script \
  --function "() => ({ href: location.href, title: document.title, h1: document.querySelector('h1')?.innerText || null })"
```

Stop the session:

```bash
uvx mcp2cli --session-stop browser
```

Confirm cleanup when needed:

```bash
uvx mcp2cli --session-list
```

## Useful browser commands

Keep discovery progressive. Ask for command help only when needed:

```bash
uvx mcp2cli --session browser <command> --help
```

Common commands:

- `list-pages`
- `select-page`
- `navigate-page`
- `take-snapshot`
- `evaluate-script`
- `click`
- `fill`
- `fill-form`
- `press-key`
- `wait-for`
- `list-console-messages`
- `get-console-message`
- `list-network-requests`
- `get-network-request`
- `take-screenshot`

Prefer these defaults:

- `take-snapshot` before `take-screenshot` for ordinary page-state evidence.
- `fill-form` or the selector-first `fill-selector` helper over many individual click/fill steps.
- `evaluate-script` for exact assertions, route checks, counters, and DOM values.
- console/network commands only after a page misbehaves or when the task asks for diagnostics.
- one session per target app unless the task explicitly needs more.

## Selector-first wrapper behavior

The helper script turns common actions into selector-based operations so the normal flow does not bounce through uid resolution.

Use `click-selector` for stable elements, `fill-selector` for inputs/selects/checkboxes/radios, `get-selector-text` to read content, and `assert-selector-contains` for direct pass/fail checks.

Use `wait-for-text` for page-wide text that should eventually appear.

By default `wait-for-text` returns a concise one-line success message; set `WAIT_FOR_VERBOSE=1` when you need the full wait output and snapshot.

If a control is too dynamic or the helper is not enough, drop to `evaluate-script` or the raw `click`/`fill` commands as needed.

## Smoke-test reporting pattern

For browser smoke tests, report each step as:

```text
PASS/FAIL | reason | concrete evidence string
```

Prefer evidence like:

- current URL
- page title
- heading text
- visible navigation label
- form control label
- console error count or exact message
- network request status

Avoid using screenshots as primary evidence unless the failure is visual.

## Failure handling

- If a click times out, take a fresh snapshot before retrying; element IDs can go stale.
- If a checkbox or similar control is non-interactive, try the associated label once and record that fallback.
- If a snapshot is huge, use `evaluate-script` for a smaller assertion instead of repeatedly dumping page state.
- If navigation fails, report the command output as app reachability evidence rather than treating it as a preflight prerequisite failure.
- If a session already exists, reuse it instead of starting a duplicate.
- Always stop the browser session before handoff unless the task explicitly needs it left alive.

## Security notes

Chrome DevTools MCP can inspect and modify browser state. Do not use it on pages with secrets or personal information that should not enter the agent transcript.

Do not pass secrets literally on the command line. Prefer environment variables or files when a target MCP/API requires credentials.

Chrome DevTools MCP collects usage statistics by default and may use CrUX data for performance tooling. If that matters for the task, set the server command explicitly, for example with `--no-usage-statistics`, `--no-performance-crux`, or the documented environment variables from Chrome DevTools MCP.
