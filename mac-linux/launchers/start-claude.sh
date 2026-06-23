#!/usr/bin/env bash
# =============================================================================
# E-Divin Agentic Platform — Anthropic Claude Code Launcher (macOS/Linux)
# Usage: ./start-claude.sh [--agent-key KEY] [--product-key KEY] [-- <claude args>]
# =============================================================================
set -euo pipefail

AGENT_KEY="${E_DIVIN_ACTOR:-}"
PRODUCT_KEY="${E_DIVIN_PRODUCT_KEY:-}"
SQUAD_KEY="${E_DIVIN_SQUAD_KEY:-}"
CONFIG_PATH="${E_DIVIN_CONFIG:-${HOME}/.local/share/e-divin/runner/config.json}"
EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent-key)   AGENT_KEY="$2";   shift 2 ;;
    --product-key) PRODUCT_KEY="$2"; shift 2 ;;
    --squad-key)   SQUAD_KEY="$2";   shift 2 ;;
    --config)      CONFIG_PATH="$2"; shift 2 ;;
    --)            shift; EXTRA_ARGS+=("$@"); break ;;
    *)             EXTRA_ARGS+=("$1"); shift ;;
  esac
done

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
  export E_DIVIN_TOOL="claude"
  echo "[E-Divin] Claude launcher: product=$PRODUCT_KEY squad=$SQUAD_KEY agent=$AGENT_KEY"
fi

RUNTIME_ROOT="$(dirname "$CONFIG_PATH")"
INBOX_PATH="$RUNTIME_ROOT/inbox"
mkdir -p "$INBOX_PATH"
EVENT_FILE="$INBOX_PATH/tool-launch-event-claude-$(date +%Y%m%d-%H%M%S).json"
python3 - <<PYEOF
import json, datetime, os
json.dump({"eventType":"tool_launch","toolKey":"claude","agentKey":"$AGENT_KEY",
  "productKey":"$PRODUCT_KEY","squadKey":"$SQUAD_KEY","hostKey":os.uname().nodename,
  "launchedAt":datetime.datetime.utcnow().isoformat()+"Z","processId":os.getpid()},
  open("$EVENT_FILE","w"), indent=2)
PYEOF
echo "[E-Divin] Tool-launch event: $EVENT_FILE"

LATEST_PROMPT=$(ls -t "$INBOX_PATH"/prompt-packet-claude-*.json 2>/dev/null | head -1 || true)
if [[ -n "$LATEST_PROMPT" && -f "$LATEST_PROMPT" ]]; then
  PROMPT_BODY=$(python3 -c "import json; d=json.load(open('$LATEST_PROMPT')); print(d.get('promptBody',''))" 2>/dev/null || true)
  if [[ -n "$PROMPT_BODY" ]]; then
    export CLAUDE_SYSTEM_PROMPT="$PROMPT_BODY"
    export ANTHROPIC_PROMPT_FILE="$LATEST_PROMPT"
    echo "[E-Divin] Startup prompt injected from $LATEST_PROMPT"
  fi
fi

echo "[E-Divin] Starting Anthropic Claude Code..."
if command -v claude &>/dev/null; then
  exec claude "${EXTRA_ARGS[@]}"
else
  echo "[E-Divin] 'claude' not found. Trying npx..."
  exec npx @anthropic-ai/claude-code "${EXTRA_ARGS[@]}"
fi
