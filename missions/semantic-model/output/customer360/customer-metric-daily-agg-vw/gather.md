**Stage name:** gather
**The coding agent was given these instructions:** You are a Data Governance analyst. Your job is to gather ONLY verifiable facts
about a Data Lake table from the authoritative ETL code and supporting sources.
Do not guess. If something is unknown, say "Unknown" and explain what you checked.

## Source-of-truth rule
The PySpark script and the DAG that calls it are the source of truth. If Alation,
Confluence, DDL, policies, or other docs conflict with code, treat the code as
correct and record the discrepancy for validation.

## Step 1: Read INPUT.md
Read `INPUT.md` in your workspace. It contains:
- PySpark GitHub URL + parsed repo/ref/path
- Repository folder names inside the container (under `repos/`)
- Optional lake table override and semantic model name
- Supporting docs (Confluence URLs, other URLs)
- Alation configuration

Use INPUT.md as the contract for what to fetch and where to look.

## Step 2: Check out the exact Git ref for the source repo
INPUT.md includes the desired git ref (branch/tag/SHA) and the source repo URL.
The Moon Units framework clones repos into `repos/<repo-name>/` where repo-name is
derived from the git URL (e.g., `https://github.com/org/my-repo.git` → `repos/my-repo/`).

Determine the source repo folder name from the URL in INPUT.md (strip org and .git).
Then checkout the desired ref:

```bash
git -C repos/<repo-name> fetch --all --tags
git -C repos/<repo-name> checkout <ref_from_INPUT_md>
```

## Step 3: Read the PySpark script and the calling DAG
- Read the PySpark file at the path from INPUT.md.
- Locate and read the DAG file that calls it. Per repo convention, from the parent
  folder of the pyspark folder you should find sibling folders: `dag/`, `policies/`,
  `data_quality/`, `ddl/`.
- The DAG must be treated as authoritative for schedule/cadence, dependencies, and
  which job/version is run.
- **Extract all join conditions** (explicit `on=` keys, join predicates) — these
  will become OSI relationships in later stages.

## Step 4: Collect nearby repo context (secondary sources)
- Read relevant files under sibling folders:
  - `ddl/` (table DDLs) — helpful but may be stale
  - `policies/` — helpful but may be stale
  - `data_quality/` — checks and expectations (treat as evidence, not truth)
Record any conflicts with code explicitly.

## Step 5: Fetch Confluence pages (if provided)
For each URL in INPUT.md under CONFLUENCE PAGES, fetch page content via Atlassian REST API.
The page ID is the numeric part of the URL path.

**IMPORTANT: Parent pages may link to child pages.** Fetch the provided page first,
list child pages, identify relevant ones, fetch only those.

Credentials:
- Prefer `MOONUNIT_JIRA` env var (JSON: {"url","email","api_token"}) OR
- `MOONUNIT_ATLASSIAN` env var (JSON: {"email","api_token"})

Example:
```bash
ATLASSIAN_CREDS=$(node -e "const j=JSON.parse(process.env.MOONUNIT_JIRA || process.env.MOONUNIT_ATLASSIAN); console.log(j.email + ':' + j.api_token)")
curl -s -u "$ATLASSIAN_CREDS" \
  "https://godaddy-corp.atlassian.net/wiki/rest/api/content/{PAGE_ID}?expand=body.storage"
```

Extract content relevant to business meaning, grain, metrics, filters, SLAs, ownership.

## Step 6: Alation lookup (if enabled)
If INPUT.md says Alation is enabled:
1. Check if `MOONUNIT_ALATION` env var is available; skip if not set.
2. Create API token via Alation integration API.
3. Search for the target table (Lake entry) and record descriptions/custom fields.
4. Fetch saved queries referencing the table (use Max queries from INPUT.md).

For each Alation query, record: Query ID, Title, Author, Description, SQL (verbatim).

## Step 7: Enumerate tables and column schemas
For EVERY table referenced in the PySpark (read and write targets):
- Record table name (schema.table form)
- Record whether it is read, written, or both
- If a lake DDL exists in `repos/lake/`, read `table.ddl` and list columns with types
- If only in-repo DDL exists, read that instead (note it may be stale)
- Record any join keys used with this table

