<#
.SYNOPSIS
  Launcher for Google Antigravity (AI Coding Assistant) — E-Divin Agentic Platform.

  Antigravity is an agentic AI coding environment built by Google DeepMind.
  This launcher:
    1. Loads the E-Divin runner config and sets workspace env vars
    2. Writes a tool-launch event to the runner inbox so the squad runner
       registers a visible session heartbeat and delivers the startup prompt
    3. Injects the startup prompt via ANTIGRAVITY_SYSTEM_PROMPT env var
       and writes it to AGENTS.md / .agents/AGENTS.md for context pickup
    4. Optionally opens the Antigravity workspace in the browser

.USAGE
  .\start-antigravity.ps1 [-AgentKey "my-agent"] [-ProductKey "my-product"] [-WorkDir "D:\MyRepo"]

.NOTES
  ANTIGRAVITY_SYSTEM_PROMPT is picked up automatically if Antigravity CLI supports it.
  AGENTS.md injection is the primary context delivery mechanism for repo-based workspaces.
#>
param(
  [string]$AgentKey    = "",
  [string]$ProductKey  = "",
  [string]$SquadKey    = "",
  [string]$WorkDir     = ".",
  [string]$ConfigPath  = (Join-Path $env:LOCALAPPDATA "E-Divin\runner\config.json"),
  [switch]$OpenBrowser
)

$ErrorActionPreference = "Continue"

# ── 1. Load runner config ─────────────────────────────────────────────────────
if (-not (Test-Path -LiteralPath $ConfigPath)) {
  Write-Warning "[E-Divin] Runner config not found at $ConfigPath. Antigravity will launch without Command Center context."
} else {
  $config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
  if (-not $AgentKey)   { $AgentKey   = [string]($config.actor      -or "") }
  if (-not $ProductKey) { $ProductKey = [string]($config.productKey  -or "") }
  if (-not $SquadKey)   { $SquadKey   = [string]($config.squadKey    -or "") }

  $env:E_DIVIN_PRODUCT_KEY = $ProductKey
  $env:E_DIVIN_SQUAD_KEY   = $SquadKey
  $env:E_DIVIN_HOST_KEY    = [string]($config.hostKey    -or $env:COMPUTERNAME)
  $env:E_DIVIN_SERVICE_URL = [string]($config.serviceUrl -or "")
  $env:E_DIVIN_ACTOR       = $AgentKey
  $env:E_DIVIN_TOOL        = "antigravity"

  Write-Host "[E-Divin] Antigravity launcher: product=$ProductKey squad=$SquadKey agent=$AgentKey host=$env:E_DIVIN_HOST_KEY"
}

# ── 2. Write tool-launch event to runner inbox ────────────────────────────────
$runtimeRoot = Split-Path -Parent $ConfigPath
$inboxPath   = Join-Path $runtimeRoot "inbox"
New-Item -ItemType Directory -Force -Path $inboxPath -ErrorAction SilentlyContinue | Out-Null

$eventFileName = "tool-launch-event-antigravity-{0}.json" -f (Get-Date -Format "yyyyMMdd-HHmmss-fff")
$eventFilePath = Join-Path $inboxPath $eventFileName
[ordered]@{
  eventType   = "tool_launch"
  toolKey     = "antigravity"
  agentKey    = $AgentKey
  productKey  = $ProductKey
  squadKey    = $SquadKey
  hostKey     = $env:E_DIVIN_HOST_KEY
  launchedAt  = (Get-Date).ToString("o")
  processId   = $PID
  machineName = $env:COMPUTERNAME
  workDir     = (Resolve-Path $WorkDir -ErrorAction SilentlyContinue)?.Path -or $WorkDir
} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $eventFilePath -Encoding utf8
Write-Host "[E-Divin] Tool-launch event written: $eventFilePath"
Write-Host "[E-Divin] Runner will deliver startup prompt on next poll (heartbeat registered)."

