# Rewrite catalogue

Each entry is one defect class. It states the rule, then gives a pair taken from a
documentation rewrite in the `sol` repository (commit `a86778a`).

Read this file when rewriting an existing document, or when a checker hit has no obvious
literal replacement.

The `Before` lines contain the constructions this skill excludes. A checker run over this
file reports them. That is expected.

## 1. Idiom and metaphor

Replace the figure of speech with the behaviour it described, and with the failure it
prevents.

```text
Before: Within an environment vault, items divide by consumer, and the division is
        load-bearing.
After:  Within an environment vault, items are divided by consumer. The division
        determines which component may read each item.

Before: On a GitHub-hosted runner the VM is destroyed afterwards, so this is belt and
        braces.
After:  On a GitHub-hosted runner the VM is destroyed after the job, so the session cannot
        be reused.

Before: Two details in that trap are not decoration.
After:  Four details in the block above are required, not stylistic.

Before: The distinction has teeth in two places.
After:  Two mechanisms depend on the distinction.

Before: It also sets the blast radius of a leaked deploy token, which is vault-wide.
After:  It also defines the exposure of a leaked deploy token, which is vault-wide.

Before: State is not encrypted. That makes "no credential reaches state" the only thing
        protecting it, rather than a belt worn with braces.
After:  State is not encrypted. The only protection is that no credential reaches it.
```

## 2. Rhetorical framing

A heading or an opener names its content. It does not predict the reader's reaction.

```text
Before: Two consequences that surprise people:
After:  Two consequences follow:

Before: The `foundation` layer deliberately declares no resources, so a plan reports no
        changes. That is the point.
After:  The `foundation` layer declares no resources, so a plan reports no changes. This
        proves the state backend and the secret resolution in isolation.

Before: Reading docs/architecture.md before changing anything here is worth the five
        minutes.
After:  Read docs/architecture.md before changing anything here.
```

## 3. Clause chain

Split a chain joined by an em dash or a semicolon. Use a colon to introduce a list.

```text
Before: The controls that actually matter are on the Coolify Cloud account — single
        sign-on, multi-factor authentication, team roles, API token lifecycle, audit
        logging — not on the network path.
After:  The effective controls are on the Coolify Cloud account, not on the network path:
        single sign-on, multi-factor authentication, team roles, API token lifecycle, and
        audit logging.

Before: ... in a single transaction, and running statements individually defeats the
        guards — the database check in `state-schemas.sh`, and the over-privileged-role
        check in the SQL.
After:  ... in a single transaction. Running statements individually defeats two guards:
        the database check in `state-schemas.sh`, and the over-privileged-role check in
        the SQL.

Before: ... with any site suffix flattened — `dev`, `prod-fra1`.
After:  ... with any site suffix flattened: `dev`, `prod-fra1`.
```

## 4. Requirement strength

A requirement takes MUST, MUST NOT, SHOULD, or MAY. A description takes the plain
indicative.

```text
Before: Both are executed by `neondb_owner`. Neither is ever executed by the state role.
        That role is the subject of the grants, not their author, and it is the point that
        it cannot run either file.
After:  Both MUST be executed by `neondb_owner`. Neither is executed by the state role.
        The state role is the subject of the grants, not their author. It MUST NOT be able
        to run either file.

Before: The same reasoning makes `.gitignore`'s exclusion of plan artifacts load-bearing.
After:  `.gitignore` MUST continue to exclude plan artifacts for the same reason.

Before: Nothing else belongs in that vault that CI has no use for.
After:  An environment vault MUST NOT hold anything CI has no use for.
```

## 5. Vague qualifier and hedged recommendation

State the recommendation with SHOULD. State the current fact separately.

```text
Before: ... narrowing a deploy token to the items its application actually reads is worth
        doing where the workflow allows it — but the tokens in use today are vault-scoped,
        so state the blast radius accurately rather than aspirationally.
After:  ... a deploy token SHOULD be narrowed to the items its application reads where the
        workflow allows it. The tokens in use today are vault-scoped. A leaked deploy
        token therefore exposes every secret in that environment's vault.

Before: Only the form is unchecked, so it is worth being deliberate about which tool a file
        is written for.
After:  Only the form is unchecked. Each file MUST therefore be written for one tool, and
        state which.
```

## 6. Prose that should be a list

Three or more independent statements in one paragraph become a list.

```text
Before: `root.hcl` derives a unit's state schema from the layer name, so the same layer in
        two environments takes the same schema name in different databases. And
        `state-schemas.sh` reads the unit directories under an environment to decide which
        schemas that environment needs — which is why an environment that does not run a
        layer never gets its schema.
After:  Two mechanisms depend on the distinction:

        - `root.hcl` derives a unit's state schema from the layer name. The same layer in
          two environments therefore takes the same schema name, in different databases.
        - `state-schemas.sh` reads the unit directories under an environment to determine
          which schemas that environment requires. An environment that does not run a
          layer does not receive its schema.
```

## 7. Attributed intent and evaluative adverbs

Software sends, reads, writes, or rejects. Remove `quietly`, `happily`, `actually`, and
`never gets`.

```text
Before: ... a typo in a path cannot quietly create a new schema with an empty state beside
        the real one.
After:  ... a typo in a path cannot create a new schema with an empty state beside the real
        one.

Before: ... an environment that does not run a layer never gets its schema.
After:  ... an environment that does not run a layer does not receive its schema.

Before: | One layer in one environment. This is what Terragrunt actually runs, and what
        owns exactly one state schema. |
After:  | One layer in one environment. Terragrunt runs a unit, and a unit owns exactly one
        state schema. |
```

## 8. Duplication

State a fact once. The rewrite removed a passage that explained hosted and self-hosted
runner session cleanup twice. Before deleting a duplicate, confirm the two passages state
the same fact. Keep the one in the document that owns the subject, and link from the other.
