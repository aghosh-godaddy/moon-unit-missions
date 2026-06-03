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

## Stage: gather — customer_life_cycle (customer360)
**Gathered:** 2026-06-03

---

### 1. PySpark Job Identity

| Field | Value |
|---|---|
| Repo URL | https://github.com/gdcorp-dna/dof-dpaas-customer-feature.git |
| Git ref | main (pulled; was 5 commits behind origin at time of run) |
| File path | `customer360/customer-metrics/src/pyspark/customer_life_cycle.py` |
| Feed name constant | `FEED_NAME = "customer_life_cycle"` |
| Author / initial date | aghosh, 2025-10-31 |
| Spark app name | `customer_life_cycle` |
| Write mode | `insertInto(overwrite=True)` per partition, then `MSCK REPAIR TABLE` |

**Primary write target (data lake internal):**
- Hive/Glue table: `customer_core_conformed.customer_life_cycle`
- S3 location: `s3://gd-ckpetlbatch-{AWS_ENV}-customer-core-conformed/customer_core_conformed/customer_life_cycle/`
- Partition key: `partition_eval_mst_date` (string)
- Format: Parquet, zstd compression, 30 output partitions

**Secondary write targets (via DAG post-EMR steps):**
- Lake view: `customer360.customer_life_cycle_vw` (SuccessNotificationOperator, prod only)
- Redshift staging: `{REDSHIFT_DATABASE_STG}.customer_life_cycle_vw_stg` (S3 COPY from Parquet)
- Redshift final: `customer360.customer_life_cycle` (SQL INSERT from staging)

---

### 2. DAG Identity

| Field | Value |
|---|---|
| DAG file | `customer360/customer-metrics/src/dag/customer_life_cycle_dag.py` |
| DAG ID | `customer-life-cycle` |
| Schedule | `"20 7 * * *"` — 7:20 AM MST daily (prod/stage only; None for dev-private) |
| Start date | 2026-01-01 (America/Phoenix timezone) |
| Catchup | False |
| Max active runs | 15 |
| Owner | `customer360` |
| On-call Slack | `#marketing-data-product-engineering` |
| On-call Email | `dl-bi-enterprise-data@godaddy.com` |
| Alert Slack | `#edt-airflow-alerts` (prod) / `#edt-airflow-alerts-low-priority` (others) |
| Tags | domain:customer, sub-domain:active-customer, layer:enterprise, team:EDT, pipeline-group:active-customer, special:daily |
| EMR version | emr-7.10.0, Iceberg runtime jar included |
| EMR master | m6g.xlarge |
| EMR core | m6g.16xlarge × 15 nodes |
| Runtime param | `eval_mst_date` (YYYY-MM-DD, passed via DAG config) |
| Spark config (fallback) | executor.memory=16G, cores=4, memOverhead=512, driver.memory=4G, driver.cores=2, maxExecutors=10 |

**DAG task flow (abridged):**
`dag_config` → `dependencies` (S3KeySensor for 14 upstream tables) → `create_redshift_tables` → `create_emr` → `run_customer_life_cycle` → `remove_emr` → `dq_check_customer_life_cycle_local` → `conditional_call_lake_api` → `[call_lake_api | skip_call_lake_api]` → `s3_to_redshift_customer_life_cycle_stg` → `insert_customer_life_cycle` → `check_for_failure_branch` → `[succeed_dag_run | fail_dag_run]`

**S3 dependency success-file path pattern** (waiting before run):
`s3://gd-{team}-{env}-success-files/local_process/customer_core_conformed/{table}/{YYYY/MM/DD}/_SUCCESS`
and
`s3://gd-{team}-{env}-success-files/{db}/{table}/{YYYY/MM/DD}/_SUCCESS`

---

### 3. Source Tables Inventory (all READ)

All table references are resolved from `get_tables(aws_env)` which switches schema prefix (`enterprise_linked`/`enterprise`, `dp_enterprise_linked`/`dp_enterprise`) by environment.

