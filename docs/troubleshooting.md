# Troubleshooting

---

## Machine not appearing in Command Center

1. Check runner logs:
   - **Windows**: `%LOCALAPPDATA%\E-Divin\runner.log`
   - **macOS / Linux**: `~/.e-divin/runner.log`
2. Verify `SERVICE_SHARED_SECRET` is set correctly
3. Verify the Command Center URL is reachable: `curl https://e-divin-agent-communication-service.vercel.app/health`

---

## SERVICE_SHARED_SECRET errors

```bash
# macOS/Linux — add to shell profile permanently
echo "export SERVICE_SHARED_SECRET='sk-your-secret'" >> ~/.zshrc
source ~/.zshrc

# Windows — set machine-level (Admin PowerShell)
[Environment]::SetEnvironmentVariable('SERVICE_SHARED_SECRET','sk-your-secret','Machine')
```

---

## AI CLI not found after install

```bash
# Codex
npm install -g @openai/codex

# Claude Code
npm install -g @anthropic-ai/claude-code

# GitHub CLI (macOS)
brew install gh
gh auth login
gh copilot --help
```

---

## Background runner not starting

**Windows** — Open Task Scheduler, find `E-Divin-Runner-*`, right-click → Run

**macOS** — Reload launchd:
```bash
launchctl unload ~/Library/LaunchAgents/com.e-divin.runner-*.plist
launchctl load ~/Library/LaunchAgents/com.e-divin.runner-*.plist
```

**Linux** — Restart systemd service:
```bash
systemctl --user restart e-divin-runner-<your-squad>
```

---

## Re-run installer (safe to repeat)

The installer is idempotent — safe to run again on the same machine. It will update env vars and re-register the machine without duplicating anything.

---

## Getting your SERVICE_SHARED_SECRET

Ask your **founder** — they find it in:
**Command Center Dashboard → Settings → Service Secret**
