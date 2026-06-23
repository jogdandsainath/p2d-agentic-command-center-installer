# Pur2Divin Machine Onboarding Guide

## 1. Prepare The Product Workspace

The administrator must complete these steps in Command Center before installing:

1. Select the correct product workspace.
2. Verify the product name and workspace key.
3. Create or select a squad assigned to that product.
4. Confirm the intended runtime tool.
5. Create an enrollment token for the machine.

Do not proceed when the product or squad is uncertain. Product assignment controls which agents, prompts, messages, approvals, and work can reach the machine.

## 2. Run The Guided Installer

Use the operating-system command in the repository README.

The installer asks for:

| Input | Meaning |
|---|---|
| Product workspace key | The single product this runner serves |
| Product ID | Immutable product identity supplied by Command Center |
| Squad key | The squad receiving commands |
| Squad ID | Immutable product-squad identity supplied by Command Center |
| Release / wave | Isolates commands and evidence for the active delivery scope |
| Runtime | Codex, Claude, Copilot, Cursor, or service |
| User ID | Human or service owner recorded in audit evidence |
| Enrollment token | Secret supplied by Command Center |

## 3. Tool Authentication

The installer configures the runtime but does not copy personal vendor credentials.

After installation, authenticate the selected tool using its own secure login:

- Codex: run `codex` and complete its sign-in flow.
- Claude Code: run `claude` and complete its sign-in flow.
- GitHub Copilot: run `gh auth login`, then verify Copilot access.
- Cursor: sign in to Cursor and enable the `cursor` shell command.

## 4. AI Tool Capability Profile

Each installation writes a product-scoped capability profile under the machine workspace `hooks` folder. This profile explains how the selected tool should connect to Command Center.

What it includes:

- Product, release, squad, runtime, host, and workspace identity.
- Command Center API, Swagger, and OpenAPI links.
- Required `P2D_*` environment variable names.
- Local inbox, outbox, runtime, config, log, and hook folders.
- Startup hook command for Codex, Claude, GitHub Copilot, Cursor, or service runners.
- Visible-session prompt path.

Use the startup hook from the profile when the AI tool supports hooks, startup tasks, rules, MCP configuration, or agent launch commands. The hook writes a local tool-launch event and wakes the squad runner. The squad runner then sends the heartbeat, registers the visible session, and writes the local prompt packet for the selected product and squad.

Command Center remains the source of truth. Local files are the machine copy of the product's approved capability profile.

## 5. Verify Command Center Registration

Open the same product workspace used during installation:

1. **Automation** must show the machine runner.
2. **Squads & Runtimes** must show the selected squad and runtime.
3. **Runtime Sessions** must not show resources from another product.
4. Runner health must change from starting to idle or active.

## 6. Run A Low-Risk Test

Send a low-risk command to the selected squad. Verify:

1. Command Center records the command.
2. The machine runner claims it.
3. A local inbox packet is created.
4. The visible agent session receives the governed prompt.
5. Evidence returns to the same product workspace.

## 7. Security Rules

- Never paste enrollment tokens into GitHub issues, prompts, or chat.
- Use a different enrollment token for each onboarding window.
- Revoke the token after installation.
- Retire or transfer the machine from Command Center before reassigning it.
- Never point one runner at multiple products.
- Do not edit hook, prompt, or MCP policy locally to bypass Command Center.

## 8. Ownership Transfer

To move a machine or agent to another squad:

1. Initiate transfer in the source product Command Center.
2. Capture memory and active-work evidence.
3. Approve the transfer when governance requires it.
4. Update the local runner registration.
5. Verify the destination squad before resuming commands.

Do not edit local configuration as a substitute for an audited transfer.
