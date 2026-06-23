<#
.SYNOPSIS
  Launcher for Cursor IDE — E-Divin Agentic Platform.
  Writes a tool-launch event and starts Cursor with env vars and startup prompt injected.
#>
param(
  [string]$AgentKey    = "",
  [string]$ProductKey  = "",
  [string]$SquadKey    = "",
  [string]$WorkDir     = ".",
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
  $env:E_DIVIN_TOOL        = "cursor"
  Write-Host "[E-Divin] Cursor launcher: product=$ProductKey squad=$SquadKey agent=$AgentKey"
}
$runtimeRoot = Split-Path -Parent $ConfigPath
$inboxPath   = Join-Path $runtimeRoot "inbox"
New-Item -ItemType Directory -Force -Path $inboxPath -ErrorAction SilentlyContinue | Out-Null
$eventFilePath = Join-Path $inboxPath ("tool-launch-event-cursor-{0}.json" -f (Get-Date -Format "yyyyMMdd-HHmmss-fff"))
@{ eventType="tool_launch"; toolKey="cursor"; agentKey=$AgentKey; productKey=$ProductKey; squadKey=$SquadKey;
   hostKey=$env:E_DIVIN_HOST_KEY; launchedAt=(Get-Date).ToString("o"); processId=$PID; machineName=$env:COMPUTERNAME
} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $eventFilePath -Encoding utf8
Write-Host "[E-Divin] Tool-launch event: $eventFilePath"

# Write .cursorrules with startup prompt if available
$latestPrompt = Get-ChildItem -Path (Join-Path $inboxPath "prompt-packet-cursor-*.json") -ErrorAction SilentlyContinue |
  Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($latestPrompt) {
  $pkt = Get-Content -LiteralPath $latestPrompt.FullName -Raw | ConvertFrom-Json
  if ($pkt.promptBody) {
    $cursorRulesPath = Join-Path (Resolve-Path $WorkDir) ".cursorrules"
    $header = "# E-Divin Startup Prompt v$($pkt.promptVersion) — agent: $($pkt.agentKey) — product: $($pkt.productKey)`n# Generated: $(Get-Date -Format o)`n`n"
    $header + $pkt.promptBody | Set-Content -LiteralPath $cursorRulesPath -Encoding utf8
    Write-Host "[E-Divin] .cursorrules written with startup prompt v$($pkt.promptVersion)."
  }
}

Write-Host "[E-Divin] Starting Cursor IDE..."
$cursorExe = "${env:LOCALAPPDATA}\Programs\cursor\Cursor.exe"
if (Test-Path -LiteralPath $cursorExe) {
  & $cursorExe $WorkDir @args
} elseif (Get-Command cursor -ErrorAction SilentlyContinue) {
  cursor $WorkDir @args
} else {
  Write-Warning "[E-Divin] Cursor not found. Download from https://cursor.sh"
}
