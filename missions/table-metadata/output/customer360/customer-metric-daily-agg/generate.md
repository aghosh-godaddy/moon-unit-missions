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
    2. Database (e.g., "Redshift - Serverless - Dev")
    3. Schema (the Redshift schema)
    4. Alation URL (link to the Redshift table entry in Alation)
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

## Generate Stage — Summary

**Stage:** generate
**Date:** 2026-05-28

### Target table resolved
`customer360.customer_metric_daily_agg_vw` (HIGH confidence)
- Lake path: `dlms-api/us-west-2/customer360/customer-metric-daily-agg-vw/`
- Physical write target: `customer_core_conformed.customer_metric_daily_agg`

### Sections requiring manual input: 3

| Section | Tag | Missing Information |
|---|---|---|
| A3 | `DG` | Individual data steward name — Alation shows group-level only (Franchise: Customer, group ID 47) |
| A3 | `DG` | Data classification / PII sensitivity level — not documented in code or lake registry |
| D3 | `DG` | Data retention policy — not documented in code, lake registry, or policy YAML |

### Key sources used

| Source | Used For |
|---|---|
| PySpark `customer_metric_daily_agg.py` (main, HEAD `7523b6d5`) | Column schema, business logic, COALESCE defaults, write target, metric formulas, ETL steps |
| DAG `customer_metric_daily_agg_dag.py` | Schedule (`30 7 * * *` MST), task flow, SLA reference, upstream dependency, EMR config, contacts |
| Lake `table.yaml` | SLA delivery target (`cron(00 15 * * ? *)` UTC), data tier (4), permissions, SLO identifier |
| Lake `table.ddl` | Column schema cross-check (noted discrepancies: missing `data_source_enum`, incomplete `@PrimaryKey`) |
| DQ constraints JSON (local + lake) | Authoritative 19-column composite primary key |
| Policy YAML | Max duration (120 min), TIER_4, team/environment contacts |
| `RESOLVED_TARGET.json` | Schema/table identity confirmation |
| Confluence (pages 3779199819, 4042131239, 4042131351, 4192469643) | Official metric definitions (Active Customer, New, Churn, Net Adds), deprecation notice, validation thresholds |
| Alation (lake ID 7038346, Redshift ID 7038887) | Alation URLs, Alation description, steward, 6 saved queries |

### Lineage resolution
All intermediate tables fully resolved — zero UNRESOLVED entries.

- `customer_core_conformed.customer_life_cycle` → `customer360.customer_life_cycle_vw` (lake)
- `customer360.customer_life_cycle_vw` itself traced through 15+ lake tables across 7 schemas (`enterprise`, `analytic_feature`, `customer360`, `finance360`, `dp_enterprise`, `ecomm_mart`, `customers`, `finance_cln`)
- All 32 target columns mapped to lake source `customer360.customer_life_cycle_vw` (or derived/hardcoded)

### Notable discrepancies documented (not fabricated — all sourced from code)
1. Lake DDL missing `data_source_enum` column
2. Lake DDL `@PrimaryKey` covers 16 of 19 PK columns (DQ JSON is authoritative)
3. Policy YAML input listing is stale (lists `customer_life_cycle_vw`; code reads conformed table)
4. DAG docstring SLA = `N/A` (contradicted by lake `table.yaml` and policy YAML)
5. Legacy column rename: `evaluation_mst_date` → `partition_eval_mst_date`

**The agent's final response to the user was:**
`TABLE_METADATA.md` has been created and `generate.md` has been updated. Here is a summary of what was produced:

---

**`TABLE_METADATA.md` — `customer360.customer_metric_daily_agg_vw`**

All 20 sections (A1–E3) across 5 pillars are populated:

- **A1** — Identity table with Redshift table name, database, schema, both Alation URLs, grain, partition key, storage format, Data Tier 4, SLA, DAG ID, and upstream dependency.
- **A2** — Business description of the daily customer lifecycle roll-up, its 18 dimensions, 5 lifecycle events, and replacement of `customer_mart.daily_active_customers` (from USER NOTES + code).
- **A3** — Full ownership table: EDT team, contacts, MWAA environment, Alation steward.
- **B1** — Key business value: DAC reporting, unified lifecycle view, 18-dim segmentation, legacy migration.
- **B2** — 8 questions this table answers + all 6 Alation queries with SQL verbatim.
- **B3** — Advanced analytics use cases (cohort transitions, churn modeling, product affinity, etc.).
- **C1** — Complete 32-column schema table with types, descriptions, COALESCE defaults, and source table (`customer360.customer_life_cycle_vw` for all data columns; derived/hardcoded for computed/system columns).
- **C2** — 19-column composite PK, Redshift DISTKEY/SORTKEY, known lake DDL discrepancy noted.
- **C3–C7** — Features/limitations, pitfalls (partition filter, column renames, UK→GB normalization), always-on filters, metric definitions, glossary with official Confluence definitions and COALESCE defaults table.
- **C8** — 4 focused, annotated example queries.
- **D1–D4** — Source reference (upstream lake tables), pipeline/infrastructure details, SLA/schedule, ETL logic summary.
- **E1–E3** — DQ constraints (isPrimaryKey, 19 columns), best practices, full related assets table.

**Sections requiring manual input: 3** (individual steward name, PII classification, retention policy — all tagged `DG`).