# ── 3. Inject startup prompt ──────────────────────────────────────────────────
$latestPrompt = Get-ChildItem -Path (Join-Path $inboxPath "prompt-packet-antigravity-*.json") `
  -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1

if ($latestPrompt) {
  $pkt = Get-Content -LiteralPath $latestPrompt.FullName -Raw | ConvertFrom-Json
  if ($pkt.promptBody) {
    # Primary: env var for CLI pickup
    $env:ANTIGRAVITY_SYSTEM_PROMPT = $pkt.promptBody

    # Secondary: inject into AGENTS.md in the workspace root (Antigravity reads this natively)
    $resolvedWorkDir = (Resolve-Path $WorkDir -ErrorAction SilentlyContinue)?.Path -or $WorkDir
    $agentsDir  = Join-Path $resolvedWorkDir ".agents"
    $agentsMd   = Join-Path $resolvedWorkDir "AGENTS.md"
    $agentsFile = if (Test-Path -LiteralPath $agentsDir) { Join-Path $agentsDir "AGENTS.md" } else { $agentsMd }

    $header = @"
<!-- E-Divin Startup Prompt — injected by start-antigravity.ps1 -->
<!-- Agent: $($pkt.agentKey) | Product: $($pkt.productKey) | Prompt v$($pkt.promptVersion) | $(Get-Date -Format o) -->

$($pkt.promptBody)

<!-- END E-Divin Startup Prompt -->
"@
    # Prepend to existing AGENTS.md, or create it
    if (Test-Path -LiteralPath $agentsFile) {
      $existing = Get-Content -LiteralPath $agentsFile -Raw
      # Remove previous injection block if present
      $existing = $existing -replace '(?s)<!-- E-Divin Startup Prompt.*?<!-- END E-Divin Startup Prompt -->\r?\n?', ''
      ($header + "`n" + $existing.TrimStart()) | Set-Content -LiteralPath $agentsFile -Encoding utf8
    } else {
      $header | Set-Content -LiteralPath $agentsFile -Encoding utf8
    }

    Write-Host "[E-Divin] Startup prompt v$($pkt.promptVersion) injected:"
    Write-Host "           - env: ANTIGRAVITY_SYSTEM_PROMPT"
    Write-Host "           - file: $agentsFile"
  }
} else {
  Write-Host "[E-Divin] No prompt packet found yet. The runner will deliver one shortly after the tool-launch event is processed."
  Write-Host "[E-Divin] Re-run this launcher after a few seconds to inject the prompt, or check the runner log."
}

# ── 4. Launch Antigravity ─────────────────────────────────────────────────────
Write-Host ""
Write-Host "[E-Divin] Starting Google Antigravity..."
Write-Host "          Workspace : $WorkDir"
Write-Host "          Product   : $ProductKey"
Write-Host "          Agent     : $AgentKey"
Write-Host ""

if (Get-Command antigravity -ErrorAction SilentlyContinue) {
  antigravity @args
} elseif (Get-Command ag -ErrorAction SilentlyContinue) {
  ag @args
} else {
  # Antigravity may be running as a browser-based agent; open workspace
  if ($OpenBrowser -and $env:E_DIVIN_SERVICE_URL) {
    $url = "$($env:E_DIVIN_SERVICE_URL.TrimEnd('/'))/p2d-command-center/sessions"
    Write-Host "[E-Divin] Opening Command Center sessions view: $url"
    Start-Process $url
  } else {
    Write-Host "[E-Divin] Antigravity CLI not found. Env vars and AGENTS.md have been set."
    Write-Host "[E-Divin] Open your Antigravity workspace manually. The product context is ready."
    Write-Host ""
    Write-Host "  E_DIVIN_PRODUCT_KEY = $ProductKey"
    Write-Host "  E_DIVIN_SQUAD_KEY   = $SquadKey"
    Write-Host "  E_DIVIN_ACTOR       = $AgentKey"
    Write-Host "  E_DIVIN_TOOL        = antigravity"
    if ($env:ANTIGRAVITY_SYSTEM_PROMPT) {
      Write-Host "  ANTIGRAVITY_SYSTEM_PROMPT = [set, $(($env:ANTIGRAVITY_SYSTEM_PROMPT).Length) chars]"
    }
  }
}
