**Stage name:** generate
**The coding agent was given these instructions:** You are an author producing a **Business Context / Metadata** document for a Data Lake table.
Your output must be 100% accurate. Never fabricate. Avoid too much technical implementation detail.

## Step 1: Read INPUT.md, gather.md, analyze.md
Read:
- `INPUT.md` — includes USER NOTES (HIGHEST PRIORITY) if provided
- `gather.md`
- `analyze.md`
- `RESOLVED_TARGET.json`

**USER NOTES (if present in INPUT.md):** Treat as verified expert input from the
table owner. Incorporate into A2, B1, C4, C7, and other relevant sections. USER NOTES
override Confluence, Alation descriptions, and DDL — but NEVER override PySpark/DAG code.

## Step 2: Create the final metadata document
Create a new markdown file in the workspace root named:
`TABLE_METADATA.md`

This file must follow the structure defined in `docs/Metadata-Structure.pdf`:
5 pillars, 20 sections, in order:
- A1, A2, A3
- B1, B2, B3
- C1..C8
- D1..D4
- E1..E3

Use this exact heading skeleton (keep headings even if content is missing):

- `# Business Context: <schema>.<table>`
- `## Pillar A: WHAT Is It? — Identity & Purpose`
  - `### A1. Table Overview`
  - `### A2. What This Table Is About`
  - `### A3. Organizational Context & Ownership`
- `## Pillar B: WHY Does It Matter? — Value & Use Cases`
  - `### B1. Key Business Value`
  - `### B2. Primary Use Cases`
  - `### B3. Advanced Analytics Use Cases`
- `## Pillar C: HOW Do I Use It Correctly? — Schema, Rules & Guidance`
  - `### C1. Complete Column Reference with Data Insights`
  - `### C2. Primary Key & Performance`
  - `### C3. Key Features, Capabilities & Limitations`
  - `### C4. Important Notes & Pitfalls`
  - `### C5. Always-On Column Filters`
  - `### C6. Common Business Metrics`
  - `### C7. Glossary & Term Definitions`
  - `### C8. Example Queries & Patterns`
- `## Pillar D: HOW Is It Built? — Pipeline & Provenance`
  - `### D1. Data Source Reference`
  - `### D2. Data Pipeline & Infrastructure`
  - `### D3. SLA & Refresh Schedule`
  - `### D4. Table Creation & ETL Implementation`
- `## Pillar E: HOW Is It Governed? — Quality, Standards & Ecosystem`
  - `### E1. Data Quality Checks`
  - `### E2. Best Practices & Tips`
  - `### E3. Related Articles & Documentation`

Content guidance (follow the PDF):
- A1 should be a compact key-value table. The FIRST rows must be the access/identity
  information in this exact order (if available from gather.md Alation section):
    1. Table Name (the table name as seen in Redshift)
    2. Database — always "Redshift - Serverless - Dev" (use the dev.* entry, never bi.*)
    3. Schema (the Redshift schema, e.g. `customer360`)
    4. Alation URL (link to the dev Redshift Serverless table entry in Alation)
    5. Lake Alation URL (link to the Lake table entry in Alation)
  Then continue with the remaining technical metadata (Lake Table, Grain, Partition Key,
  Storage Format, Data Tier, SLA, Refresh Cadence, etc.).
  If Alation was skipped or URLs are unavailable, omit those rows but keep the rest.
  A1 MUST include grain.
