---
name: doc-style
description: Write and revise documentation in the controlled technical English required by the global CLAUDE.md. Use this skill BEFORE writing or editing any Markdown file, README, ADR, runbook, docs/ page, long code comment, commit message body, or pull request description, and whenever the user asks to review, rewrite, tighten, shorten, or fix the tone or style of existing prose. Use it for a single paragraph or a one-line edit as well as for a full document. Use it when a task ends in a written explanation of a system.
---

# Documentation style

Documentation MUST follow the `Communication Style`, `Code Explanations and Architecture`,
and `Documentation` sections of `~/.claude/CLAUDE.md`. This skill converts those rules into
a procedure, a set of checkable patterns, and a script.

## Scope

Apply this skill to:

- Markdown files: `README.md`, `docs/**`, runbooks, ADRs, `CLAUDE.md`.
- Commit message bodies and pull request descriptions.
- Code comments longer than one line, and docstrings.

Do not apply it to: identifiers, quoted third-party text, or command output reproduced
verbatim.

## Procedure

1. Read the project `CLAUDE.md` if one exists. A project rule overrides a global rule when
   the two conflict. Report the conflict.
2. Read the file you are about to change. Read one sibling document in the same directory.
   Match the existing terminology, heading depth, and table conventions.
3. Write the draft.
4. Run the checker on every file you changed:

   ```bash
   ~/.claude/skills/doc-style/scripts/check-style.sh docs/example.md
   ```

   The checker reports candidates, not errors. Judge each hit. Rewrite it, or keep it and
   state the reason. A hit inside a quotation, a rules table, or an example of what not to
   write is expected. Keep it.

   The patterns assume Markdown. Run it on a source file to check long comment blocks, and
   ignore the hits produced by the file's own syntax.
5. Run the manual pass. The checker cannot detect the items in
   [Manual pass](#manual-pass).
6. Report what changed. State explicitly when a rule was not applied and why.

## Sentences

- State one fact, requirement, or instruction per sentence.
- Keep sentences under 25 words. Split a longer sentence.
- Split a clause chain joined by an em dash, a semicolon, or a trailing `, which` into
  separate sentences.
- Use active voice when it names the component that acts.
- Use a colon to introduce a list. Do not use an em dash.

```text
Before: The distinction has teeth in two places. `root.hcl` derives a unit's state schema
        from the layer name, and `state-schemas.sh` reads the unit directories — which is
        why an environment that does not run a layer never gets its schema.
After:  Two mechanisms depend on the distinction:

        - `root.hcl` derives a unit's state schema from the layer name.
        - `state-schemas.sh` reads the unit directories under an environment to determine
          which schemas that environment requires.
```

## Words

- Use one term for one concept, in every document. Never substitute a synonym for variety.
- Replace every idiom and metaphor with the behaviour it described.
- Remove vague qualifiers: `just`, `simply`, `basically`, `obviously`, `of course`,
  `a bit`, `fairly`, `pretty much`, `worth doing`.
- Remove filler openers: `Note that`, `It is worth noting`, `Keep in mind`, `Let us`.
- Do not attribute intent to software. A component sends, reads, writes, or rejects. It
  does not know, want, or talk to.
- Keep established technical terminology. Do not simplify `idempotent`, `quorum`,
  `fail closed`, or `transaction`.

Frequent replacements:

| Do not write | Write |
| --- | --- |
| load-bearing, not decoration, has teeth | the requirement it states, with the failure it prevents |
| belt and braces | the second control, and what it covers that the first does not |
| that is the point | the literal reason |
| blast radius | what the credential can read, stated exactly |
| talks to, knows about, wants to | sends to, reads, requires |
| under the hood, magic | the named mechanism |
| worth knowing, worth the five minutes | the consequence of not knowing it, or nothing |
| surprises people, counterintuitive | the fact alone |
| leverage, utilize, seamless, robust, powerful | use, or the measurable property |

The full catalogue with real before and after pairs is in
[references/rewrites.md](references/rewrites.md). Read it when rewriting an existing
document, or when a checker hit has no obvious literal replacement.

## Requirement strength

- Use MUST, MUST NOT, SHOULD, and MAY when the text states a requirement.
- Use the plain indicative when the text describes behaviour. A description MUST NOT be
  written as a requirement.
- Keep the keyword in upper case. Bold it only where the surrounding document already does.

```text
Requirement: Both files MUST be executed by `neondb_owner`.
Description: Terragrunt copies the lock file to the unit directory.
```

## Structure

- Use a list for independent requirements or steps.
- Use a table when every item has the same fields.
- Use an example when it fixes exact behaviour: a command, a path, a value.
- State each fact in one place. Link to it from anywhere else.
- Give each section a heading that names its subject, not its rhetorical role.

## Facts, requirements, assumptions, recommendations

Mark which one a sentence is. Use these frames:

| Type | Frame |
| --- | --- |
| Fact | `root.hcl` generates `common_vars.tf` in every unit. |
| Requirement | A layer MUST NOT declare those four variables. |
| Assumption | This assumes the `sol-dev` vault exists. |
| Recommendation | A deploy token SHOULD be narrowed to the items its application reads. |

Do not state a recommendation as a fact. Do not state an assumption as a requirement.

## Manual pass

The checker cannot detect these. Verify each one before reporting the work complete:

- **Terminology.** One term per concept across the whole document set.
- **Duplication.** The same explanation MUST NOT appear in two documents. Keep one, link
  the other.
- **Requirement strength.** Every MUST is a real requirement. Every real requirement has a
  keyword.
- **Verification.** Every claim about behaviour is either verified or marked as an
  assumption.
- **Speculation.** No requirement, abstraction, or section exists for a hypothetical future
  need.
- **Rhetorical framing.** Headings and openers describe content, not the reader's expected
  reaction.

## Constraints

- Change prose only. A style rewrite MUST NOT change technical content. State separately
  when a rewrite exposed a factual error.
- Do not rewrite documents the task did not ask you to touch.
- Do not add attribution for Claude, AI, or generation to any document or commit.
