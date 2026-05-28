# CLAUDE.md — table-metadata mission

Mission-specific guidance. Loaded automatically when working under
`missions/table-metadata/`. Repo-level guidance lives in `../../CLAUDE.md`.

## What this mission does

Generates a **business context / metadata document** for a Data Lake table from
its **authoritative code**:

- The PySpark job/script that populates the table
- The Airflow DAG that calls the PySpark job

Supporting sources (Alation, Confluence, in-repo DDL/policies/data-quality) may
be used **only when consistent** with the code.

## Source-of-truth rules (non-negotiable)

- **PySpark + DAG are the source of truth.** If DDL/policies/Alation/Confluence
  contradict the PySpark or DAG, treat the code as correct and flag the
  discrepancy in validation.
- **Always traverse to the lake table — recursively.** If the PySpark
  references local/intermediate Athena tables (e.g., `*_stg`, `*_conformed.*`,
  `*_driver`), you MUST find the PySpark script that builds that intermediate
  table, read it, discover ITS sources, and continue upstream until you reach
  an actual lake table (one that exists in `gdcorp-dna/lake`). If traversal
  fails, mark it `UNRESOLVED — requires manual input`. Never list intermediate
  tables as column sources in C1.
- **Never guess.** If a section cannot be populated with high confidence, mark
  it as requiring manual input using:
  `<!-- REQUIRES_MANUAL_INPUT: <BA|DE|DG|DP> -->`
- **Avoid implementation noise.** Keep the final doc business-facing. Include
  pipeline identity, schedule, and provenance, but avoid detailed code walkthroughs.

## Where things live

- `manifest.yaml` — static template; **never edit per-table.**
- `config/<id>/<name>.yaml` — per-run input. The only files to add for new tables.
- `docs/creating-a-config.md` — playbook for authoring configs.
- `output/<id>/<name>/` — per-run artifacts (stage `.md` files + final metadata doc). Committed.
- `.env.local` — local secrets; never committed.

## Stage output semantics (Moon Units convention)

- `plan.stages[].output` in `manifest.yaml` is a **markdown file**; the framework
  pre-writes a header, the agent appends content, the framework appends a footer.
- The final metadata deliverable is written into the workspace and copied out by
  `run.sh` into `output/<id>/<name>/<schema>.<table>-metadata.md`.

## Adding/updating configs

Use the repo-level skill `table-metadata-config` (under `.claude/skills/`)
when creating new configs.

## Model notes

The manifest uses `claude-sonnet-4-6` for all stages. If `claude-opus-4`
becomes available via GoCode, update `manifest.yaml` for higher quality.

## Don't

- Edit `manifest.yaml` for a single table — use a per-table config.
- Run `./run.sh` proactively; the user runs it after reviewing configs.
- Commit `.env.local`, `.workspace/`, or `.mu-run.log` (all gitignored).