## Step 8: Output (append to gather.md)
Append a structured, evidence-oriented report including:
- PySpark job identity (repo/ref/path), output write target(s)
- DAG identity (path, schedule, params)
- **Table inventory** — all referenced tables with read/write role and column schemas
- **Join conditions** — explicit join keys extracted from PySpark
- **Aggregation expressions** — SUM/COUNT/AVG/GROUP BY patterns found in PySpark
- DDL/policy/DQ files consulted
- Confluence summaries (if any)
- Alation section (table info + queries if fetched)
- Conflicts / discrepancies section

**The agent summarized its work in this way:**

---

## Stage: Data Governance Gather — customer360 / customer-metric-daily-agg-vw

**Date:** 2026-06-05  
**Source repo:** `repos/dof-dpaas-customer-feature` @ `main`  
**Source file:** `customer360/customer-metrics/src/pyspark/customer_metric_daily_agg.py`

---

### 1. PySpark Job Identity

| Field | Value |
|---|---|
| FEED_NAME | `customer_metric_daily_agg` |
| Script path | `customer360/customer-metrics/src/pyspark/customer_metric_daily_agg.py` |
| App name | `customer_metrics_daily_agg` |
| Git ref | `main` |
| Repo URL | `https://github.com/gdcorp-dna/dof-dpaas-customer-feature.git` |
| Write target (Hive/Lake) | `customer_core_conformed.customer_metric_daily_agg` |
| Lake-published view | `customer360.customer_metric_daily_agg_vw` (via `SuccessNotificationOperator`) |
| Write mode | `insertInto(overwrite=True)` + MSCK REPAIR |
| Partition column | `partition_eval_mst_date` (string) |
| DDL file used at runtime | `customer_metric_daily_agg.ddl` |
| S3 location (prod) | `s3://gd-ckpetlbatch-prod-customer-core-conformed/customer_core_conformed/customer_metric_daily_agg/` |

---

### 2. DAG Identity

| Field | Value |
|---|---|
| DAG file | `customer360/customer-metrics/src/dag/customer_metric_daily_agg_dag.py` |
| DAG ID | `customer-metric-daily-agg` |
| Schedule | `30 7 * * *` (7:30 AM MST daily; disabled in dev-private) |
| Start date | 2026-01-01 (America/Phoenix TZ) |
| Catchup | False |
| Max active runs | 15 |
| Retries | 1 with 3-min delay |
| Owner | customer360 |
| Team | EDT (Emerald Data Team) |
| MWAA environment | `dof-customers` (AWS account 688051721285) |
| EMR compute | EMR Serverless, release `emr-7.10.0`, `m6g.16xlarge` × 15 core |
| SLA (policy yaml) | Max 120 min, TIER_4 severity |
| SLA (lake yaml) | Delivered by 08:00 AM MST (`cron(00 15 * * ? *)` UTC) |
| Alerts channel | `#edt-airflow-alerts` (prod) / `#edt-airflow-alerts-low-priority` (lower envs) |
| OnCall SNOW | `DEV-EDT-OnCall` |
| Contact email | `dl-bi-enterprise-data@godaddy.com` |

**DAG parameters:**
- `start_mst_date` (string, YYYY-MM-DD, defaults to logical_date in MST)
- `end_mst_date` (string, YYYY-MM-DD, defaults to logical_date in MST)
- `spark_config` (Spark conf string override)

**Upstream dependency (S3KeySensor):**
- Waits for success file: `customer360/customer_life_cycle_vw/{YYYY}/{MM}/{DD}/_SUCCESS`

**Task flow:**
```
dag_config → dependencies (wait for customer_life_cycle_vw success)
  → create Redshift tables (create_customer_metric_daily_agg.sql + stg)
  → create_emr → run_customer_metric_daily_agg → remove_emr
  → dq_check (local: customer_core_conformed.customer_metric_daily_agg)
  → conditional_call_lake_api → call_lake_api (prod) / skip (non-prod)
  → s3_to_redshift_stg → insert_customer_metric_daily_agg (Redshift)
  → check_for_failure_branch → succeed/fail
  → dq_check_lake (customer360.customer_metric_daily_agg_vw) [after call_lake_api]
```

