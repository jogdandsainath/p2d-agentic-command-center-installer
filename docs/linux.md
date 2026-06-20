# Linux Installation Guide

Complete guide to onboarding a Linux machine into the P2D Agentic Command Center.

---

## Prerequisites

- Ubuntu 20.04+ / Debian / RHEL / Fedora / Amazon Linux
- `curl` and `bash` (pre-installed on most distros)
- Internet connection
- `SERVICE_SHARED_SECRET` and squad key from your founder

---

## Step-by-step

### 1. Download the installer

[**⬇ Download mac-linux/install.sh**](../mac-linux/install.sh)

```bash
curl -fsSL https://raw.githubusercontent.com/jogdandsainath/p2d-agentic-command-center-installer/main/mac-linux/install.sh -o install.sh
chmod +x install.sh
```

---

### 2. Set your credentials

```bash
export SERVICE_SHARED_SECRET='paste-your-secret-here'
export E_DIVIN_ACTOR='your-github-username'
```

---

### 3. Run the installer

Pick your AI tool and replace `ui-squad` with your squad key:

#### OpenAI Codex
```bash
bash install.sh --squad ui-squad --runtime codex
```

#### Anthropic Claude Code
```bash
bash install.sh --squad ui-squad --runtime claude
```

#### GitHub Copilot
```bash
bash install.sh --squad ui-squad --runtime copilot
```

#### Service / Backend runner only
```bash
bash install.sh --squad backend-squad --runtime service
```

---

### 5. What happens automatically

| Step | What the installer does |
|------|------------------------|
| ✅ Install Node.js 20 | Via `nvm` |
| ✅ Install AI CLI | `npm install -g @openai/codex` / `@anthropic-ai/claude-code` / `apt/dnf install gh` |
| ✅ Set environment variables | Written to `~/.e-divin/env`, sourced in `~/.bashrc` |
| ✅ Register machine | Calls Command Center `/machines/register` |
| ✅ Install systemd user service | `~/.config/systemd/user/e-divin-runner-*.service` — starts at login |
| ✅ Start runner | Begins polling for commands immediately |

---

### 6. Verify it worked

Open the **Command Center dashboard** → **Automation** → **Machine Runner Health**

Your machine should appear within 60 seconds.

---

## One-liner (no download)

```bash
export SERVICE_SHARED_SECRET='YOUR_SECRET'
export E_DIVIN_ACTOR='YOUR_USERNAME'
curl -fsSL https://e-divin-agent-communication-service.vercel.app/install.sh \
  | bash -s -- --squad ui-squad --runtime codex
```

---

## Add secret to shell profile (recommended)

```bash
echo "export SERVICE_SHARED_SECRET='YOUR_SECRET'" >> ~/.bashrc
echo "export E_DIVIN_ACTOR='YOUR_USERNAME'" >> ~/.bashrc
source ~/.bashrc
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `systemctl --user` fails | Run `loginctl enable-linger $USER` to enable user services |
| `nvm: command not found` | Run `source ~/.bashrc` or restart shell |
| Machine not in dashboard | Check logs: `~/.e-divin/runner.log` |
| systemd service not running | `systemctl --user start e-divin-runner-<squad>` |
| Permission denied on install.sh | Run `chmod +x install.sh` first |

---

## Uninstall

```bash
systemctl --user stop e-divin-runner-* 2>/dev/null
systemctl --user disable e-divin-runner-* 2>/dev/null
rm ~/.config/systemd/user/e-divin-runner-*.service
systemctl --user daemon-reload
rm -rf ~/.e-divin
```
