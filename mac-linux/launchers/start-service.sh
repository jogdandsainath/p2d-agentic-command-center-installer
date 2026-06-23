#!/usr/bin/env bash
# =============================================================================
# E-Divin Agentic Platform — Service/Backend Agent Launcher (macOS/Linux)
# Usage: ./start-service.sh [--entry-point dist/index.js] [--agent-key KEY] [-- <node args>]
# =============================================================================
set -euo pipefail

AGENT_KEY="${E_DIVIN_ACTOR:-}"
PRODUCT_KEY="${E_DIVIN_PRODUCT_KEY:-}"
SQUAD_KEY="${E_DIVIN_SQUAD_KEY:-}"
ENTRY_POINT=""
CONFIG_PATH="${E_DIVIN_CONFIG:-${HOME}/.local/share/e-divin/runner/config.json}"
EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent-key)    AGENT_KEY="$2";    shift 2 ;;
    --product-key)  PRODUCT_KEY="$2";  shift 2 ;;
    --squad-key)    SQUAD_KEY="$2";    shift 2 ;;
    --entry-point)  ENTRY_POINT="$2";  shift 2 ;;
    --config)       CONFIG_PATH="$2";  shift 2 ;;
    --)             shift; EXTRA_ARGS+=("$@"); break ;;
    *)              EXTRA_ARGS+=("$1"); shift ;;
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
  export E_DIVIN_TOOL="service"
  echo "[E-Divin] Service launcher: product=$PRODUCT_KEY squad=$SQUAD_KEY agent=$AGENT_KEY"
fi

RUNTIME_ROOT="$(dirname "$CONFIG_PATH")"
INBOX_PATH="$RUNTIME_ROOT/inbox"
mkdir -p "$INBOX_PATH"
EVENT_FILE="$INBOX_PATH/tool-launch-event-service-$(date +%Y%m%d-%H%M%S).json"
python3 - <<PYEOF
import json, datetime, os
json.dump({"eventType":"tool_launch","toolKey":"service","agentKey":"$AGENT_KEY",
  "productKey":"$PRODUCT_KEY","squadKey":"$SQUAD_KEY","hostKey":os.uname().nodename,
  "launchedAt":datetime.datetime.utcnow().isoformat()+"Z","processId":os.getpid()},
  open("$EVENT_FILE","w"), indent=2)
PYEOF
echo "[E-Divin] Tool-launch event: $EVENT_FILE"

LATEST_PROMPT=$(ls -t "$INBOX_PATH"/prompt-packet-service-*.json 2>/dev/null | head -1 || true)
if [[ -n "$LATEST_PROMPT" && -f "$LATEST_PROMPT" ]]; then
  PROMPT_BODY=$(python3 -c "import json; d=json.load(open('$LATEST_PROMPT')); print(d.get('promptBody',''))" 2>/dev/null || true)
  if [[ -n "$PROMPT_BODY" ]]; then
    export E_DIVIN_SYSTEM_PROMPT="$PROMPT_BODY"
    echo "[E-Divin] Startup prompt set in E_DIVIN_SYSTEM_PROMPT."
  fi
fi

if [[ -n "$ENTRY_POINT" ]]; then
  echo "[E-Divin] Starting service: node $ENTRY_POINT"
  exec node "$ENTRY_POINT" "${EXTRA_ARGS[@]}"
else
  echo "[E-Divin] No --entry-point given. E-Divin env vars are exported. Run your service manually."
  echo "  E_DIVIN_PRODUCT_KEY=$PRODUCT_KEY  E_DIVIN_ACTOR=$AGENT_KEY"
fi
