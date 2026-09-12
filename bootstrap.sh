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

printf 'Installing CLI tools...\n'
./scripts/install-tools.sh
