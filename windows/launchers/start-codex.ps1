<#
.SYNOPSIS
  Launcher for OpenAI Codex CLI — E-Divin Agentic Platform.
  Writes a tool-launch event to the runner inbox so the squad runner
  can register a heartbeat and deliver the product startup prompt.

.USAGE
  .\start-codex.ps1 [-AgentKey "my-agent"] [-ProductKey "my-product"] [-SquadKey "my-squad"]

.NOTES
  The runner must be running (via machine-squad-runner.ps1 or the Scheduled Task) for
  prompt delivery to work. The launcher sets E-Divin env vars from the runner config.
#>
param(
  [string]$AgentKey    = "",
  [string]$ProductKey  = "",
  [string]$SquadKey    = "",
  [string]$ConfigPath  = (Join-Path $env:LOCALAPPDATA "E-Divin\runner\config.json")
)

$ErrorActionPreference = "Continue"

# ── 1. Load runner config ────────────────────────────────────────────────────
if (-not (Test-Path -LiteralPath $ConfigPath)) {
  Write-Warning "E-Divin runner config not found at $ConfigPath. Codex will launch without Command Center context."
} else {
  $config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
  # Override from config if not passed
  if (-not $AgentKey)   { $AgentKey   = [string]($config.actor   -or "") }
  if (-not $ProductKey) { $ProductKey = [string]($config.productKey -or "") }
  if (-not $SquadKey)   { $SquadKey   = [string]($config.squadKey  -or "") }

  # Set env vars so Codex CLI inherits them
  $env:E_DIVIN_PRODUCT_KEY = $ProductKey
  $env:E_DIVIN_SQUAD_KEY   = $SquadKey
  $env:E_DIVIN_HOST_KEY    = [string]($config.hostKey    -or $env:COMPUTERNAME)
  $env:E_DIVIN_SERVICE_URL = [string]($config.serviceUrl -or "")
  $env:E_DIVIN_ACTOR       = $AgentKey
  $env:E_DIVIN_TOOL        = "codex"
  Write-Host "[E-Divin] Codex launcher: product=$ProductKey squad=$SquadKey agent=$AgentKey host=$env:E_DIVIN_HOST_KEY"
}

# ── 2. Write tool-launch event to runner inbox ───────────────────────────────
$runtimeRoot = Split-Path -Parent $ConfigPath
$inboxPath   = Join-Path $runtimeRoot "inbox"
New-Item -ItemType Directory -Force -Path $inboxPath -ErrorAction SilentlyContinue | Out-Null

$eventFileName = "tool-launch-event-codex-{0}.json" -f (Get-Date -Format "yyyyMMdd-HHmmss-fff")
$eventFilePath = Join-Path $inboxPath $eventFileName
$launchEvent   = [ordered]@{
  eventType   = "tool_launch"
  toolKey     = "codex"
  agentKey    = $AgentKey
  productKey  = $ProductKey
  squadKey    = $SquadKey
  hostKey     = $env:E_DIVIN_HOST_KEY
  launchedAt  = (Get-Date).ToString("o")
  processId   = $PID
  machineName = $env:COMPUTERNAME
}
$launchEvent | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $eventFilePath -Encoding utf8
Write-Host "[E-Divin] Tool-launch event written: $eventFilePath"

# ── 3. Launch Codex CLI ──────────────────────────────────────────────────────
$codexArgs = $args
if ($AgentKey) {
  # Pass agent context via CODEX_INITIAL_PROMPT env var if supported
  $promptPacketPath = Join-Path $inboxPath "prompt-packet-codex-*.json"
  $latestPrompt = Get-ChildItem -Path (Join-Path $inboxPath "prompt-packet-codex-*.json") -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($latestPrompt) {
    $packetContent = Get-Content -LiteralPath $latestPrompt.FullName -Raw | ConvertFrom-Json
    if ($packetContent.promptBody) {
      $env:CODEX_SYSTEM_PROMPT = $packetContent.promptBody
      Write-Host "[E-Divin] Startup prompt loaded from packet v$($packetContent.promptVersion) for agent $AgentKey."
    }
  }
}
Write-Host "[E-Divin] Starting OpenAI Codex CLI..."
if (Get-Command codex -ErrorAction SilentlyContinue) {
  codex @codexArgs
} else {
  Write-Warning "[E-Divin] 'codex' command not found. Install it with: npm install -g @openai/codex"
  Write-Host "[E-Divin] Attempting: npx @openai/codex ..."
  npx @openai/codex @codexArgs
}
