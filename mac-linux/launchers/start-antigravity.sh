#!/usr/bin/env bash
# =============================================================================
# E-Divin Agentic Platform — Google Antigravity Launcher (macOS/Linux)
#
# 1. Loads E-Divin runner config and exports workspace env vars
# 2. Writes a tool-launch event to the runner inbox (triggers heartbeat + prompt delivery)
# 3. Injects the startup prompt into:
#      - ANTIGRAVITY_SYSTEM_PROMPT (env var for CLI pickup)
#      - AGENTS.md or .agents/AGENTS.md in the workspace (native context file)
# 4. Starts Antigravity CLI if available, otherwise prints instructions
#
# Usage:
#   ./start-antigravity.sh [--agent-key KEY] [--product-key KEY] [--work-dir PATH]
#                          [--open-browser] [-- <antigravity args>]
# =============================================================================
set -euo pipefail

AGENT_KEY="${E_DIVIN_ACTOR:-}"
PRODUCT_KEY="${E_DIVIN_PRODUCT_KEY:-}"
SQUAD_KEY="${E_DIVIN_SQUAD_KEY:-}"
WORK_DIR="."
OPEN_BROWSER=false
CONFIG_PATH="${E_DIVIN_CONFIG:-${HOME}/.local/share/e-divin/runner/config.json}"
EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent-key)    AGENT_KEY="$2";    shift 2 ;;
    --product-key)  PRODUCT_KEY="$2";  shift 2 ;;
    --squad-key)    SQUAD_KEY="$2";    shift 2 ;;
    --work-dir)     WORK_DIR="$2";     shift 2 ;;
    --config)       CONFIG_PATH="$2";  shift 2 ;;
    --open-browser) OPEN_BROWSER=true; shift ;;
    --)             shift; EXTRA_ARGS+=("$@"); break ;;
    *)              EXTRA_ARGS+=("$1"); shift ;;
  esac
done

# ── 1. Load runner config ─────────────────────────────────────────────────────
if [[ -f "$CONFIG_PATH" ]]; then
  _jq() { python3 -c "import json; d=json.load(open('$CONFIG_PATH')); print(d.get('$1',''))" 2>/dev/null || true; }
  [[ -z "$AGENT_KEY"   ]] && AGENT_KEY="$(_jq actor)"
  [[ -z "$PRODUCT_KEY" ]] && PRODUCT_KEY="$(_jq productKey)"
  [[ -z "$SQUAD_KEY"   ]] && SQUAD_KEY="$(_jq squadKey)"
  export E_DIVIN_PRODUCT_KEY="$PRODUCT_KEY"
  export E_DIVIN_SQUAD_KEY="$SQUAD_KEY"
  export E_DIVIN_HOST_KEY="${E_DIVIN_HOST_KEY:-$(hostname)}"
  export E_DIVIN_SERVICE_URL="${E_DIVIN_SERVICE_URL:-$(_jq serviceUrl)}"
  export E_DIVIN_ACTOR="$AGENT_KEY"
  export E_DIVIN_TOOL="antigravity"
  echo "[E-Divin] Antigravity launcher: product=$PRODUCT_KEY squad=$SQUAD_KEY agent=$AGENT_KEY host=$E_DIVIN_HOST_KEY"
else
  echo "[E-Divin] Warning: runner config not found at $CONFIG_PATH. Launching without Command Center context."
fi

# ── 2. Write tool-launch event ────────────────────────────────────────────────
RUNTIME_ROOT="$(dirname "$CONFIG_PATH")"
INBOX_PATH="$RUNTIME_ROOT/inbox"
mkdir -p "$INBOX_PATH"

WORK_DIR_ABS="$(cd "$WORK_DIR" 2>/dev/null && pwd || echo "$WORK_DIR")"
EVENT_FILE="$INBOX_PATH/tool-launch-event-antigravity-$(date +%Y%m%d-%H%M%S).json"
python3 - <<PYEOF
import json, datetime, os
json.dump({
  "eventType": "tool_launch",
  "toolKey": "antigravity",
  "agentKey": "$AGENT_KEY",
  "productKey": "$PRODUCT_KEY",
  "squadKey": "$SQUAD_KEY",
  "hostKey": os.uname().nodename,
  "launchedAt": datetime.datetime.utcnow().isoformat() + "Z",
  "processId": os.getpid(),
  "machineName": os.uname().nodename,
  "workDir": "$WORK_DIR_ABS"
}, open("$EVENT_FILE", "w"), indent=2)
PYEOF
echo "[E-Divin] Tool-launch event: $EVENT_FILE"
echo "[E-Divin] Runner will deliver startup prompt on next poll (heartbeat registered)."

