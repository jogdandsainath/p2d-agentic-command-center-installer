#!/usr/bin/env bash
# =============================================================================
# E-Divin Machine Onboarding Script — Cross-Platform (macOS / Linux)
# =============================================================================
# Usage:
#   curl -fsSL https://e-divin-agent-communication-service.vercel.app/install.sh | bash
#   OR locally:
#   bash scripts/onboard-machine.sh --squad ui-squad --runtime claude --product e-divin-eos
#
# Required env vars (or passed as flags):
#   E_DIVIN_AGENT_SERVICE_URL  — service base URL
#   SERVICE_SHARED_SECRET      — bearer token
#   E_DIVIN_ACTOR              — your GitHub username
#
# Flags:
#   --squad    SQUAD_KEY      squad to join (required)
#   --runtime  RUNTIME_TYPE   codex | claude | copilot | service (required)
#   --product  PRODUCT_KEY    product key (default: e-divin-eos)
#   --host     HOST_KEY       machine host key (default: hostname)
#   --url      SERVICE_URL    override service URL
#   --no-daemon               skip installing background runner daemon
# =============================================================================
set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
SQUAD_KEY=""
RUNTIME_TYPE=""
PRODUCT_KEY="e-divin-eos"
HOST_KEY="$(hostname -s 2>/dev/null || hostname)"
SERVICE_URL="${E_DIVIN_AGENT_SERVICE_URL:-https://e-divin-agent-communication-service.vercel.app}"
SECRET="${SERVICE_SHARED_SECRET:-}"
ACTOR="${E_DIVIN_ACTOR:-}"
NO_DAEMON=false
OS="$(uname -s)"   # Darwin | Linux
ARCH="$(uname -m)" # x86_64 | arm64

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}[e-divin]${NC} $*"; }
success() { echo -e "${GREEN}[e-divin]${NC} $*"; }
warn()    { echo -e "${YELLOW}[e-divin]${NC} $*"; }
error()   { echo -e "${RED}[e-divin]${NC} $*" >&2; exit 1; }

# ── Parse args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --squad)    SQUAD_KEY="$2";   shift 2 ;;
    --runtime)  RUNTIME_TYPE="$2"; shift 2 ;;
    --product)  PRODUCT_KEY="$2"; shift 2 ;;
    --host)     HOST_KEY="$2";    shift 2 ;;
    --url)      SERVICE_URL="$2"; shift 2 ;;
    --actor)    ACTOR="$2";       shift 2 ;;
    --no-daemon) NO_DAEMON=true;  shift ;;
    *) warn "Unknown flag: $1"; shift ;;
  esac
done

[[ -z "$SQUAD_KEY" ]]   && error "--squad is required (e.g. --squad ui-squad)"
[[ -z "$RUNTIME_TYPE" ]] && error "--runtime is required: codex | claude | copilot | service"
[[ -z "$SECRET" ]]       && error "Set SERVICE_SHARED_SECRET env var before running."
[[ -z "$ACTOR" ]]        && ACTOR="$(git config user.name 2>/dev/null || echo 'founder')"

SERVICE_URL="${SERVICE_URL%/}"
INSTALL_DIR="$HOME/.e-divin"
mkdir -p "$INSTALL_DIR/inbox/$SQUAD_KEY" "$INSTALL_DIR/outbox/$SQUAD_KEY" "$INSTALL_DIR/runtime"

info "E-Divin Machine Onboarding"
info "  OS:      $OS $ARCH"
info "  Squad:   $SQUAD_KEY"
info "  Runtime: $RUNTIME_TYPE"
info "  Product: $PRODUCT_KEY"
info "  Host:    $HOST_KEY"
info "  Service: $SERVICE_URL"
echo ""

# ── Helper: call service ──────────────────────────────────────────────────────
svc_post() {
  local path="$1" body="$2"
  curl -sf -X POST \
    -H "Authorization: Bearer $SECRET" \
    -H "X-E-Divin-Actor: $ACTOR" \
    -H "Content-Type: application/json" \
    -d "$body" \
    "$SERVICE_URL$path" || true
}

# ── Step 1: Install prerequisites by runtime type ────────────────────────────
info "Step 1: Installing prerequisites for $RUNTIME_TYPE …"

