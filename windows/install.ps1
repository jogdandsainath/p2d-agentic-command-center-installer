<#
.SYNOPSIS
  Pur2Divin Machine Onboarding - Windows (PowerShell 5+)
  Single entry point for Codex, Claude Code, GitHub Copilot, or Cursor machines.

.DESCRIPTION
  Run this once on a new Windows machine to:
  1. Install or verify the required AI CLI tool
  2. Set machine-level environment variables
  3. Register the machine with the Pur2Divin Command Center
  4. Install a Windows Scheduled Task to run the squad runner on login

.PARAMETER Squad
  Squad key to join (required). e.g. "ui-squad", "delivery-squad"

.PARAMETER Runtime
  AI platform: codex | claude | copilot | cursor | service

.PARAMETER ProductKey
  Product workspace key. This is required and is never defaulted to another product.

.PARAMETER ServiceUrl
  Pur2Divin Command Center URL

.PARAMETER Secret
  Command Center enrollment token. If omitted, prompts securely.

.PARAMETER Actor
  Organization user ID (default: P2D_ACTOR env var)

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
  [string]$Squad = "",
  [string]$Runtime = "",
  [string]$ProductKey = "",
  [string]$ServiceUrl = "",
  [string]$Secret = "",
  [string]$Actor = "",
  [string]$HostKey = "",
  [switch]$NoDaemon
)

$ErrorActionPreference = "Stop"
$repoRoot  = Split-Path -Parent $PSScriptRoot
$installDir = Join-Path $env:LOCALAPPDATA "Pur2Divin"
New-Item -ItemType Directory -Force -Path "$installDir\inbox\$Squad","$installDir\outbox\$Squad","$installDir\runtime" | Out-Null

function info    { param($m) Write-Host "[p2d] $m" -ForegroundColor Cyan }
function success { param($m) Write-Host "[p2d] $m" -ForegroundColor Green }
function warn    { param($m) Write-Host "[p2d] $m" -ForegroundColor Yellow }

# ── Resolve connection params ─────────────────────────────────────────────────
function Get-MachineEnv { param($n) [Environment]::GetEnvironmentVariable($n,"Machine") }

if (-not $ServiceUrl) {
  $ServiceUrl = $env:P2D_COMMAND_CENTER_URL
  if (-not $ServiceUrl) { $ServiceUrl = Get-MachineEnv "P2D_COMMAND_CENTER_URL" }
  if (-not $ServiceUrl) { $ServiceUrl = "https://www.thep2d.com/p2d-command-center" }
}
if (-not $Secret) {
  $Secret = $env:P2D_ENROLLMENT_TOKEN
  if (-not $Secret) { $Secret = $env:SERVICE_SHARED_SECRET }
  if (-not $Secret) { $Secret = Get-MachineEnv "P2D_ENROLLMENT_TOKEN" }
  if (-not $Secret) {
    $secure = Read-Host "Command Center enrollment token" -AsSecureString
    $Secret = [System.Net.NetworkCredential]::new("",$secure).Password
  }
}
if (-not $Actor) {
  $Actor = $env:P2D_ACTOR
  if (-not $Actor) { $Actor = Get-MachineEnv "P2D_ACTOR" }
  if (-not $Actor) { $Actor = Read-Host "Organization user ID" }
}

if (-not $ProductKey) { $ProductKey = Read-Host "Product workspace key" }
if (-not $Squad) { $Squad = Read-Host "Squad key" }
if (-not $Runtime) { $Runtime = Read-Host "AI runtime (codex, claude, copilot, cursor, service)" }
if ($Runtime -notin @("codex","claude","copilot","cursor","service")) { throw "Unsupported runtime: $Runtime" }
if (-not $ProductKey -or -not $Squad -or -not $Actor -or -not $Secret) { throw "Product, squad, user ID, and enrollment token are required." }
if (-not $HostKey) { $HostKey = [Environment]::MachineName }
$HostKey = ($HostKey -replace "[^A-Za-z0-9._-]", "-").Trim("-").ToLowerInvariant()
if (-not $HostKey) {
  $machineGuid = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Cryptography" -Name MachineGuid -ErrorAction SilentlyContinue).MachineGuid
  if ($machineGuid) { $HostKey = "win-$($machineGuid.Replace('-', '').Substring(0, 12).ToLowerInvariant())" }
}
if (-not $HostKey) { $HostKey = "win-$([Guid]::NewGuid().ToString('N').Substring(0, 12))" }

$secretBytes = New-Object byte[] 32
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
$rng.GetBytes($secretBytes)
$rng.Dispose()
$machineSecret = [Convert]::ToBase64String($secretBytes)
$runtimeType = switch ($Runtime) {
  "copilot" { "github_action" }
  "cursor" { "other" }
  default { $Runtime }
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

info "Pur2Divin Machine Onboarding"
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
    cmd /c "gh copilot --help >nul 2>&1"
    if ($LASTEXITCODE -eq 0) {
      success "GitHub Copilot command is available."
    } else {
      warn "GitHub Copilot CLI command was not detected."
      warn "Authenticate GitHub CLI with 'gh auth login' and confirm Copilot access for this account."
    }
  }
  "cursor" {
    if (Test-Command "cursor") {
      success "Cursor command-line launcher detected."
    } else {
      warn "Cursor is not installed or its shell command is unavailable."
      warn "Install Cursor, then enable its command-line launcher from the Cursor command palette."
    }
  }
  "service" { Install-Node }
}

