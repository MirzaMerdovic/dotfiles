#!/usr/bin/env bash
#
# Exercises the agent guards by feeding hook payloads on stdin and asserting
# the exit code the guard returns.
set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(dirname -- "$script_dir")"
guard="${repo_root}/private_dot_local/libexec/agent-guards/executable_block-remote-main-push.py"

# Hook exit codes. 2 denies the tool call, 0 permits it.
readonly BLOCKED=2
readonly ALLOWED=0

failures=0
checks=0

[[ -f "$guard" ]] || {
	printf 'error: guard not found: %s\n' "$guard" >&2
	exit 1
}

# Feeds a raw payload to the guard and reports the guard exit code.
run_guard() {
	local payload="$1"
	local status=0

	printf '%s' "$payload" | python3 "$guard" >/dev/null 2>&1 || status=$?

	return "$status"
}

# Asserts the guard exit code for a Bash tool command.
expect() {
	local expected="$1"
	local command="$2"
	local payload
	local status=0

	payload="$(
		python3 -c \
			'import json, sys; print(json.dumps({"tool_input": {"command": sys.argv[1]}}))' \
			"$command"
	)"

	checks=$((checks + 1))

	run_guard "$payload" || status=$?

	if [[ "$status" -ne "$expected" ]]; then
		failures=$((failures + 1))
		printf 'FAIL expected %s, got %s: %s\n' "$expected" "$status" "$command" >&2
		return 0
	fi

	printf 'ok   %s: %s\n' "$expected" "$command"
}

# Destinations that resolve to remote main.
expect "$BLOCKED" 'git push origin main'
expect "$BLOCKED" 'git push origin HEAD:main'
expect "$BLOCKED" 'git push origin :main'
expect "$BLOCKED" 'git push --force origin main'
expect "$BLOCKED" 'git push origin refs/heads/main'
expect "$BLOCKED" 'git push --force-with-lease origin main'
expect "$BLOCKED" 'git push origin +main'
expect "$BLOCKED" 'git push --all origin'
expect "$BLOCKED" 'git push --mirror origin'
expect "$BLOCKED" 'git push --repo=origin main'

# A bare push depends on upstream state, so the guard requires an explicit
# refspec.
expect "$BLOCKED" 'git push'
expect "$BLOCKED" 'git push origin'

# Destinations the guard cannot resolve without inspecting repository state.
expect "$BLOCKED" 'git push origin HEAD'
expect "$BLOCKED" 'git push origin @'
expect "$BLOCKED" 'git push origin HEAD~1'
expect "$BLOCKED" 'git push --force origin @'
expect "$BLOCKED" 'git push origin refs/heads/HEAD'
expect "$BLOCKED" 'git push origin feature:'

# Revision suffixes must not hide a main destination.
expect "$BLOCKED" 'git push origin feature:main~0'
expect "$BLOCKED" 'git push origin main^'
expect "$BLOCKED" 'git push origin feature:main@{0}'

# Compound commands must be inspected segment by segment.
expect "$BLOCKED" 'git status && git push origin main'
expect "$BLOCKED" 'git push origin feature && git push origin main'

# Non-main destinations.
expect "$ALLOWED" 'git push origin feature'
expect "$ALLOWED" 'git push -u origin feature'
expect "$ALLOWED" 'git push origin feature && gh pr create'
expect "$ALLOWED" 'git push origin HEAD:feature'
expect "$ALLOWED" 'git push origin :feature'
expect "$ALLOWED" 'git push --force origin feature'
expect "$ALLOWED" 'git push origin main-ish'
expect "$ALLOWED" 'git push origin feature@2'
expect "$ALLOWED" 'git push origin HEAD:refs/heads/feature'

# Commands that are not a push at all.
expect "$ALLOWED" 'git status'
expect "$ALLOWED" 'git commit -m "update main"'
expect "$ALLOWED" 'ls'

printf '\n%s checks, %s failures\n' "$checks" "$failures"

[[ "$failures" -eq 0 ]]
