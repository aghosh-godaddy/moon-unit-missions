# Creating a Column Comments Config for a New Table

Step-by-step playbook for adding a new table to this mission. The goal is a populated
`config/<db>/<table>.yaml` with verified Confluence URLs and Alation-backed
`reference_tables`, ready to run via `./run.sh <db> <table>`.

All helpers live in `scripts/`; see `scripts/README.md` for detailed flag reference.

## Prerequisites

One-time:
- `.env.local` configured (copy from `.env.local.example`) with:
  `ALATION_URL`, `ALATION_REFRESH_TOKEN`, `ALATION_USER_ID`,
  `ATLASSIAN_EMAIL`, `ATLASSIAN_API_TOKEN`, `GITHUB_PAT`
- `mu` CLI installed, Docker running (`colima start`), `AWS_PROFILE` set

Per-shell:

```bash
cd missions/column-comments
set -a; source .env.local; set +a
```

## 1. Identify the table + registry path

Find the table in the lake registry on GitHub (`gdcorp-dna/lake`):

- `catalog/config/prod/us-west-2/<db>/<table>/` → `registry_path: "standard"`
- `catalog/config/prod/dlms-api/us-west-2/<db>/<table>/` → `registry_path: "dlms-api"`

Note: the registry uses **hyphenated** table names (`dim-entitlement`), but Alation
and SQL use **underscored** names (`dim_entitlement`). Configs and CATALOG.md follow
this split.

## 2. Create the config skeleton

Copy an existing config as a template:

```bash
mkdir -p config/<db>
cp config/enterprise/fact-bill-line.yaml config/<db>/<table>.yaml
```

Edit `target.db_name`, `target.table_name`, `target.registry_path`. Leave
`confluence_pages: []` and `reference_tables: []` for now.

## 3. Pull Confluence URLs from Alation (table-level)

The fastest source — many tables have Confluence links inline in the Alation
Description or custom fields (Data Lake Owner Info, Data Lake SLA, etc.).

```bash
python3 scripts/alation_fetch_table_metadata.py <db>.<table>
```

Paste any returned URLs into `confluence_pages` with short descriptions. Legacy
`confluence.godaddy.com` hosts are already normalized to
`godaddy-corp.atlassian.net`; fragment-only duplicates are deduped.

## 4. If step 3 returns no URLs: check the Catalog Set shared Description

Some tables have their "Data Design" link only in a **Catalog Set**'s shared
Description (the block rendered as "Shared from ⚙ <Title>" on the table's
Overview page). This content is stored in `/api/v1/table/<id>/` under
`shared_catalog_sets[].description` — not in `/integration/v2/custom_field_value/`
(that endpoint returns only the Title for catalog sets).

```bash
python3 scripts/fetch_alation_catalog_set_design.py --table <table> --resolve-tiny-links
```

Add any returned URLs to `confluence_pages`. Tiny `/wiki/x/<code>` links are
resolved to their full page URLs when `--resolve-tiny-links` is passed.

## 5. If steps 3–4 return nothing: search the BI Confluence space

Hunt for a design doc by name, filter noise, and inspect excerpts:

```bash
python3 scripts/confluence_search_bi_space.py "<table_underscore>" "<Alation Title>"
```

Review the JSON output — each hit shows title + body excerpt so you can
distinguish actual design docs from dashboards, JIRA reports, and bi-weeklies
(those are already filtered by default). Add any genuinely relevant page to
`confluence_pages` with a description that says *why* it's relevant.

If nothing turns up, leave `confluence_pages: []` with a TODO and set the
table's CATALOG.md status to `planned` until a design doc exists.

## 6. Populate `reference_tables` from lake lineage

Pull `table.yaml` from the lake registry, filter upstream deps to curated schemas,
and resolve each to an Alation id:

```bash
python3 scripts/lake_lineage_fetch.py <db>/<table>
# or for dlms-api variant:
python3 scripts/lake_lineage_fetch.py --registry dlms-api <db>/<table>
# or to see ALL upstreams (not just curated schemas):
python3 scripts/lake_lineage_fetch.py --all <db>/<table>
```

The default filter keeps only enriched layers (`customer360`, `enterprise`,
`ecomm360`, `ecomm_mart`, `analytic`, `analytic_feature`, `bi_reports`,
`finance360`, `partner360`, `gd_traffic_mart`, `pricing_mart`, `signals_platform_cln`,
etc.). Raw `godaddybilling_txlog.*` / `godaddy.*` / `*_snap` tables are dropped
because their Alation descriptions don't aid column-level enrichment. Add new
schemas to `CURATED_SCHEMAS` at the top of the script when needed.

Paste the returned references into `reference_tables`, keeping `name`, `schema`,
`alation_table_id`, and a short description. If the table is a `_history` daily
snapshot (e.g. `dim_entitlement_history`), manually add the base table as a
reference — the lineage yaml often doesn't capture that relationship.

## 7. Record the table in CATALOG.md

Add a row with: db, table, registry, status (`planned` / `ready` / `enriched` /
`stale` / `blocked`), owner, config link, and short notes (Confluence URL
counts, lineage ref counts, any replacement notes).

## 8. Run

```bash
./run.sh <db> <table>
```

Check output at `output/<db>/<table>/`, verify the enriched DDL, and flip the
CATALOG.md status to `enriched` once committed.

## Decision tree (quick reference)

```
Start
 ├─ alation_fetch_table_metadata.py → URLs found?
 │    ├─ YES → add to confluence_pages, go to step 6
 │    └─ NO  → continue
 ├─ fetch_alation_catalog_set_design.py → URLs found?
 │    ├─ YES → add to confluence_pages, go to step 6
 │    └─ NO  → continue
 ├─ confluence_search_bi_space.py → relevant design doc?
 │    ├─ YES → add to confluence_pages, status=ready
 │    └─ NO  → leave confluence_pages:[], status=planned
 └─ lake_lineage_fetch.py → populate reference_tables
      └─ add _history base table if target ends in _history
```

## API surface notes

- The Catalog Set shared Description **is not** at
  `/integration/v2/custom_field_value/?otype=dynamic_set_property&oid=<id>&field_id=4`
  — that endpoint returns only the Title. The rich-text HTML the UI renders
  lives at `/api/v1/table/<any_member_table_id>/` under
  `shared_catalog_sets[].description`. `fetch_alation_catalog_set_design.py`
  uses that path.
- Alation refresh tokens rotate; if any Alation script starts returning
  "token expired or revoked", regenerate from Alation → Account Settings →
  Authentication and update `.env.local`.
