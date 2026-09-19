#!/usr/bin/env python3
"""Exercise the remote-main push guard.

Two layers are tested:

- The hook contract. A payload is written to the guard on stdin in a
  subprocess, and the exit code is asserted. Status 2 denies the tool call and
  status 0 permits it. This is what Claude Code and Codex do, so it covers the
  entry point and its fail-closed handler.
- The pure helpers. The guard is imported and its functions are called
  directly, which reaches inputs that are awkward to express as a command.

The repository copy is tested by default. The deployed copy is the file the
hook runs, and it differs until chezmoi apply completes.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from types import ModuleType
from typing import ClassVar

BLOCKED = 2
ALLOWED = 0

REPO_ROOT = Path(__file__).resolve().parent.parent
SOURCE_GUARD = (
    REPO_ROOT
    / "private_dot_local/libexec/agent-guards/executable_block-remote-main-push.py"
)
DEPLOYED_GUARD = Path.home() / ".local/libexec/agent-guards/block-remote-main-push.py"

# Set by main() before the tests run.
GUARD: Path = SOURCE_GUARD


def load_guard(path: Path) -> ModuleType:
    spec = importlib.util.spec_from_file_location("guard_under_test", path)

    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot import guard: {path}")

    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def run_guard(payload: str, timeout: float = 10.0) -> int:
    result = subprocess.run(
        [sys.executable, str(GUARD)],
        input=payload,
        capture_output=True,
        text=True,
        timeout=timeout,
        check=False,
    )
    return result.returncode


def payload_for(command: str, cwd: str | None = None) -> str:
    body: dict[str, object] = {"tool_input": {"command": command}}

    if cwd is not None:
        body["cwd"] = cwd

    return json.dumps(body)


class GuardContractTest(unittest.TestCase):
    """Assert the exit code the hook receives."""

    def assert_commands(self, expected: int, commands: list[str]) -> None:
        for command in commands:
            with self.subTest(command=command, expected=expected):
                self.assertEqual(expected, run_guard(payload_for(command)))

    def test_destinations_that_resolve_to_main(self) -> None:
        self.assert_commands(
            BLOCKED,
            [
                "git push origin main",
                "git push origin HEAD:main",
                "git push origin :main",
                "git push --force origin main",
                "git push origin refs/heads/main",
                "git push --force-with-lease origin main",
                "git push origin +main",
                "git push --all origin",
                "git push --mirror origin",
                "git push --repo=origin main",
            ],
        )

    def test_bare_push_requires_an_explicit_refspec(self) -> None:
        self.assert_commands(BLOCKED, ["git push", "git push origin"])

    def test_unresolved_destinations(self) -> None:
        self.assert_commands(
            BLOCKED,
            [
                "git push origin HEAD",
                "git push origin @",
                "git push origin HEAD~1",
                "git push --force origin @",
                "git push origin refs/heads/HEAD",
                "git push origin feature:",
            ],
        )

    def test_revision_suffixes_do_not_hide_main(self) -> None:
        self.assert_commands(
            BLOCKED,
            [
                "git push origin feature:main~0",
                "git push origin main^",
                "git push origin feature:main@{0}",
            ],
        )

    def test_compound_commands_are_inspected_per_segment(self) -> None:
        self.assert_commands(
            BLOCKED,
            [
                "git status && git push origin main",
                "git push origin feature && git push origin main",
            ],
        )

    def test_non_main_destinations_are_permitted(self) -> None:
        self.assert_commands(
            ALLOWED,
            [
                "git push origin feature",
                "git push -u origin feature",
                "git push origin feature && gh pr create",
                "git push origin HEAD:feature",
                "git push origin :feature",
                "git push --force origin feature",
                "git push origin main-ish",
                "git push origin feature@2",
                "git push origin HEAD:refs/heads/feature",
            ],
        )

    def test_commands_that_are_not_a_push(self) -> None:
        self.assert_commands(
            ALLOWED,
            [
                "git status",
                'git commit -m "update main"',
                "ls",
            ],
        )

    def test_push_outside_the_subcommand_position(self) -> None:
        self.assert_commands(
            ALLOWED,
            [
                "git stash push -m wip",
                "git stash push",
                "git log --grep push",
                "git config --get push.default",
                "git help push",
                "git branch --list push",
            ],
        )

    def test_global_options_do_not_hide_a_push(self) -> None:
        self.assert_commands(
            BLOCKED,
            [
                "git -C /tmp/repo push origin main",
                "git -c user.name=x push origin main",
                "git --git-dir=/tmp/repo/.git push origin main",
                "git --git-dir /tmp/repo/.git push origin main",
                "git --work-tree /tmp/repo push origin main",
                "git --namespace ns push origin main",
                "git --no-pager push origin main",
                "git -C /tmp/repo -c user.name=x push origin main",
                "git --exec-path push origin main",
                "git --exec-path=/usr/lib/git-core push origin main",
                "env GIT_TRACE=1 git push origin main",
            ],
        )
        self.assert_commands(
            ALLOWED,
            [
                "git -C /tmp/repo push origin feature",
                "git -C /tmp/repo stash push -m wip",
            ],
        )

    def test_inline_alias_definitions_are_refused(self) -> None:
        self.assert_commands(
            BLOCKED,
            [
                "git -c alias.p=push p origin main",
                'git -c alias.p="push origin main" p',
                "git --config-env=alias.p=EVIL p",
            ],
        )


class MalformedPayloadTest(unittest.TestCase):
    """A payload the guard cannot inspect must fail closed.

    An exit status other than 2 is a non-blocking hook error, so the tool call
    would proceed.
    """

    CASES_BLOCKED: ClassVar[dict[str, str]] = {
        "null tool_input": '{"tool_input":null}',
        "empty stdin": "",
        "non-JSON stdin": "not json",
        "truncated JSON": '{"tool_input":',
        "JSON array": "[]",
        "JSON null": "null",
        "string tool_input": '{"tool_input":"str"}',
        "non-string command": '{"tool_input":{"command":123}}',
    }

    CASES_ALLOWED: ClassVar[dict[str, str]] = {
        "empty object": "{}",
        "absent command": '{"tool_input":{}}',
        "null command": '{"tool_input":{"command":null}}',
    }

    def test_uninspectable_payloads_block(self) -> None:
        for name, payload in self.CASES_BLOCKED.items():
            with self.subTest(payload=name):
                self.assertEqual(BLOCKED, run_guard(payload))

    def test_payloads_without_a_command_are_permitted(self) -> None:
        for name, payload in self.CASES_ALLOWED.items():
            with self.subTest(payload=name):
                self.assertEqual(ALLOWED, run_guard(payload))


class AliasResolutionTest(unittest.TestCase):
    """An alias can hide a push.

    The aliases are defined with git config in a real repository, because the
    guard reads them from the directory named in the payload.
    """

    ALIASES: ClassVar[dict[str, str]] = {
        "p": "push origin main",
        "safe": "push origin feature",
        "st": "status --short",
        "shellpush": "!git push origin main",
        "shellsafe": "!echo hello",
        "hop": "p",
        "withopts": "-C /tmp push origin main",
        "status": "push origin main",
    }

    @classmethod
    def setUpClass(cls) -> None:
        cls._tmp = tempfile.TemporaryDirectory()
        cls.repo = cls._tmp.name

        subprocess.run(
            ["git", "init", "-q", cls.repo], check=True, capture_output=True
        )

        for name, expansion in cls.ALIASES.items():
            subprocess.run(
                ["git", "-C", cls.repo, "config", f"alias.{name}", expansion],
                check=True,
                capture_output=True,
            )

    @classmethod
    def tearDownClass(cls) -> None:
        cls._tmp.cleanup()

    def assert_in_repo(self, expected: int, commands: list[str]) -> None:
        for command in commands:
            with self.subTest(command=command, expected=expected):
                self.assertEqual(
                    expected, run_guard(payload_for(command, cwd=self.repo))
                )

    def test_alias_expanding_to_a_push_is_blocked(self) -> None:
        self.assert_in_repo(
            BLOCKED,
            [
                "git p",
                "git hop",
                "git shellpush",
                "git withopts",
            ],
        )

    def test_alias_not_expanding_to_a_main_push_is_permitted(self) -> None:
        self.assert_in_repo(
            ALLOWED,
            [
                "git safe",
                "git st",
                "git shellsafe",
                "git unknown-not-an-alias",
            ],
        )

    def test_alias_shadowing_a_builtin_is_ignored(self) -> None:
        # git ignores an alias named after a built-in command, so alias.status
        # does not make 'git status' a push.
        self.assert_in_repo(ALLOWED, ["git status"])


class HelperTest(unittest.TestCase):
    """Call the guard's pure functions directly."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.guard = load_guard(GUARD)

    def attribute(self, name: str) -> object:
        # A missing attribute means the guard under test predates the function.
        # Report that rather than raising AttributeError from the call site.
        if not hasattr(self.guard, name):
            self.fail(
                f"the guard at {GUARD} does not define {name}. "
                "Run chezmoi apply when testing the deployed copy."
            )

        return getattr(self.guard, name)

    def test_normalize_destination(self) -> None:
        cases = {
            "main": "main",
            "refs/heads/main": "main",
            "main~0": "main",
            "main^": "main",
            "main@{0}": "main",
            "main@{0}~1": "main",
            "refs/heads/main~2": "main",
            "HEAD": "HEAD",
            "HEAD~1": "HEAD",
            "@": "@",
            "@{0}": "",
            "feature@2": "feature@2",
            "main-ish": "main-ish",
        }

        for source, expected in cases.items():
            with self.subTest(destination=source):
                normalize = self.attribute("normalize_destination")
                self.assertEqual(expected, normalize(source))

    def test_find_subcommand(self) -> None:
        cases: list[tuple[list[str], str | None]] = [
            (["git", "push"], "push"),
            (["git", "-C", "/tmp", "push"], "push"),
            (["git", "-c", "a=b", "push"], "push"),
            (["git", "--no-pager", "push"], "push"),
            (["git", "--git-dir=/tmp/.git", "push"], "push"),
            (["git", "--git-dir", "/tmp/.git", "push"], "push"),
            (["git", "--exec-path", "push"], "push"),
            (["git", "stash", "push"], "stash"),
            (["git", "-C", "/tmp"], None),
        ]

        for tokens, expected in cases:
            with self.subTest(tokens=tokens):
                find = self.attribute("find_subcommand")
                index = find(tokens, 1)
                actual = None if index is None else tokens[index]
                self.assertEqual(expected, actual)

    def test_defines_alias(self) -> None:
        cases: list[tuple[list[str], bool]] = [
            (["git", "-c", "alias.p=push", "p"], True),
            (["git", "-c", "ALIAS.p=push", "p"], True),
            (["git", "--config-env=alias.p=VAR", "p"], True),
            (["git", "--config-env", "alias.p=VAR", "p"], True),
            (["git", "-c", "user.name=x", "push"], False),
            (["git", "-C", "/tmp", "push"], False),
            (["git", "push"], False),
        ]

        for tokens, expected in cases:
            with self.subTest(tokens=tokens):
                find = self.attribute("find_subcommand")
                defines = self.attribute("defines_alias")
                end = find(tokens, 1)
                self.assertIsNotNone(end)
                self.assertEqual(expected, defines(tokens, 1, int(end)))

    def test_push_is_a_builtin_subcommand(self) -> None:
        # The alias chain relies on this set to stop resolving.
        builtins = self.attribute("GIT_BUILTIN_SUBCOMMANDS")
        self.assertIn("push", builtins)
        self.assertIn("status", builtins)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    target = parser.add_mutually_exclusive_group()
    target.add_argument(
        "--deployed",
        action="store_true",
        help="test the copy the hook runs, under ~/.local/libexec",
    )
    target.add_argument("--guard", type=Path, help="test the copy at this path")
    parser.add_argument(
        "-v", "--verbose", action="store_true", help="name every case"
    )
    args = parser.parse_args()

    global GUARD

    if args.deployed:
        GUARD = DEPLOYED_GUARD
    elif args.guard is not None:
        GUARD = args.guard

    if not GUARD.is_file():
        print(f"error: guard not found: {GUARD}", file=sys.stderr)
        return 1

    print(f"guard: {GUARD}\n", file=sys.stderr)

    runner = unittest.TextTestRunner(verbosity=2 if args.verbose else 1)
    suite = unittest.defaultTestLoader.loadTestsFromModule(sys.modules[__name__])
    return 0 if runner.run(suite).wasSuccessful() else 1


if __name__ == "__main__":
    raise SystemExit(main())
