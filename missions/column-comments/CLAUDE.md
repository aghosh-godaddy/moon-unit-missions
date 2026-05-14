# CLAUDE.md — column-comments mission

Mission-specific guidance. Loaded automatically when working under
`missions/column-comments/`. The repo-level `../../CLAUDE.md` covers
cross-mission concerns.

## What this mission does

A 3-stage Moon Units pipeline that enriches Data Lake table DDLs with
standardized column descriptions. For a target table, the agent reads the
DDL from `gdcorp-dna/lake`, gathers context from Confluence + Alation +
the Certified Data Dictionary, edits the DDL in place with COMMENT
clauses, and validates the 255-char limit. The launcher snapshots the
in-repo `table.ddl` at three boundaries to produce
`original/enriched/validated-table.ddl`.

## Where things live

- `manifest.yaml` — static template; **never edit per-table.**
- `config/<db>/<table>.yaml` — per-table input. The only file to edit when
  adding/refining a table.
- `config/CATALOG.md` — index of all configured tables + status.
- `scripts/` — helper scripts to populate configs (Alation lookup, BI-space
  Confluence search, lake lineage). See `scripts/README.md`.
- `docs/creating-a-new-config.md` — full playbook for adding a table.
- `output/<db>/<table>/` — per-run artifacts (stage `.md` files + DDL
  snapshots). Committed as audit trail.
- `.env.local` — local secrets, never committed.

## Adding or updating a table

Use the `column-comments-config` skill — it chains the helper scripts in
the right order and follows `docs/creating-a-new-config.md`. Don't
reimplement the chain manually.

## Stage output semantics (Moon Units convention)

- `output:` in `manifest.yaml` is a **markdown file**, not a DDL file. The
  framework pre-writes a header, the agent appends a summary, the framework
  appends a footer. Stage outputs are: `research.md`, `enrich.md`, `validate.md`.
- `enrich`/`validate` agents edit the cloned repo's `table.ddl` **in
  place**. The launcher snapshots that file at stage boundaries to produce
  the `*-table.ddl` artifacts. They are not stage outputs.
- Don't tell agents to "output only the DDL, no markdown" — that fights
  the framework's envelope. Use the `.md` summary + in-place DDL pattern.

## Naming gotcha

The data lake registry uses **hyphenated** table names
(`enterprise/dim-entitlement/table.ddl`). Alation and SQL use
**underscored** names (`enterprise.dim_entitlement`). Configs and
CATALOG.md follow this split — feed each tool the form it expects.

## Alation API quirks

- The `description` field on a Catalog Set's shared block lives at
  `/api/v1/table/<id>/` under `shared_catalog_sets[].description` —
  **not** at `/integration/v2/custom_field_value/?otype=dynamic_set_property`
  (which only returns Title for catalog sets).
- `/integration/v2/custom_field_value/` ignores `limit`/`skip` for global
  scans — silently caps at ~10. Always query by `(otype, oid, field_id)`.
- Refresh tokens rotate. If any script returns "token expired or revoked",
  regenerate from Alation → Account Settings → Authentication and update
  `.env.local`.

## Container lifecycle (failure mode)

`mu launch --keep-container` keeps the docker container alive past the
mission's SUCCEEDED state. The launcher must `docker stop` the
`mu-<timestamp>` container (parsed from the log) **before** wiping
`.workspace/`, otherwise late writes recreate `.workspace/repos/...`
skeletons. See `run.sh` SUCCEEDED branch + Ctrl+C `cleanup()`.

## DDL `COMMENT` casing

The agent emits both `COMMENT` and lowercase `comment` depending on the
table. Any pattern matching in `run.sh` (OVER_LIMIT check, comparison
report) must be case-insensitive (`grep -i`, sed character class).

## Don't

- Edit `manifest.yaml` for a single table — use a per-table config.
- Hand-craft a config — run the helper scripts via the skill.
- Run `./run.sh` proactively; the user runs it after reviewing configs.
- Commit `.env.local`, `api-keys.txt`, `.workspace/`, or `.DS_Store`
  (all gitignored).