**Tags:** `domain:customer`, `sub-domain:active-customer`, `layer:enterprise`, `team:EDT`, `pipeline-group:active-customer`, `special:daily`

---

### 3. Table Inventory

#### 3a. Source Table — `customer_core_conformed.customer_life_cycle` (READ)

> **Authoritative source per PySpark code.** The script reads `customer_core_conformed.customer_life_cycle` directly. The `customer360.customer_life_cycle_vw` reference exists but is **commented out** in the PySpark code (line 228).

**Filter used:** `WHERE partition_eval_mst_date BETWEEN '{start_mst_date_minus_1}' AND '{end_mst_date}'`  
(Note: starts 1 day before the requested start to enable LAG for beginning_customer_qty)

**DDL source:** `repos/dof-dpaas-customer-feature/customer360/customer-metrics/src/ddls/customer_life_cycle.ddl`

| Column | Type | Notes |
|---|---|---|
| shopper_id | string | PK (together with partition date) |
| customer_id | string | PK |
| customer_acquisition_bill_id | string | FK to acquisition event |
| customer_acquisition_mst_date | date | |
| customer_acquisition_mst_month | string | |
| customer_acquisition_country_code | string | |
| customer_acquisition_channel_name | string | |
| customer_tenure_year_count | int | |
| customer_acquisition_country_name | string | |
| customer_region_1_name | string | |
| customer_region_2_name | string | |
| customer_region_3_name | string | |
| customer_domestic_international_name | string | |
| reseller_type_id | int | |
| reseller_type_name | string | |
| customer_type_name | string | |
| customer_type_reason_desc | string | |
| customer_fraud_flag | boolean | |
| active_paid_subscription_list | array<string> | |
| product_pnl_category_list | array<string> | → becomes `product_ownership_category_list` in output |
| product_pnl_category_qty | int | |
| product_pnl_line_list | array<string> | → becomes `product_ownership_line_list` in output |
| ttm_all_bill_list | array<string> | |
| brand_name_list | array<string> | |
| ttm_gcr_usd_amt | decimal(18,2) | |
| customer_churn_mst_date | date | null if not churned |
| customer_reactivate_mst_date | date | null if not reactivated |
| customer_merge_mst_date | date | null if not merged |
| customer_fraud_mst_date | date | |
| customer_state_enum | string | active/churned/merged/reactivated |
| active_status_flag | boolean | |
| point_of_purchase_name | string | |
| customer_acquisition_bill_fraud_flag | boolean | |
| etl_build_mst_ts | timestamp | |
| **partition_eval_mst_date** | string | PARTITION KEY |

---

#### 3b. Output Table — `customer_core_conformed.customer_metric_daily_agg` (WRITE, Hive/Parquet)

Also surfaced as **`customer360.customer_metric_daily_agg_vw`** (Data Lake published view).

**DDL sources:**
- In-repo authoritative: `repos/dof-dpaas-customer-feature/customer360/customer-metrics/src/ddls/customer_metric_daily_agg.ddl`
- Lake DDL: `repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/customer-metric-daily-agg-vw/table.ddl`
- Redshift DDL: `src/ddls/create_customer_metric_daily_agg.sql`

**Full column schema (from in-repo DDL, cross-checked against `conform_datatype()` in PySpark — source of truth):**

