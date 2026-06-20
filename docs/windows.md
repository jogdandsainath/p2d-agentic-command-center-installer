# Windows Installation Guide

Complete guide to onboarding a Windows machine into the P2D Agentic Command Center.

---

## Prerequisites

- Windows 10 / 11
- PowerShell 5 or later (pre-installed on all modern Windows)
- Internet connection
- `SERVICE_SHARED_SECRET` and squad key from your founder

---

## Step-by-step

### 1. Download the installer

[**⬇ Download windows/install.ps1**](../windows/install.ps1)

Save it to your `Downloads` folder.

---

### 2. Open PowerShell as Administrator

Press **Windows key** → type `PowerShell` → right-click → **Run as Administrator**

---

### 3. Set your credentials

```powershell
$env:SERVICE_SHARED_SECRET = 'paste-your-secret-here'
$env:E_DIVIN_ACTOR         = 'your-github-username'
```

---

### 4. Run the installer

Pick your AI tool and replace `ui-squad` with your squad key:

#### OpenAI Codex
```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\Downloads\install.ps1" `
  -Squad 'ui-squad' -Runtime 'codex'
```

#### Anthropic Claude Code
```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\Downloads\install.ps1" `
  -Squad 'ui-squad' -Runtime 'claude'
```

#### GitHub Copilot
```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\Downloads\install.ps1" `
  -Squad 'ui-squad' -Runtime 'copilot'
```

---

### 5. What happens automatically

| Step | What the installer does |
|------|------------------------|
| ✅ Install Node.js 20 | Via `winget` (Windows Package Manager) |
| ✅ Install AI CLI | `npm install -g @openai/codex` / `@anthropic-ai/claude-code` / GitHub CLI |
| ✅ Set environment variables | Machine-level: service URL, squad, product, actor |
| ✅ Register machine | Calls Command Center `/machines/register` |
| ✅ Install Scheduled Task | Runs squad runner automatically at login |
| ✅ Start runner | Begins polling for commands immediately |

---

### 6. Verify it worked

Open the **Command Center dashboard** → **Automation** → **Machine Runner Health**

Your machine should appear within 60 seconds.

---

## One-liner alternative (no download)

```powershell
$env:SERVICE_SHARED_SECRET='YOUR_SECRET'; $env:E_DIVIN_ACTOR='YOUR_USERNAME'
iwr 'https://e-divin-agent-communication-service.vercel.app/install.ps1' -UseBasicParsing -OutFile "$env:TEMP\edv.ps1"
powershell -ExecutionPolicy Bypass -File "$env:TEMP\edv.ps1" -Squad 'ui-squad' -Runtime 'codex'
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `Execution Policy` error | Run `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` first |
| `winget not found` | Install App Installer from Microsoft Store, or install Node.js manually from [nodejs.org](https://nodejs.org) |
| `SERVICE_SHARED_SECRET not set` | Make sure you set `$env:SERVICE_SHARED_SECRET` in the same PowerShell window |
| Machine not in dashboard | Check logs: `%LOCALAPPDATA%\E-Divin\runner.log` |
| Scheduled Task not running | Open Task Scheduler → find `E-Divin-Runner-*` → right-click → Run |

---

## Uninstall

```powershell
# Remove scheduled task
Unregister-ScheduledTask -TaskName "E-Divin-Runner-*" -Confirm:$false
# Remove env vars
[Environment]::SetEnvironmentVariable('E_DIVIN_AGENT_SERVICE_URL', $null, 'Machine')
[Environment]::SetEnvironmentVariable('SERVICE_SHARED_SECRET', $null, 'Machine')
# Remove files
Remove-Item "$env:LOCALAPPDATA\E-Divin" -Recurse -Force
```
