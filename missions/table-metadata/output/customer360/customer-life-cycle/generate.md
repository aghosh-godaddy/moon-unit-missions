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
- A1 should be a compact key-value table and MUST include grain.
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

## Generate Stage Summary

**Generated:** 2026-05-28
**Target table resolved:** `customer360.customer_life_cycle_vw` (confidence: high)
**Output file:** `TABLE_METADATA.md`

### Sections requiring manual input: 3

| Section | Tag | Missing Information |
|---|---|---|
| A3 | BA | Named Business Analyst owner and formal data steward not identified in code, policy, or Confluence |
| E1 | DG | Only PK uniqueness DQ checks found; confirm whether additional checks exist in external DQ platform |
| E3 | DG | Alation table/column documentation not retrieved (MOONUNIT_ALATION credentials not available) |

### Key sources used

| Source | Used For |
|---|---|
| PySpark: `customer_life_cycle.py` (main, 7523b6d5) | Column definitions, derivation logic, always-on filters, write target, ETL steps |
| DAG: `customer_life_cycle_dag.py` | Schedule, SLA, task flow, EMR config, upstream dependency sensors, consumers |
| DDL: `customer_life_cycle.ddl`, `create_customer_life_cycle.sql` | Column types, Redshift schema |
| Policy: `customer_life_cycle_dag.yaml` | SLA maxDurationMins, TIER_4, declared inputs/outputs |
| DQ: `customer_life_cycle.json`, `customer_life_cycle_vw.json` | PK definition, DQ check scope |
| Lake: `table.yaml` + `table.ddl` (customer-life-cycle-vw) | Data tier, SLO schedule, partition key, consumer groups, legacyLookBackEnabled |
| Intermediate PySpark scripts (4): `customer_ttm_payment_driver.py`, `customer_active_subscription_detail_driver.py`, `active_customer_stg.py`, `subscription_grace_policy.py` | Recursive lineage traversal to resolve intermediate tables to lake sources |
| Confluence: pages 3779199819, 3970861345, 4387965088 | Business purpose, grain confirmation, OSI/OWL context, design doc |
| Alation | Skipped — credentials not available |

### Lineage resolution summary

- **Total direct upstream references in target PySpark:** 16 (3 intermediate `customer_core_conformed.*` tables + 12 lake tables + 1 external S3)
- **Intermediate tables resolved:** 4 (all fully resolved to lake sources via recursive script traversal)
- **Total distinct lake + external sources:** 20 lake tables + 1 external S3 (`ads_bill_line_ext`)
- **UNRESOLVED entries:** 0
- **C1 Source Table(s) column:** uses only lake tables and external S3; no intermediate/staging tables listed
- **Stale lake catalog lineage noted:** 8 entries in the lake catalog lineage predate the current ETL architecture; not included in the metadata document (code is authoritative)

**The agent's final response to the user was:**
`TABLE_METADATA.md` has been created and `generate.md` has been updated. Here is a summary of what was produced:

---

## Output: `TABLE_METADATA.md` — `customer360.customer_life_cycle_vw`

**All 5 pillars / 20 sections completed** following the exact heading skeleton.

### Key content highlights

| Section | Content |
|---|---|
| **A1** | Compact key-value table: schema, table, internal landing table, grain, partition, tier, SLO, historical lookback |
| **A2** | Business narrative: daily customer-state driver for Finance and Marketing; OSI/OWL primary target |
| **A3** | Engineering team (Customer360/EDT), on-call channels, SNOW group; BA/steward flagged for manual input |
| **B1** | Churn/retention, cohort analysis, revenue attribution, product portfolio, fraud segmentation |
| **B2** | 10 natural-language business questions the table answers |
| **B3** | 5 advanced analytics use cases (survival modeling, forecasting, attribution, fraud impact, geo expansion) |
| **C1** | Full 35-column schema table with only lake tables in "Source Table(s)" — no intermediate tables |
| **C2** | Composite PK `(partition_eval_mst_date, shopper_id)`; partition guidance; DDL annotation caveat |
| **C4** | 9 documented pitfalls (churned d-1 data, country normalization, 123 Reg override, no country sensor, etc.) |
| **C5** | 8 always-on ETL filters defining scope of every row |
| **C6–C7** | 5 key metrics + 14 glossary terms including all 6 `customer_state_enum` values |
| **C8** | 5 annotated, focused query patterns |
| **D1** | Full 20-source table reference (20 lake tables + 1 external S3) |
| **D2** | Pipeline identity: repo, paths, DAG ID, Airflow/MWAA, EMR config, task flow summary |
| **D3** | Daily 7:20 AM MST schedule, 8:00 AM MST SLO, 120-min TIER_4 SLA |
| **D4** | 11-step ETL summary (no code walk-through) |
| **E1–E3** | DQ checks, 9 best-practice tips, reference links |

### Sections requiring manual input: **3**
- `A3` (BA) — named business owner / data steward
- `E1` (DG) — confirm additional DQ checks beyond PK uniqueness
- `E3` (DG) — Alation metadata (credentials unavailable)

### Unresolved lineage: **0** — all 4 intermediate tables fully traced to lake sources