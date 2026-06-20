<#
.SYNOPSIS
  E-Divin Machine Onboarding — Windows (PowerShell 5+)
  Single entry point for Codex, Claude Code, or GitHub Copilot machines.

.DESCRIPTION
  Run this once on a new Windows machine to:
  1. Install the required AI CLI tool (Codex / Claude / Copilot gh extension)
  2. Set machine-level environment variables
  3. Register the machine with the E-Divin service
  4. Install a Windows Scheduled Task to run the squad runner on login

.PARAMETER Squad
  Squad key to join (required). e.g. "ui-squad", "delivery-squad"

.PARAMETER Runtime
  AI platform: codex | claude | copilot | service (required)

.PARAMETER ProductKey
  Product key (default: e-divin-eos)

.PARAMETER ServiceUrl
  E-Divin service URL (default: E_DIVIN_AGENT_SERVICE_URL env or production URL)

.PARAMETER Secret
  Service shared secret. If omitted, prompts securely.

.PARAMETER Actor
  Your GitHub username (default: E_DIVIN_ACTOR env var)

.PARAMETER NoDaemon
  Skip installing the Scheduled Task background runner.

.EXAMPLE
  # Onboard as a Codex machine in ui-squad
  iex (irm https://e-divin-agent-communication-service.vercel.app/install.ps1)

  # Or run locally:
  .\scripts\onboard-machine.ps1 -Squad ui-squad -Runtime codex

  # Claude Code machine:
  .\scripts\onboard-machine.ps1 -Squad ux-squad -Runtime claude

  # GitHub Copilot machine:
  .\scripts\onboard-machine.ps1 -Squad delivery-squad -Runtime copilot
#>
param(
  [Parameter(Mandatory)][string]$Squad,
  [Parameter(Mandatory)][ValidateSet("codex","claude","copilot","service")][string]$Runtime,
  [string]$ProductKey = "e-divin-eos",
  [string]$ServiceUrl = "",
  [string]$Secret = "",
  [string]$Actor = "",
  [string]$HostKey = $env:COMPUTERNAME,
  [switch]$NoDaemon
)

$ErrorActionPreference = "Stop"
$repoRoot  = Split-Path -Parent $PSScriptRoot
$installDir = Join-Path $env:LOCALAPPDATA "E-Divin"
New-Item -ItemType Directory -Force -Path "$installDir\inbox\$Squad","$installDir\outbox\$Squad","$installDir\runtime" | Out-Null

function info    { param($m) Write-Host "[e-divin] $m" -ForegroundColor Cyan }
function success { param($m) Write-Host "[e-divin] $m" -ForegroundColor Green }
function warn    { param($m) Write-Host "[e-divin] $m" -ForegroundColor Yellow }

# ── Resolve connection params ─────────────────────────────────────────────────
function Get-MachineEnv { param($n) [Environment]::GetEnvironmentVariable($n,"Machine") }

if (-not $ServiceUrl) {
  $ServiceUrl = $env:E_DIVIN_AGENT_SERVICE_URL
  if (-not $ServiceUrl) { $ServiceUrl = Get-MachineEnv "E_DIVIN_AGENT_SERVICE_URL" }
  if (-not $ServiceUrl) { $ServiceUrl = "https://e-divin-agent-communication-service.vercel.app" }
}
if (-not $Secret) {
  $Secret = $env:SERVICE_SHARED_SECRET
  if (-not $Secret) { $Secret = Get-MachineEnv "SERVICE_SHARED_SECRET" }
  if (-not $Secret) {
    $secure = Read-Host "SERVICE_SHARED_SECRET" -AsSecureString
    $Secret = [System.Net.NetworkCredential]::new("",$secure).Password
  }
}
if (-not $Actor) {
  $Actor = $env:E_DIVIN_ACTOR
  if (-not $Actor) { $Actor = Get-MachineEnv "E_DIVIN_ACTOR" }
  if (-not $Actor) { $Actor = "jogdandsainath" }
}

$ServiceUrl = $ServiceUrl.TrimEnd("/")
$headers = @{ Authorization = "Bearer $Secret"; "X-E-Divin-Actor" = $Actor; "Content-Type" = "application/json" }

function Invoke-Svc {
  param([string]$Method, [string]$Path, [hashtable]$Body = @{})
  try {
    return Invoke-RestMethod -Method $Method -Uri "$ServiceUrl$Path" -Headers $headers `
      -Body ($Body | ConvertTo-Json -Depth 10 -Compress) -ErrorAction Stop
  } catch { warn "Service call $Method $Path failed: $($_.Exception.Message)"; return $null }
}

info "E-Divin Windows Machine Onboarding"
info "  Squad:   $Squad"
info "  Runtime: $Runtime"
info "  Product: $ProductKey"
info "  Host:    $HostKey"
info "  Service: $ServiceUrl"
Write-Host ""

# ── Step 1: Install AI CLI tool ───────────────────────────────────────────────
info "Step 1: Installing $Runtime CLI …"

function Test-Command { param($cmd) return [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }

function Install-Node {
  if (Test-Command "node") {
    success "Node.js $(node --version) already installed."
    return
  }
  info "Installing Node.js 20 via winget …"
  winget install OpenJS.NodeJS.LTS --silent --accept-package-agreements --accept-source-agreements 2>$null
  if ($LASTEXITCODE -eq 0) { success "Node.js installed." } else { warn "winget failed. Install Node 20 manually: https://nodejs.org" }
}

switch ($Runtime) {
  "codex" {
    Install-Node
    if (-not (Test-Command "codex")) {
      info "Installing OpenAI Codex CLI …"
      npm install -g "@openai/codex" 2>$null | Out-Null
      if (Test-Command "codex") { success "Codex CLI installed." } else { warn "codex install failed. Run: npm i -g @openai/codex" }
    } else { success "Codex CLI already installed." }
  }
  "claude" {
    if (-not (Test-Command "claude")) {
      Install-Node
      info "Installing Claude Code CLI …"
      npm install -g "@anthropic-ai/claude-code" 2>$null | Out-Null
      if (Test-Command "claude") { success "Claude Code CLI installed." } else { warn "claude install failed. Install manually." }
    } else { success "Claude Code CLI already installed." }
  }
  "copilot" {
    Install-Node
    if (-not (Test-Command "gh")) {
      info "Installing GitHub CLI …"
      winget install GitHub.cli --silent --accept-package-agreements --accept-source-agreements 2>$null | Out-Null
      if (Test-Command "gh") { success "GitHub CLI installed." } else { warn "gh install failed. Install from https://cli.github.com" }
    } else { success "GitHub CLI already installed." }
    gh extension install github/gh-copilot 2>$null | Out-Null
    success "GitHub Copilot CLI extension ready."
  }
  "service" { Install-Node }
}

# ── Step 2: Set machine environment variables ─────────────────────────────────
info "Step 2: Setting machine environment variables …"
$machineVars = @{
  E_DIVIN_AGENT_SERVICE_URL = $ServiceUrl
  E_DIVIN_ACTOR             = $Actor
  E_DIVIN_SQUAD_KEY         = $Squad
  E_DIVIN_RUNTIME_TYPE      = $Runtime
  E_DIVIN_PRODUCT_KEY       = $ProductKey
  E_DIVIN_LOCAL_INBOX_ROOT  = "$installDir\inbox"
  E_DIVIN_LOCAL_OUTBOX_ROOT = "$installDir\outbox"
  E_DIVIN_LOCAL_RUNTIME_ROOT= "$installDir\runtime"
}
foreach ($kv in $machineVars.GetEnumerator()) {
  try {
    [Environment]::SetEnvironmentVariable($kv.Key, $kv.Value, "Machine")
    $env:($kv.Key) = $kv.Value
  } catch {
    [Environment]::SetEnvironmentVariable($kv.Key, $kv.Value, "User")
    warn "$($kv.Key) set at User scope (run as Admin for Machine scope)"
  }
}
success "Environment variables set."

# ── Step 3: Register machine ──────────────────────────────────────────────────
info "Step 3: Registering machine with E-Divin service …"
$reg = Invoke-Svc -Method POST -Path "/machines/register" -Body @{
  hostKey         = $HostKey
  displayName     = "$HostKey (Windows $Runtime)"
  hostType        = "desktop"
  squadKey        = $Squad
  squadDisplayName= "$Squad on $HostKey"
  runtimeType     = $Runtime
  locationHint    = "$Runtime on Windows"
  productKey      = $ProductKey
}
if ($reg -and $reg.ok) { success "Machine registered: $HostKey" }
else { warn "Registration response: $($reg | ConvertTo-Json -Compress) (may already exist)" }

# ── Step 4: Install Scheduled Task background runner ─────────────────────────
if (-not $NoDaemon) {
  info "Step 4: Installing Scheduled Task runner …"
  $runnerPath = Join-Path $repoRoot "scripts\squad-lead-runner.ps1"
  if (-not (Test-Path $runnerPath)) {
    $runnerPath = Join-Path $installDir "squad-lead-runner.ps1"
    Copy-Item (Join-Path $PSScriptRoot "squad-lead-runner.ps1") $runnerPath -Force -ErrorAction SilentlyContinue
  }

  $taskName   = "E-Divin-Runner-$Squad-$Runtime"
  $psArgs     = "-NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$runnerPath`" -SquadKey $Squad"
  $action     = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $psArgs
  $trigger    = New-ScheduledTaskTrigger -AtLogOn
  $settings   = New-ScheduledTaskSettingsSet -RestartOnIdle -ExecutionTimeLimit (New-TimeSpan -Hours 0) -MultipleInstances IgnoreNew
  $principal  = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

  try {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
      -Settings $settings -Principal $principal -Description "E-Divin $Runtime squad runner for $Squad" | Out-Null
    Start-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    success "Scheduled Task installed and started: $taskName"
  } catch {
    warn "Scheduled Task install failed: $($_.Exception.Message)"
    warn "Start manually: powershell -File `"$runnerPath`" -SquadKey $Squad"
  }
} else {
  info "Skipping Scheduled Task (--NoDaemon). Start manually:"
  info "  powershell -File `"$repoRoot\scripts\squad-lead-runner.ps1`" -SquadKey $Squad"
}

# ── Step 5: Publish onboarding heartbeat ─────────────────────────────────────
Invoke-Svc -Method POST -Path "/automation/runner-heartbeat" -Body @{
  squadKey    = $Squad
  runtimeType = $Runtime
  status      = "active"
  message     = "Machine onboarded: $HostKey (Windows $Runtime)"
  productKey  = $ProductKey
} | Out-Null

Write-Host ""
success "═══════════════════════════════════════════════"
success " E-Divin Windows onboarding complete!"
success " Squad:   $Squad"
success " Runtime: $Runtime"
success " Product: $ProductKey"
success " Logs:    $installDir\runner.log"
success "═══════════════════════════════════════════════"
Write-Host ""
warn "IMPORTANT: SERVICE_SHARED_SECRET must be set as a Machine env var:"
warn "  (Admin PS): [Environment]::SetEnvironmentVariable('SERVICE_SHARED_SECRET','your-secret','Machine')"
