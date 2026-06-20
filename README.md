# P2D Agentic Command Center — Machine Installer

> **One command to join your AI agent fleet.** No GitHub access needed. No manual setup.

This repo contains installer scripts for onboarding any machine into the **P2D Agentic Command Center** — the platform that lets a founder manage an entire AI-staffed product team across OpenAI Codex, Anthropic Claude Code, and GitHub Copilot.

---

## ⬇️ Download

| OS | File | Instructions |
|----|------|-------------|
| **Windows** | [`windows/install.ps1`](windows/install.ps1) | [→ Windows guide](docs/windows.md) |
| **macOS** | [`mac-linux/install.sh`](mac-linux/install.sh) | [→ macOS guide](docs/macos.md) |
| **Linux** | [`mac-linux/install.sh`](mac-linux/install.sh) | [→ Linux guide](docs/linux.md) |

---

## What gets installed?

| AI Tool | What the installer sets up |
|---------|---------------------------|
| **OpenAI Codex** | Node.js 20 + Codex CLI + squad runner background service |
| **Anthropic Claude Code** | Node.js 20 + Claude Code CLI + squad runner background service |
| **GitHub Copilot** | Node.js 20 + GitHub CLI + Copilot extension + squad runner |
| **Service / Backend** | Node.js 20 + squad runner only |

All options also:
- Set machine environment variables (squad, product, service URL)
- Register the machine in the Command Center
- Start a background runner that polls for commands and routes them to the AI tool automatically

---

## Before you start — get these 2 things

Your **founder** provides these from the Command Center dashboard:

| What | Example |
|------|---------|
| `SERVICE_SHARED_SECRET` | `sk-xxxxxxxxxxxxxxxx` |
| Squad key | `ui-squad`, `delivery-squad`, `backend-squad` |

---

## Quick start

### Windows (PowerShell)
```powershell
# 1. Download install.ps1 from this repo
# 2. Open PowerShell as Administrator
# 3. Run:
$env:SERVICE_SHARED_SECRET = 'YOUR_SECRET'
$env:E_DIVIN_ACTOR         = 'your-github-username'
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\Downloads\install.ps1" `
  -Squad 'ui-squad' -Runtime 'codex'
```

### macOS / Linux (Terminal)
```bash
# 1. Download install.sh from this repo
# 2. Open Terminal
# 3. Run:
export SERVICE_SHARED_SECRET='YOUR_SECRET'
export E_DIVIN_ACTOR='your-github-username'
bash ~/Downloads/install.sh --squad ui-squad --runtime claude
```

### One-liner (no download needed)
```powershell
# Windows — run in PowerShell as Administrator
$env:SERVICE_SHARED_SECRET='YOUR_SECRET'; $env:E_DIVIN_ACTOR='YOUR_USERNAME'
iwr 'https://e-divin-agent-communication-service.vercel.app/install.ps1' -UseBasicParsing -OutFile "$env:TEMP\edv.ps1"
powershell -ExecutionPolicy Bypass -File "$env:TEMP\edv.ps1" -Squad 'ui-squad' -Runtime 'codex'
```
```bash
# macOS / Linux — run in Terminal
export SERVICE_SHARED_SECRET='YOUR_SECRET' E_DIVIN_ACTOR='YOUR_USERNAME'
curl -fsSL https://e-divin-agent-communication-service.vercel.app/install.sh | bash -s -- --squad ui-squad --runtime claude
```

---

## Detailed guides

- [Windows — all AI tools](docs/windows.md)
- [macOS — all AI tools](docs/macos.md)
- [Linux — all AI tools](docs/linux.md)
- [Troubleshooting](docs/troubleshooting.md)

---

## After installation

1. Machine appears in **Command Center → Automation → Machine Runner Health**
2. Founder sends a command from the dashboard
3. Command is automatically routed to this machine's AI tool
4. Result flows back to the Command Center timeline

---

## Logs

| OS | Log location |
|----|-------------|
| Windows | `%LOCALAPPDATA%\E-Divin\runner.log` |
| macOS / Linux | `~/.e-divin/runner.log` |