| Column | Type | PK | Description |
|---|---|---|---|
| customer_type_reason_desc | string | ✓ | Reason for customer type classification |
| customer_acquisition_mst_month | string | ✓ | Month of customer acquisition (MST), as yyyy-MM |
| customer_domestic_international_name | string | ✓ | Domestic vs International classification |
| customer_region_1_name | string | ✓ | Geographic region level 1 |
| customer_region_2_name | string | ✓ | Geographic region level 2 |
| customer_region_3_name | string | ✓ | Geographic region level 3 |
| customer_country_name | string | ✓ | Customer country name at evaluation date |
| customer_country_code | string | ✓ | Customer country code (ISO, UK→GB normalized) |
| customer_type_name | string | ✓ | Customer type at evaluation date |
| acquisition_channel_name | string | ✓ | Acquisition channel |
| customer_tenure_year_count | int | ✓ | Customer tenure in years (integer) |
| product_ownership_category_list | string | ✓ | Owned product category list (string-encoded array) |
| product_ownership_line_list | string | ✓ | Owned product line list (string-encoded array) |
| reseller_type_name | string | ✓ | Reseller type name |
| fraud_flag | boolean | ✓ | True if customer flagged as fraud (input field: `customer_fraud_flag`) |
| point_of_purchase_name | string | ✓ | Point of purchase name from acquisition bill |
| customer_acquisition_bill_fraud_flag | boolean | ✓ | True if acquisition bill has fraud record |
| brand_name_list | string | ✓ | List of all brands associated with customer (string-encoded array) |
| product_category_qty | int | | `coalesce(size(product_ownership_category_list), 0)` |
| ttm_gcr_usd_amt | decimal(18,2) | | SUM of TTM gross cash received in USD |
| ending_customer_qty | bigint | | COUNT_IF(active_status_flag = true) |
| churn_customer_qty | bigint | | COUNT_IF(customer_churn_mst_date is not null) |
| merge_customer_qty | bigint | | COUNT_IF(customer_merge_mst_date is not null) |
| new_customer_qty | bigint | | COUNT_IF(customer_acquisition_mst_date = partition_eval_mst_date) |
| reactivate_customer_qty | bigint | | COUNT_IF(customer_reactivate_mst_date is not null) |
| beginning_customer_qty | bigint | | LAG(ending_customer_qty) over dim partition, 0 if not consecutive |
| net_move_qty | bigint | | ending - beginning - new + (churn - reactivate) + merge |
| net_add_qty | bigint | | ending - beginning |
| net_churn_qty | bigint | | churn - reactivate |
| data_source_enum | string | | Hard-coded `'customer360'` |
| etl_build_mst_ts | timestamp | | `from_utc_timestamp(current_timestamp(), "MST")` |
| **partition_eval_mst_date** | string | ✓ | PARTITION KEY — Evaluation date (MST) |

**Grain:** One row per `partition_eval_mst_date` × unique combination of all 19 PK dimension columns.

**Row count (Alation):** 0 (metadata not refreshed in Alation)

---

### 4. Aggregation Expressions (from PySpark)

All aggregations are performed in the initial GROUP BY against `customer_core_conformed.customer_life_cycle`:

| Output Column | SQL Expression | Type |
|---|---|---|
| ttm_gcr_usd_amt | `SUM(ttm_gcr_usd_amt)` | SUM |
| ending_customer_qty | `COUNT_IF(active_status_flag = true)` | COUNT_IF |
| churn_customer_qty | `COUNT_IF(customer_churn_mst_date is not null)` | COUNT_IF |
| merge_customer_qty | `COUNT_IF(customer_merge_mst_date is not null)` | COUNT_IF |
| new_customer_qty | `COUNT_IF(customer_acquisition_mst_date = partition_eval_mst_date)` | COUNT_IF |
| reactivate_customer_qty | `COUNT_IF(customer_reactivate_mst_date is not null)` | COUNT_IF |

**Derived metrics (computed post-aggregation):**
| Output Column | Formula |
|---|---|
| product_category_qty | `coalesce(size(product_ownership_category_list), 0)` |
| beginning_customer_qty | `LAG(ending_customer_qty) OVER (PARTITION BY <all 18 dims> ORDER BY partition_eval_mst_date)`, else 0 |
| net_move_qty | `ending - beginning - new + (churn - reactivate) + merge` |
| net_add_qty | `ending - beginning` |
| net_churn_qty | `churn - reactivate` |

**GROUP BY columns (19):**
`partition_eval_mst_date, customer_type_reason_desc, customer_acquisition_mst_month, customer_domestic_international_name, customer_region_1_name, customer_region_2_name, customer_region_3_name, customer_country_name, customer_country_code, customer_type_name, acquisition_channel_name, customer_tenure_year_count, product_pnl_category_list, product_pnl_line_list, reseller_type_name, customer_fraud_flag, point_of_purchase_name, customer_acquisition_bill_fraud_flag, brand_name_list`

