**Stage name:** validate
**The coding agent was given these instructions:** You are a strict validation agent. Your job is to ensure the final metadata doc is:
1) accurate (no false claims) and 2) complete in structure (all 20 sections present).

## Step 1: Read all artifacts
Read:
- `INPUT.md`
- `gather.md`
- `analyze.md`
- `RESOLVED_TARGET.json`
- `TABLE_METADATA.md`

## Step 2: Accuracy validation
For each non-trivial claim in TABLE_METADATA.md (grain, keys, filters, metrics, SLA, lineage):
- Identify the exact evidence source (PySpark line, DAG setting, lake table.yaml, etc.)
- If evidence is missing or contradictory, rewrite the metadata doc to remove or soften the claim.
- If a claim cannot be validated, replace it with a REQUIRES_MANUAL_INPUT marker.

## Step 2b: C1 Source Table validation (CRITICAL)
Scan the C1 "Source Table(s)" column in TABLE_METADATA.md. For EACH entry:
- If it references a local/intermediate/staging table (look for patterns like `*_stg`,
  `*_conformed.*`, `*_driver`, `analytic_local.*`, or any table NOT in the lake registry),
  this is a FAILURE. Replace it with:
  - The actual lake table if analyze.md resolved it
  - `UNRESOLVED - requires manual input` if analyze.md could not resolve it
- Only lake tables (those in `repos/lake/`) or external systems are acceptable as sources.

## Step 3: Completeness validation
Ensure all 20 sections exist with the correct headings. If missing, add them.
If a section is too sparse and cannot be completed accurately, add the manual-input marker.

## Step 4: Append a report to validate.md
Append:
- Target table
- PASS/FAIL for accuracy and completeness
- List of issues found + how they were fixed
- Sections requiring manual input (final list)

**The agent summarized its work in this way:**

---

## Validate Stage Report — customer360.customer_life_cycle_vw

**Generated:** 2026-05-28  
**Target table:** `customer360.customer_life_cycle_vw`  
**Validation basis:** TABLE_METADATA.md cross-checked against gather.md, analyze.md, RESOLVED_TARGET.json, and source repo files

---

### Overall Result

| Check | Result |
|---|---|
| **Accuracy** | **PASS** (1 issue found and fixed) |
| **Completeness (20 sections)** | **PASS** (21 sections present — exceeds minimum) |
| **C1 Source Table cleanliness** | **PASS** (no intermediate/staging tables found) |

---

### Step 2: Accuracy Validation

Each non-trivial claim was checked against its evidence source:

