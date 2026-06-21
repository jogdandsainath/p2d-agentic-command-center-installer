# Pur2Divin Agentic Command Center Installer

One guided installer connects a Windows, macOS, or Linux machine to one Pur2Divin product workspace and squad.

The installer is platform-neutral. E-Divin is an existing product workspace, not the platform default.

## Supported Agent Tools

| Tool | Installer behavior |
|---|---|
| OpenAI Codex | Installs or detects Node.js and Codex CLI |
| Anthropic Claude Code | Installs or detects Node.js and Claude Code |
| GitHub Copilot | Installs or detects GitHub CLI and Copilot tooling |
| Cursor | Detects the Cursor shell launcher and configures the Pur2Divin runner |
| Service runner | Installs the background runner without an interactive coding tool |

## What The Installer Does

1. Collects the product workspace, squad, user ID, runtime, and enrollment token.
2. Refuses to assume E-Divin or any other product.
3. Generates a unique machine identity secret.
4. Installs or verifies the selected coding-agent tool.
5. Registers the machine and squad against the selected product.
6. Creates product-specific inbox, outbox, runtime, configuration, and log paths.
7. Installs a persistent background runner:
   - Windows Scheduled Task
   - macOS launchd agent
   - Linux systemd user service
8. Publishes a health signal to Command Center.

## Before Installation

In Pur2Divin Command Center:

1. Open the required product workspace.
2. Create or select the destination squad.
3. Generate or obtain a short-lived enrollment token.
4. Confirm the user ID that will own the machine registration.

Never reuse a token from another organization or product.

## Simplest Installation

When Node.js 20 or newer is already installed:

```bash
npx github:jogdandsainath/p2d-agentic-command-center-installer
```

This opens the same guided workflow on Windows, macOS, and Linux.

## Windows

Open PowerShell:

```powershell
iwr 'https://raw.githubusercontent.com/jogdandsainath/p2d-agentic-command-center-installer/main/windows/install.ps1' `
  -UseBasicParsing -OutFile "$env:TEMP\p2d-install.ps1"
powershell -ExecutionPolicy Bypass -File "$env:TEMP\p2d-install.ps1"
```

The guided installer asks for all required values. For automated installation:

```powershell
$env:P2D_ENROLLMENT_TOKEN = 'TOKEN_FROM_COMMAND_CENTER'
$env:P2D_ACTOR = 'organization-user-id'
powershell -ExecutionPolicy Bypass -File "$env:TEMP\p2d-install.ps1" `
  -ProductKey 'product-workspace-key' `
  -Squad 'squad-key' `
  -Runtime 'codex'
```

## macOS Or Linux

```bash
curl -fsSL \
  'https://raw.githubusercontent.com/jogdandsainath/p2d-agentic-command-center-installer/main/mac-linux/install.sh' \
  | bash
```

For automated installation:

```bash
export P2D_ENROLLMENT_TOKEN='TOKEN_FROM_COMMAND_CENTER'
export P2D_ACTOR='organization-user-id'
curl -fsSL \
  'https://raw.githubusercontent.com/jogdandsainath/p2d-agentic-command-center-installer/main/mac-linux/install.sh' \
  | bash -s -- \
      --product 'product-workspace-key' \
      --squad 'squad-key' \
      --runtime 'claude'
```

## Runtime Values

Use one of:

```text
codex
claude
copilot
cursor
service
```

## Installation Locations

| OS | Runtime data |
|---|---|
| Windows | `%LOCALAPPDATA%\Pur2Divin` |
| macOS / Linux | `~/.pur2divin` |

Each installation is product- and squad-bound. Switching products requires a separate registration or a governed ownership transfer from Command Center.

## Verification

After installation:

1. Open the selected product workspace.
2. Go to **Automation**.
3. Confirm the machine appears under runner health.
4. Confirm its product, squad, runtime tool, and host key.
5. Send a low-risk test command to that squad.
6. Confirm the command reaches the local inbox and reports evidence back.

See [docs/installation-guide.md](docs/installation-guide.md) for the full operator procedure and [docs/troubleshooting.md](docs/troubleshooting.md) for recovery steps.

## Compatibility

New installations use `P2D_*` configuration names. Legacy `E_DIVIN_*` aliases remain temporarily available so existing E-Divin runners continue operating during migration.