---

### 5. Join Conditions

**Join 1 — LEFT ANTI JOIN** (`missing_next_day`): Identifies dimension combinations from prior day that have no data on the next date, inserting zero-valued rows to maintain continuity.

```
candidates_next_day c
LEFT ANTI JOIN daily_metrics b ON
  b.partition_eval_mst_date               = c.partition_eval_mst_date
  AND b.customer_type_reason_desc         = c.customer_type_reason_desc
  AND b.customer_acquisition_mst_month    = c.customer_acquisition_mst_month
  AND b.customer_domestic_international_name = c.customer_domestic_international_name
  AND b.customer_region_1_name            = c.customer_region_1_name
  AND b.customer_region_2_name            = c.customer_region_2_name
  AND b.customer_region_3_name            = c.customer_region_3_name
  AND b.customer_country_name             = c.customer_country_name
  AND b.customer_country_code             = c.customer_country_code
  AND b.customer_type_name                = c.customer_type_name
  AND b.acquisition_channel_name          = c.acquisition_channel_name
  AND b.customer_tenure_year_count        = c.customer_tenure_year_count
  AND coalesce(cast(sort_array(b.product_ownership_category_list) as string), 'na')
    = coalesce(cast(sort_array(c.product_ownership_category_list) as string), 'na')
  AND coalesce(cast(sort_array(b.product_ownership_line_list) as string), 'na')
    = coalesce(cast(sort_array(c.product_ownership_line_list) as string), 'na')
  AND coalesce(b.reseller_type_name, 'na') = coalesce(c.reseller_type_name, 'na')
  AND b.customer_fraud_flag               = c.customer_fraud_flag
  AND coalesce(b.point_of_purchase_name, 'na') = coalesce(c.point_of_purchase_name, 'na')
  AND b.customer_acquisition_bill_fraud_flag = c.customer_acquisition_bill_fraud_flag
  AND coalesce(cast(sort_array(b.brand_name_list) as string), 'na')
    = coalesce(cast(sort_array(c.brand_name_list) as string), 'na')
```

**OSI note:** This is a self-join on the output of `customer_core_conformed.customer_life_cycle` (same source), not a cross-table join. The only upstream OSI relationship is `customer_core_conformed.customer_life_cycle` → `customer_core_conformed.customer_metric_daily_agg`.

---

### 6. COALESCE / Default Value Logic (Null Handling)

| Source Column | Default Value Applied |
|---|---|
| customer_type_reason_desc | `'Not Classified'` |
| customer_acquisition_mst_month | `''` (empty string) |
| customer_domestic_international_name | `'International'` |
| customer_region_1_name | `'International - RoW'` |
| customer_region_2_name | `'Rest of World (RoW)'` |
| customer_region_3_name | `'NA'` |
| customer_acquisition_country_name → customer_country_name | `'Unknown'` |
| customer_acquisition_country_code → customer_country_code | `'--'` |
| customer_type_name | `'Not Classified'` |
| customer_acquisition_channel_name → acquisition_channel_name | `'Not GA Attributed'` |
| customer_tenure_year_count | `0` |
| customer_fraud_flag | `false` |
| point_of_purchase_name | `'Unknown'` |
| customer_acquisition_bill_fraud_flag | `false` |

**Country code normalization:** `WHEN upper(customer_country_code) = 'UK' THEN 'GB'` (applied via `.withColumn` after aggregation)

---

### 7. DDL / Policy / DQ Files Consulted

