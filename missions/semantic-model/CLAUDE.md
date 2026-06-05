# CLAUDE.md — semantic-model mission

Mission-specific guidance. Loaded automatically when working under
`missions/semantic-model/`. Repo-level guidance lives in `../../CLAUDE.md`.

## What this mission does

Generates an **OSI-compliant semantic model** (YAML) for a Data Lake table from
its **authoritative code**:

- The PySpark job/script that populates the table
- The Airflow DAG that calls the PySpark job

The mission auto-discovers related upstream/dimension tables, foreign-key
relationships, fields, and business metrics to produce a complete semantic model
conforming to the [OSI Core Spec v0.2.0.dev0](https://github.com/open-semantic-interchange/OSI).

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
  fails, omit the dataset or mark it with a note in analyze.md — never use
  intermediate tables as OSI dataset sources.
- **User notes in config** (`notes: |` in YAML) are highest priority after code.
  Fold them into descriptions, ai_context, and metrics.
- **Never guess.** If a field, relationship, or metric cannot be populated with
  high confidence, omit it and document the gap in analyze.md / validate.md.
- **ANSI_SQL dialect only** for all field and metric expressions.

## Provenance preservation

Items on the analyze **do-not-claim** list must **not** become OSI datasets,
relationships, or metrics — but their lineage must **not** be dropped either.

The analyze stage writes `PROVENANCE.json` (alongside `RESOLVED_TARGET.json`).
Generate and validate consume it to preserve excluded lineage via:

- **Field descriptions** — upstream source for materialized/transitive columns
- **`ai_context.instructions`** — grain, partition filter, PK caveats, array-field warnings
- **`custom_extensions.data`** — `pipeline_lineage` and `query_guards` JSON (GODADDY vendor)

Prefer **scalar proxy metrics** (e.g. `product_pnl_category_qty`) over array unnesting.
See `docs/osi-spec-reference.md` for the GODADDY custom_extensions schema.

## OSI output contract

The final deliverable is `SEMANTIC_MODEL.yaml` in the workspace root, copied by
`run.sh` to:
- `output/<id>/<name>/<schema>.<table>.yaml` (audit trail in moon-unit-missions)
- `repos/<source-repo>/<...>/src/semantics/<schema>.<table>.yaml` (source repo placement)
- A pull request opened against the **PySpark source repo** (e.g. `gdcorp-dna/dof-ecomm-customer`), not moon-unit-missions

Structure reference: `docs/osi-spec-reference.md`

Required root shape:
```yaml
version: "0.2.0.dev0"
semantic_model:
  - name: ...
    datasets: [...]      # min 1, lake tables only
    relationships: [...]
    metrics: [...]
```

## Where things live

- `manifest.yaml` — static template; **never edit per-table.**
- `config/<id>/<name>.yaml` — per-run input. The only files to add for new tables.
- `docs/creating-a-config.md` — playbook for authoring configs.
- `docs/osi-spec-reference.md` — condensed OSI spec for agent context.
- `output/<id>/<name>/` — per-run artifacts (stage `.md` files + OSI YAML). Committed.
- `.env.local` — local secrets; never committed.

## Stage output semantics (Moon Units convention)

- `plan.stages[].output` in `manifest.yaml` is a **markdown file**; the framework
  pre-writes a header, the agent appends content, the framework appends a footer.
- The final OSI deliverable is written into the workspace as `SEMANTIC_MODEL.yaml`
  and copied out by `run.sh` to the output directory and into `src/semantics/`
  alongside `dag/` and `pyspark/` in the cloned source repo. On success, `run.sh`
  commits, pushes, and opens a PR against the PySpark source repo.

## Adding/updating configs

Use the repo-level skill `semantic-model-config` (under `.claude/skills/`)
when creating new configs.

## Model notes

The manifest uses `claude-sonnet-4-6` for all stages.

## Don't

- Edit `manifest.yaml` for a single table — use a per-table config.
- Run `./run.sh` proactively; the user runs it after reviewing configs.
- Commit `.env.local`, `.workspace/`, or `.mu-run.log` (all gitignored).
- Use intermediate/staging tables as OSI dataset `source` values.
- Drop do-not-claim lineage — always preserve it in descriptions, ai_context, or custom_extensions.
