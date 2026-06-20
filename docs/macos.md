# macOS Installation Guide

Complete guide to onboarding a macOS machine into the P2D Agentic Command Center.

---

## Prerequisites

- macOS 12 Monterey or later
- Terminal (pre-installed)
- Internet connection
- `SERVICE_SHARED_SECRET` and squad key from your founder

---

## Step-by-step

### 1. Download the installer

[**⬇ Download mac-linux/install.sh**](../mac-linux/install.sh)

Save it to your `Downloads` folder.

---

### 2. Open Terminal

Press **⌘ Space** → type `Terminal` → press **Enter**

---

### 3. Set your credentials

```bash
export SERVICE_SHARED_SECRET='paste-your-secret-here'
export E_DIVIN_ACTOR='your-github-username'
```

---

### 4. Run the installer

Pick your AI tool and replace `ui-squad` with your squad key:

#### OpenAI Codex
```bash
bash ~/Downloads/install.sh --squad ui-squad --runtime codex
```

#### Anthropic Claude Code
```bash
bash ~/Downloads/install.sh --squad ui-squad --runtime claude
```

#### GitHub Copilot
```bash
bash ~/Downloads/install.sh --squad ui-squad --runtime copilot
```

---

### 5. What happens automatically

| Step | What the installer does |
|------|------------------------|
| ✅ Install Node.js 20 | Via `nvm` (Node Version Manager) |
| ✅ Install AI CLI | `npm install -g @openai/codex` / `@anthropic-ai/claude-code` / `brew install gh` |
| ✅ Set environment variables | Written to `~/.e-divin/env`, sourced in `~/.zshrc` / `~/.bashrc` |
| ✅ Register machine | Calls Command Center `/machines/register` |
| ✅ Install launchd service | Runs squad runner automatically at login (`~/Library/LaunchAgents/`) |
| ✅ Start runner | Begins polling for commands immediately |

---

### 6. Verify it worked

Open the **Command Center dashboard** → **Automation** → **Machine Runner Health**

Your machine should appear within 60 seconds.

---

## One-liner alternative (no download)

```bash
export SERVICE_SHARED_SECRET='YOUR_SECRET'
export E_DIVIN_ACTOR='YOUR_USERNAME'
curl -fsSL https://e-divin-agent-communication-service.vercel.app/install.sh \
  | bash -s -- --squad ui-squad --runtime claude
```

---

## Add secret to shell profile (recommended)

So you don't need to set it every time:

```bash
echo "export SERVICE_SHARED_SECRET='YOUR_SECRET'" >> ~/.zshrc
echo "export E_DIVIN_ACTOR='YOUR_USERNAME'" >> ~/.zshrc
source ~/.zshrc
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `bash: curl: command not found` | Install Xcode CLI tools: `xcode-select --install` |
| `nvm: command not found` after install | Run `source ~/.zshrc` or restart Terminal |
| Machine not in dashboard | Check logs: `~/.e-divin/runner.log` |
| launchd service not running | Run `launchctl load ~/Library/LaunchAgents/com.e-divin.runner-*.plist` |
| `claude: command not found` | Run `npm install -g @anthropic-ai/claude-code` manually |

---

## Uninstall

```bash
# Remove launchd service
launchctl unload ~/Library/LaunchAgents/com.e-divin.runner-*.plist
rm ~/Library/LaunchAgents/com.e-divin.runner-*.plist
# Remove files
rm -rf ~/.e-divin
# Remove from shell profile (edit ~/.zshrc and remove the e-divin lines)
```
