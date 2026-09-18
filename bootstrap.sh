#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

touch .chezmoiignore

grep -qxF 'README.md' .chezmoiignore ||
	printf '%s\n' 'README.md' >>.chezmoiignore

grep -qxF 'bootstrap.sh' .chezmoiignore ||
	printf '%s\n' 'bootstrap.sh' >>.chezmoiignore

grep -qxF 'scripts/' .chezmoiignore ||
	printf '%s\n' 'scripts/' >>.chezmoiignore

CHEZMOI_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/chezmoi/chezmoi.toml"

if [[ -f "$CHEZMOI_CONFIG" ]]; then
	if grep -qxF "sourceDir = \"${REPO_DIR}\"" "$CHEZMOI_CONFIG"; then
		printf 'chezmoi source directory already set to %s\n' "$REPO_DIR"
	else
		printf 'warning: %s exists and does not set sourceDir to %s. Left unchanged.\n' \
			"$CHEZMOI_CONFIG" "$REPO_DIR" >&2
	fi
else
	mkdir -p -- "$(dirname -- "$CHEZMOI_CONFIG")"
	printf 'sourceDir = "%s"\n' "$REPO_DIR" >"$CHEZMOI_CONFIG"
	printf 'Wrote %s\n' "$CHEZMOI_CONFIG"
fi

printf 'Installing CLI tools...\n'
./scripts/install-tools.sh