| File | Path | Notes |
|---|---|---|
| PySpark DDL | `src/ddls/customer_metric_daily_agg.ddl` | Loaded at runtime by PySpark; authoritative in-repo schema |
| Hive source DDL | `src/ddls/customer_life_cycle.ddl` | Source table schema |
| Redshift create | `src/ddls/create_customer_metric_daily_agg.sql` | Redshift target (customer360 schema in prod) |
| Redshift create stg | `src/ddls/create_customer_metric_daily_agg_stg.sql` | Redshift staging table |
| Redshift insert | `src/ddls/insert_customer_metric_daily_agg.sql` | Delete + insert from stg; strips `[]` from array columns |
| Policy YAML | `src/policies/customer_metric_daily_agg_dag.yaml` | Declares inputs/outputs, SLA, orchestrator |
| Prod environment | `src/policies/environment.prod.yaml` | AWS accounts, Redshift ARN, Airflow cluster |
| DQ (local) | `src/data_quality/constraints/customer_metric_daily_agg.json` | isPrimaryKey check on all 19 dim columns |
| DQ (lake) | `src/data_quality/constraints/customer_metric_daily_agg_vw.json` | isPrimaryKey check on all 19 dim columns |
| Lake table YAML | `repos/lake/catalog/.../customer-metric-daily-agg-vw/table.yaml` | Owner, SLA, permissions, lineage |
| Lake table DDL | `repos/lake/catalog/.../customer-metric-daily-agg-vw/table.ddl` | Lake-registered schema |

---

### 8. Confluence Summary

**Page:** Customer360 (ID: 3779199819), https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3779199819/Customer360

**Key findings:**
- `customer_metric_daily_agg_vw` is described as the **Business Metrics Layer** — "business-ready metrics including Active Customers, 2+ Customers, Daily & Monthly customer metrics"
- Status: **✅ Completed**
- Replaces: No legacy deprecation specified for this table specifically
- Planned new feature: 🟡 "NRU and Lapsed users metrics co-existing with all externally reported metrics"

**Child page:** Customer360 Business Context Structure (ID: 4387965088)
- `customer_metric_daily_agg_vw` grain: "One row per date × reporting dimension combo"
- Data Product Schema: `customer360`; Domain: Customer; Organization: DNA
- Data Tier: 4
- OSI/OWL coverage for this table: Partially covered (15% weight in Customer360 coverage matrix)

---

### 9. Alation Section

**Table:** `customer360.customer_metric_daily_agg_vw`  
**Alation ID:** 7038346  
**Qualified name:** `AwsDataCatalog.customer360.customer_metric_daily_agg_vw`  
**Data source ID:** 81 (AWS Glue Data Catalog)  
**Num queries:** 0  

**Description (verbatim, cleaned):**  
> A daily aggregated metrics table providing summarized customer performance indicators. Key Features: Daily aggregation of customer metrics. [...column reference table...] Common Use Cases: Physical Model for Customer Lifecycle table which will act as driver for Customer Metrics requested by Finance. GitHub Repo: https://github.com/gdcorp-dna/dof-dpaas-customer-feature/blob/main/customer360/customer-metrics/src/dag/customer_metric_daily_agg_dag.py

**Custom fields:** All null (Business Context, Context Certification, Data Lake Owner Info, SLA, Tier, Technical Context — none populated)

**Saved queries referencing table:** 0 (num_queries = 0; no queries found in Alation for this table)

---

### 10. Conflicts / Discrepancies

| # | Location | Description | Resolution Needed |
|---|---|---|---|
| 1 | PySpark line 228 | PySpark reads `customer_core_conformed.customer_life_cycle` but a **commented-out** line references `customer360.customer_life_cycle_vw`. The DAG dependency sensor waits for `customer360/customer_life_cycle_vw` success file. | Code is authoritative: actual source is `customer_core_conformed.customer_life_cycle`. The success file dependency is a proxy signal for upstream readiness, not the actual read target. No change needed to semantic model. |
| 2 | Alation description | Alation uses `shopper_tenure_year_count` (stale name); code/DDL uses `customer_tenure_year_count` | Alation description is stale. Code/DDL is correct. |
| 3 | Alation description | Alation uses `churned_customer_qty` and `reactivated_customer_qty`; code/DDL uses `churn_customer_qty` and `reactivate_customer_qty` | Alation description is stale. Code/DDL is correct. |
| 4 | Lake DDL vs in-repo DDL | Lake DDL (`table.ddl`) **omits** `data_source_enum` column. In-repo DDL and PySpark `conform_datatype()` both output `data_source_enum` (hardcoded `'customer360'`). | In-repo DDL and PySpark are authoritative. Lake DDL needs update. |
| 5 | Lake DDL vs in-repo DDL | Lake DDL reorders `brand_name_list` (after `reseller_type_name`), `point_of_purchase_name`, and `customer_acquisition_bill_fraud_flag` (at end) vs in-repo DDL order. | Column ordering differs; in-repo DDL and PySpark `conform_datatype()` are authoritative for physical column order. |
| 6 | DAG dependency vs PySpark read | DAG waits for `customer360.customer_life_cycle_vw` success file before running, but PySpark reads `customer_core_conformed.customer_life_cycle` directly. These are two different registered tables (vw vs raw). | Confirm with team: does `customer_life_cycle` (raw) update in sync with `customer_life_cycle_vw` success file? This is likely intentional (success file gates on the vw, which has the same underlying data). |
| 7 | Policy YAML inputs | `customer_metric_daily_agg_dag.yaml` lists `customer360.customer_life_cycle_vw` as primary input, but PySpark reads `customer_core_conformed.customer_life_cycle`. | Pipeline policy YAML does not match code. Code is authoritative for lineage. |