| # | Logical key | Resolved table (prod) | Join key(s) | Notes |
|---|---|---|---|---|
| 1 | `analytic_feature__shopper_acquisition` | `analytic_feature.shopper_acquisition` | `bill_shopper_id → shopper_id`, `shopper_id` | Fraud flag, acq bill |
| 2 | `analytic_feature__customer_type_history` | `analytic_feature.customer_type_history` | `shopper_id` | Date-filtered: `record_start ≤ eval_date ≤ record_end` |
| 3 | `customer360__dim_customer_history_vw` | `customer360.dim_customer_history_vw` | `shopper_id` | Used to get `private_label_id` (SCD2, date-filtered) |
| 4 | `finance360__dim_country_vw` | `finance360.dim_country_vw` | `acq.bill_country_code = geo.country_code AND geo.current_record_flag = true` | BROADCAST hint |
| 5 | `dp_enterprise__dim_reseller` | `dp_enterprise.dim_reseller` | `private_label_id` | BROADCAST hint in final join |
| 6 | `enterprise_dim_new_acquisition_shopper` | `enterprise.dim_new_acquisition_shopper` | `bill_shopper_id = shopper_id` | Acquisition bill, date, country |
| 7 | `enterprise__dim_subscription_history` | `enterprise.dim_subscription_history` | `shopper_id` | First subscription by `subscription_create_mst_date ASC` (row_number=1) |
| 8 | `ecomm_mart_bill_line_traffic_ext` | `ecomm_mart.bill_line_traffic_ext` | `original_shopper_id → shopper_id` | channel_grouping_name; filtered `bill_modified_mst_date ≤ eval_date` |
| 9 | `ecomm_mart__dim_bill_line_purchase_attribution` | `ecomm_mart.dim_bill_line_purchase_attribution` | `bill_id` | point_of_purchase_name; latest record per bill_id by bill_line_num |
| 10 | `finance360__dim_bill_fraud_history_vw` | `finance360.dim_bill_fraud_history_vw` | `bill_id` | SELECT DISTINCT bill_id |
| 11 | `customer360__customer_ttm_payment_driver` | `customer_core_conformed.customer_ttm_payment_driver` | `shopper_id`, `customer_id` | Internal driver table; TTM window |
| 12 | `customer360__customer_active_subscription_detail_driver` | `customer_core_conformed.customer_active_subscription_detail_driver` | `subscription_shopper_id → shopper_id`, `subscription_customer_id → customer_id` | Internal driver; active paid subscriptions |
| 13 | `customer360__active_customer` | `customer_core_conformed.active_customer_stg` | `shopper_id` | Determines active/churned status |
| 14 | `analytic_feature__customer_fraud` | `analytic_feature.customer_fraud` | `shopper_id`, `customer_id` | Fraud flag and dates |
| 15 | `analytic_feature__shopper_merge` | `analytic_feature.shopper_merge` | `original_shopper_id` | Date-filtered: `start ≤ eval_date ≤ end` |
| 16 | *(legacy, hardcoded S3)* | `s3://gd-ckpetlbatch-prod-analytic/analytic/ads_bill_line_ext/` | `original_shopper_id`, `bill_id`, `new_acquisition_bill_id` | Legacy channel data pre-2022-08; hardcoded prod S3 path |

---

### 4. Destination Table — Column Schema

**Table:** `customer_core_conformed.customer_life_cycle` (internal)
**Lake view:** `customer360.customer_life_cycle_vw`
**DDL source:** `customer360/customer-metrics/src/ddls/customer_life_cycle.ddl` + lake repo `catalog/config/prod/dlms-api/us-west-2/customer360/customer-life-cycle-vw/table.ddl`

