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
- shad (bash completion only)
- systemd user services
- Claude Code
- Codex
- zoxide

Bash completions are generated from the installed binary at shell start, by a snippet in `~/.bashrc.d`. No completion script is committed. A committed script is a copy that drifts from the CLI it completes.

The repository also contains shared agent safety configuration used by Claude Code and Codex.

### Shell entry point

`~/.bashrc` is managed. It reproduces the behaviour of Fedora's stock file:

- It sources `/etc/bashrc`.
- It prepends `$HOME/.local/bin` and `$HOME/bin` to `PATH`.
- It sources the snippets in `~/.bashrc.d`.

It differs from the stock file in two ways:

- It sources `~/.bashrc.d/*.sh` rather than every file in that directory. An editor backup such as `30-aliases.sh~` is therefore not sourced.
- It sources `~/.bashrc.local` last, when that file exists.

The entry point MUST be managed. The snippets in `~/.bashrc.d` load only because `~/.bashrc` iterates that directory. An unmanaged entry point can be replaced without `chezmoi diff` reporting a change, because no managed file changes. Every snippet then stops loading and the validation check does not detect it.

### Machine-local shell settings

`~/.bashrc.local` holds shell settings that MUST NOT be committed, such as credentials and host-specific completions. The file is not managed, so `chezmoi apply` does not overwrite it. Create it with mode `600`.

## Not Managed

Authentication and machine-local application state MUST NOT be committed.

Examples include:

```text
~/.bashrc.local
~/.claude.json
~/.codex/auth.json
~/.codex/*.sqlite*
~/.config/gh/
~/.azure/
~/.local/share/proton-pass-cli/.session/
```

Caches, logs, browser profiles, desktop state, and downloaded application packages are also intentionally excluded.

`~/.config/shad/shad.toml` is also not managed. It holds a machine-specific project list.

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

### 3. Initialize chezmoi

```bash
chezmoi init --source=~/src/mm/dotfiles https://github.com/MirzaMerdovic/dotfiles.git
```

`--source` sets both the clone location and the chezmoi source directory. Any path works. `~/src/mm/dotfiles` is an example. Omit `--source` to use the chezmoi default, `~/.local/share/chezmoi`.

The repository contains `.chezmoi.toml.tmpl`. chezmoi renders it during `init` and writes the chosen location to `~/.config/chezmoi/chezmoi.toml`. Later chezmoi commands require no `--source` flag.

`init` also prompts for the git identity:

```text
Git user name
Git email address
```

The answers are stored in `~/.config/chezmoi/chezmoi.toml` and render `~/.config/git/config`. The identity is not committed, so a different person can install this repository without inheriting another person's name and address.

A non-interactive `init` accepts the defaults, `Your Name` and `you@example.invalid`. Both are placeholders. Replace them:

```bash
chezmoi init --promptString git.name='Your Name' --promptString git.email='you@example.com'
```

`chezmoi init` re-prompts only for values that `~/.config/chezmoi/chezmoi.toml` does not already hold, so it is safe to re-run.

Verify the source directory:

```bash
chezmoi source-path
```

Re-run `chezmoi init --source=<new path>` after moving the clone. The recorded path is absolute.

### 4. Run the bootstrap script

```bash
cd "$(chezmoi source-path)"
./bootstrap.sh
```

The script performs two actions:

- It runs `chezmoi init` to keep the recorded source directory current.
- It installs the CLI tools that mise does not manage.

chezmoi is a prerequisite. The script exits with status 1 when `chezmoi` is not on `PATH`, and it installs nothing. Complete step 2 first.

`chezmoi init` prompts for the git identity when `~/.config/chezmoi/chezmoi.toml` does not already hold it. See [Initialize chezmoi](#3-initialize-chezmoi).

The tool installation requires `curl`, `jq`, `sha256sum`, `python3`, and `install`. Install any missing command at host level before running the script.

### 5. Apply the dotfiles

```bash
chezmoi diff
chezmoi apply
```

Review the diff before applying configuration to an existing machine.

Start a new shell after applying:

```bash
exec bash
```

### 6. Install mise

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

### 7. Restore Machine-Local Authentication

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

TypeScript

ShellCheck
shfmt
uv
actionlint

bat
zoxide
just
delta
eza

OpenTofu
Terragrunt
```

TypeScript is installed globally for type checking outside a project. A project that declares `typescript` in `package.json` uses its own version through package scripts or `npx`.

React, Vite, and similar application dependencies MUST remain project-local.

`dot_config/mise/config.toml` is the authoritative list. This section is a summary.

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

### mise lockfile

`~/.config/mise/config.toml` sets `lockfile = true`, and `~/.config/mise/mise.lock` records the resolved version, download URL, and SHA-256 checksum of every tool. Both files are managed. The lockfile is what makes two machines install the same toolchain from the same commit, because most tools are declared as `latest`.

The lockfile covers seven platforms, so it is valid on Linux, macOS, and Windows, on x64 and arm64.

Update the pinned versions deliberately:

```bash
mise upgrade
mise lock --global
chezmoi re-add ~/.config/mise/mise.lock
```

Then commit the change to `dot_config/mise/private_mise.lock` and state which tools moved.

`mise lock --global` is required. Plain `mise lock` operates on the current project and reports that the global config declares the tools.

Run the same three commands after adding a tool to `[tools]`. An unlocked tool resolves to whatever version is current at install time, which is the behaviour the lockfile exists to prevent.

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

Global Claude Code skills are stored in:

```text
~/.claude/skills/
```

The `doc-style` skill applies the `Communication Style` and `Documentation` rules from `~/.claude/CLAUDE.md`. Both files are managed here, so the skill and the rules it implements stay in one repository.

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

### Expected diff output

Claude Code writes to `~/.claude/settings.json` while it runs. It updates the theme, the output style, and the enabled plugin state. A `chezmoi diff` for that file is therefore expected, and it does not indicate a broken configuration.

Review the difference before acting on it:

```bash
chezmoi diff ~/.claude/settings.json
```

Keep the live value:

```bash
chezmoi re-add ~/.claude/settings.json
```

Restore the repository value:

```bash
chezmoi apply ~/.claude/settings.json
```
