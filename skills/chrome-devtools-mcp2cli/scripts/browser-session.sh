#!/usr/bin/env bash
set -euo pipefail

DEFAULT_SERVER_CMD="${MCP_SERVER_CMD:-npx -y chrome-devtools-mcp@latest --isolated}"
WAIT_FOR_VERBOSE="${WAIT_FOR_VERBOSE:-0}"

usage() {
  cat <<'EOF'
Usage:
  browser-session.sh session-list
  browser-session.sh ensure-session [session-name] [server-cmd]
  browser-session.sh start-session [session-name] [server-cmd]
  browser-session.sh stop-session [session-name]
  browser-session.sh navigate [session-name] <url> [timeout-ms]
  browser-session.sh snapshot [session-name] [--verbose]
  browser-session.sh click-selector [session-name] <css-selector> [--dbl-click]
  browser-session.sh fill-selector [session-name] <css-selector> <value>
  browser-session.sh get-selector-text [session-name] <css-selector>
  browser-session.sh assert-selector-contains [session-name] <css-selector> <needle>
  browser-session.sh wait-for-text [session-name] <text> [timeout-ms]
  browser-session.sh eval [session-name] <js-function> [arg ...]

Defaults:
  session-name: browser
  server-cmd:   MCP_SERVER_CMD or npx -y chrome-devtools-mcp@latest --isolated

Environment:
  MCP_SERVER_CMD   default server command for ensure/start session
  WAIT_FOR_VERBOSE if set to 1, wait-for-text prints full wait output
EOF
}

json_array() {
  node -e 'process.stdout.write(JSON.stringify(process.argv.slice(1)))' "$@"
}

json_string() {
  node -e 'process.stdout.write(JSON.stringify(process.argv[1]))' "$1"
}

is_tool_error_output() {
  local output="$1"
  local first_line="${output%%$'\n'*}"
  [[ "$first_line" == Error:* || "$first_line" == Unable\ to* ]]
}

run_mcp2cli() {
  local output
  if ! output="$(uvx mcp2cli "$@" 2>&1)"; then
    printf '%s\n' "$output" >&2
    return 1
  fi

  if is_tool_error_output "$output"; then
    printf '%s\n' "$output" >&2
    return 1
  fi

  printf '%s\n' "$output"
}

session_exists() {
  local session="$1"
  uvx mcp2cli --session-list 2>/dev/null | awk -v name="$session" '
    $1 == name && $0 ~ /(^|[[:space:]])alive([[:space:]]|$)/ { found = 1 }
    END { exit(found ? 0 : 1) }
  '
}

ensure_session() {
  local session="$1"
  local server_cmd="$2"
  if session_exists "$session"; then
    echo "SESSION REUSE: '$session' is already alive"
    return 0
  fi
  run_mcp2cli --session-start "$session" --mcp-stdio "$server_cmd"
}

start_session() {
  local session="$1"
  local server_cmd="$2"
  run_mcp2cli --session-start "$session" --mcp-stdio "$server_cmd"
}