| Column | Type | Description |
|---|---|---|
| shopper_id | string | PK: Unique numeric ID for shopper profile |
| customer_id | string | PK: Unique UUID representing customer entity |
| customer_acquisition_bill_id | string | Bill ID triggering first net positive status (FK → shopper_acquisition) |
| customer_acquisition_mst_date | date | Date of first net positive bill (MST) |
| customer_acquisition_mst_month | string | Acquisition month truncated to month (TRUNC to MONTH) |
| customer_acquisition_country_code | string | Country code at acquisition (UK normalized to GB) |
| customer_acquisition_channel_name | string | Channel name at acquisition |
| customer_tenure_year_count | int | `datediff(eval_date, acq_date) / 365` cast to int |
| customer_acquisition_country_name | string | Country name at acquisition |
| customer_region_1_name | string | Geographic region 1 |
| customer_region_2_name | string | Geographic region 2 |
| customer_region_3_name | string | Geographic region 3 |
| customer_domestic_international_name | string | Domestic vs. international indicator |
| reseller_type_id | int | FK → dp_enterprise.dim_reseller |
| reseller_type_name | string | Reseller name |
| customer_type_name | string | Customer type at eval date; overridden to '123 Reg' if private_label_id=587240 |
| customer_type_reason_desc | string | Customer type reason; overridden to '123 Reg' for 123Reg shoppers |
| customer_fraud_flag | boolean | True if customer flagged as fraud at eval date |
| active_paid_subscription_list | array<string> | COLLECT_SET of subscription_id (active, finance-payable) |
| product_pnl_category_list | array<string> | COLLECT_SET of product_pnl_category |
| product_pnl_category_qty | int | COUNT(DISTINCT product_pnl_category) |
| product_pnl_line_list | array<string> | COLLECT_SET of product_pnl_line |
| ttm_all_bill_list | array<string> | COLLECT_SET of last_net_positive_bill_id (TTM) |
| brand_name_list | array<string> | SORT_ARRAY(ARRAY_UNION(subscription brands, TTM brands)) |
| ttm_gcr_usd_amt | decimal(18,2) | SUM(ttm_total_gcr_usd_amt) for TTM window; excludes trxn_currency_code='N/A' |
| customer_churn_mst_date | date | Eval date when churned (if status='churned' and not merged); also set for intraday |
| customer_reactivate_mst_date | date | Eval date when status='new' AND acq_date < eval_date |
| customer_merge_mst_date | date | shopper_merge_start_mst_date (if churned and merged) |
| customer_fraud_mst_date | date | fraud_flag_mst_date from customer_fraud (if not reinstated and acq_fraud_flag=true) |
| customer_state_enum | string | Enum: intraday → merged → churned → reactivated → new → active |
| active_status_flag | boolean | True if customer_status NOT IN ('churned', 'intraday') |
| point_of_purchase_name | string | From dim_bill_line_purchase_attribution for acquisition bill |
| customer_acquisition_bill_fraud_flag | boolean | True if acquisition bill exists in dim_bill_fraud_history_vw |
| etl_build_mst_ts | timestamp | `from_utc_timestamp(current_timestamp(), 'MST')` |
| **partition_eval_mst_date** | string | Partition key: evaluation date (YYYY-MM-DD) |

---

### 5. Grain

**One row per (shopper_id, partition_eval_mst_date)**

DQ constraint (data_quality/constraints/customer_life_cycle.json):
```json
{ "code": ".isPrimaryKey(\"partition_eval_mst_date\", \"shopper_id\")", "enabled": "true" }
```

Business grain from Confluence: "One row per customer per eval date" (using `customer_id` as PK in lake DDL, `shopper_id` as unique key).

---

### 6. Join Conditions (Explicit — from PySpark)

**Inner assembly joins (get_combined_customer_life_cycle_df, all LEFT JOIN):**
1. `ac.shopper_id = acq.shopper_id` → `combined_customer_base` ↔ `shopper_acquisition`
2. `ac.shopper_id = ss.shopper_id` → `combined_customer_base` ↔ `shopper_subscription`
3. `ac.shopper_id = pl.shopper_id` → `combined_customer_base` ↔ `private_label`
4. `ac.shopper_id = ct.shopper_id` → `combined_customer_base` ↔ `customer_type_history`
5. `ac.shopper_id = gd.shopper_id` → `combined_customer_base` ↔ `reg123_shopper`
6. `ac.shopper_id = blt.shopper_id` → `combined_customer_base` ↔ `combined_bill_line`
7. `ac.shopper_id = sm.original_shopper_id` → `combined_customer_base` ↔ `shopper_merge`
8. `ac.shopper_id = cf.shopper_id AND ac.customer_id = cf.customer_id` → ↔ `customer_fraud`
9. `pop.bill_id = COALESCE(acq.bill_id, ss.original_bill_id)` (conditional on status new/intraday) → ↔ `point_of_purchase`
10. `bf.bill_id = COALESCE(acq.bill_id, ss.original_bill_id)` (same condition) → ↔ `bill_fraud`