install_node() {
  if command -v node &>/dev/null; then
    NODE_VER=$(node --version)
    success "Node.js $NODE_VER already installed."
  else
    info "Installing Node.js 20 via nvm …"
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    # shellcheck disable=SC1091
    [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
    nvm install 20 && nvm use 20 && nvm alias default 20
    success "Node.js $(node --version) installed."
  fi
}

install_gh_cli() {
  if command -v gh &>/dev/null; then
    success "GitHub CLI $(gh --version | head -1) already installed."
    return
  fi
  info "Installing GitHub CLI …"
  if [[ "$OS" == "Darwin" ]]; then
    brew install gh 2>/dev/null || warn "brew install gh failed — install manually: https://cli.github.com"
  elif [[ "$OS" == "Linux" ]]; then
    if command -v apt-get &>/dev/null; then
      curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
      sudo apt-get update -qq && sudo apt-get install -y gh
    elif command -v yum &>/dev/null; then
      sudo dnf install -y 'dnf-command(config-manager)'
      sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
      sudo dnf install -y gh
    fi
  fi
  success "GitHub CLI installed."
}

case "$RUNTIME_TYPE" in
  codex)
    install_node
    if ! command -v codex &>/dev/null; then
      info "Installing OpenAI Codex CLI …"
      npm install -g @openai/codex 2>/dev/null || warn "codex CLI install failed — run: npm i -g @openai/codex"
    else
      success "Codex CLI already installed."
    fi
    ;;
  claude)
    if ! command -v claude &>/dev/null; then
      info "Installing Claude Code CLI …"
      if command -v npm &>/dev/null; then
        npm install -g @anthropic-ai/claude-code 2>/dev/null || warn "claude CLI install failed — install manually."
      else
        install_node
        npm install -g @anthropic-ai/claude-code 2>/dev/null || warn "claude CLI install failed."
      fi
    else
      success "Claude Code CLI already installed."
    fi
    ;;
  copilot)
    install_node
    install_gh_cli
    info "Verifying GitHub Copilot extension …"
    gh extension install github/gh-copilot 2>/dev/null || true
    success "GitHub Copilot CLI ready."
    ;;
  service)
    install_node
    ;;
esac

# ── Step 2: Write env config ──────────────────────────────────────────────────
info "Step 2: Writing environment configuration …"
ENV_FILE="$INSTALL_DIR/env"
cat > "$ENV_FILE" <<EOF
# E-Divin environment — sourced by runner daemon
export E_DIVIN_AGENT_SERVICE_URL="$SERVICE_URL"
export E_DIVIN_ACTOR="$ACTOR"
export E_DIVIN_SQUAD_KEY="$SQUAD_KEY"
export E_DIVIN_RUNTIME_TYPE="$RUNTIME_TYPE"
export E_DIVIN_PRODUCT_KEY="$PRODUCT_KEY"
export E_DIVIN_LOCAL_INBOX_ROOT="$INSTALL_DIR/inbox"
export E_DIVIN_LOCAL_OUTBOX_ROOT="$INSTALL_DIR/outbox"
export E_DIVIN_LOCAL_RUNTIME_ROOT="$INSTALL_DIR/runtime"
# SERVICE_SHARED_SECRET must already be set in your shell profile (do not store here)
EOF
success "Env config written to $ENV_FILE"

# Add to shell profile if not already there
SHELL_PROFILE="$HOME/.bashrc"
[[ "$SHELL" == *"zsh"* ]] && SHELL_PROFILE="$HOME/.zshrc"
if ! grep -q "e-divin/env" "$SHELL_PROFILE" 2>/dev/null; then
  echo "" >> "$SHELL_PROFILE"
  echo "# E-Divin agent runtime" >> "$SHELL_PROFILE"
  echo "[[ -f $ENV_FILE ]] && source $ENV_FILE" >> "$SHELL_PROFILE"
  success "Shell profile updated: $SHELL_PROFILE"
fi

