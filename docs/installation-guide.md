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

## 4. Verify Command Center Registration

Open the same product workspace used during installation:

1. **Automation** must show the machine runner.
2. **Squads & Runtimes** must show the selected squad and runtime.
3. **Runtime Sessions** must not show resources from another product.
4. Runner health must change from starting to idle or active.

## 5. Run A Low-Risk Test

Send a low-risk command to the selected squad. Verify:

1. Command Center records the command.
2. The machine runner claims it.
3. A local inbox packet is created.
4. The visible agent session receives the governed prompt.
5. Evidence returns to the same product workspace.

## 6. Security Rules

- Never paste enrollment tokens into GitHub issues, prompts, or chat.
- Use a different enrollment token for each onboarding window.
- Revoke the token after installation.
- Retire or transfer the machine from Command Center before reassigning it.
- Never point one runner at multiple products.

## 7. Ownership Transfer

To move a machine or agent to another squad:

1. Initiate transfer in the source product Command Center.
2. Capture memory and active-work evidence.
3. Approve the transfer when governance requires it.
4. Update the local runner registration.
5. Verify the destination squad before resuming commands.

Do not edit local configuration as a substitute for an audited transfer.
