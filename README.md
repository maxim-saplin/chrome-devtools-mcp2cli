# Chrome DevTools MCP through mcp2cli

A skill for agents that need to drive Chrome from a terminal, including agents without native MCP integration.

It wraps [Chrome DevTools MCP](https://github.com/ChromeDevTools/chrome-devtools-mcp) through [mcp2cli](https://github.com/knowsuchagency/mcp2cli), giving shell-first agents a repeatable way to start a browser session, navigate, inspect page state, interact with forms, read console/network evidence, and clean up.

It is meant for browser smoke tests, app-driving checks, and focused debugging from command-line-capable agents. Use direct MCP when your agent has native MCP support and you want the full typed tool surface inside the agent runtime.

## Field note

This skill came out of a small Copilot CLI experiment comparing direct Chrome DevTools MCP with a CLI-wrapper path over the same 9-step browser smoke test (3 runs per variant).

| Path | Fresh context | Completed-run message growth | Runtime notes |
|---|---:|---:|---|
| CLI skill through `mcp2cli` | 19k total, `MCP Tools` 155 | about 18-21k | 9/9 passes; slower in one run, steadier context growth |
| Direct Chrome DevTools MCP | 24k total, `MCP Tools` 4.9k | about 16-56k | 9/9 passes; fastest single run, more variance |

Direct MCP is richer; the CLI skill has basic set of MCP tools exposed and is useful when you want a shell-native path with progressive discovery and lower upfront tool-surface load.

[pi](https://pi.dev) is a good example of the target shape: a lean coding agent that can run commands but may not come with MCP mounted in the runtime. For that kind of agent, `mcp2cli` is less about replacing MCP and more about reaching MCP servers from the interface the agent already has.

## Why

Native MCP clients expose tool schemas directly to the model. That is convenient, but it has an upfront context cost and assumes the agent runtime can mount MCP servers.

Some agents are shell-first. They can run commands but do not come with MCP installed. For those agents, `mcp2cli` is a practical bridge: the agent discovers browser tools through CLI commands (`--list`, `--search`, command help, snapshots, small probes) and keeps the working workflow in a skill.

This skill packages that workflow:

- preflight local prerequisites before browser work
- use one named browser session for repeated commands
- prefer text snapshots and DOM assertions over screenshots
- prefer form-level interactions over many one-off clicks/fills
- inspect console and network output when the page misbehaves
- stop the session when done

## Install

From your project root (or add `-g` for a global install):

```bash
npx skills add maxim-saplin/chrome-devtools-mcp2cli
```

Manual alternative: copy everything under [`skills/chrome-devtools-mcp2cli/`](skills/chrome-devtools-mcp2cli/) into your agent's skills folder, for example:

```text
.agents/skills/chrome-devtools-mcp2cli
.claude/skills/chrome-devtools-mcp2cli
```

## Requirements

The target machine must have:

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

The included preflight script is Bash. On Windows it may work through Git Bash or WSL if `uvx`, Node.js, `npx`, and Chrome launching all work from that environment, but this package does not claim Windows support yet.

The skill starts Chrome DevTools MCP with an isolated browser profile by default.

By default it uses the Chrome DevTools MCP README posture:

```bash
npx -y chrome-devtools-mcp@latest --isolated
```

Override `MCP_SERVER_CMD` if a run needs headless mode, pinned versions, disabled usage statistics, disabled CrUX lookups, custom Chrome paths, or connection to an existing debuggable browser.

## Quick preflight

From the installed skill directory:

```bash
bash scripts/preflight.sh
```

Optional target smoke check:

```bash
bash scripts/preflight.sh http://localhost:8501 browser-preflight
```

Preflight checks browser-driving prerequisites. Target app reachability is not a mandatory preflight gate unless you pass a URL.

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
```

## Use

Ask in plain language:

- "Run a browser smoke test of the local app."
- "Open the app, verify the main navigation, inspect console errors, and report evidence."
- "Use a browser session to reproduce the failing interaction and capture page state."

The agent should run preflight first, keep one named session for repeated commands, and clean up the session at the end.

## Security and privacy

Chrome DevTools MCP can inspect and modify browser state. Do not use this skill against pages containing secrets or personal data you do not want exposed to the agent transcript.

When passing credentials to any MCP or API server through `mcp2cli`, use environment variables or files rather than literal command-line secrets.

Chrome DevTools MCP collects usage statistics by default and performance tooling may use CrUX data unless disabled. Set `MCP_SERVER_CMD` with the upstream privacy flags when that matters for the run.
