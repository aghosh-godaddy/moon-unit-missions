# Column Comments Mission — Helper Scripts

Reusable helpers for populating per-table config YAMLs (`confluence_pages`,
`reference_tables`) and discovering design documentation. None of these mutate
config files — they print JSON to stdout, which you can inspect or pipe into
your own edit step.

All scripts load credentials from environment variables. Source `.env.local`
before running:

```bash
set -a; source .env.local; set +a
```

## `alation_fetch_table_metadata.py`

Look up tables in Alation and extract any Confluence URLs referenced in the
table description or custom fields (Data Lake Table Description, Data Lake
Owner Info, Data Lake SLA, etc.).

Use when: you need to know what Confluence links a table already has
registered in Alation.

```bash
# pass "schema.table" pairs as args (or one per line on stdin):
python3 scripts/alation_fetch_table_metadata.py \
  enterprise.dim_entitlement ecomm360.fact_bill_line_vw
```

Requires `ALATION_URL`, `ALATION_REFRESH_TOKEN`, `ALATION_USER_ID`.

## `fetch_alation_catalog_set_design.py`

Look for Confluence URLs in an Alation **Catalog Set's shared Description** —
the rich-text block rendered as "Shared from ⚙ <Title>" on each member
table's Overview page, which often contains the "Data Design" link.

Use when: `alation_fetch_table_metadata.py` returns no Confluence links but
the Alation UI shows a "Data Design" section on the table page.

```bash
python3 scripts/fetch_alation_catalog_set_design.py \
  --table bill_line_traffic_ext --resolve-tiny-links
```

**Important**: the shared Description is stored at `/api/v1/table/<id>/` under
`shared_catalog_sets[].description`, not at `/integration/v2/custom_field_value/`
(that endpoint returns only the Title for catalog sets). The script uses the
correct `/api/v1/table/` path; no special Alation permission beyond normal
read access is required.

Requires `ALATION_URL`, `ALATION_REFRESH_TOKEN`, `ALATION_USER_ID`. Tiny-link
resolution (optional `--resolve-tiny-links`) also needs `ATLASSIAN_EMAIL` and
`ATLASSIAN_API_TOKEN`.

## `confluence_search_bi_space.py`

Search a Confluence space (defaults to `BI`) for pages matching one or more
terms. For each term, runs a narrow `title ~` query first (high-signal,
exact-name design docs surface here regardless of broader-text rank), then a
`text ~` query (subject to the noise filter and per-term `--limit`). Each
hit's `match` field reports which query found it. CQL `~` is case-insensitive,
so the search term's casing doesn't matter. Filters known-noisy titles (weekly
JIRA reports, dashboards, bi-weeklies, …) on text matches and fetches a body
excerpt so you can judge relevance.

Use when: Alation has no Confluence link for the table and you need to hunt
for a design doc by name.

```bash
python3 scripts/confluence_search_bi_space.py \
  "dim_entitlement" "Entitlement Dimension"
```

Flags: `--space BI`, `--limit 15`, `--no-noise-filter`, `--no-excerpts`.

Requires `ATLASSIAN_EMAIL`, `ATLASSIAN_API_TOKEN`.

## `lake_lineage_fetch.py`

Pull `table.yaml` from `gdcorp-dna/lake`, parse
`lineage.upstream_table_dependencies`, filter to curated schemas, and resolve
each upstream table to an Alation id. Output feeds directly into a config's
`reference_tables` block.

Use when: you're populating `reference_tables:` for a new table.

```bash
python3 scripts/lake_lineage_fetch.py enterprise/dim-entitlement
python3 scripts/lake_lineage_fetch.py --registry dlms-api ecomm360/dim-bill-vw
python3 scripts/lake_lineage_fetch.py --all enterprise/dim-subscription  # no curated filter
```

Curated-schema allowlist lives in `CURATED_SCHEMAS` at the top of the file —
add schemas there when new curated layers appear in the lake.

Requires `ALATION_URL`, `ALATION_REFRESH_TOKEN`, `ALATION_USER_ID`,
`GITHUB_PAT` (with read access to `gdcorp-dna/lake`).

## Typical workflow for a new table

1. Create the config skeleton at `config/<db>/<table>.yaml` (copy an existing
   one).
2. Run `alation_fetch_table_metadata.py <db>.<table>` — paste any returned
   Confluence URLs into `confluence_pages`.
3. If that turns up nothing, run `confluence_search_bi_space.py <table>` and
   review the excerpts to pick the real design doc.
4. If the Alation UI shows a "Data Design" field but the API didn't,
   `fetch_alation_catalog_set_design.py --table <table>` confirms the catalog
   set id so you can eyeball the fields page in the UI (or wait on the API
   permission).
5. Run `lake_lineage_fetch.py <db>/<table>` — paste the returned references
   into `reference_tables`, adjusting descriptions as needed.