| Claim | Evidence Source | Result |
|---|---|---|
| Grain: one row per `(shopper_id, partition_eval_mst_date)` | `src/data_quality/constraints/customer_life_cycle_vw.json` PK check; analyze.md B1 | ✓ CONFIRMED |
| Composite key `(partition_eval_mst_date, shopper_id)` | DQ constraint file; gather.md Section 4; analyze.md B2 | ✓ CONFIRMED |
| `@PrimaryKey customer_id` DDL annotation is misleading — actual grain is `shopper_id` | analyze.md Do Not Claim item 4; DQ constraints override DDL comment | ✓ CONFIRMED; correctly noted as misleading in C2 |
| DAG schedule `20 7 * * *` = 7:20 AM MST | gather.md Section 2; `customer_life_cycle_dag.py` | ✓ CONFIRMED |
| SLO delivery `cron(00 15 * * ? *)` = 8:00 AM MST | Lake catalog `table.yaml`; gather.md Section 6 | ✓ CONFIRMED |
| Max runtime 120 min; TIER_4 | `customer_life_cycle_dag.yaml` policy file; gather.md Section 5 | ✓ CONFIRMED |
| retries=1, catchup=False, max_active_runs=15 | gather.md Section 2 (`customer_life_cycle_dag.py`) | ✓ CONFIRMED |
| DAG start_date 2026-01-01 (America/Phoenix) | gather.md Section 2 | ✓ CONFIRMED |
| 35 columns (34 data + 1 partition) | Lake DDL `customer-life-cycle-vw/table.ddl`; analyze.md B3 | ✓ CONFIRMED |
| EMR 7.10.0, core: m6g.16xlarge × 15 (ARM) | gather.md Section 2 (`customer_life_cycle_dag.py`) | ✓ CONFIRMED |
| `repartition(30)` → 30 Parquet files per partition | `customer_life_cycle.py` L1083 (RESOLVED_TARGET.json evidence) | ✓ CONFIRMED |
| 14 of 16 upstream sources gated by S3 sensors; `finance360.dim_country_vw` and `ads_bill_line_ext` ungated | gather.md Section 3 (16-row table; 2 rows show "No" in DAG sensor column) | ✓ CONFIRMED |
| `finance_payable_resource_flag = true` filter in C5 | `customer_active_subscription_detail_driver.py`; gather.md Section 3 | ✓ CONFIRMED |
| Legacy S3 path hardcoded to prod bucket | gather.md conflict #8; analyze.md D4 | ✓ CONFIRMED |
| UK→GB normalization for `customer_acquisition_country_code` | analyze.md E3; gather.md Section 4 | ✓ CONFIRMED |
| 123 Reg override for `private_label_id = 587240` | analyze.md E3; gather.md Section 4 | ✓ CONFIRMED |
| `customer_state_enum` priority: intraday > merged > churned > reactivated > new > active | gather.md Section 4 derivation block; analyze.md C1 | ✓ CONFIRMED |
| `ttm_gcr_usd_amt = 0` (not NULL) for intraday | analyze.md E3; gather.md Section 4 | ✓ CONFIRMED |
| 20 lake tables + 1 external S3 in D1 | analyze.md Step 3 Full Lineage Resolution (20 distinct lake tables confirmed) | ✓ CONFIRMED |
| Data Tier 4 | Lake catalog `table.yaml`; policy file; analyze.md Do Not Claim item 1 | ✓ CONFIRMED (NOT Tier 2; Confluence Tier 2 refers to dim tables only) |
| "primary OSI and OWL target"; "35% weight in coverage matrix" (A2) | gather.md Section 7: Confluence page ID 4387965088 explicitly states this | ✓ CONFIRMED (Confluence-sourced; gather stage read page directly) |
| Declared consumers list in A3 | Lake catalog `table.yaml` permissions block; gather.md Section 6 | ✓ CONFIRMED |
| On-call contacts (Slack channels, email, SNOW group) | gather.md Section 2 (`customer_life_cycle_dag.py` owner config) | ✓ CONFIRMED |
| Redshift DISTKEY + SORTKEY = `partition_eval_mst_date` | gather.md Section 5 (`create_customer_life_cycle.sql`) | ✓ CONFIRMED |
| `legacyLookBackEnabled: true` | Lake catalog `table.yaml`; gather.md Section 6 | ✓ CONFIRMED |
| DQ: only PK uniqueness checks found (REQUIRES_MANUAL_INPUT in E1) | gather.md Section 5 (`customer_life_cycle.json`, `customer_life_cycle_vw.json` — only PK checks present) | ✓ CONFIRMED; manual-input marker appropriately placed |
| Churned customers' subscription/payment data is from d-1 | gather.md Section 4; analyze.md D4 | ✓ CONFIRMED |

---

### Step 2b: C1 Source Table Validation (CRITICAL)

Scanned all 35 rows of the C1 "Source Table(s)" column in TABLE_METADATA.md.

**Result: PASS — no intermediate/staging tables found in any C1 row.**

All entries reference only:
- Lake tables confirmed in `repos/lake/catalog/config/prod/` (both `us-west-2/` and `dlms-api/us-west-2/` paths)
- External S3 (`ads_bill_line_ext`) explicitly marked as such
- Derived columns (e.g., `etl_build_mst_ts`, `active_status_flag`, `customer_acquisition_mst_month`) correctly annotated as "Derived" or "ETL runtime"

No `*_stg`, `*_conformed.*`, `*_driver`, `analytic_local.*`, or other intermediate patterns were present.

---

### Issues Found and Fixed

| # | Severity | Issue | Fix Applied |
|---|---|---|---|
| 1 | **HIGH** | C5 "Always-On Column Filters" was missing the `internal_shopper_flag = true` exclusion filter. This is an always-on ETL filter confirmed in `customer_ttm_payment_driver.py` L256 and `customer_active_subscription_detail_driver.py` L317: internal GoDaddy shoppers are excluded via anti-join on `customer360.dim_customer_history_vw.internal_shopper_flag` from both the TTM payment driver and the subscription detail driver, meaning they never appear in the output table. | **Fixed:** Added row to C5 table: `internal_shopper_flag = true rows excluded (anti-join)` | `customer360.dim_customer_history_vw` → subscription detail driver + TTM payment driver | Internal GoDaddy shoppers are fully excluded from all subscription and TTM payment calculations; they never appear in the output |

