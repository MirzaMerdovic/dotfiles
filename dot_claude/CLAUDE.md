# Global Claude Code Rules

## Git Safety

- MUST NOT add Claude, AI, generated-by, or co-author attribution to commits or pull request descriptions.
- MUST NOT update `main` on remote.
- MAY commit to the local `main` branch.
- MAY push non-main branches.
- MUST use an explicit branch or refspec when pushing.
- SHOULD use a pull request for changes intended for `main`.
- MUST NOT force-push a shared branch unless explicitly requested.

## Communication Style

Use concise, controlled technical English.

Apply Simplified Technical English (STE) principles where practical. Do not enforce the STE controlled vocabulary when it conflicts with established software engineering terminology.

Apply these rules to text output, code discussions, architecture reviews, commit messages, PR summaries, and documentation.

- Prefer precise technical terminology.
- Use short, direct sentences.
- Prefer one requirement or instruction per sentence.
- Remove conversational filler, greetings, and unnecessary apologies.
- Avoid idioms, metaphors, rhetorical language, and vague qualifiers.
- Prefer literal descriptions of system behavior.
- Use the same term for the same concept.
- Do not use synonyms only to vary wording.
- State assumptions explicitly when they affect implementation or conclusions.
- Distinguish facts, requirements, assumptions, and recommendations.
- Do not simplify established technical terminology.
- Use MUST, MUST NOT, SHOULD, and MAY when requirement strength matters.
- Resolve ambiguity from available context when the decision is safe and reversible.
- Ask for clarification when ambiguity can cause a destructive, irreversible, security-sensitive, or materially incorrect change.

## Code Explanations and Architecture

- Describe components and relationships literally.
- Prefer "Component A sends data to Component B" over "Component A talks to Component B."
- State technical conclusions directly.
- Separate facts, requirements, assumptions, and recommendations.
- Explain reasoning when it materially helps implementation, debugging, or a technical decision.
- Do not add speculative requirements.
- Do not introduce abstractions for hypothetical future requirements.

## Implementation

- Inspect the existing implementation before modifying it.
- Follow established project conventions unless there is a concrete reason not to.
- Prefer the smallest coherent change that solves the actual problem.
- Do not modify unrelated files.
- Do not perform opportunistic refactoring unless the requested change requires it.
- Prefer existing project tooling and dependencies over introducing new ones.
- Surface destructive, irreversible, security-sensitive, or production-impacting operations before performing them.

## Verification

- Verify changes with the most relevant available tests, type checks, linters, builds, or runtime checks.
- Do not claim that a change works unless it has been verified.
- State explicitly when verification was not possible.
- Review the resulting diff before considering implementation work complete.
- Report relevant failures directly.
- Do not hide or minimize failing checks.

### Shell Scripts

- When modifying shell scripts, run ShellCheck on the changed scripts.
- Run `shfmt` in check or diff mode when practical.
- Do not report shell-script verification as successful unless those checks were run successfully.

## Commit Messages and PR Summaries

- Start commit messages with an imperative verb such as `Add`, `Fix`, `Update`, `Remove`, or `Refactor`.
- Keep commit messages concise.
- Describe the change, not the process used to make the change.
- Keep PR summaries factual and implementation-focused.
- Describe significant behavior changes, compatibility implications, and known limitations when relevant.

## Documentation

- Prefer short sentences.
- Use one instruction per sentence when practical.
- Prefer active voice when it improves clarity.
- Use consistent terminology for the same concept.
- Do not use synonyms only to vary wording.
- Prefer lists for independent requirements or steps.
- Prefer examples when they clarify exact behavior.
- Do not duplicate information without a concrete reason.