- B2 must contain TWO parts:
  1. **Questions this table answers** — bullet list of natural-language questions.
  2. **Alation Queries** (if gather.md has ## Alation Queries with results) — for EACH
     query, use this format (use empty string if a field is unknown):

     #### Query: <Title or "Untitled">

     | Field | Value |
     |---|---|
     | Query ID | <id> |
     | Title | <title> |
     | Author | <author> |
     | Description | <description> |
     | Schedule | <schedule or "Not scheduled"> |
     | Last Saved | <date> |
     | Last Run | <date> |
     | Datasource | <datasource> |
     | Alation Query URL | <url> |

     ```sql
     <SQL verbatim — do not modify>
     ```

     If Alation was skipped or no queries were found, omit the Alation Queries part.
- C1 should be a single readable schema table with a "Source Table(s)" column.
  **CRITICAL C1 RULE**: The "Source Table(s)" column must ONLY contain:
    - Lake tables (e.g., `enterprise.dim_subscription`) — the ultimate authoritative source
    - External systems (e.g., "S3 direct read")
    - `UNRESOLVED - requires manual input` if analyze.md marked it unresolved
  NEVER list intermediate/local/staging tables (e.g., `*_stg`, `*_conformed.*`,
  `*_driver`) as sources. These are implementation details. Use the column-level
  lineage mapping from analyze.md to find the lake table behind each intermediate table.
- C8 should include 2-5 short, annotated query patterns (avoid huge queries; keep focused).
- D2 should identify repo + file paths + orchestration tool + compute platform.
- D4 should summarize creation logic (no long code walk-through).

### Requirements
- If a section cannot be completed accurately, include:
  `<!-- REQUIRES_MANUAL_INPUT: <BA|DE|DG|DP> -->`
  and briefly state what information is missing.
- Do not include long code blocks. Reference file paths + brief snippets only when needed.
- Do not assert owners, SLAs, or definitions unless supported by code or authoritative sources.
- Keep “pipeline identity” concise (repo, paths, DAG name, schedule), not a walkthrough.

## Step 3: Append a stage summary to generate.md
Append to `generate.md`:
- Target table resolved (schema.table)
- Whether any sections require manual input (count + list)
- Key sources used (PySpark, DAG, lake table.ddl/table.yaml, Confluence, Alation)
- Any unresolved lineage items

**The agent summarized its work in this way:**

---

## generate stage output

**Generated:** 2026-05-28
**Stage:** generate (TABLE_METADATA.md authoring)

### Target Table Resolved
`customer360.customer_metric_daily_agg_vw`
- Physical Hive table: `customer_core_conformed.customer_metric_daily_agg`
- Lake registry path: `catalog/config/prod/dlms-api/us-west-2/customer360/customer-metric-daily-agg-vw/`

### Sections Requiring Manual Input
**Count: 0**

All 20 sections (A1–E3) were populated from authoritative sources. No `REQUIRES_MANUAL_INPUT` tags were inserted. Notes on unavailable sources:
- Confluence content (page 3779199819) — credentials unavailable during gather; URL included in E3 for reference.
- Alation table entries and query catalog — credentials unavailable during gather; Alation URL rows omitted from A1 per instructions; Alation Queries section omitted from B2.

### Key Sources Used
| Source | Used For |
|---|---|
| PySpark: `customer_metric_daily_agg.py` | A1 grain/partition, A2 business purpose, C1 column lineage/types/transforms, C2 PK, C3 features, C4 pitfalls (renames, UK→GB), C6 metric definitions, D2 pipeline, D4 ETL logic |
| DAG: `customer_metric_daily_agg_dag.py` | A1 DAG ID/cadence, A3 ownership/oncall, D2 pipeline flow, D3 SLA/schedule |
| Lake registry: `table.yaml` + `table.ddl` | A1 lake table path/SLO/tier, D1 consumers, D3 SLA delivery cron |
| Policies YAML: `customer_metric_daily_agg_dag.yaml` | D3 SLA tier (TIER_4), max duration (120 min) |
| DQ JSON: `customer_metric_daily_agg.json` + `_vw.json` | C2 authoritative 19-column PK, E1 DQ checks |
| Hive DDL: `customer_metric_daily_agg.ddl` | C1 column types, storage format, S3 location |
| Redshift DDLs (create + insert SQL) | C1 Redshift type notes, C3 distribution/sort keys, C4 bracket-stripping pitfall |
| Backfill DAG: `customer_metric_daily_agg_backfill_dag.py` | A2 legacy cutoff date (2026-04-01), D3 backfill range |
| USER NOTES (INPUT.md) | A2 description (18 dims, legacy replacement), B1 value statement, C4 partition filter warning, C5 always-on filters, C7 glossary terms |
| analyze.md column-level lineage | C1 source column mappings for all 32 columns |

### Unresolved Lineage Items
The following intermediate tables used by `customer_life_cycle.py` (two hops upstream) could not be resolved to lake tables — they are internal pipeline intermediates and do not appear in C1 (per C1 rules):
- `customer_core_conformed.active_customer_stg`
- `customer_core_conformed.customer_ttm_payment_driver`
- `customer_core_conformed.customer_active_subscription_detail_driver`

These are noted in analyze.md but have no impact on `customer_metric_daily_agg_vw` consumers, as they are already encapsulated within `customer360.customer_life_cycle_vw`.

### Known Discrepancies Captured (from gather.md / analyze.md)
1. Lake DDL `@PrimaryKey` annotates 16 of 19 PK columns — noted in C2.
2. `data_source_enum` absent from lake DDL — noted in C1 and C3.
3. Redshift `partition_eval_mst_date` typed DATE vs. Hive string — noted in C1 and C3.
4. DAG `documentation_markdown` says "SLA: N/A" — authoritative SLA from policy YAML and lake registry used in D3.

**The agent's final response to the user was:**
`TABLE_METADATA.md` has been written. Here is a summary of what was produced:

---

## What was created

**File:** `/tmp/moonunit-workspace/TABLE_METADATA.md`
**Target:** `customer360.customer_metric_daily_agg_vw`

### All 20 sections populated — 0 require manual input

| Pillar | Sections | Notes |
|---|---|---|
| A — Identity & Purpose | A1, A2, A3 | A1 omits Alation URL rows (credentials unavailable); includes all other identity fields. A2 incorporates USER NOTES verbatim. |
| B — Value & Use Cases | B1, B2, B3 | B2 has questions-only (no Alation queries — credentials unavailable). |
| C — Schema, Rules & Guidance | C1–C8 | C1 is a full 32-column table with source mapped to `customer360.customer_life_cycle_vw` for all resolved columns. C4 leads with the USER NOTE partition filter warning. |
| D — Pipeline & Provenance | D1–D4 | D2 includes repo paths, DAG task flow, and compute platform. D4 summarizes ETL logic without code walkthrough. |
| E — Governance | E1–E3 | E1 covers both Hive and lake view DQ checks. E3 references Confluence URL and upstream lake table. |

### Key decisions
- **C1 Source Table column** — all columns show `customer360.customer_life_cycle_vw` (the authoritative lake table). Intermediate tables (`active_customer_stg`, etc.) are never surfaced.
- **USER NOTES** incorporated into A2 (purpose/legacy replacement), B1 (value), C4 (partition filter pitfall), C5 (always-on filter), C7 (glossary).
- **PK authority** — 19-column composite from PySpark `GROUP BY` + DQ JSON (not the stale 16-column lake DDL annotation).
- **No fabrication** — Confluence and Alation content omitted rather than guessed; URLs included in E3 for human follow-up.