# ── Step 3: Register machine with service ────────────────────────────────────
info "Step 3: Registering machine with E-Divin service …"
REG_BODY=$(cat <<JSON
{
  "hostKey": "$HOST_KEY",
  "displayName": "$HOST_KEY ($OS $RUNTIME_TYPE)",
  "hostType": "desktop",
  "squadKey": "$SQUAD_KEY",
  "squadDisplayName": "$SQUAD_KEY on $HOST_KEY",
  "runtimeType": "$RUNTIME_TYPE",
  "locationHint": "$RUNTIME_TYPE on $OS $ARCH",
  "productKey": "$PRODUCT_KEY"
}
JSON
)
REG_RESULT=$(svc_post "/machines/register" "$REG_BODY")
if echo "$REG_RESULT" | grep -q '"ok":true'; then
  success "Machine registered: $HOST_KEY"
else
  warn "Machine registration returned: $REG_RESULT (non-fatal, may already exist)"
fi

# ── Step 4: Write runner script ───────────────────────────────────────────────
info "Step 4: Writing background runner …"
RUNNER_SCRIPT="$INSTALL_DIR/runner.sh"
cat > "$RUNNER_SCRIPT" <<'RUNNER'
#!/usr/bin/env bash
# E-Divin background runner — polls for commands and dispatches to local agent
set -uo pipefail

INSTALL_DIR="$HOME/.e-divin"
ENV_FILE="$INSTALL_DIR/env"
LOG_FILE="$INSTALL_DIR/runner.log"
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

SERVICE_URL="${E_DIVIN_AGENT_SERVICE_URL:-}"
SECRET="${SERVICE_SHARED_SECRET:-}"
ACTOR="${E_DIVIN_ACTOR:-founder}"
SQUAD="${E_DIVIN_SQUAD_KEY:-}"
RUNTIME="${E_DIVIN_RUNTIME_TYPE:-codex}"
PRODUCT="${E_DIVIN_PRODUCT_KEY:-e-divin-eos}"
POLL_SECONDS="${E_DIVIN_POLL_SECONDS:-30}"

[[ -z "$SERVICE_URL" ]] && { echo "E_DIVIN_AGENT_SERVICE_URL not set" >> "$LOG_FILE"; exit 1; }
[[ -z "$SECRET" ]]      && { echo "SERVICE_SHARED_SECRET not set" >> "$LOG_FILE"; exit 1; }

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

svc() {
  local method="$1" path="$2" body="${3:-{}}"
  curl -sf -X "$method" \
    -H "Authorization: Bearer $SECRET" \
    -H "X-E-Divin-Actor: $ACTOR" \
    -H "Content-Type: application/json" \
    -d "$body" \
    "${SERVICE_URL%/}$path" 2>>"$LOG_FILE" || true
}

heartbeat() {
  svc POST /automation/runner-heartbeat \
    "{\"squadKey\":\"$SQUAD\",\"runtimeType\":\"$RUNTIME\",\"status\":\"active\",\"message\":\"$(date '+%H:%M:%S') $RUNTIME runner polling\",\"productKey\":\"$PRODUCT\"}" >/dev/null
}

log "E-Divin $RUNTIME runner started (squad: $SQUAD, product: $PRODUCT)"

while true; do
  heartbeat

  # Fetch queued commands for this squad
  FEED=$(svc GET "/automation/runner-feed?squadKey=$SQUAD&productKey=$PRODUCT" "")
  if echo "$FEED" | grep -q '"commands":\[{'; then
    echo "$FEED" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for cmd in data.get('commands', []):
    print(cmd['id'], cmd.get('command_type',''), cmd.get('target_agent_key',''))
" 2>/dev/null | while read -r CMD_ID CMD_TYPE AGENT_KEY; do
      log "Claiming command $CMD_ID ($CMD_TYPE → $AGENT_KEY)"
      CLAIM=$(svc POST "/commands/$CMD_ID/claim" '{}')
      if echo "$CLAIM" | grep -q '"ok":true'; then
        INBOX_FILE="$INSTALL_DIR/inbox/$SQUAD/cmd-$CMD_ID.md"
        echo "# Command $CMD_ID\nType: $CMD_TYPE\nAgent: $AGENT_KEY\nProduct: $PRODUCT\n\nCheck Command Center for full prompt." > "$INBOX_FILE"
        log "Command $CMD_ID written to inbox. Manual bridge required for $RUNTIME."
        # Post delivery evidence (manual bridge)
        svc POST "/commands/$CMD_ID/deliver" \
          "{\"deliveredBy\":\"$ACTOR\",\"deliveryMethod\":\"manual_bridge\",\"deliveryStatus\":\"delivered\",\"productKey\":\"$PRODUCT\"}" >/dev/null
      fi
    done
  fi

  sleep "$POLL_SECONDS"
