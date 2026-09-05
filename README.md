# Fedora Silverblue Dotfiles

Personal workstation configuration for Fedora Silverblue.

The setup keeps the immutable host relatively small and uses user-level tooling where practical.

## Architecture

Tool ownership is intentionally separated:

| Concern | Tool |
|---|---|
| Dotfiles | chezmoi |
| Language runtimes | mise |
| Developer CLI tools | mise |
| JavaScript project dependencies | pnpm |
| Python project/tool workflows | uv |
| Containers | Podman |
| GUI applications | Flatpak where practical |
| System-integrated applications | RPM/rpm-ostree when required |
| Claude Code | Anthropic native installer |
| Codex CLI | mise |

Do not use multiple package managers to manage the same tool.

## Managed Configuration

The repository includes configuration for:

- Bash
- Git
- Kitty
- tmux
- mise
- Zed
- shad
- systemd user services
- Claude Code
- Codex
- zoxide
- Bash completion files

The repository also contains shared agent safety configuration used by Claude Code and Codex.

## Not Managed

Authentication and machine-local application state MUST NOT be committed.

Examples include:

```text
~/.claude.json
~/.codex/auth.json
~/.codex/*.sqlite*
~/.config/gh/
~/.azure/
~/.local/share/proton-pass-cli/.session/
```

Caches, logs, browser profiles, desktop state, and downloaded application packages are also intentionally excluded.

## New Workstation Bootstrap

### 1. Prepare Fedora Silverblue

Update the system:

```bash
rpm-ostree upgrade
```

Reboot if a new deployment was created.

Install the small set of host-level tools required by the workstation.

Host-level packages are reserved for software that requires direct system integration.

### 2. Install chezmoi

Install chezmoi using its official user-level installer.

Verify:

```bash
chezmoi --version
```

### 3. Apply the dotfiles

Initialize chezmoi from this repository:

```bash
chezmoi init https://github.com/MirzaMerdovic/dotfiles.git
chezmoi diff
chezmoi apply
```

Review the diff before applying configuration to an existing machine.

Start a new shell after applying:

```bash
exec bash
```

### 4. Install mise

Install mise using its official installer.

The managed configuration is stored at:

```text
~/.config/mise/config.toml
```

Install the configured runtimes and tools:

```bash
mise install
```

Verify:

```bash
mise doctor
mise ls
```

### 5. Restore Machine-Local Authentication

Authentication is intentionally not stored in this repository.

Authenticate the tools that are required on the machine.

Examples:

```bash
gh auth login
gh auth setup-git

az login

pass-cli login
```

Authenticate Claude Code and Codex separately using their supported login flows.

## CLI Tooling

The global mise configuration includes development tools such as:

```text
Go
Node.js
Python
Bun
pnpm
Codex

ripgrep
fd
fzf
jq
yq
gh

ShellCheck
shfmt
uv

bat
zoxide
just
delta
eza
```

TypeScript, React, Vite, and similar application dependencies should normally remain project-local.

## Shell Script Verification

ShellCheck and `shfmt` are available globally.

For changed shell scripts:

```bash
shellcheck path/to/script.sh
shfmt -d path/to/script.sh
```

Claude Code and Codex are also instructed to perform these checks when modifying shell scripts.

## Tool Updates

Update tools through the package manager that owns them.

### mise-managed tools

Check:

```bash
mise outdated
```

Upgrade:

```bash
mise upgrade
```

Codex is mise-managed:

```bash
mise upgrade 'npm:@openai/codex'
```

pnpm is also mise-managed.

Do not use:

```bash
pnpm self-update
```

### Claude Code

Claude Code uses Anthropic's native installer:

```bash
claude update
```

Check installation health with:

```bash
claude doctor
```

### Fedora Silverblue

Update the host with:

```bash
rpm-ostree upgrade
```

### Flatpak

Update GUI applications with:

```bash
flatpak update
```

## AI Coding Agents

Global Claude Code instructions are stored in:

```text
~/.claude/CLAUDE.md
```

Claude's default engineering persona is stored in:

```text
~/.claude/output-styles/pragmatic-engineer.md
```

Global Codex instructions are stored in:

```text
~/.codex/AGENTS.md
```

Both agents use a shared Git safety guard under:

```text
~/.local/libexec/agent-guards/
```

The agents:

- MUST NOT push directly to remote `main`.
- MAY commit to local `main`.
- MAY push non-`main` branches.
- MUST NOT add AI or co-author attribution to commits or pull requests.
- SHOULD verify changes before reporting them as successful.

Remote repository rules should provide the authoritative protection for `main`.

## Keep-Awake Service

The workstation includes a user-level caffeine service.

Start:

```bash
awake-on
```

Stop:

```bash
awake-off
```

Check:

```bash
awake-status
```

The service inhibits both system sleep and GNOME idle locking while active.

It is not enabled automatically at login.

## Dotfiles Workflow

Edit the live configuration normally, then import the change into chezmoi:

```bash
chezmoi add ~/.config/example/config
```

Review:

```bash
chezmoi diff
```

Inspect repository changes:

```bash
chezmoi cd
git status
git diff
```

Commit only after reviewing the changes.

Never add an entire application-state directory without first inspecting its contents.

## Validation

Useful checks after restoring the workstation:

```bash
chezmoi diff
mise doctor
mise ls

git --version
gh --version
podman --version
tmux -V

claude --version
codex --version

shellcheck --version
shfmt --version

bat --version
zoxide --version
just --version
delta --version
eza --version
```

An empty:

```bash
chezmoi diff
```

indicates that the live managed configuration matches the repository state.
