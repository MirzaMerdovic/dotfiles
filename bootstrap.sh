#!/usr/bin/env bash
set -Eeuo pipefail

touch .chezmoiignore

grep -qxF 'README.md' .chezmoiignore ||
	printf '%s\n' 'README.md' >>.chezmoiignore

grep -qxF 'bootstrap.sh' .chezmoiignore ||
	printf '%s\n' 'bootstrap.sh' >>.chezmoiignore
