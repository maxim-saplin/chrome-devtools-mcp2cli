---
name: chrome-devtools-mcp2cli
description: Use mcp2cli as a CLI shim for Chrome DevTools MCP to drive a live Chrome browser from terminal-first agents. Use when native MCP is unavailable or when you want browser smoke tests, app driving, console/network inspection, or page-state evidence through shell commands with progressive tool discovery.
---
# Chrome DevTools MCP through mcp2cli

Use this skill when you need to drive Chrome from the terminal through `mcp2cli`, especially in agents that can run shell commands but do not have native MCP servers mounted, or when you want a shell-native browser workflow with progressive command discovery.

Direct Chrome DevTools MCP remains the richer native interface when your agent has MCP available. This skill packages a terminal-first workflow for smoke tests, app checks, and focused debugging.

## Mental model

Native MCP exposes tool definitions directly to the agent. This CLI path makes the agent discover and use the tool surface through command-line affordances:

1. preflight browser-driving prerequisites
2. start one named session
3. navigate to the target app
4. inspect page state through snapshots or script assertions
5. interact with stable controls
6. inspect console/network only when needed
7. stop the session

Keep discovery progressive. Do not dump every available command into the conversation when the task only needs navigation, snapshots, and one or two interactions.

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

Override it when needed:

```bash
MCP_SERVER_CMD='npx -y chrome-devtools-mcp@latest --isolated --headless' bash scripts/preflight.sh
```

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

Useful environment variables:

- `MCP_SERVER_CMD` — override the Chrome DevTools MCP server command
- `NAV_TIMEOUT_MS` — override navigation timeout, default `60000`
- `KEEP_LOG_ON_FAIL=1` — keep preflight temp logs on failure

If preflight fails, stop and fix the missing prerequisite first.

## Session flow

Use one named session for repeated browser commands. Replace `browser` if another session is already active.

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

Use verbose snapshots only when necessary; they can get large:

```bash
uvx mcp2cli --session browser take-snapshot --verbose
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

Start narrow and ask for command help only when needed:

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
- `fill-form`
- `type-text`
- `press-key`
- `wait-for`
- `list-console-messages`
- `get-console-message`
- `list-network-requests`
- `get-network-request`
- `take-screenshot`

Prefer these defaults:

- `take-snapshot` before `take-screenshot` for ordinary page-state evidence.
- `fill-form` over many individual `fill` or `click` calls when interacting with forms.
- `evaluate-script` for exact assertions, route checks, counters, and DOM values.
- console/network commands only after a page misbehaves or when the task asks for diagnostics.
- one session per target app unless the task explicitly needs more.

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
- Always stop the browser session before handoff.

## Security notes

Chrome DevTools MCP can inspect and modify browser state. Do not use it on pages with secrets or personal information that should not enter the agent transcript.

Do not pass secrets literally on the command line. Prefer environment variables or files when a target MCP/API requires credentials.

Chrome DevTools MCP collects usage statistics by default and may use CrUX data for performance tooling. If that matters for the task, set the server command explicitly, for example with `--no-usage-statistics`, `--no-performance-crux`, or the documented environment variables from Chrome DevTools MCP.