---

### Step 3: Completeness Validation

TABLE_METADATA.md contains **21 sections** (exceeds the 20-section minimum):

| Section | Heading | Status |
|---|---|---|
| A1 | Table Overview | ✓ Present |
| A2 | What This Table Is About | ✓ Present |
| A3 | Organizational Context & Ownership | ✓ Present (includes key consumers) |
| B1 | Key Business Value | ✓ Present |
| B2 | Primary Use Cases | ✓ Present |
| B3 | Advanced Analytics Use Cases | ✓ Present |
| C1 | Complete Column Reference with Data Insights | ✓ Present (35 columns, all sourced) |
| C2 | Primary Key & Performance | ✓ Present |
| C3 | Key Features, Capabilities & Limitations | ✓ Present |
| C4 | Important Notes & Pitfalls | ✓ Present |
| C5 | Always-On Column Filters | ✓ Present (fixed: internal shoppers row added) |
| C6 | Common Business Metrics | ✓ Present |
| C7 | Glossary & Term Definitions | ✓ Present |
| C8 | Example Queries & Patterns | ✓ Present |
| D1 | Data Source Reference | ✓ Present (20 lake + 1 external S3) |
| D2 | Data Pipeline & Infrastructure | ✓ Present |
| D3 | SLA & Refresh Schedule | ✓ Present |
| D4 | Table Creation & ETL Implementation | ✓ Present |
| E1 | Data Quality Checks | ✓ Present |
| E2 | Best Practices & Tips | ✓ Present |
| E3 | Related Articles & Documentation | ✓ Present |

All sections are substantively populated. No section was found to be empty or stub-only.

---

### Sections Requiring Manual Input (Final List)

| Marker | Location | What Is Needed |
|---|---|---|
| `REQUIRES_MANUAL_INPUT: BA` | A3 | Named Business Analyst owner and formal data steward are not identifiable from DAG, policy file, or Confluence. Confirm from Customer360 / EDT team roster. |
| `REQUIRES_MANUAL_INPUT: DG` (E1) | E1 | Only PK uniqueness DQ checks confirmed in source files. Confirm with Data Governance team whether additional row-count, null-rate, or referential integrity checks exist in an external data quality platform. |
| `REQUIRES_MANUAL_INPUT: DG` (E3) | E3 | Alation table/column documentation was not retrievable (`MOONUNIT_ALATION` env var not set). Incorporate Alation business stewardship metadata, column descriptions, and usage statistics manually if available. |


**The agent's final response to the user was:**
Validation complete. Here is a summary of what was done:

---

## Validation Summary — `customer360.customer_life_cycle_vw`

### Overall Result: PASS

| Check | Result |
|---|---|
| Accuracy | **PASS** (1 issue found and fixed) |
| C1 Source Table cleanliness | **PASS** — no intermediate/staging tables in any C1 row |
| Completeness | **PASS** — 21 sections present (exceeds 20-section minimum) |

---

### One Fix Applied

**HIGH severity — C5 missing "internal shoppers excluded" filter.**

The always-on ETL filter that excludes internal GoDaddy shoppers was absent from the C5 "Always-On Column Filters" table in `TABLE_METADATA.md`. This is a material data scoping constraint confirmed in the source code at:
- `customer_ttm_payment_driver.py` L256: `iss.shopper_id IS NULL -- exclude internal shoppers`
- `customer_active_subscription_detail_driver.py` L317: `WHERE iss.shopper_id IS NULL`

Both scripts query `customer360.dim_customer_history_vw` for `internal_shopper_flag = true` and anti-join to exclude them. The fix adds this row as the first entry in the C5 table.

---

### Sections Requiring Manual Input (3 remaining)

1. **A3 (BA marker)** — Named Business Analyst / data steward not identifiable from code artifacts
2. **E1 (DG marker)** — Only PK uniqueness DQ checks confirmed; additional platform-level checks unknown
3. **E3 (DG marker)** — Alation documentation unavailable (credentials not present during gather stage)