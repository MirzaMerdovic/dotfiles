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
| Kitty and Zed | Vendor installers |
| Claude Code | Anthropic native installer |
| Codex CLI | mise |

Do not use multiple package managers to manage the same tool.

## Managed Configuration

The repository includes configuration for:

- Bash
- Git
- Kitty
- JetBrains Mono font
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
~/.claude/settings.local.json
~/.codex/auth.json
~/.codex/*.sqlite*
~/.config/gh/
~/.azure/
~/.local/share/proton-pass-cli/.session/
```

Caches, logs, browser profiles, desktop state, and downloaded application packages are also intentionally excluded.

`~/.config/shad/shad.toml` is also not managed. It holds a machine-specific project list.

`~/.claude/settings.local.json` is also not managed. `.chezmoiignore` lists the path.

## New Workstation Bootstrap

### 1. Prepare Fedora Silverblue

Update the system:

```bash
rpm-ostree upgrade
```

Reboot if a new deployment was created.

Host-level packages are reserved for software that requires direct system integration.

#### Package repositories

Enable the third-party repositories. This enables Flathub and the RPM Fusion NVIDIA driver repository:

```bash
sudo fedora-third-party enable
```

Add the NetBird repository:

```bash
sudo tee /etc/yum.repos.d/netbird.repo <<'EOF'
[NetBird]
name=NetBird
baseurl=https://pkgs.netbird.io/yum/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.netbird.io/yum/repodata/repomd.xml.key
repo_gpgcheck=1
EOF
```

#### Secure Boot signing key

Secure Boot is enabled. The kernel loads the NVIDIA module only when the module is signed with an enrolled Machine Owner Key (MOK). akmods signs the module with the key pair in `/etc/pki/akmods`. On Silverblue, akmods cannot read that directory during an rpm-ostree transaction. The local package `akmods-keys` from [CheariX/silverblue-akmods-keys](https://github.com/CheariX/silverblue-akmods-keys) installs a copy of the key pair that akmods can read.

The enrolled MOK stays in the firmware after a reinstall. The key pair does not. Back it up before the reinstall:

```bash
sudo tar -C /etc/pki -czf akmods-keys.tar.gz akmods/certs akmods/private
```

The archive contains the private key. Store it as a credential.

Install the build requirements:

```bash
rpm-ostree install --apply-live rpmdevtools akmods
```

Restore the key pair from the backup:

```bash
sudo tar -C /etc/pki -xzf akmods-keys.tar.gz
```

Without a backup, create a new key pair and request its enrollment. `mokutil` asks for a one-time password. The MOK manager asks for the same password at the next boot.

```bash
sudo kmodgenca
sudo mokutil --import /etc/pki/akmods/certs/public_key.der
```

Build and install `akmods-keys`:

```bash
git clone https://github.com/CheariX/silverblue-akmods-keys
cd silverblue-akmods-keys
sudo bash setup.sh
rpm-ostree install "akmods-keys-0.0.2-8.fc$(rpm -E %fedora).noarch.rpm"
```

The built RPM contains the private key. Delete it after the install.

Reboot.

#### Layered packages

```bash
rpm-ostree install akmod-nvidia xorg-x11-drv-nvidia-cuda netbird netbird-ui podman-compose tmux
```

Slack and Zoom are local RPMs. Download them from <https://slack.com/downloads/linux> and <https://zoom.us/download?os=linux>, then install them:

```bash
rpm-ostree install ./slack-*.rpm ./zoom_x86_64.rpm
```

#### Kernel arguments

```bash
rpm-ostree kargs \
	--append=rd.driver.blacklist=nouveau,nova_core \
	--append=modprobe.blacklist=nouveau,nova_core \
	--append=acpi_backlight=native \
	--append=amdgpu.dcdebugmask=0x10
```

- The blacklist arguments stop the `nouveau` and `nova_core` drivers from loading, so the NVIDIA driver binds to the GPU.
- `acpi_backlight=native` selects the native backlight driver.
- `amdgpu.dcdebugmask=0x10` disables Panel Self Refresh in the AMD display driver.

Reboot. Verify that the loaded NVIDIA module is signed with the akmods key:

```bash
modinfo -F signer nvidia
```

The output is the key name, for example `fedora_1788802164_0a05346e`.

#### Flatpak applications

```bash
flatpak install flathub app.zen_browser.zen io.dbeaver.DBeaverCommunity
```

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

### 8. Install the remaining applications

Kitty and Zed use their vendor installers. The installers write the applications to `~/.local/kitty.app` and `~/.local/zed.app`.

```bash
curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin
curl -f https://zed.dev/install.sh | sh
```

The Zed installer links `~/.local/bin/zed` and creates a desktop entry. The kitty installer does neither. Link the binaries and create the desktop entry:

```bash
ln -sf ~/.local/kitty.app/bin/kitty ~/.local/kitty.app/bin/kitten ~/.local/bin/
mkdir -p ~/.local/share/applications
cp ~/.local/kitty.app/share/applications/kitty.desktop ~/.local/share/applications/
sed -i \
	-e "s|Icon=kitty|Icon=$HOME/.local/kitty.app/share/icons/hicolor/256x256/apps/kitty.png|" \
	-e "s|Exec=kitty|Exec=$HOME/.local/kitty.app/bin/kitty|" \
	~/.local/share/applications/kitty.desktop
```

Install the Python CLI applications as uv tools:

```bash
uv tool install azure-cli
uv tool install --editable ~/src/tin/shad
```

`shad` is an editable install. It runs the code in a clone of [throw-if-null/shad](https://github.com/throw-if-null/shad), so clone the repository first. The path is an example. Do not move or delete the clone after the install.

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
Databricks CLI
Exoscale CLI
rainfrog
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

`rpm-ostree upgrade` does not update the local RPMs: `akmods-keys`, Slack, and Zoom. To update one, install the new RPM file and uninstall the old package in one transaction:

```bash
rpm-ostree install ./slack-*.rpm --uninstall slack
```

### Flatpak

Update GUI applications with:

```bash
flatpak update
```

### JetBrains Mono

Kitty uses JetBrains Mono. `.chezmoiexternal.toml` declares the font. `chezmoi apply` downloads the release archive and writes the variable fonts to `~/.local/share/fonts/JetBrainsMono`. fontconfig reads that directory, so no host package is required.

The entry pins the archive URL and its SHA-256 checksum. `chezmoi apply` fails when the downloaded archive does not match the checksum. JetBrains publishes no checksum for the archive. The pinned value is the hash of the archive when it was pinned.

The entry in `.chezmoiexternal.toml` writes below `~/.local/share`. `private_dot_local/private_share/.keep` declares `~/.local/share` with mode `0700`. It MUST NOT be removed. Without it, chezmoi treats `~/.local/share` as a parent directory of the external and changes its mode to `0755`.

Update the font:

1. Set `url` to the archive of the new release.
2. Compute the checksum with `curl -fsSL <url> | sha256sum`.
3. Set `checksum.sha256` to the result.
4. Run `chezmoi apply`.

## AI Coding Agents

Global Claude Code instructions are stored in:

```text
~/.claude/CLAUDE.md
```

Claude's default engineering persona is stored in:

```text
~/.claude/output-styles/pragmatic-engineer.md
```

The `doc-maintenance` skill comes from the [haddock](https://github.com/throw-if-null/haddock) Claude Code plugin. `dot_claude/modify_settings.json` adds the `throw-if-null` marketplace at a tagged `ref` and enables `haddock@throw-if-null`.

To update the plugin, change `ref`, run `chezmoi apply`, then run `claude plugin marketplace update throw-if-null` and `claude plugin update haddock@throw-if-null`.

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
- MUST NOT add generic tool attribution to commits or pull requests.
- MUST commit under the user's Git identity in a session the user directs.
- MAY commit under its own configured identity when it works without the user's direction.
- SHOULD verify changes before reporting them as successful.

Remote repository rules should provide the authoritative protection for `main`.

### Guard verification

`scripts/test_agent_guards.py` tests the guard at two levels:

- It writes hook payloads to the guard on stdin in a subprocess and asserts the exit code. Status 2 denies the tool call and status 0 permits it.
- It imports the guard and calls its functions directly, which reaches inputs that are awkward to express as a command.

The suite uses only the Python standard library.

Check the repository copy:

```bash
./scripts/test_agent_guards.py
```

Check the copy the hook runs:

```bash
./scripts/test_agent_guards.py --deployed
```

Name every case:

```bash
./scripts/test_agent_guards.py --verbose
```

Run the second command after `chezmoi apply`. The repository copy and the deployed copy differ until the apply completes, and only the deployed copy enforces the policy.

The guard resolves git aliases, because an alias can hide a push. It reads them from the directory in the hook payload. An alias that shadows a built-in command is not resolved, because git ignores such an alias.

### Claude Code settings

chezmoi manages part of `~/.claude/settings.json`. Claude Code writes its own keys to the same file, for example `model`, `modelSettings`, `autoMode`, and `skillOverrides`. `/model` saves the default model to this file.

`dot_claude/modify_settings.json` is a chezmoi modify script. On `chezmoi apply`, chezmoi sends the live file to the script on stdin. The script merges the repository keys into the live content with `jq`:

- An object merges key by key, at every depth.
- Any other value replaces the live value. This includes arrays, for example `hooks.PreToolUse`.
- A key that the repository does not set keeps its live value.

The script requires `jq` on `PATH`. [Run the bootstrap script](#4-run-the-bootstrap-script) lists `jq` as a host requirement.

`chezmoi diff ~/.claude/settings.json` reports a difference only when a repository key has a different live value. Claude Code changes `theme`, `outputStyle`, and `enabledPlugins` when they are changed in a session. `chezmoi apply` restores the repository values.

To change a managed key, edit the JSON document in `dot_claude/modify_settings.json`.

The live file can hold organization-specific values, and this repository is public. `chezmoi add` MUST NOT be run on `~/.claude/settings.json` or on `~/.claude`. It replaces the modify script with a copy of the live file, without a prompt. `chezmoi re-add` skips the file.

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