---

### 11. Lake Metadata Summary

| Field | Value |
|---|---|
| Table name (lake) | `customer360.customer_metric_daily_agg_vw` |
| Table type | PARTITIONED |
| Storage format | Parquet |
| Partition key | `partition_eval_mst_date` (string) |
| S3 relative path | `customer_metric_daily_agg` |
| Data tier | 4 |
| SLA (lake) | Delivered by 08:00 AM MST (`cron(00 15 * * ? *)` UTC) |
| Upstream dependency (lake lineage) | `customer360.customer_life_cycle_vw` |
| Permissions | analytics.prod, martech_data, revenue_and_relevance, data_platform, data_lab, ckpetlbatch |

---

*Gathered by: Data Governance Gather agent — 2026-06-05*

**The agent's final response to the user was:**
The gather.md has been appended with 346 lines of structured findings. Here is a summary of what was researched and documented:

---

## Research Summary

### Sources Checked

1. **PySpark script** (`customer_metric_daily_agg.py`) — fully read; all SQL, aggregations, joins, null-handling, and output schema extracted
2. **DAG** (`customer_metric_daily_agg_dag.py`) — fully read; schedule, dependencies, task flow, Redshift targets, SLA, and tags extracted
3. **In-repo DDL** (`customer_metric_daily_agg.ddl`, `customer_life_cycle.ddl`, Redshift DDLs) — all read
4. **Data Quality constraints** — both `customer_metric_daily_agg.json` and `customer_metric_daily_agg_vw.json` read; both enforce 19-column composite primary key
5. **Policy YAML** — `customer_metric_daily_agg_dag.yaml` and `environment.prod.yaml` read
6. **Lake DDL & YAML** — `repos/lake/catalog/.../customer-metric-daily-agg-vw/table.ddl` and `.yaml` read
7. **Confluence** — Parent page (ID 3779199819) and child page "Business Context Structure" (ID 4387965088) fetched via REST API
8. **Alation** — API token created from refresh token; table ID 7038346 (`customer360.customer_metric_daily_agg_vw`) found and inspected; 0 saved queries

### Key Findings

- **Write target**: `customer_core_conformed.customer_metric_daily_agg` (Hive/Parquet); surfaced as `customer360.customer_metric_daily_agg_vw` in the Data Lake
- **Source**: `customer_core_conformed.customer_life_cycle` (the `customer360.customer_life_cycle_vw` reference is commented out in the PySpark)
- **Schedule**: Daily at 7:30 AM MST (`30 7 * * *`)
- **Grain**: One row per date × 18-dimension combination (19-column composite PK)
- **Aggregations**: SUM(ttm_gcr_usd_amt), COUNT_IF for ending/churn/merge/new/reactivate customers; LAG-based beginning_customer_qty; 3 derived metrics (net_move, net_add, net_churn)
- **7 conflicts/discrepancies** documented, including stale Alation column names, missing `data_source_enum` in Lake DDL, and PySpark read source differing from policy YAML and DAG dependency declaration