#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: preflight.sh [target-url] [session-name]

Checks prerequisites required to drive Chrome via mcp2cli:
- required commands are available (uvx, node, npx)
- chrome-devtools-mcp session can start
- mcp2cli can list pages, navigate to about:blank, and capture a snapshot

Optional: if target-url is provided, also tries navigation to that URL.

Environment:
  MCP_SERVER_CMD               Full MCP server command override
  NAV_TIMEOUT_MS               Navigation timeout in milliseconds (default: 60000)
  KEEP_LOG_ON_FAIL             Keep temporary log file on failure when set to 1
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

TARGET_URL="${1:-}"
SESSION_NAME="${2:-browser-preflight}"
SERVER_CMD="${MCP_SERVER_CMD:-npx -y chrome-devtools-mcp@latest --isolated}"
NAV_TIMEOUT_MS="${NAV_TIMEOUT_MS:-60000}"
KEEP_LOG_ON_FAIL="${KEEP_LOG_ON_FAIL:-0}"

fail() {
  echo "PREFLIGHT FAIL: $*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

for cmd in uvx node npx; do
  need_cmd "$cmd"
done

tmp_log="$(mktemp -t chrome-devtools-mcp-preflight.XXXXXX.log)"
cleanup() {
  local exit_code=$?
  uvx mcp2cli --session-stop "$SESSION_NAME" >/dev/null 2>&1 || true
  if [[ "$exit_code" -eq 0 || "$KEEP_LOG_ON_FAIL" == "0" ]]; then
    rm -f "$tmp_log"
  else
    echo "PREFLIGHT INFO: keeping log at $tmp_log" >&2
  fi
}
trap cleanup EXIT

if ! uvx mcp2cli --session-start "$SESSION_NAME" --mcp-stdio "$SERVER_CMD" >"$tmp_log" 2>&1; then
  cat "$tmp_log" >&2
  fail "unable to start chrome-devtools-mcp session '$SESSION_NAME'"
fi

if ! uvx mcp2cli --session "$SESSION_NAME" list-pages >"$tmp_log" 2>&1; then
  cat "$tmp_log" >&2
  fail "chrome-devtools-mcp session '$SESSION_NAME' started, but list-pages failed"
fi

if ! uvx mcp2cli --session "$SESSION_NAME" navigate-page --url "about:blank" --timeout "$NAV_TIMEOUT_MS" >"$tmp_log" 2>&1; then
  cat "$tmp_log" >&2
  fail "chrome-devtools-mcp could not navigate to about:blank"
fi

snapshot="$(uvx mcp2cli --session "$SESSION_NAME" take-snapshot 2>&1)"
if [[ "$snapshot" != *"RootWebArea"* ]]; then
  echo "$snapshot" >&2
  fail "snapshot did not contain a RootWebArea"
fi

if [[ -n "$TARGET_URL" ]]; then
  if ! uvx mcp2cli --session "$SESSION_NAME" navigate-page --url "$TARGET_URL" --timeout "$NAV_TIMEOUT_MS" >"$tmp_log" 2>&1; then
    cat "$tmp_log" >&2
    fail "target navigation failed: $TARGET_URL"
  fi

  target_snapshot="$(uvx mcp2cli --session "$SESSION_NAME" take-snapshot 2>&1)"
  if [[ "$target_snapshot" != *"RootWebArea"* ]]; then
    echo "$target_snapshot" >&2
    fail "target snapshot did not contain a RootWebArea"
  fi

  echo "PREFLIGHT PASS: prerequisites OK; target navigation succeeded: $TARGET_URL"
  exit 0
fi

echo "PREFLIGHT PASS: prerequisites OK (session start, list-pages, about:blank navigation, snapshot)"
