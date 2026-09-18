#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

die() {
	printf 'error: %s\n' "$*" >&2
	exit 1
}

command -v chezmoi >/dev/null 2>&1 ||
	die "chezmoi not found. Install chezmoi, then re-run this script."

printf 'Setting the chezmoi source directory to %s\n' "$REPO_DIR"
chezmoi init --source="$REPO_DIR"

printf 'Installing CLI tools...\n'
./scripts/install-tools.sh