# ── 3. Inject startup prompt ──────────────────────────────────────────────────
LATEST_PROMPT=$(ls -t "$INBOX_PATH"/prompt-packet-antigravity-*.json 2>/dev/null | head -1 || true)
if [[ -n "$LATEST_PROMPT" && -f "$LATEST_PROMPT" ]]; then
  PROMPT_BODY=$(python3 -c "import json; d=json.load(open('$LATEST_PROMPT')); print(d.get('promptBody',''))" 2>/dev/null || true)
  PROMPT_VER=$(python3 -c "import json; d=json.load(open('$LATEST_PROMPT')); print(d.get('promptVersion',1))" 2>/dev/null || echo "1")

  if [[ -n "$PROMPT_BODY" ]]; then
    # Primary: env var
    export ANTIGRAVITY_SYSTEM_PROMPT="$PROMPT_BODY"

    # Secondary: inject into AGENTS.md (Antigravity's native context file)
    if [[ -d "$WORK_DIR_ABS/.agents" ]]; then
      AGENTS_FILE="$WORK_DIR_ABS/.agents/AGENTS.md"
    else
      AGENTS_FILE="$WORK_DIR_ABS/AGENTS.md"
    fi

    HEADER="<!-- E-Divin Startup Prompt — injected by start-antigravity.sh -->
<!-- Agent: $AGENT_KEY | Product: $PRODUCT_KEY | Prompt v${PROMPT_VER} | $(date -u +%Y-%m-%dT%H:%M:%SZ) -->

${PROMPT_BODY}

<!-- END E-Divin Startup Prompt -->"

    if [[ -f "$AGENTS_FILE" ]]; then
      # Remove previous injection block, prepend new one
      EXISTING=$(python3 -c "
import re, sys
txt = open('$AGENTS_FILE').read()
txt = re.sub(r'<!-- E-Divin Startup Prompt.*?<!-- END E-Divin Startup Prompt -->\n?', '', txt, flags=re.DOTALL)
sys.stdout.write(txt)
")
      printf '%s\n\n%s' "$HEADER" "$EXISTING" > "$AGENTS_FILE"
    else
      printf '%s\n' "$HEADER" > "$AGENTS_FILE"
    fi

    echo "[E-Divin] Startup prompt v${PROMPT_VER} injected:"
    echo "           - env: ANTIGRAVITY_SYSTEM_PROMPT"
    echo "           - file: $AGENTS_FILE"
  fi
else
  echo "[E-Divin] No prompt packet found yet. The runner will deliver one shortly after the tool-launch event is processed."
  echo "[E-Divin] Re-run this launcher after a few seconds, or check the runner log."
fi

# ── 4. Launch Antigravity ─────────────────────────────────────────────────────
echo ""
echo "[E-Divin] Starting Google Antigravity..."
echo "          Workspace : $WORK_DIR_ABS"
echo "          Product   : $PRODUCT_KEY"
echo "          Agent     : $AGENT_KEY"
echo ""

if command -v antigravity &>/dev/null; then
  exec antigravity "${EXTRA_ARGS[@]}"
elif command -v ag &>/dev/null; then
  exec ag "${EXTRA_ARGS[@]}"
else
  # Open Command Center sessions view in browser if requested
  if $OPEN_BROWSER && [[ -n "${E_DIVIN_SERVICE_URL:-}" ]]; then
    SESSIONS_URL="${E_DIVIN_SERVICE_URL%/}/p2d-command-center/sessions"
    echo "[E-Divin] Opening Command Center: $SESSIONS_URL"
    if command -v open &>/dev/null; then
      open "$SESSIONS_URL"
    elif command -v xdg-open &>/dev/null; then
      xdg-open "$SESSIONS_URL"
    fi
  else
    echo "[E-Divin] Antigravity CLI not found. Env vars and AGENTS.md are ready."
    echo "          Open your Antigravity workspace manually — the product context is set."
    echo ""
    echo "  export E_DIVIN_PRODUCT_KEY='$PRODUCT_KEY'"
    echo "  export E_DIVIN_SQUAD_KEY='$SQUAD_KEY'"
    echo "  export E_DIVIN_ACTOR='$AGENT_KEY'"
    echo "  export E_DIVIN_TOOL='antigravity'"
    [[ -n "${ANTIGRAVITY_SYSTEM_PROMPT:-}" ]] && echo "  export ANTIGRAVITY_SYSTEM_PROMPT='[set, ${#ANTIGRAVITY_SYSTEM_PROMPT} chars]'"
  fi
fi