**Reseller sub-query (get_reseller_df):**
11. `date_filtered df FULL OUTER JOIN latest_record lr ON df.shopper_id = lr.shopper_id` → `customer360.dim_customer_history_vw` self-join to get current private_label_id
12. `combined c LEFT JOIN dim_reseller res ON c.private_label_id = res.private_label_id` → BROADCAST hint

**Acquisition sub-query (get_shopper_acquisition_df):**
13. `acq.bill_shopper_id = sa.shopper_id` → `dim_new_acquisition_shopper` ↔ `shopper_acquisition_source` (BROADCAST hint)
14. `acq.bill_country_code = geo.country_code AND geo.current_record_flag = true` → ↔ `finance360.dim_country_vw` (BROADCAST hint)

**Customer base assembly (get_combined_customer_base_df):**
15. `ac.shopper_id = sd.shopper_id AND COALESCE(ac.customer_id,'na') = COALESCE(sd.customer_id,'na')` → active_customer ↔ subscription_detail
16. `ac.shopper_id = ttm.shopper_id AND COALESCE(ac.customer_id,'na') = COALESCE(ttm.customer_id,'na')` → active_customer ↔ ttm_payment

**Intraday filter (get_intraday_subscription_detail_df):**
17. `acq.bill_shopper_id = isd.shopper_id` + `acq.new_acquisition_bill_mst_date = eval_date` → filter for intraday new shoppers
18. `isd.shopper_id = ac.shopper_id` (LEFT + WHERE ac.shopper_id IS NULL) → exclude already-active shoppers

---

### 7. Aggregation Expressions

| Expression | Source table | Output column |
|---|---|---|
| `SUM(ttm_total_gcr_usd_amt)` | `customer_ttm_payment_driver` (WHERE trxn_currency_code <> 'N/A' AND net_positive_ttm_payment_flag = true) | `ttm_gcr_usd_amt` |
| `COLLECT_SET(last_net_positive_bill_id)` | `customer_ttm_payment_driver` | `ttm_all_bill_list` |
| `COLLECT_SET(brand_name)` | `customer_ttm_payment_driver` + `customer_active_subscription_detail_driver` (ARRAY_UNION) | `brand_name_list` |
| `COUNT(DISTINCT product_pnl_category)` | `customer_active_subscription_detail_driver` | `product_pnl_category_qty` |
| `COLLECT_SET(product_pnl_category)` | `customer_active_subscription_detail_driver` | `product_pnl_category_list` |
| `COLLECT_SET(product_pnl_line)` | `customer_active_subscription_detail_driver` | `product_pnl_line_list` |
| `COLLECT_SET(subscription_id)` | `customer_active_subscription_detail_driver` | `active_paid_subscription_list` |
| `MAX(CASE WHEN partition_eval_mst_date = T THEN 1 ELSE 0 END)` | `active_customer_stg` | customer_status derivation |
| `MAX(STRUCT(effective_end_mst_ts, private_label_id)).private_label_id` | `dim_customer_history_vw` | private_label_id selection |
| `MIN(reseller_type_id), MIN(reseller_type_name)` | `dp_enterprise.dim_reseller` | dedup per private_label_id |
| `ROW_NUMBER() OVER(PARTITION BY shopper_id ORDER BY subscription_create_mst_date ASC)` | `enterprise.dim_subscription_history` | first subscription record |
| `ROW_NUMBER() OVER(PARTITION BY bill_id ORDER BY bill_line_num DESC)` | `ecomm_mart.dim_bill_line_purchase_attribution` | latest record per bill |
| `TRUNC(customer_acquisition_mst_date, 'MONTH')` | derived | `customer_acquisition_mst_month` |
| `DATEDIFF(eval_date, acq_date) / 365` | derived | `customer_tenure_year_count` |
| `GROUP BY eval_date, shopper_id, customer_id` | subscription_detail / ttm / intraday | all collect_set aggregations |