# ── Step 2: Set machine environment variables ─────────────────────────────────
info "Step 2: Setting machine environment variables …"
$machineVars = @{
  P2D_COMMAND_CENTER_URL = $ServiceUrl
  P2D_ACTOR              = $Actor
  P2D_SQUAD_KEY          = $Squad
  P2D_RUNTIME            = $Runtime
  P2D_PRODUCT_KEY        = $ProductKey
  P2D_MACHINE_SECRET     = $machineSecret
  P2D_LOCAL_INBOX_ROOT   = "$installDir\inbox"
  P2D_LOCAL_OUTBOX_ROOT  = "$installDir\outbox"
  P2D_LOCAL_RUNTIME_ROOT = "$installDir\runtime"
  # Legacy aliases keep existing runners compatible during migration.
  E_DIVIN_AGENT_SERVICE_URL = $ServiceUrl
  E_DIVIN_ACTOR             = $Actor
  E_DIVIN_SQUAD_KEY         = $Squad
  E_DIVIN_RUNTIME_TYPE      = $Runtime
  E_DIVIN_PRODUCT_KEY       = $ProductKey
}
foreach ($kv in $machineVars.GetEnumerator()) {
  try {
    [Environment]::SetEnvironmentVariable($kv.Key, $kv.Value, "Machine")
    Set-Item -Path "Env:$($kv.Key)" -Value $kv.Value
  } catch {
    [Environment]::SetEnvironmentVariable($kv.Key, $kv.Value, "User")
    warn "$($kv.Key) set at User scope (run as Admin for Machine scope)"
  }
}
success "Environment variables set."

# ── Step 3: Register machine ──────────────────────────────────────────────────
info "Step 3: Registering machine with Pur2Divin Command Center ..."
$reg = Invoke-Svc -Method POST -Path "/machines/register" -Body @{
  hostKey         = $HostKey
  displayName     = "$HostKey (Windows $Runtime)"
  hostType        = "desktop"
  squadKey        = $Squad
  squadDisplayName= "$Squad on $HostKey"
  runtimeType     = $runtimeType
  locationHint    = "$Runtime on Windows"
  productKey      = $ProductKey
}
if ($reg -and $reg.ok) { success "Machine registered: $HostKey" }
else { warn "Registration response: $($reg | ConvertTo-Json -Compress) (may already exist)" }

# ── Step 4: Install Scheduled Task background runner ─────────────────────────
if (-not $NoDaemon) {
  info "Step 4: Installing Scheduled Task runner …"
  $runnerRoot = Join-Path $installDir "runner"
  New-Item -ItemType Directory -Force -Path $runnerRoot | Out-Null
  $runnerPath = Join-Path $runnerRoot "machine-runner.ps1"
  $configPath = Join-Path $runnerRoot "config.json"
  Invoke-WebRequest -Uri "$ServiceUrl/bootstrap/runner.ps1" -UseBasicParsing -OutFile $runnerPath
  $encryptedToken = ConvertTo-SecureString $Secret -AsPlainText -Force | ConvertFrom-SecureString
  [ordered]@{
    serviceUrl = $ServiceUrl
    productKey = $ProductKey
    hostKey = $HostKey
    squadKey = $Squad
    runtimeType = $runtimeType
    runtimeTool = $Runtime
    actor = $Actor
    pollSeconds = 20
    localDevelopment = $false
    encryptedToken = $encryptedToken
    machineSecret = $machineSecret
    installedAt = (Get-Date).ToString("o")
  } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $configPath -Encoding UTF8

  $taskName   = "Pur2Divin-Runner-$ProductKey-$Squad-$Runtime"
  $psArgs     = "-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$runnerPath`" -ConfigPath `"$configPath`""
  $action     = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $psArgs
  $trigger    = New-ScheduledTaskTrigger -AtLogOn
  $settings   = New-ScheduledTaskSettingsSet -RestartOnIdle -ExecutionTimeLimit (New-TimeSpan -Hours 0) -MultipleInstances IgnoreNew
  $principal  = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

  try {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
      -Settings $settings -Principal $principal -Description "Pur2Divin $Runtime runner for $ProductKey / $Squad" | Out-Null
    Start-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    success "Scheduled Task installed and started: $taskName"
  } catch {
    warn "Scheduled Task install failed: $($_.Exception.Message)"
    warn "Start manually: powershell -File `"$runnerPath`" -ConfigPath `"$configPath`""
  }
} else {
  info "Skipping Scheduled Task (--NoDaemon). Start manually:"
  info "  Re-run without -NoDaemon to install the persistent runner."
}

# ── Step 5: Publish onboarding heartbeat ─────────────────────────────────────
Invoke-Svc -Method POST -Path "/automation/runner-heartbeat" -Body @{
  squadKey    = $Squad
  runtimeType = $runtimeType
  status      = "active"
  message     = "Machine onboarded: $HostKey (Windows $Runtime)"
  productKey  = $ProductKey
} | Out-Null

Write-Host ""
success "═══════════════════════════════════════════════"
success " Pur2Divin Windows onboarding complete!"
success " Squad:   $Squad"
success " Runtime: $Runtime"
success " Product: $ProductKey"
success " Logs:    $installDir\runner.log"
success "═══════════════════════════════════════════════"
Write-Host ""
success " Machine identity secret generated and stored for this user."
warn "Keep the enrollment token private. Rotate it from Command Center if this machine is retired."
