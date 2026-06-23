<#
.SYNOPSIS
  Launcher for Anthropic Claude Code — E-Divin Agentic Platform.
  Writes a tool-launch event, sets E-Divin env vars, injects startup prompt, and starts Claude Code.
#>
param(
  [string]$AgentKey    = "",
  [string]$ProductKey  = "",
  [string]$SquadKey    = "",
  [string]$ConfigPath  = (Join-Path $env:LOCALAPPDATA "E-Divin\runner\config.json")
)
$ErrorActionPreference = "Continue"
if (-not (Test-Path -LiteralPath $ConfigPath)) {
  Write-Warning "E-Divin runner config not found. Claude will launch without Command Center context."
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
  $env:E_DIVIN_TOOL        = "claude"
  Write-Host "[E-Divin] Claude launcher: product=$ProductKey squad=$SquadKey agent=$AgentKey"
}
$runtimeRoot = Split-Path -Parent $ConfigPath
$inboxPath   = Join-Path $runtimeRoot "inbox"
New-Item -ItemType Directory -Force -Path $inboxPath -ErrorAction SilentlyContinue | Out-Null
$eventFilePath = Join-Path $inboxPath ("tool-launch-event-claude-{0}.json" -f (Get-Date -Format "yyyyMMdd-HHmmss-fff"))
@{ eventType="tool_launch"; toolKey="claude"; agentKey=$AgentKey; productKey=$ProductKey; squadKey=$SquadKey;
   hostKey=$env:E_DIVIN_HOST_KEY; launchedAt=(Get-Date).ToString("o"); processId=$PID; machineName=$env:COMPUTERNAME
} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $eventFilePath -Encoding utf8
Write-Host "[E-Divin] Tool-launch event: $eventFilePath"

# Inject startup prompt if available
$latestPrompt = Get-ChildItem -Path (Join-Path $inboxPath "prompt-packet-claude-*.json") -ErrorAction SilentlyContinue |
  Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($latestPrompt) {
  $pkt = Get-Content -LiteralPath $latestPrompt.FullName -Raw | ConvertFrom-Json
  if ($pkt.promptBody) {
    $env:CLAUDE_SYSTEM_PROMPT  = $pkt.promptBody
    $env:ANTHROPIC_PROMPT_FILE = $latestPrompt.FullName
    Write-Host "[E-Divin] Startup prompt v$($pkt.promptVersion) loaded for $AgentKey."
  }
}

Write-Host "[E-Divin] Starting Anthropic Claude Code..."
if (Get-Command claude -ErrorAction SilentlyContinue) {
  claude @args
} else {
  Write-Warning "[E-Divin] 'claude' not found. Install with: npm install -g @anthropic-ai/claude-code"
  npx @anthropic-ai/claude-code @args
}
