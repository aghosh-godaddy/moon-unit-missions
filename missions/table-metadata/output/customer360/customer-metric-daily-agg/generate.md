**Stage name:** generate
**The coding agent was given these instructions:** You are an author producing a **Business Context / Metadata** document for a Data Lake table.
Your output must be 100% accurate. Never fabricate. Avoid too much technical implementation detail.

## Step 1: Read INPUT.md, gather.md, analyze.md
Read:
- `INPUT.md`
- `gather.md`
- `analyze.md`
- `RESOLVED_TARGET.json`

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
- B2 should be a bullet list of natural-language questions.
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

## Generate Stage Summary — customer360.customer_metric_daily_agg_vw

**Generated:** 2026-05-28

### Target table resolved
`customer360.customer_metric_daily_agg_vw` (high confidence)
- Physical write target: `customer_core_conformed.customer_metric_daily_agg` (Hive/Parquet on S3)
- Lake-registered canonical name: `customer360.customer_metric_daily_agg_vw`
- Lake registry path: `catalog/config/prod/dlms-api/us-west-2/customer360/customer-metric-daily-agg-vw/`

### Sections requiring manual input
**Count: 1**

| Section | Tag | What is missing |
|---|---|---|
| A1 (Table Overview) — Alation URLs | `REQUIRES_MANUAL_INPUT: DG` | Alation URLs for both Redshift Serverless and Lake entries; `MOONUNIT_ALATION` env var was not available at generation time |

### Key sources used
| Source | Used for |
|---|---|
| PySpark: `customer360/customer-metrics/src/pyspark/customer_metric_daily_agg.py` | Business logic, grain, column derivations, write target, ETL steps |
| DAG: `customer360/customer-metrics/src/dag/customer_metric_daily_agg_dag.py` | Schedule, SLA, dependencies, compute spec, task flow, ownership contacts |
| Hive DDL: `customer360/customer-metrics/src/ddls/customer_metric_daily_agg.ddl` | Full column schema with DDL comments (32 cols + partition) |
| Redshift DDL: `customer360/customer-metrics/src/ddls/create_customer_metric_daily_agg.sql` | Redshift representation, DISTKEY/SORTKEY |
| Policies YAML: `customer360/customer-metrics/src/policies/customer_metric_daily_agg_dag.yaml` | SLA maxDurationMins, TIER_4, input/output lineage |
| DQ constraints: `customer360/customer-metrics/src/data_quality/` | 19-column composite PK constraint (both Hive and lake layers) |
| Lake table.yaml: `customer360/customer-metric-daily-agg-vw/table.yaml` | Data tier 4, SLA delivery cron, partition keys, consumer permissions, upstream lineage |
| Lake table.ddl: `customer360/customer-metric-daily-agg-vw/table.ddl` | Column set (note: stale — missing `data_source_enum`) |
| Confluence page 3779199819 | Business purpose, legacy table replacements, stewardship, NRU feature in progress |
| Confluence page 4387965088 | Grain confirmation, data tier, coverage weight (15%) |
| Alation | Skipped — `MOONUNIT_ALATION` not set |

### Unresolved lineage items
- **Alation URLs**: Not available (credentials missing). Both Redshift Serverless and Lake Alation table entries should be populated manually.
- **`customer_acquisition_mst_month` exact format**: DDL comment says "as yyyy-MM" but source table comment says "truncated to month" — exact string format (YYYY-MM vs. YYYY-MM-01) not confirmed from data; flagged in C4 pitfalls.
- **Three intermediate driver tables** (`customer_core_conformed.customer_ttm_payment_driver`, `customer_core_conformed.customer_active_subscription_detail_driver`, `customer_core_conformed.active_customer_stg`) feed into `customer_life_cycle` but their lake-level sources were not recursively traced — they do not surface as columns in `customer_metric_daily_agg` directly, so this does not affect C1 column lineage.

**The agent's final response to the user was:**
`TABLE_METADATA.md` has been created and `generate.md` has been updated. Here is a summary of what was produced:

---

## TABLE_METADATA.md — Summary

**Target table:** `customer360.customer_metric_daily_agg_vw`

The document covers all 5 pillars and 20 sections (A1–E3):

| Pillar | Key content |
|---|---|
| **A — Identity** | Table overview key-value table (grain, partition, format, data tier, SLA, DAG); business description replacing legacy `customer_mart` tables; ownership (EDT team, Slack channels, email) |
| **B — Value** | Business value narrative; 10 natural-language use case questions; 5 advanced analytics patterns |
| **C — Usage** | Full 32-column schema table with types, descriptions, source column renames, and derivation notes; 19-column composite PK; gap-fill and normalization pitfalls; always-filter guidance; metric definitions; glossary; 5 annotated example queries |
| **D — Pipeline** | Source table (`customer360.customer_life_cycle_vw`); repo paths, DAG task flow diagram, EMR spec; SLA table; ETL logic summary (7-step aggregation) |
| **E — Governance** | DQ constraints (19-col PK on both Hive and lake layers); 7 best-practice tips; Confluence and code references |

**Sections requiring manual input: 1**
- `A1` Alation URLs — `MOONUNIT_ALATION` credentials were not available; the Data Governance team should populate these after lookup.