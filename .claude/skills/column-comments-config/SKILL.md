---
name: column-comments-config
description: Create or populate a column-comments mission config for a new data lake table. Use when the user asks to "add a table to column-comments", "create a config for <schema>.<table>", "populate reference_tables", "find Confluence URLs for a table", or similar tasks in the Moon-Units column-comments mission. Chains Alation metadata lookups, Confluence search, and data-lake lineage resolution via the mission's helper scripts.
---

# Column Comments — New Config Playbook

This skill walks through creating or populating a per-table config at
`missions/column-comments/config/<db>/<table>.yaml` in the Moon-Units repo.

## Authoritative reference

The full, up-to-date playbook lives in the repo:

```
missions/column-comments/docs/creating-a-new-config.md
```

Read that file first. It contains the decision tree, flag reference, and known
permission gaps. This SKILL.md is a pointer — do not duplicate its content.

## Helper scripts

All under `missions/column-comments/scripts/` (see `scripts/README.md`):

| Script | Purpose |
|---|---|
| `alation_fetch_table_metadata.py` | Pull table description + custom fields from Alation, extract Confluence URLs |
| `fetch_alation_catalog_set_design.py` | Resolve the table's Catalog Set id and (if permissions allow) read its shared Description |
| `confluence_search_bi_space.py` | CQL search of the BI Confluence space with noise filter + excerpts |
| `lake_lineage_fetch.py` | Fetch `table.yaml` from `gdcorp-dna/lake`, resolve upstream deps to Alation ids |

All scripts print JSON to stdout; none mutate config files. The caller (you,
or Claude) pastes the output into the YAML.

## Quick invocation pattern

```bash
cd missions/column-comments
set -a; source .env.local; set +a

# 1. Confluence URLs from Alation table metadata
python3 scripts/alation_fetch_table_metadata.py <schema>.<table>

# 2. Fallback: catalog-set shared Description
python3 scripts/fetch_alation_catalog_set_design.py --table <table> --resolve-tiny-links

# 3. Fallback: search BI Confluence space
python3 scripts/confluence_search_bi_space.py "<table_underscore>"

# 4. reference_tables from lineage
python3 scripts/lake_lineage_fetch.py <db>/<table>
# (add --registry dlms-api if applicable)
```

## Gotchas to remember

- Registry uses **hyphenated** table names (`dim-entitlement`); Alation + SQL
  use **underscored** names (`dim_entitlement`). Feed each tool the form it
  expects.
- `_history` tables (daily snapshots) usually don't have their base table in
  the lineage yaml — manually add `<table>` as a reference when target is
  `<table>_history`.
- Catalog Set shared Description lives at `/api/v1/table/<id>/` under
  `shared_catalog_sets[].description`, NOT at `/integration/v2/custom_field_value/`
  (that one only returns Title for catalog sets).
  `fetch_alation_catalog_set_design.py` already queries the correct path.
- If any Alation script errors with "token expired or revoked", regenerate the
  refresh token in Alation → Account Settings → Authentication and update
  `.env.local`.
- After editing a config, update `missions/column-comments/config/CATALOG.md`
  with a new row (or status change).

## What to produce

When asked to create a config:
1. Read `missions/column-comments/docs/creating-a-new-config.md`.
2. Run the helper scripts in order (stop when you have enough signal).
3. Write the config YAML with populated `target`, `confluence_pages`,
   `reference_tables`, and `alation` blocks. Follow the format of existing
   configs like `config/enterprise/fact-bill-line.yaml`.
4. Add a row to `CATALOG.md` with accurate status and notes.
5. Do NOT run `./run.sh` unless explicitly asked — the user typically runs
   that themselves after reviewing the config.