---

### 8. DDL / Policy / DQ Files Consulted

| File | Location | Notes |
|---|---|---|
| `customer_life_cycle.ddl` | `src/ddls/customer_life_cycle.ddl` | 34 columns + 1 partition; Parquet; S3 location template uses `{DATABASE_NAME}` and `{AWS_ENV}` |
| `customer_life_cycle_dag.yaml` (policy) | `src/policies/customer_life_cycle_dag.yaml` | Lists 17 input sources; 2 output targets; SLA: 120 min, TIER_4 |
| `customer_life_cycle.json` (DQ constraints) | `src/data_quality/constraints/customer_life_cycle.json` | Primary key check: (partition_eval_mst_date, shopper_id) |
| `table.yaml` (lake) | `repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/customer-life-cycle-vw/table.yaml` | SLA cron `00 15 * * ? *`, data_tier: 4, permissions list |
| `table.ddl` (lake) | `repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/customer-life-cycle-vw/table.ddl` | Canonical column list for lake view; notes FK references |

---

### 9. Confluence Summary

**Page:** Customer360 (ID 3779199819) → Design Docs → Customer Lifecycle (ID 3970861345)

Key findings from **Customer Lifecycle** design doc:
- Physical model designed as driver for Customer Metrics requested by Finance
- Customer defined by (customer_id, shopper_id) pair from shopper_status_v2 → active_customer
- Churned: user turns from Paid to Free trial, or service lapses
- Acquisition logic: case 1 (new customer, future acq date → use subscription_create_mst_date or eval_date); case 2 (existing customer, acq not in past → NULL)
- `customer_tenure_year_count` = shopper_tenure_days_count / 365

**Business Context page (ID 4387965088):**
- Dataset: `customer_life_cycle_vw` — Type: PARTITIONED, Tier: 4, Grain: one row per customer per eval date
- `customer_life_cycle_vw` is **primary OSI and OWL target** in C360 domain (35% weight)
- Domain: Customer, Org: DNA
- Stakeholders: Finance (Business Stewards), Marketing, DAP (Business Stewards), FORGE (Data Products PgM)

---

### 10. Alation Section

**Table found:** `customer_life_cycle_vw` (AwsDataCatalog.customer360)
- Alation table ID: 7038345
- Connector: Athena
- Auto-title confidence: HIGH_CONFIDENCE

**Description (from Alation):**
> A comprehensive snapshot table that tracks the complete lifecycle journey of customers from acquisition through various lifecycle states. This table captures daily snapshots of customer status, enabling analysis of state transitions, and changes between consecutive evaluation periods.
>
> **Key Features:** Lifecycle tracking (acquisition, churn, reactivation, merge, fraud) · Active subscription product tracking · Multi-dimensional state tracking through Foreign Keys · Trailing twelve month (TTM) GCR

**Column data types in Alation** (note discrepancy — see §11):
- `customer_tenure_year_count` described as `string` in Alation vs `int` in code/DDL

**Saved queries (5 retrieved, table_id=7038345):**
| Query ID | Author | Title | SQL |
|---|---|---|---|
| 1 | Sharon Graves (shgraves@godaddy.com) | *(empty)* | *(empty — content not available via API)* |
| 27 | Michael Valeri (mvaleri@godaddy.com) | *(empty)* | *(empty)* |
| 130 | Sharon Graves | *(empty)* | *(empty)* |
| 226 | Daniel Vargo (dvargo@godaddy.com) | *(empty)* | *(empty)* |
| 324 | Douglas Diamant (ddiamant@godaddy.com) | *(empty)* | *(empty)* |

*Note: Alation API returned query stubs with no title/SQL content. Content field was empty for all 5. Likely private or unpublished queries.*

---

### 11. Conflicts / Discrepancies

