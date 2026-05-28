---
name: table-metadata-config
description: Create or populate a table-metadata mission config for a PySpark job. Use when the user provides a GitHub link to a PySpark script and wants a config to generate the 5-pillar/20-section metadata document.
---

# Table Metadata — Config Playbook

This skill helps create a per-run config at:

`missions/table-metadata/config/<identifier>/<name>.yaml`

## Authoritative reference

The full playbook lives in:

`missions/table-metadata/docs/creating-a-config.md`

Read that first; keep this skill as a pointer.

## What to collect for a good config

- The **exact** GitHub *blob* URL to the PySpark script that populates the table.
  - Format: `https://github.com/<org>/<repo>/blob/<ref>/<path>.py`
- Any supporting docs that explain business meaning (Confluence, Alation, design docs).
- Optional: `lake_table_override` if the target lake table is known and auto-detect might fail.

## Gotchas

- **Code is truth**: PySpark + DAG override DDL/policies/Alation/Confluence if they conflict.
- **Always traverse to lake**: if the PySpark reads local Athena tables, resolve upstream until you
  find the lake registry table.
- **Use hyphens** for lake registry path overrides (`enterprise/payment-cogs-audit`), even if Alation/SQL
  uses underscores (`payment_cogs_audit`).

## Deliverable

1. Create the YAML config file under `missions/table-metadata/config/...`.
2. Populate at minimum `target.pyspark_url`.
3. Add any supporting URLs under `sources.confluence_pages` / `sources.additional_docs`.
4. Do **not** run `missions/table-metadata/run.sh` unless explicitly asked.

