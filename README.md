# Sol–Terra Codex Workflow

Reusable Codex setup that runs **GPT-5.6 Sol** as the main orchestrator and delegates bounded implementation work to a **GPT-5.6 Terra** executor.

## What gets installed

```text
AGENTS.md
.codex/
├── config.toml
└── agents/
    └── terra-executor.toml
codex-sol-terra
codex-sol-terra.ps1
```

- `AGENTS.md` defines when the main agent should delegate and when it must keep control.
- `.codex/config.toml` selects Sol for the main session and limits nested agent spawning.
- `.codex/agents/terra-executor.toml` defines the Terra implementation agent.
- The launcher scripts explicitly start Codex with Sol, including when a project already has its own config.

## Install into a project

### Linux, macOS, or WSL

Run this from the root of the target project:

```bash
curl -fsSL https://raw.githubusercontent.com/TaqiyudinMiftah/agent-skills/main/install.sh | bash
```

To install into another directory:

```bash
curl -fsSL https://raw.githubusercontent.com/TaqiyudinMiftah/agent-skills/main/install.sh \
  | bash -s -- /path/to/project
```

To replace an existing `.codex/config.toml` after making a timestamped backup:

```bash
curl -fsSL https://raw.githubusercontent.com/TaqiyudinMiftah/agent-skills/main/install.sh \
  | bash -s -- . --force
```

### Windows PowerShell

Run this from the root of the target project:

```powershell
& ([scriptblock]::Create((Invoke-RestMethod "https://raw.githubusercontent.com/TaqiyudinMiftah/agent-skills/main/install.ps1")))
```

For custom options, download the script and run it directly:

```powershell
Invoke-WebRequest "https://raw.githubusercontent.com/TaqiyudinMiftah/agent-skills/main/install.ps1" -OutFile install-sol-terra.ps1
./install-sol-terra.ps1 -TargetPath "C:\path\to\project" -Force
```

## Start Codex

Linux, macOS, or WSL:

```bash
./codex-sol-terra
```

Windows PowerShell:

```powershell
./codex-sol-terra.ps1
```

You can also start Codex normally after trusting the project:

```bash
codex
```

Codex only loads project-scoped `.codex/config.toml` files for trusted projects. The launcher still explicitly selects `gpt-5.6-sol`.

## Example task

```text
Implement the password-reset feature.

Act as the orchestrator:
1. Inspect the existing authentication architecture.
2. Produce a concise plan and acceptance criteria.
3. Delegate only the fully specified implementation work to terra_executor.
4. Wait for Terra, inspect its diff, and verify the relevant tests.
5. Resolve correctness, architecture, and security issues before reporting completion.
```

Inside an interactive Codex session, use `/agent` to inspect the executor thread.

## Existing-file behavior

- Existing `AGENTS.md`: the managed workflow block is appended once; unrelated project instructions are preserved.
- Existing `.codex/config.toml`: preserved by default. Use `--force` or `-Force` to back it up and install the provided config.
- Existing Terra agent file: backed up when its content changes, then updated.
- Launcher files: regenerated on each installation.

Review backups before deleting them. They use names such as `config.toml.bak.20260714-210000`.

## Customize cost and quality

Edit `.codex/agents/terra-executor.toml`:

```toml
model_reasoning_effort = "low"
```

Change it to `medium` when the executor needs more planning. Keep architecture decisions, security-sensitive changes, destructive migrations, and final review with Sol.

## Prerequisites

- A current Codex CLI installation.
- Access to the selected models on your ChatGPT or API account.
- `curl` for the shell installer, or PowerShell 5+ for the Windows installer.

## Official references

- [Codex subagents](https://developers.openai.com/codex/concepts/subagents)
- [AGENTS.md guidance](https://developers.openai.com/codex/guides/agents-md)
- [Codex configuration reference](https://developers.openai.com/codex/config-reference)
- [Codex models](https://developers.openai.com/codex/models)

## License

MIT
