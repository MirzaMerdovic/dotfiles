#!/usr/bin/env python3

import json
import shlex
import subprocess
import sys

# git ignores an alias that shadows a built-in command, so a token in this set
# is never an alias and needs no resolution. See git-config(1), alias.*.
GIT_BUILTIN_SUBCOMMANDS = {
    "add", "am", "apply", "archive", "bisect", "blame", "branch", "checkout",
    "cherry-pick", "clean", "clone", "commit", "config", "describe", "diff",
    "fetch", "fsck", "gc", "grep", "help", "init", "log", "ls-files",
    "ls-remote", "merge", "mv", "notes", "pull", "push", "rebase", "reflog",
    "remote", "reset", "restore", "revert", "rev-parse", "rm", "shortlog",
    "show", "stash", "status", "submodule", "switch", "tag", "worktree",
}

# An alias may expand to another alias. Bound the chain.
ALIAS_DEPTH_LIMIT = 5

# Options that set configuration on the command line, and so can define an
# alias that this guard cannot resolve from the repository configuration.
GIT_CONFIG_OPTIONS = {"-c", "--config-env"}

# A branch name may not contain '~' or '^', so either character always starts a
# revision suffix. See gitrevisions(7) and git-check-ref-format(1).
REVISION_SUFFIX_CHARS = "~^"

# Git global options that take the following argument as their value. An option
# missing from this set would hide the subcommand behind its value. The '=' forms
# need no entry because they are a single token. See git(1).
GIT_GLOBAL_OPTIONS_WITH_VALUE = {
    "-C",
    "-c",
    "--git-dir",
    "--work-tree",
    "--namespace",
    "--super-prefix",
    "--config-env",
    "--attr-source",
}

# Destinations that name the checked-out branch instead of an explicit ref.
# Committing to local main is permitted, so these may resolve to main.
UNRESOLVED_DESTINATIONS = {"", "HEAD", "@"}


def block(reason: str) -> None:
    print(f"Blocked: {reason}", file=sys.stderr)
    raise SystemExit(2)


def normalize_destination(destination: str) -> str:
    destination = destination.removeprefix("refs/heads/")

    suffix_index = next(
        (
            index
            for index, char in enumerate(destination)
            if char in REVISION_SUFFIX_CHARS
        ),
        None,
    )

    if suffix_index is not None:
        destination = destination[:suffix_index]

    return destination.split("@{", 1)[0]


def check_push(args: list[str]) -> None:
    if "--all" in args:
        block("Claude Code may not use 'git push --all' because it can update remote main.")

    if "--mirror" in args:
        block("Claude Code may not use 'git push --mirror' because it can update remote main.")

    positionals: list[str] = []
    remote_from_option = False

    options_with_value = {
        "--repo",
        "--receive-pack",
        "--exec",
        "--push-option",
        "-o",
    }

    i = 0
    while i < len(args):
        arg = args[i]

        if arg == "--":
            positionals.extend(args[i + 1 :])
            break

        if arg in options_with_value:
            if arg == "--repo":
                remote_from_option = True
            i += 2
            continue

        if arg.startswith("--repo="):
            remote_from_option = True
            i += 1
            continue

        if arg.startswith("-"):
            i += 1
            continue

        positionals.append(arg)
        i += 1

    if remote_from_option:
        refspecs = positionals
    else:
        # First positional argument is normally the remote.
        refspecs = positionals[1:] if positionals else []

    # A bare push depends on upstream/current-branch state.
    # Require Claude to make its destination explicit.
    if not refspecs:
        block(
            "Claude Code must use an explicit non-main refspec when pushing. "
            "Bare or ambiguous git push commands are not allowed."
        )

    for refspec in refspecs:
        refspec = refspec.lstrip("+")

        if ":" in refspec:
            destination = refspec.rsplit(":", 1)[1]
        else:
            destination = refspec

        destination = normalize_destination(destination)

        if destination in UNRESOLVED_DESTINATIONS:
            block(
                "Claude Code must name the destination branch explicitly when "
                "pushing. A HEAD or @ destination resolves to the checked-out "
                "branch, which may be main."
            )

        if destination == "main":
            block("Claude Code may not push, delete, force-push, or otherwise update remote main.")


