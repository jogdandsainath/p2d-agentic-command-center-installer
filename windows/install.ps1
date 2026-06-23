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
  [string]$ProductId = "",
  [string]$SquadId = "",
  [string]$ReleaseKey = "current",
  [string]$ServiceUrl = "",
  [string]$Secret = "",
  [string]$Actor = "",
  [string]$HostKey = "",
  [switch]$NoDaemon,
  [switch]$NoHooks
)

$ErrorActionPreference = "Stop"
$repoRoot  = Split-Path -Parent $PSScriptRoot
$installDir = Join-Path $env:LOCALAPPDATA "Pur2Divin"
New-Item -ItemType Directory -Force -Path $installDir | Out-Null

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
if (-not $ProductId) { $ProductId = Read-Host "Product ID" }
if (-not $Squad) { $Squad = Read-Host "Squad key" }
if (-not $SquadId) { $SquadId = Read-Host "Squad ID" }
if (-not $Runtime) { $Runtime = Read-Host "AI runtime (codex, claude, copilot, cursor, service)" }
if ($Runtime -notin @("codex","claude","copilot","cursor","service")) { throw "Unsupported runtime: $Runtime" }
if (-not $ProductKey -or -not $ProductId -or -not $Squad -or -not $SquadId -or -not $ReleaseKey -or -not $Actor -or -not $Secret) { throw "Product ID/key, squad ID/key, release, user ID, and enrollment token are required." }
if (-not $HostKey) { $HostKey = [Environment]::MachineName }
$HostKey = ($HostKey -replace "[^A-Za-z0-9._-]", "-").Trim("-").ToLowerInvariant()
if (-not $HostKey) {
  $machineGuid = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Cryptography" -Name MachineGuid -ErrorAction SilentlyContinue).MachineGuid
  if ($machineGuid) { $HostKey = "win-$($machineGuid.Replace('-', '').Substring(0, 12).ToLowerInvariant())" }
}
if (-not $HostKey) { $HostKey = "win-$([Guid]::NewGuid().ToString('N').Substring(0, 12))" }
$safeRelease = ($ReleaseKey -replace "[^A-Za-z0-9._-]", "-").Trim("-").ToLowerInvariant()
if (-not $safeRelease) { $safeRelease = "current" }
$workspaceRoot = Join-Path $installDir "workspaces\$ProductKey\$safeRelease\$Squad\$Runtime\$HostKey"
New-Item -ItemType Directory -Force -Path `
  "$workspaceRoot\config","$workspaceRoot\inbox","$workspaceRoot\outbox","$workspaceRoot\runtime","$workspaceRoot\logs" | Out-Null

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
info "  Release: $ReleaseKey"
info "  Host:    $HostKey"
info "  Folder:  $workspaceRoot"
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
  P2D_PRODUCT_ID         = $ProductId
  P2D_SQUAD_ID           = $SquadId
  P2D_RELEASE_KEY        = $ReleaseKey
  P2D_MACHINE_SECRET     = $machineSecret
  P2D_WORKSPACE_ROOT     = $workspaceRoot
  P2D_LOCAL_INBOX_ROOT   = "$workspaceRoot\inbox"
  P2D_LOCAL_OUTBOX_ROOT  = "$workspaceRoot\outbox"
  P2D_LOCAL_RUNTIME_ROOT = "$workspaceRoot\runtime"
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
  $runnerRoot = Join-Path $workspaceRoot "runtime"
  New-Item -ItemType Directory -Force -Path $runnerRoot | Out-Null
  $runnerPath = Join-Path $runnerRoot "machine-runner.ps1"
  $configPath = Join-Path $runnerRoot "config.json"
  Invoke-WebRequest -Uri "$ServiceUrl/bootstrap/runner.ps1" -UseBasicParsing -OutFile $runnerPath
  $encryptedToken = ConvertTo-SecureString $Secret -AsPlainText -Force | ConvertFrom-SecureString
  [ordered]@{
    serviceUrl = $ServiceUrl
    productKey = $ProductKey
    productId = $ProductId
    hostKey = $HostKey
    squadKey = $Squad
    squadId = $SquadId
    releaseKey = $ReleaseKey
    runtimeType = $runtimeType
    runtimeTool = $Runtime
    actor = $Actor
    pollSeconds = 20
    localDevelopment = $false
    encryptedToken = $encryptedToken
    machineSecret = $machineSecret
    workspaceRoot = $workspaceRoot
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
if (-not $NoHooks) {
  info "Step 5: Installing AI tool capability profile ..."
  $hookRoot = Join-Path $workspaceRoot "hooks"
  New-Item -ItemType Directory -Force -Path $hookRoot | Out-Null
  $hookScript = Join-Path $hookRoot "p2d-tool-start.ps1"
  $promptPath = Join-Path $hookRoot "visible-session-startup-prompt.md"
  $profilePath = Join-Path $hookRoot "tool-capability-profile.json"
  $hookLog = Join-Path $workspaceRoot "logs\tool-hook.log"
  $taskName = "Pur2Divin-Runner-$ProductKey-$Squad-$Runtime"
  $launcherRoot = Join-Path $workspaceRoot "launchers"
  New-Item -ItemType Directory -Force -Path $launcherRoot | Out-Null

  @"
# Pur2Divin visible-session startup prompt

Product: $ProductKey
Squad: $Squad
Runtime: $Runtime
Host: $HostKey

Use this tool session as a visible, product-scoped agent workspace.

Operating contract:
- Command Center is the source of truth.
- Use Swagger/OpenAPI from $ServiceUrl/swagger and $ServiceUrl/openapi.json.
- Preserve product, squad, command, run, and correlation IDs.
- Send evidence, blockers, prompt changes, reviews, and handoffs back through Command Center.
- Do not bypass product governance, prompt review, approval, release, or repo gates.
"@ | Set-Content -LiteralPath $promptPath -Encoding UTF8

  @"
param([string]`$Tool = "$Runtime")
`$ErrorActionPreference = "SilentlyContinue"
function Write-P2DLog { param([string]`$Message) Add-Content -LiteralPath "$hookLog" -Value "[$(Get-Date -Format o)] `$Message" }
try {
  `$config = Get-Content -LiteralPath "$configPath" -Raw | ConvertFrom-Json
  `$eventRoot = Join-Path `$config.workspaceRoot "hooks\events"
  New-Item -ItemType Directory -Force -Path `$eventRoot | Out-Null
  `$eventPath = Join-Path `$eventRoot ("{0}-{1}.json" -f (Get-Date -Format "yyyyMMdd-HHmmssfff"), `$Tool)
  [ordered]@{
    tool = `$Tool
    runtimeTool = `$config.runtimeTool
    runtimeType = `$config.runtimeType
    productKey = `$config.productKey
    productId = `$config.productId
    squadKey = `$config.squadKey
    squadId = `$config.squadId
    hostKey = `$config.hostKey
    releaseKey = `$config.releaseKey
    workspaceRoot = `$config.workspaceRoot
    promptPath = "$promptPath"
    source = "tool_startup_hook"
    createdAt = (Get-Date).ToString("o")
  } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath `$eventPath -Encoding UTF8
  `$task = Get-ScheduledTask -TaskName "$taskName" -ErrorAction SilentlyContinue
  if (`$task) { Start-ScheduledTask -TaskName "$taskName" -ErrorAction SilentlyContinue }
  Write-P2DLog "Hook wrote local launch event for `$Tool: `$eventPath"
} catch {
  Write-P2DLog "Hook failed for `$Tool: `$(`$_.Exception.Message)"
}
"@ | Set-Content -LiteralPath $hookScript -Encoding UTF8

  $hookCommand = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$hookScript`" -Tool $Runtime"
  $launcherPath = Join-Path $launcherRoot "start-$Runtime.ps1"
  $launcherCmdPath = Join-Path $launcherRoot "start-$Runtime.cmd"
  @"
param([string[]]`$ToolArgs = @())
`$ErrorActionPreference = "Continue"
& "$hookScript" -Tool "$Runtime"
switch ("$Runtime") {
  "codex" {
    if (Get-Command codex -ErrorAction SilentlyContinue) { & codex @ToolArgs }
    else { Write-Host "Codex CLI not found. Run: npm install -g @openai/codex" -ForegroundColor Yellow }
  }
  "claude" {
    if (Get-Command claude -ErrorAction SilentlyContinue) { & claude @ToolArgs }
    else { Write-Host "Claude Code CLI not found. Run: npm install -g @anthropic-ai/claude-code" -ForegroundColor Yellow }
  }
  "cursor" {
    if (Get-Command cursor -ErrorAction SilentlyContinue) { & cursor @ToolArgs }
    else { Write-Host "Cursor launcher not found. Enable the Cursor command-line launcher." -ForegroundColor Yellow }
  }
  "copilot" {
    if (Get-Command gh -ErrorAction SilentlyContinue) {
      if (`$ToolArgs.Count -gt 0) { & gh copilot @ToolArgs } else { & gh copilot --help }
    } else { Write-Host "GitHub CLI not found. Install gh and authenticate with gh auth login." -ForegroundColor Yellow }
  }
  default {
    Write-Host "Pur2Divin service runner started. No interactive tool command is required."
  }
}
"@ | Set-Content -LiteralPath $launcherPath -Encoding UTF8
  "@echo off`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$launcherPath`" %*`r`n" |
    Set-Content -LiteralPath $launcherCmdPath -Encoding ASCII
  [ordered]@{
    productKey = $ProductKey
    productId = $ProductId
    squadKey = $Squad
    squadId = $SquadId
    releaseKey = $ReleaseKey
    runtime = $Runtime
    runtimeType = $runtimeType
    hostKey = $HostKey
    workspaceRoot = $workspaceRoot
    commandCenter = $ServiceUrl
    swaggerUrl = "$ServiceUrl/swagger"
    openapiUrl = "$ServiceUrl/openapi.json"
    environmentVariables = $machineVars
    localFolders = @{
      config = "$workspaceRoot\config"
      inbox = "$workspaceRoot\inbox"
      outbox = "$workspaceRoot\outbox"
      runtime = "$workspaceRoot\runtime"
      logs = "$workspaceRoot\logs"
      launchers = $launcherRoot
    }
    hookScript = $hookScript
    hookCommand = $hookCommand
    launcherScript = $launcherPath
    launcherCommand = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$launcherPath`""
    visibleSessionPrompt = $promptPath
    tools = @{
      codex = @{ settingsArea = "Settings > Coding > Hooks"; startupHook = $hookCommand; launcher = $launcherPath; promptFile = $promptPath }
      claude = @{ settingsArea = "Developer / Claude Code hooks"; startupHook = $hookCommand; launcher = $launcherPath; promptFile = $promptPath }
      copilot = @{ settingsArea = "Agent startup terminal/task"; startupHook = $hookCommand; launcher = $launcherPath; promptFile = $promptPath }
      cursor = @{ settingsArea = "Hooks / Rules / MCPs"; startupHook = $hookCommand; launcher = $launcherPath; promptFile = $promptPath }
    }
  } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $profilePath -Encoding UTF8

  "P2D_TOOL_CAPABILITY_PROFILE=$profilePath`r`nP2D_TOOL_START_HOOK=$hookScript`r`nP2D_TOOL_LAUNCHER=$launcherPath`r`nP2D_VISIBLE_SESSION_PROMPT=$promptPath`r`n" |
    Set-Content -LiteralPath (Join-Path $hookRoot "tool-env.cmd") -Encoding ASCII
  "Preferred launcher for ${Runtime}:`r`n$launcherPath`r`n`r`nStartup hook only:`r`n$hookCommand`r`n`r`nVisible-session prompt:`r`n$promptPath`r`n" |
    Set-Content -LiteralPath (Join-Path $hookRoot "tool-hook-readme.txt") -Encoding UTF8

  success "Tool capability profile written: $profilePath"
  success "Tool startup hook written: $hookScript"
  success "Tool launcher written: $launcherPath"
} else {
  info "Skipping AI tool hooks and capability profile (--NoHooks)."
}

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
success " Release: $ReleaseKey"
success " Folder:  $workspaceRoot"
success "═══════════════════════════════════════════════"
Write-Host ""
success " Machine identity secret generated and stored for this user."
warn "Keep the enrollment token private. Rotate it from Command Center if this machine is retired."
