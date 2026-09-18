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

# Records the result of one check.
assert_status() {
	local expected="$1"
	local actual="$2"
	local label="$3"

	checks=$((checks + 1))

	if [[ "$actual" -ne "$expected" ]]; then
		failures=$((failures + 1))
		printf 'FAIL expected %s, got %s: %s\n' "$expected" "$actual" "$label" >&2
		return 0
	fi

	printf 'ok   %s: %s\n' "$expected" "$label"
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

	run_guard "$payload" || status=$?

	assert_status "$expected" "$status" "$command"
}

# Asserts the guard exit code for a payload the hook did not necessarily
# produce.
expect_payload() {
	local expected="$1"
	local label="$2"
	local payload="$3"
	local status=0

	run_guard "$payload" || status=$?

	assert_status "$expected" "$status" "$label"
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

# 'push' outside the subcommand position does not push anything.
expect "$ALLOWED" 'git stash push -m wip'
expect "$ALLOWED" 'git stash push'
expect "$ALLOWED" 'git log --grep push'
expect "$ALLOWED" 'git config --get push.default'
expect "$ALLOWED" 'git help push'
expect "$ALLOWED" 'git branch --list push'

# A global option before the subcommand must not hide a push.
expect "$BLOCKED" 'git -C /tmp/repo push origin main'
expect "$BLOCKED" 'git -c user.name=x push origin main'
expect "$BLOCKED" 'git --git-dir=/tmp/repo/.git push origin main'
expect "$BLOCKED" 'git --git-dir /tmp/repo/.git push origin main'
expect "$BLOCKED" 'git --work-tree /tmp/repo push origin main'
expect "$BLOCKED" 'git --namespace ns push origin main'
expect "$BLOCKED" 'git --no-pager push origin main'
expect "$BLOCKED" 'git -C /tmp/repo -c user.name=x push origin main'
expect "$BLOCKED" 'git --exec-path push origin main'
expect "$BLOCKED" 'git --exec-path=/usr/lib/git-core push origin main'
expect "$BLOCKED" 'env GIT_TRACE=1 git push origin main'
expect "$ALLOWED" 'git -C /tmp/repo push origin feature'
expect "$ALLOWED" 'git -C /tmp/repo stash push -m wip'

# A payload the guard cannot inspect must fail closed. An exit status other
# than 2 is a non-blocking error and lets the tool call proceed.
expect_payload "$BLOCKED" 'null tool_input' '{"tool_input":null}'
expect_payload "$BLOCKED" 'empty stdin' ''
expect_payload "$BLOCKED" 'non-JSON stdin' 'not json'
expect_payload "$BLOCKED" 'truncated JSON' '{"tool_input":'
expect_payload "$BLOCKED" 'JSON array' '[]'
expect_payload "$BLOCKED" 'JSON null' 'null'
expect_payload "$BLOCKED" 'string tool_input' '{"tool_input":"str"}'
expect_payload "$BLOCKED" 'non-string command' '{"tool_input":{"command":123}}'

# A well-formed payload that carries no command is not a push.
expect_payload "$ALLOWED" 'empty object' '{}'
expect_payload "$ALLOWED" 'absent command' '{"tool_input":{}}'
expect_payload "$ALLOWED" 'null command' '{"tool_input":{"command":null}}'

printf '\n%s checks, %s failures\n' "$checks" "$failures"

[[ "$failures" -eq 0 ]]