def find_subcommand(tokens: list[str], start: int) -> int | None:
    index = start

    while index < len(tokens):
        token = tokens[index]

        if not token.startswith("-"):
            return index

        if token in GIT_GLOBAL_OPTIONS_WITH_VALUE:
            index += 2
            continue

        index += 1

    return None


def defines_alias(tokens: list[str], start: int, end: int) -> bool:
    index = start

    while index < end:
        token = tokens[index]

        if token in GIT_CONFIG_OPTIONS:
            if index + 1 < end and tokens[index + 1].lower().startswith("alias."):
                return True
            index += 2
            continue

        if token.lower().startswith("--config-env=alias."):
            return True

        index += 1

    return False


def resolve_alias(name: str, cwd: str | None) -> list[str] | None:
    try:
        result = subprocess.run(
            ["git", "config", "--get", f"alias.{name}"],
            capture_output=True,
            text=True,
            timeout=2,
            cwd=cwd,
            check=False,
        )
    except (OSError, subprocess.SubprocessError):
        return None

    if result.returncode != 0:
        return None

    expansion = result.stdout.strip()

    if not expansion:
        return None

    try:
        return shlex.split(expansion)
    except ValueError:
        return [expansion]


def inspect_alias(name: str, args: list[str], cwd: str | None, depth: int = 0) -> bool:
    if depth >= ALIAS_DEPTH_LIMIT:
        block("Claude Code may not use a git alias chain this deep.")

    expansion = resolve_alias(name, cwd)

    if expansion is None:
        return False

    # An alias beginning with '!' runs a shell command. Its text cannot be
    # parsed as a git invocation, so treat any mention of push as a push.
    if expansion[0].startswith("!"):
        if "push" in " ".join(expansion):
            block(
                f"The git alias '{name}' runs a shell command containing push. "
                "Claude Code must invoke git push directly."
            )
        return False

    target_index = find_subcommand(expansion, 0)

    if target_index is None:
        return False

    target = expansion[target_index]
    remaining = expansion[target_index + 1 :] + args

    if target == "push":
        check_push(remaining)
        return True

    if target in GIT_BUILTIN_SUBCOMMANDS:
        return False

    return inspect_alias(target, remaining, cwd, depth + 1)


def inspect_segment(tokens: list[str], cwd: str | None = None) -> bool:
    for git_index, token in enumerate(tokens):
        if token != "git":
            continue

        subcommand_index = find_subcommand(tokens, git_index + 1)

        if subcommand_index is None:
            continue

        if defines_alias(tokens, git_index + 1, subcommand_index):
            block(
                "Claude Code may not define a git alias on the command line. "
                "An inline alias hides the subcommand this guard inspects."
            )

        subcommand = tokens[subcommand_index]
        args = tokens[subcommand_index + 1 :]

        if subcommand == "push":
            check_push(args)
            return True

        if subcommand in GIT_BUILTIN_SUBCOMMANDS:
            continue

        if inspect_alias(subcommand, args, cwd):
            return True

    return False


def main() -> None:
    payload = json.load(sys.stdin)
    command = payload.get("tool_input", {}).get("command", "")

    # Alias definitions are read from the configuration of the directory the
    # command runs in.
    cwd = payload.get("cwd") or None

    if not command:
        return

    # Make ordinary compound commands inspectable.
    normalized = command.replace("\n", " ; ")

    try:
        lexer = shlex.shlex(normalized, posix=True, punctuation_chars=";&|")
        lexer.whitespace_split = True
        tokens = list(lexer)
    except ValueError:
        if "git push" in command:
            block("Could not safely parse a command containing git push.")
        return

    segment: list[str] = []
    saw_direct_push = False

    for token in tokens:
        if token and all(char in ";&|" for char in token):
            if segment:
                saw_direct_push |= inspect_segment(segment, cwd)
                segment = []
            continue

        segment.append(token)

    if segment:
        saw_direct_push |= inspect_segment(segment, cwd)

    # Conservatively block nested or obscured push commands.
    if not saw_direct_push and "git push" in command:
        block("Nested or indirect git push commands are not allowed.")


if __name__ == "__main__":
    # A hook exit status other than 2 is a non-blocking error, so the tool call
    # proceeds. Any failure to inspect the payload must therefore exit 2.
    # block() raises SystemExit, which derives from BaseException and is not
    # caught here.
    try:
        main()
    except Exception as error:
        block(f"Could not inspect the hook payload: {type(error).__name__}: {error}")