done
RUNNER
chmod +x "$RUNNER_SCRIPT"
success "Runner script written: $RUNNER_SCRIPT"

# ── Step 5: Install daemon ────────────────────────────────────────────────────
if [[ "$NO_DAEMON" == "false" ]]; then
  info "Step 5: Installing background daemon …"

  if [[ "$OS" == "Darwin" ]]; then
    # launchd plist
    PLIST_PATH="$HOME/Library/LaunchAgents/com.e-divin.runner-$SQUAD_KEY.plist"
    cat > "$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>         <string>com.e-divin.runner-$SQUAD_KEY</string>
  <key>ProgramArguments</key>
  <array><string>/bin/bash</string><string>$RUNNER_SCRIPT</string></array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>SERVICE_SHARED_SECRET</key><string>$SECRET</string>
    <key>HOME</key><string>$HOME</string>
    <key>PATH</key><string>/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin</string>
  </dict>
  <key>RunAtLoad</key>     <true/>
  <key>KeepAlive</key>     <true/>
  <key>StandardOutPath</key><string>$INSTALL_DIR/runner.log</string>
  <key>StandardErrorPath</key><string>$INSTALL_DIR/runner-err.log</string>
</dict>
</plist>
PLIST
    launchctl load "$PLIST_PATH" 2>/dev/null && success "launchd daemon loaded: com.e-divin.runner-$SQUAD_KEY" \
      || warn "launchctl load failed — run manually: bash $RUNNER_SCRIPT &"

  elif [[ "$OS" == "Linux" ]]; then
    # systemd user unit
    mkdir -p "$HOME/.config/systemd/user"
    UNIT_FILE="$HOME/.config/systemd/user/e-divin-runner-${SQUAD_KEY}.service"
    cat > "$UNIT_FILE" <<UNIT
[Unit]
Description=E-Divin Squad Runner ($SQUAD_KEY - $RUNTIME_TYPE)
After=network-online.target

[Service]
Type=simple
ExecStart=/bin/bash $RUNNER_SCRIPT
Restart=on-failure
RestartSec=30
Environment=SERVICE_SHARED_SECRET=$SECRET
Environment=HOME=$HOME

[Install]
WantedBy=default.target
UNIT
    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user enable --now "e-divin-runner-${SQUAD_KEY}.service" 2>/dev/null \
      && success "systemd user service enabled: e-divin-runner-${SQUAD_KEY}" \
      || warn "systemd enable failed — run manually: bash $RUNNER_SCRIPT &"
  fi
else
  info "Skipping daemon install (--no-daemon)."
  info "Run manually: bash $RUNNER_SCRIPT &"
fi

# ── Step 6: Publish onboarding heartbeat ────────────────────────────────────
svc_post "/automation/runner-heartbeat" \
  "{\"squadKey\":\"$SQUAD_KEY\",\"runtimeType\":\"$RUNTIME_TYPE\",\"status\":\"active\",\"message\":\"Machine onboarded: $HOST_KEY ($OS $RUNTIME_TYPE)\",\"productKey\":\"$PRODUCT_KEY\"}" >/dev/null || true

echo ""
success "═══════════════════════════════════════════════"
success " E-Divin machine onboarding complete!"
success " Squad:   $SQUAD_KEY"
success " Runtime: $RUNTIME_TYPE"
success " Product: $PRODUCT_KEY"
success " Logs:    $INSTALL_DIR/runner.log"
success "═══════════════════════════════════════════════"
echo ""
warn  "ACTION: Add SERVICE_SHARED_SECRET to your shell profile (~/.bashrc or ~/.zshrc)"
warn  "  export SERVICE_SHARED_SECRET='your-secret-here'"