| # | Item | Source A | Source B | Notes |
|---|---|---|---|---|
| 1 | **DDL comment — PK** | `customer_life_cycle.ddl` header says "Primary Key: resource_id, product_family_name, entitlement_addon_id, partition_eval_mst_date" | Code / DQ constraint use `(partition_eval_mst_date, shopper_id)` as PK | Header is copy-paste from another table (active_customer driver). Code is correct. |
| 2 | **Policy YAML — duplicate input** | `customer_life_cycle_dag.yaml` lists `finance360.dim_bill_fraud_history_vw` twice (lines 90-97 as parquet, lines 106-113 as iceberg) | Code reads the table once | Duplicate entry in policy yaml; format disagreement (parquet vs iceberg). Not a functional issue. |
| 3 | **Lake lineage — extra upstream tables** | `table.yaml` lineage includes: `customers.customer_id_mapping_snapshot`, `ecomm_mart.entitlement_bill_type`, `enterprise.dim_bill_shopper_id_xref`, `enterprise.dim_entitlement_history`, `enterprise.fact_bill_line`, `enterprise.fact_entitlement_bill`, `finance360.dim_product_vw`, `finance_cln.manual_paid_subscription` | Current PySpark does not reference these tables | Lineage yaml appears to reflect prior/broader pipeline history. Should be validated and cleaned up. |
| 4 | **Alation — customer_tenure_year_count type** | Alation description shows `customer_tenure_year_count` as `string` | DDL and PySpark cast to `int` | Alation stale / incorrect. Code is authoritative. |
| 5 | **DAG doc — SLA** | DAG documentation_markdown says `SLA: N/A` | Policy yaml says `maxDurationMins: 120, severity: TIER_4`; lake yaml SLA cron `00 15 * * ? *` | Documentation is incomplete. Policy yaml and lake yaml are more authoritative. |
| 6 | **Legacy S3 path hardcoded** | PySpark reads `s3://gd-ckpetlbatch-prod-analytic/analytic/ads_bill_line_ext/` directly | All other tables use the environment-parameterized `get_tables(aws_env)` helper | This hardcodes prod S3. Non-prod runs will read prod data for legacy acquisition channel. Potential data governance concern. |
| 7 | **customer_state_enum logic — 'intraday' churn date** | customer_churn_mst_date is set for `customer_status = 'intraday'` in code | customer_state_enum for intraday is explicitly 'intraday' (not 'churned') | Intraday customers get both churn date set AND state 'intraday'. Intentional by design but may confuse consumers. |


**The agent's final response to the user was:**
Here is a summary of everything I researched and documented for the `customer_life_cycle` data governance gather stage:

---

## What was gathered

**Source code verified** (git ref: `main`, pulled to latest):
- PySpark script: `customer360/customer-metrics/src/pyspark/customer_life_cycle.py` (1,098 lines, authored aghosh 2025-10-31)
- DAG: `customer360/customer-metrics/src/dag/customer_life_cycle_dag.py`

**Write targets confirmed from code:**
1. **Primary (S3/Hive):** `customer_core_conformed.customer_life_cycle` — partitioned Parquet at `s3://gd-ckpetlbatch-{env}-customer-core-conformed/customer_core_conformed/customer_life_cycle/`
2. **Lake view (prod only):** `customer360.customer_life_cycle_vw` via SuccessNotificationOperator
3. **Redshift:** `customer360.customer_life_cycle` via S3 COPY through staging table

**Schedule:** `20 7 * * *` (7:20 AM MST daily), SLA delivery by 08:00 AM MST, data_tier: 4, TIER_4 severity

**16 source tables** enumerated with join keys, including 15 Hive/S3 tables plus one legacy hardcoded S3 path (`gd-ckpetlbatch-prod-analytic/analytic/ads_bill_line_ext/`)

**34 columns + 1 partition key** fully documented with types and derivation logic

**18 explicit join conditions** extracted, including BROADCAST hints

**All aggregation patterns** documented (COLLECT_SET, SUM(ttm_gcr), COUNT(DISTINCT), ROW_NUMBER, MAX(STRUCT(...)))

**Grain:** One row per `(shopper_id, partition_eval_mst_date)` — confirmed by DQ primary key constraint

**7 conflicts/discrepancies** recorded including a stale PK comment in DDL, duplicate policy yaml entry, stale Alation type, and a hardcoded prod S3 path that bypasses environment parameterization.