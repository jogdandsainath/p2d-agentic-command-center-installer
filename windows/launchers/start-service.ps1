<#
.SYNOPSIS
  Launcher for a Node.js / backend service agent — E-Divin Agentic Platform.
  Registers the service session, delivers startup prompt as a JSON env var, starts the service.

.USAGE
  .\start-service.ps1 -EntryPoint "dist/index.js" [-AgentKey "backend-agent"] [-ProductKey "my-product"]
#>
param(
  [string]$EntryPoint  = "",
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
  $env:E_DIVIN_TOOL        = "service"
  Write-Host "[E-Divin] Service launcher: product=$ProductKey squad=$SquadKey agent=$AgentKey"
}
$runtimeRoot = Split-Path -Parent $ConfigPath
$inboxPath   = Join-Path $runtimeRoot "inbox"
New-Item -ItemType Directory -Force -Path $inboxPath -ErrorAction SilentlyContinue | Out-Null
$eventFilePath = Join-Path $inboxPath ("tool-launch-event-service-{0}.json" -f (Get-Date -Format "yyyyMMdd-HHmmss-fff"))
@{ eventType="tool_launch"; toolKey="service"; agentKey=$AgentKey; productKey=$ProductKey; squadKey=$SquadKey;
   hostKey=$env:E_DIVIN_HOST_KEY; launchedAt=(Get-Date).ToString("o"); processId=$PID; machineName=$env:COMPUTERNAME
} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $eventFilePath -Encoding utf8
Write-Host "[E-Divin] Tool-launch event: $eventFilePath"

$latestPrompt = Get-ChildItem -Path (Join-Path $inboxPath "prompt-packet-service-*.json") -ErrorAction SilentlyContinue |
  Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($latestPrompt) {
  $pkt = Get-Content -LiteralPath $latestPrompt.FullName -Raw | ConvertFrom-Json
  if ($pkt.promptBody) {
    $env:E_DIVIN_SYSTEM_PROMPT = $pkt.promptBody
    Write-Host "[E-Divin] Startup prompt v$($pkt.promptVersion) set in E_DIVIN_SYSTEM_PROMPT."
  }
}

if ($EntryPoint) {
  Write-Host "[E-Divin] Starting service: node $EntryPoint"
  node $EntryPoint @args
} else {
  Write-Host "[E-Divin] No EntryPoint specified. Use -EntryPoint 'dist/index.js' to start your service."
  Write-Host "[E-Divin] E-Divin env vars are set in this process. Run your service manually."
}
