---
name: semantic-model-config
description: Create or populate a semantic-model mission config for a PySpark job. Use when the user provides a GitHub link to a PySpark script and wants a config to generate an OSI-compliant semantic model YAML.
---

# Semantic Model — Config Playbook

This skill helps create a per-run config at:

`missions/semantic-model/config/<identifier>/<name>.yaml`

## Authoritative reference

The full playbook lives in:

`missions/semantic-model/docs/creating-a-config.md`

Read that first; keep this skill as a pointer.

## What to collect for a good config

- The **exact** GitHub *blob* URL to the PySpark script that populates the table.
  - Format: `https://github.com/<org>/<repo>/blob/<ref>/<path>.py`
- Optional **`notes:`** block — expert context; highest priority after PySpark/DAG code.
- Any supporting docs (Confluence, Alation, design docs).
- Optional: `lake_table_override` if auto-detect might fail.
- Optional: `semantic_model_name` if auto-derivation is not desired.
- Optional: `sources.alation.max_queries` (default 5) for metric/usage context.

## Gotchas

- **Code is truth**: PySpark + DAG override DDL/policies/Alation/Confluence if they conflict.
- **Always traverse to lake**: if the PySpark reads local Athena tables, resolve upstream until you
  find the lake registry table. Intermediate tables must not appear as OSI dataset sources.
- **Use hyphens** for lake registry path overrides (`enterprise/payment-cogs-audit`), even if Alation/SQL
  uses underscores (`payment_cogs_audit`).
- **ANSI_SQL only** for OSI expressions in the generated model.

## Deliverable

1. Create the YAML config file under `missions/semantic-model/config/...`.
2. Populate at minimum `target.pyspark_url`.
3. Add `notes: |` when the user provides special instructions.
4. Set `target.semantic_model_name` if the user wants a specific OSI model name.
5. Set `sources.alation.max_queries` if they want more/fewer queries for context.
6. Add supporting URLs under `sources.confluence_pages` / `sources.additional_docs`.
7. Do **not** run `missions/semantic-model/run.sh` unless explicitly asked.