run_eval() {
  local session="$1"
  local function="$2"
  shift 2

  local args_json='[]'
  if (($# > 0)); then
    args_json="$(json_array "$@")"
  fi

  local wrapper
  wrapper=$(cat <<EOF
() => {
  const __args = $args_json;
  return (${function})(...__args);
}
EOF
)

  run_mcp2cli --session "$session" evaluate-script --function "$wrapper"
}

run_wait_for_text() {
  local session="$1"
  local text="$2"
  local timeout_ms="$3"
  local texts_json
  texts_json="$(json_array "$text")"

  local output
  if ! output="$(uvx mcp2cli --session "$session" wait-for --text "$texts_json" --timeout "$timeout_ms" 2>&1)"; then
    printf '%s\n' "$output" >&2
    return 1
  fi

  if is_tool_error_output "$output"; then
    printf '%s\n' "${output%%$'\n'*}" >&2
    return 1
  fi

  if [[ "$WAIT_FOR_VERBOSE" == "1" ]]; then
    printf '%s\n' "$output"
  else
    printf '%s\n' "${output%%$'\n'*}"
  fi
}

case "${1:-}" in
  -h|--help|"")
    usage
    exit 0
    ;;
  session-list)
    run_mcp2cli --session-list
    ;;
  ensure-session)
    shift
    ensure_session "${1:-browser}" "${2:-$DEFAULT_SERVER_CMD}"
    ;;
  start-session)
    shift
    start_session "${1:-browser}" "${2:-$DEFAULT_SERVER_CMD}"
    ;;
  stop-session)
    shift
    run_mcp2cli --session-stop "${1:-browser}"
    ;;
  navigate)
    shift
    session="${1:-browser}"
    if [[ $# -lt 2 ]]; then
      usage
      exit 1
    fi
    url="$2"
    timeout_ms="${3:-60000}"
    run_mcp2cli --session "$session" navigate-page --url "$url" --timeout "$timeout_ms"
    ;;
  snapshot)
    shift
    session="${1:-browser}"
    if [[ "${2:-}" == "--verbose" ]]; then
      run_mcp2cli --session "$session" take-snapshot --verbose
    else
      run_mcp2cli --session "$session" take-snapshot
    fi
    ;;
  click-selector)
    shift
    session="${1:-browser}"
    if [[ $# -lt 2 ]]; then
      usage
      exit 1
    fi
    selector_json="$(json_string "$2")"
    dbl_click="false"
    if [[ "${3:-}" == "--dbl-click" ]]; then
      dbl_click="true"
    fi
    fn=$(cat <<EOF
() => {
  const selector = $selector_json;
  const dblClick = $dbl_click;
  const el = document.querySelector(selector);
  if (!el) {
    throw new Error("Selector not found: " + selector);
  }
  if (dblClick) {
    el.dispatchEvent(new MouseEvent("dblclick", { bubbles: true, cancelable: true, view: window }));
  } else {
    el.click();
  }
  return { ok: true, selector, dblClick };
}
EOF
)
    run_mcp2cli --session "$session" evaluate-script --function "$fn"
    ;;
  fill-selector)
    shift
    session="${1:-browser}"
    if [[ $# -lt 3 ]]; then
      usage
      exit 1
    fi
    selector_json="$(json_string "$2")"
    value_json="$(json_string "$3")"
    fn=$(cat <<EOF
() => {
  const selector = $selector_json;
  const value = $value_json;
  const el = document.querySelector(selector);
  if (!el) {
    throw new Error("Selector not found: " + selector);
  }

  const tag = (el.tagName || "").toLowerCase();
  const type = String(el.type || "").toLowerCase();
  const dispatch = (node) => {
    node.dispatchEvent(new Event("input", { bubbles: true }));
    node.dispatchEvent(new Event("change", { bubbles: true }));
  };
  const setNativeValue = (node, nextValue) => {
    const proto = node instanceof HTMLTextAreaElement ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
    const desc = Object.getOwnPropertyDescriptor(proto, "value");
    if (desc && typeof desc.set === "function") {
      desc.set.call(node, nextValue);
    } else {
      node.value = nextValue;
    }
    dispatch(node);
  };

  if (tag === "select") {
    el.value = value;
    dispatch(el);
    return { ok: true, selector, value };
  }

  if (type === "checkbox") {
    const on = ["1", "true", "yes", "on", "checked"].includes(String(value).toLowerCase());
    if (el.checked !== on) {
      el.click();
    } else {
      dispatch(el);
    }
    return { ok: true, selector, value: on };
  }

  if (type === "radio") {
    const on = ["1", "true", "yes", "on", "checked"].includes(String(value).toLowerCase());
    if (on && !el.checked) {
      el.click();
    }
    return { ok: true, selector, value: on };
  }

  if ("value" in el) {
    setNativeValue(el, value);
    return { ok: true, selector, value };
  }

  if (el.isContentEditable) {
    el.focus();
    el.textContent = value;
    dispatch(el);
    return { ok: true, selector, value };
  }

  el.textContent = value;
  return { ok: true, selector, value };
}
EOF
)
    run_mcp2cli --session "$session" evaluate-script --function "$fn"
    ;;
  get-selector-text)
    shift
    session="${1:-browser}"
    if [[ $# -lt 2 ]]; then
      usage
      exit 1
    fi
    selector_json="$(json_string "$2")"
    fn=$(cat <<EOF
() => {
  const selector = $selector_json;
  const el = document.querySelector(selector);
  if (!el) {
    throw new Error("Selector not found: " + selector);
  }
  return (el.innerText || el.textContent || "").trim();
}
EOF
)
    run_mcp2cli --session "$session" evaluate-script --function "$fn"
    ;;
  assert-selector-contains)
    shift
    session="${1:-browser}"
    if [[ $# -lt 3 ]]; then
      usage
      exit 1
    fi
    selector_json="$(json_string "$2")"
    needle_json="$(json_string "$3")"
    fn=$(cat <<EOF
() => {
  const selector = $selector_json;
  const needle = $needle_json;
  const el = document.querySelector(selector);
  if (!el) {
    throw new Error("Selector not found: " + selector);
  }
  const actual = (el.innerText || el.textContent || "").trim();
  if (!actual.includes(needle)) {
    throw new Error("Expected " + selector + " to contain " + JSON.stringify(needle) + ", got " + JSON.stringify(actual));
  }
  return { ok: true, selector, needle, actual };
}
EOF
)
    run_mcp2cli --session "$session" evaluate-script --function "$fn"
    ;;
  wait-for-text)
    shift
    session="${1:-browser}"
    if [[ $# -lt 2 ]]; then
      usage
      exit 1
    fi
    text="$2"
    timeout_ms="${3:-0}"
    run_wait_for_text "$session" "$text" "$timeout_ms"
    ;;
  eval)
    shift
    session="${1:-browser}"
    if [[ $# -lt 2 ]]; then
      usage
      exit 1
    fi
    function="$2"
    shift 2
    run_eval "$session" "$function" "$@"
    ;;
  *)
    usage
    exit 1
    ;;
esac
