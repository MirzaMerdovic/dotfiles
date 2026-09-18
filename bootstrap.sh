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

if command -v chezmoi >/dev/null 2>&1; then
	printf 'Setting the chezmoi source directory to %s\n' "$REPO_DIR"
	chezmoi init --source="$REPO_DIR"
else
	printf 'warning: chezmoi not found. Install chezmoi, then re-run this script.\n' >&2
fi

printf 'Installing CLI tools...\n'
./scripts/install-tools.sh
