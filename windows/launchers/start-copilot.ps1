<#
.SYNOPSIS
  Launcher for GitHub Copilot (Copilot CLI / gh copilot) — E-Divin Agentic Platform.
#>
param(
  [string]$AgentKey    = "",
  [string]$ProductKey  = "",
  [string]$SquadKey    = "",
  [string]$ConfigPath  = (Join-Path $env:LOCALAPPDATA "E-Divin\runner\config.json")
)
$ErrorActionPreference = "Continue"
if (Test-Path -LiteralPath $ConfigPath) {
  $config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
  if (-not $AgentKey)   { $AgentKey   = [string]($config.actor     -or "") }
  if (-not $ProductKey) { $ProductKey = [string]($config.productKey -or "") }
  if (-not $SquadKey)   { $SquadKey   = [string]($config.squadKey   -or "") }
  $env:E_DIVIN_PRODUCT_KEY = $ProductKey
  $env:E_DIVIN_SQUAD_KEY   = $SquadKey
  $env:E_DIVIN_HOST_KEY    = [string]($config.hostKey    -or $env:COMPUTERNAME)
  $env:E_DIVIN_SERVICE_URL = [string]($config.serviceUrl -or "")
  $env:E_DIVIN_ACTOR       = $AgentKey
  $env:E_DIVIN_TOOL        = "copilot"
  Write-Host "[E-Divin] Copilot launcher: product=$ProductKey squad=$SquadKey agent=$AgentKey"
}
$runtimeRoot = Split-Path -Parent $ConfigPath
$inboxPath   = Join-Path $runtimeRoot "inbox"
New-Item -ItemType Directory -Force -Path $inboxPath -ErrorAction SilentlyContinue | Out-Null
$eventFilePath = Join-Path $inboxPath ("tool-launch-event-copilot-{0}.json" -f (Get-Date -Format "yyyyMMdd-HHmmss-fff"))
@{ eventType="tool_launch"; toolKey="copilot"; agentKey=$AgentKey; productKey=$ProductKey; squadKey=$SquadKey;
   hostKey=$env:E_DIVIN_HOST_KEY; launchedAt=(Get-Date).ToString("o"); processId=$PID; machineName=$env:COMPUTERNAME
} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $eventFilePath -Encoding utf8
Write-Host "[E-Divin] Tool-launch event: $eventFilePath"

$latestPrompt = Get-ChildItem -Path (Join-Path $inboxPath "prompt-packet-copilot-*.json") -ErrorAction SilentlyContinue |
  Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($latestPrompt) {
  $pkt = Get-Content -LiteralPath $latestPrompt.FullName -Raw | ConvertFrom-Json
  if ($pkt.promptBody) { $env:GH_COPILOT_SYSTEM_PROMPT = $pkt.promptBody; Write-Host "[E-Divin] Startup prompt loaded v$($pkt.promptVersion)." }
}

Write-Host "[E-Divin] Starting GitHub Copilot..."
if (Get-Command gh -ErrorAction SilentlyContinue) {
  gh copilot @args
} else {
  Write-Warning "[E-Divin] 'gh' (GitHub CLI) not found. Install from https://cli.github.com"
}
