**Stage name:** analyze
**The coding agent was given these instructions:** You are a Data Engineering + Data Governance analyst. Your job is to resolve lineage
from the PySpark job to the authoritative Data Lake table, and extract only accurate,
evidence-backed metadata.

## Step 1: Read INPUT.md and gather.md
- Read `INPUT.md` and the previous stage output `gather.md`.

## Step 2: Identify the target table
Determine the final output lake table populated by this PySpark job.
- Prefer direct evidence in code: table write targets, create/insert statements,
  saveAsTable targets, Glue catalog writes, Athena CTAS, etc.
- If `lake_table_override` is provided in INPUT.md, use it only if it does not
  contradict the code; otherwise flag the conflict.
- If multiple outputs exist, list them. Identify the “primary” one if possible.

## Step 3: Deep lineage resolution — MANDATORY for EVERY source table

The PySpark script references upstream tables. Some are lake tables (in `repos/lake/`),
but many are **local/intermediate tables** (e.g., `customer_core_conformed.*`,
`analytic_local.*`, `*_stg`) that are built by OTHER PySpark scripts in the SAME repo.

**You MUST recursively trace EACH source table to its lake origin. Do NOT stop at
intermediate tables. They are implementation details, not authoritative sources.**

For EACH table referenced in the target PySpark:

1. **Check if it exists as a lake table**: search `repos/lake/catalog/config/prod/` for it.
   Try both `us-west-2/<schema>/<table-hyphenated>/` and `dlms-api/us-west-2/<schema>/<table-hyphenated>/`.
   Convert underscores to hyphens when searching lake paths.

2. **If it IS a lake table** -> record it as the authoritative source. Read its `table.yaml`
   and `table.ddl`. Done for this table.

3. **If it is NOT a lake table** (local/intermediate) — you MUST trace upstream:
   a. Search the source repo for the PySpark script that BUILDS this intermediate table.
      Use `grep -r "<table_name>" repos/<source-repo>/` to find references.
      Look for `insertInto`, `saveAsTable`, `CREATE TABLE`, or write operations targeting it.
   b. Read that upstream PySpark script.
   c. Identify what tables IT reads from.
   d. For each of THOSE tables, repeat from step 1 (recursive traversal).
   e. Continue until you reach a lake table or an external system (S3 direct read, API, etc.).

4. **If traversal fails** (cannot find the upstream script, or it reads from an unknown source):
   Record: `UNRESOLVED: <table_name> — <what you searched and why it failed>`

**CRITICAL RULE FOR C1 (Column Reference):**
The "Source Table(s)" column in C1 must show the FINAL lake table (or external system),
NOT intermediate/local tables. For example:
- BAD:  `customer_core_conformed.active_customer_stg`  (this is an intermediate table)
- GOOD: `enterprise.dim_subscription` (this is the lake table that feeds active_customer_stg)
- GOOD: `UNRESOLVED — requires manual input` (if traversal failed)

If a column aggregates data from multiple lake sources through an intermediate table,
list all the lake sources that contribute.

## Step 4: Read lake registry artifacts for ALL resolved upstream tables
For EACH lake table discovered during lineage traversal (not just the target), read:
- `table.ddl` — authoritative schema with column names and types
- `table.yaml` — lineage metadata, consumer groups, SLA info

Build a column-level mapping: `target_column -> intermediate_table.column -> lake_table.column`

## Step 5: Derive analysis outputs (no guessing)
Derive the following, strictly from code + resolved lake artifacts:
- Grain: what one row represents
- Keys: primary key / unique key strategy (or explicitly "no PK" + dedup guidance)
- Partitions and recommended always-filter columns
- Always-on filters embedded in ETL (non-overridable scope restrictions)
- Common business metrics computed in the ETL (name + definition + grain)
- **Column-level lineage** (CRITICAL): for EACH column in the target table, trace it
  to its ultimate lake source table and column. If the column is computed/derived,
  note the formula AND the lake source columns feeding it. If lineage cannot be
  fully resolved after recursive traversal, mark it as UNRESOLVED.
- SLA/refresh schedule from the DAG (cron, dependencies, expected latency)

## Step 6: Output (append to analyze.md)
Append:
- Target table resolution (with evidence and any overrides)
- **Full lineage resolution table** showing for each intermediate table:
  | Intermediate Table | Resolved To (Lake Table) | Resolution Method |
  Include UNRESOLVED entries with explanation of what was searched.
- Column-level lineage mapping (target_column -> lake_table.column) for all columns
- A structured "facts" block for each of the 20 sections (A1..E3) listing
  what can be filled and what is missing
- A "Do not claim" list: items that are tempting but not proven

## Step 7: Write resolved-target machine output (required)
Create a JSON file in the workspace root named `RESOLVED_TARGET.json` with:
- schema: string (e.g., "enterprise")
- table_hyphen: string (e.g., "payment-cogs-audit")
- table_underscore: string (e.g., "payment_cogs_audit")
- lake_table_path: string|null (e.g., "enterprise/payment-cogs-audit")
- confidence: "high"|"medium"|"low"
- evidence: array of short strings (file/line references)
If the target cannot be resolved, still write the file with nulls and a clear explanation in evidence.

**The agent summarized its work in this way:**

---

## Analyze Stage Report — customer_life_cycle

**Generated:** 2026-05-28
**Target identifier:** customer360 / customer-life-cycle
**Analysis basis:** PySpark + DAG (code wins), with recursive lineage traversal

---

## Step 2: Target Table Resolution

| Field | Value | Evidence |
|---|---|---|
| Internal landing table | `customer_core_conformed.customer_life_cycle` | `customer_life_cycle.py` L29-31: `DATABASE_NAME="customer_core_conformed"`, `TABLE_NAME="customer_life_cycle"`; L1083: `insertInto(QUALIFIED_TABLE_NAME, overwrite=True)` |
| **Public lake table (authoritative)** | **`customer360.customer_life_cycle_vw`** | DAG task `call_lake_api` (SuccessNotificationOperator); DQ constraint file `customer_life_cycle_vw.json`; lake catalog: `repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/customer-life-cycle-vw/table.yaml` |
| Lake catalog path | `catalog/config/prod/dlms-api/us-west-2/customer360/customer-life-cycle-vw/` | Direct directory listing |
| Redshift replica | `customer360.customer_life_cycle_vw` (from staging `customer_core_conformed_prod.customer_life_cycle_vw_stg`) | DAG tasks: `s3_to_redshift_customer_life_cycle_stg` → `insert_customer_life_cycle` |
| Lake table override in INPUT.md | (empty) | No conflict to flag |

**No lake_table_override provided.** Code unambiguously identifies `customer360.customer_life_cycle_vw` as the lake output.

---

## Step 3: Full Lineage Resolution Table

### Intermediate Tables Directly Referenced in target PySpark

| Intermediate Table | Built By (PySpark Script) | Resolved Lake Sources |
|---|---|---|
| `customer_core_conformed.customer_ttm_payment_driver` | `customer360/active-customer-drivers/src/pyspark/customer_ttm_payment_driver.py` | `enterprise.fact_bill_line`, `enterprise.dim_bill_shopper_id_xref`, `customer360.dim_customer_history_vw`, `customers.customer_id_mapping_snapshot` |
| `customer_core_conformed.customer_active_subscription_detail_driver` | `customer360/active-customer-drivers/src/pyspark/customer_active_subscription_detail_driver.py` | `enterprise.dim_subscription_history`, `enterprise.dim_entitlement_history`, `customer360.dim_customer_history_vw`, `finance360.dim_product_vw`, `enterprise.fact_bill_line`, `enterprise.fact_entitlement_bill`, `ecomm_mart.entitlement_bill_type`, `enterprise.dim_bill_shopper_id_xref`, `finance_cln.manual_paid_subscription` |
| `customer_core_conformed.active_customer_stg` | `customer360/active-customer/src/pyspark/active_customer_stg.py` | Reads from `customer_core_conformed.customer_active_subscription_detail_driver` + `customer_core_conformed.customer_ttm_payment_driver` + `customer_core_conformed.subscription_grace_policy` (see below) |
| `customer_core_conformed.subscription_grace_policy` | `customer360/subscription-grace-policy/src/pyspark/subscription_grace_policy.py` | `enterprise.dim_subscription_history`, `enterprise.dim_entitlement_history`, `customer360.dim_customer_history_vw`, `finance360.dim_product_vw` |

### Full Lineage Resolution — All Tables

| Intermediate Table | Resolved To (Lake Table) | Resolution Method |
|---|---|---|
| `customer_core_conformed.customer_ttm_payment_driver` | `enterprise.fact_bill_line`, `enterprise.dim_bill_shopper_id_xref`, `customer360.dim_customer_history_vw`, `customers.customer_id_mapping_snapshot` | Read `customer_ttm_payment_driver.py`; all sources confirmed in lake catalog `us-west-2/enterprise/` and `dlms-api/us-west-2/customer360/`, `us-west-2/customers/` |
| `customer_core_conformed.customer_active_subscription_detail_driver` | `enterprise.dim_subscription_history`, `enterprise.dim_entitlement_history`, `customer360.dim_customer_history_vw`, `finance360.dim_product_vw`, `enterprise.fact_bill_line`, `enterprise.fact_entitlement_bill`, `ecomm_mart.entitlement_bill_type`, `enterprise.dim_bill_shopper_id_xref`, `finance_cln.manual_paid_subscription` | Read `customer_active_subscription_detail_driver.py`; all confirmed in lake catalog |
| `customer_core_conformed.active_customer_stg` | Inherits from `customer_active_subscription_detail_driver` + `customer_ttm_payment_driver` + `subscription_grace_policy` above | Read `active_customer_stg.py` |
| `customer_core_conformed.subscription_grace_policy` | `enterprise.dim_subscription_history`, `enterprise.dim_entitlement_history`, `customer360.dim_customer_history_vw`, `finance360.dim_product_vw` | Read `subscription_grace_policy.py` |
| `analytic_feature.shopper_acquisition` | **LAKE TABLE** — `us-west-2/analytic-feature/shopper-acquisition/` | Direct lake catalog lookup |
| `analytic_feature.customer_type_history` | **LAKE TABLE** — `us-west-2/analytic-feature/customer-type-history/` | Direct lake catalog lookup |
| `customer360.dim_customer_history_vw` | **LAKE TABLE** — `dlms-api/us-west-2/customer360/dim-customer-history-vw/` | Direct lake catalog lookup |
| `finance360.dim_country_vw` | **LAKE TABLE** — `dlms-api/us-west-2/finance360/dim-country-vw/` | Direct lake catalog lookup |
| `dp_enterprise.dim_reseller` | **LAKE TABLE** — `us-west-2/dp-enterprise/dim-reseller/` | Direct lake catalog lookup |
| `enterprise.dim_new_acquisition_shopper` | **LAKE TABLE** — `us-west-2/enterprise/dim-new-acquisition-shopper/` | Direct lake catalog lookup |
| `enterprise.dim_subscription_history` | **LAKE TABLE** — `us-west-2/enterprise/dim-subscription-history/` | Direct lake catalog lookup |
| `ecomm_mart.bill_line_traffic_ext` | **LAKE TABLE** — `us-west-2/ecomm-mart/bill-line-traffic-ext/` | Direct lake catalog lookup |
| `analytic_feature.customer_fraud` | **LAKE TABLE** — `us-west-2/analytic-feature/customer-fraud/` | Direct lake catalog lookup |
| `analytic_feature.shopper_merge` | **LAKE TABLE** — `us-west-2/analytic-feature/shopper-merge/` | Direct lake catalog lookup |
| `ecomm_mart.dim_bill_line_purchase_attribution` | **LAKE TABLE** — `us-west-2/ecomm-mart/dim-bill-line-purchase-attribution/` | Direct lake catalog lookup |
| `finance360.dim_bill_fraud_history_vw` | **LAKE TABLE** — `dlms-api/us-west-2/finance360/dim-bill-fraud-history-vw/` | Direct lake catalog lookup |
| `enterprise.fact_bill_line` | **LAKE TABLE** — `us-west-2/enterprise/fact-bill-line/` | Direct lake catalog lookup (confirmed via intermediate script trace) |
| `enterprise.dim_bill_shopper_id_xref` | **LAKE TABLE** — `us-west-2/enterprise/dim-bill-shopper-id-xref/` | Direct lake catalog lookup |
| `enterprise.dim_entitlement_history` | **LAKE TABLE** — `us-west-2/enterprise/dim-entitlement-history/` | Direct lake catalog lookup |
| `enterprise.fact_entitlement_bill` | **LAKE TABLE** — `us-west-2/enterprise/fact-entitlement-bill/` | Direct lake catalog lookup |
| `ecomm_mart.entitlement_bill_type` | **LAKE TABLE** — `us-west-2/ecomm-mart/entitlement-bill-type/` | Direct lake catalog lookup |
| `finance_cln.manual_paid_subscription` | **LAKE TABLE** — `us-west-2/finance-cln/manual-paid-subscription/` | Direct lake catalog lookup |
| `customers.customer_id_mapping_snapshot` | **LAKE TABLE** — `us-west-2/customers/customer-id-mapping-snapshot/` | Direct lake catalog lookup |
| `s3://gd-ckpetlbatch-prod-analytic/analytic/ads_bill_line_ext/` | **EXTERNAL S3** — legacy channel data | Direct S3 read in `customer_life_cycle.py` L426; no lake catalog entry; pre-2022-08 acquisition channel data only |

**RESULT: All 14 direct upstream references are fully resolved. All 4 intermediate tables are fully resolved to 20 distinct lake/external sources. Zero UNRESOLVED entries.**

---

## Step 4: Column-Level Lineage Mapping

### Target Table: `customer360.customer_life_cycle_vw` (partition: `partition_eval_mst_date`)

| Target Column | Type | Source Formula | Authoritative Lake Source(s) |
|---|---|---|---|
| `shopper_id` | string | `active_customer_stg.shopper_id` | `enterprise.dim_subscription_history.shopper_id` (subscription path) or `enterprise.dim_bill_shopper_id_xref.merged_shopper_id` (TTM path) |
| `customer_id` | string | `active_customer_stg.customer_id` | `enterprise.dim_subscription_history.customer_id` |
| `customer_acquisition_bill_id` | string | `COALESCE(dim_new_acquisition_shopper.new_acquisition_bill_id, dim_subscription_history.original_bill_id)` for new/intraday; else `dim_new_acquisition_shopper.new_acquisition_bill_id` | `enterprise.dim_new_acquisition_shopper.new_acquisition_bill_id`, `enterprise.dim_subscription_history.original_bill_id` |
| `customer_acquisition_mst_date` | date | Complex COALESCE: `MIN(dim_new_acquisition_shopper.new_acquisition_bill_mst_date, dim_subscription_history.subscription_create_mst_date)` with null guards | `enterprise.dim_new_acquisition_shopper.new_acquisition_bill_mst_date`, `enterprise.dim_subscription_history.subscription_create_mst_date` |
| `customer_acquisition_mst_month` | string | `TRUNC(customer_acquisition_mst_date, 'MONTH')` | Derived from `customer_acquisition_mst_date` (see above) |
| `customer_acquisition_country_code` | string | `dim_new_acquisition_shopper.bill_country_code` with `UK→GB` normalization | `enterprise.dim_new_acquisition_shopper.bill_country_code` |
| `customer_acquisition_channel_name` | string | `bill_line_traffic_ext.channel_grouping_name` (≥2022-08); `ads_bill_line_ext.ga_channel_grouping_name` (<2022-08) | `ecomm_mart.bill_line_traffic_ext.channel_grouping_name`; External S3 `ads_bill_line_ext.ga_channel_grouping_name` |
| `customer_tenure_year_count` | int | `CAST(DATEDIFF(partition_eval_mst_date, customer_acquisition_mst_date)/365 AS INT)` | Derived; base from `enterprise.dim_new_acquisition_shopper` / `enterprise.dim_subscription_history` |
| `customer_acquisition_country_name` | string | `dim_country_vw.country_name` joined on `dim_new_acquisition_shopper.bill_country_code` | `finance360.dim_country_vw.country_name` |
| `customer_region_1_name` | string | `dim_country_vw.report_region_1_name` | `finance360.dim_country_vw.report_region_1_name` |
| `customer_region_2_name` | string | `dim_country_vw.report_region_2_name` | `finance360.dim_country_vw.report_region_2_name` |
| `customer_region_3_name` | string | `dim_country_vw.report_region_3_name` | `finance360.dim_country_vw.report_region_3_name` |
| `customer_domestic_international_name` | string | `dim_country_vw.domestic_international_ind` | `finance360.dim_country_vw.domestic_international_ind` |
| `reseller_type_id` | int | `dim_reseller.reseller_type_id` via `dim_customer_history_vw.private_label_id` | `dp_enterprise.dim_reseller.reseller_type_id`; join key: `customer360.dim_customer_history_vw.private_label_id` |
| `reseller_type_name` | string | `dim_reseller.reseller_type_name` via same join | `dp_enterprise.dim_reseller.reseller_type_name` |
| `customer_type_name` | string | `'123 Reg'` override if `dim_customer_history_vw.private_label_id=587240`; else `COALESCE(customer_type_history.customer_type_name, 'Not Evaluated')` | `analytic_feature.customer_type_history.customer_type_name`; `customer360.dim_customer_history_vw.private_label_id` |
| `customer_type_reason_desc` | string | `'123 Reg'` override if private_label_id=587240; else `COALESCE(customer_type_history.customer_type_reason_desc, 'Not Evaluated')` | `analytic_feature.customer_type_history.customer_type_reason_desc`; `customer360.dim_customer_history_vw.private_label_id` |
| `customer_fraud_flag` | boolean | `analytic_feature.shopper_acquisition.acq_fraud_flag` | `analytic_feature.shopper_acquisition.acq_fraud_flag` |
| `active_paid_subscription_list` | array<string> | `SORT_ARRAY(COLLECT_SET(customer_active_subscription_detail_driver.subscription_id))` where `finance_payable_resource_flag=true` | `enterprise.dim_subscription_history.subscription_id` |
| `product_pnl_category_list` | array<string> | `SORT_ARRAY(COLLECT_SET(customer_active_subscription_detail_driver.product_pnl_category))` | `finance360.dim_product_vw.product_pnl_category_name` (via `customer_active_subscription_detail_driver`) |
| `product_pnl_category_qty` | int | `COUNT(DISTINCT customer_active_subscription_detail_driver.product_pnl_category)` | `finance360.dim_product_vw.product_pnl_category_name` |
| `product_pnl_line_list` | array<string> | `SORT_ARRAY(COLLECT_SET(customer_active_subscription_detail_driver.product_pnl_line))` | `finance360.dim_product_vw.product_pnl_line_name` |
| `ttm_all_bill_list` | array<string> | `SORT_ARRAY(COLLECT_SET(customer_ttm_payment_driver.last_net_positive_bill_id))` where `net_positive_ttm_payment_flag=true AND trxn_currency_code<>'N/A'` | `enterprise.fact_bill_line.bill_id` (via `customer_ttm_payment_driver`) |
| `brand_name_list` | array<string> | `SORT_ARRAY(ARRAY_UNION(COALESCE(subscription_brand_name_list, []), COALESCE(ttm_brand_name_list, [])))` | `enterprise.dim_bill_shopper_id_xref.merged_shopper_id` (Leka logic) from both `customer_active_subscription_detail_driver` and `customer_ttm_payment_driver` |
| `ttm_gcr_usd_amt` | decimal(18,2) | `SUM(customer_ttm_payment_driver.ttm_total_gcr_usd_amt)` where `net_positive_ttm_payment_flag=true AND trxn_currency_code<>'N/A'`; `0` for intraday | `enterprise.fact_bill_line.gcr_usd_amt` (via `customer_ttm_payment_driver`) |
| `customer_churn_mst_date` | date | `partition_eval_mst_date` if `customer_status='churned' AND shopper_merge IS NULL`; also `partition_eval_mst_date` if `customer_status='intraday'` | Derived from `active_customer_stg` status logic |
| `customer_reactivate_mst_date` | date | `partition_eval_mst_date` if `customer_status='new' AND customer_acquisition_mst_date < partition_eval_mst_date` | Derived; base from `enterprise.dim_new_acquisition_shopper` |
| `customer_merge_mst_date` | date | `analytic_feature.shopper_merge.shopper_merge_start_mst_date` if `customer_status='churned' AND merged` | `analytic_feature.shopper_merge.shopper_merge_start_mst_date` |
| `customer_fraud_mst_date` | date | `customer_fraud.fraud_flag_mst_date` if: shopper in customer_fraud AND (not reinstated OR reinstatement_ts > eval_date) AND acq_fraud_flag=true | `analytic_feature.customer_fraud.fraud_flag_mst_date` |
| `customer_state_enum` | string | Derived: `intraday→merged→churned→reactivated→new→active` priority order | Derived from above columns |
| `active_status_flag` | boolean | `customer_status NOT IN ('churned','intraday')` | Derived from `active_customer_stg` |
| `point_of_purchase_name` | string | `dim_bill_line_purchase_attribution.point_of_purchase_name` for acquisition bill; ROW_NUMBER by `bill_line_num DESC` | `ecomm_mart.dim_bill_line_purchase_attribution.point_of_purchase_name` |
| `customer_acquisition_bill_fraud_flag` | boolean | `TRUE` if acquisition bill_id exists in `finance360.dim_bill_fraud_history_vw` | `finance360.dim_bill_fraud_history_vw.bill_id` |
| `etl_build_mst_ts` | timestamp | `from_utc_timestamp(current_timestamp(), 'MST')` | ETL runtime; no source table |
| `partition_eval_mst_date` | string | Runtime argument `eval_mst_date` | DAG input parameter |

---

## Step 5: Structured Facts Block (Sections A1–E3)

### A — Business Context

**A1: Business Purpose / Description**
- FILL: "Driver table tracking GoDaddy customer life-cycle state daily. Supports Finance-requested customer metrics (OSI, OWL, churn reporting, cohort analysis). One row per customer per evaluation date capturing active/churned/new/reactivated/merged/intraday status."
- Evidence: PySpark file header L4-7; Confluence "Customer360 Business Context Structure" (ID 4387965088); policy file `customer_life_cycle_dag.yaml`

**A2: Data Domain / Product**
- FILL: Schema = `customer360`; Domain = Customer; Org = DNA; Product = Customer360
- Evidence: lake catalog `db.yaml`, Confluence page 4387965088

**A3: Business Owner / Contacts**
- FILL: Team = Customer360 / EDT; On-call = `#marketing-data-product-engineering`, `dl-bi-enterprise-data@godaddy.com`, SNOW group = `DEV-EDT-OnCall`; Stakeholders = `#marketing-data-products-help`
- Evidence: DAG `customer_life_cycle_dag.py` alert/owner config

**A4: Key Consumers**
- FILL: ckpetlbatch (dev/prod), data_lab (dev), analytics (prod), data_platform (stage/prod, care_analytics, partners), martech_data (dev/stage/prod), revenue_and_relevance (dev/stage/prod/test)
- Evidence: lake catalog `table.yaml` permissions list

### B — Data Model

**B1: Grain**
- FILL: One row per `(shopper_id, partition_eval_mst_date)`.
- Evidence: DQ constraint `customer_life_cycle_vw.json` PK check on `(partition_eval_mst_date, shopper_id)`; gather.md; Confluence "one row per customer per eval date"

**B2: Primary Key / Unique Key**
- FILL: Composite key `(partition_eval_mst_date, shopper_id)`. No physical PK enforced (Parquet/Hive). DQ constraint enforces uniqueness. Note: DDL comment incorrectly references entitlement-driver key — that is a copy-paste artifact.
- Evidence: `customer_life_cycle_vw.json` DQ constraint; lake DDL `@PrimaryKey` comment on `customer_id` is somewhat misleading (shopper_id is the actual ecommerce grain key)

**B3: Schema Summary**
- FILL: 35 columns (34 data + 1 partition). Types: 14× string, 5× date, 4× array<string>, 3× boolean, 2× int, 2× decimal(18,2), 1× boolean, 1× timestamp.
- Evidence: lake `table.ddl` (35 columns); `customer_life_cycle.py` `conform_datatype()` L1022-1060

**B4: Partitioning**
- FILL: Partitioned by `partition_eval_mst_date STRING`. Recommended always-filter: always include `partition_eval_mst_date` predicate. 30 files per partition (repartition(30) at write).
- Evidence: lake `table.yaml` partition_keys; `customer_life_cycle.py` L1083

### C — Lineage

**C1: Column-Level Lineage (CRITICAL)**
- FILL: Full mapping provided in Step 4 above. All 35 columns traced. 0 UNRESOLVED entries.
- Lake sources feeding each column: `enterprise.*` (subscription, entitlement, billing), `analytic_feature.*` (fraud, acquisition, merge, customer type), `finance360.*` (country, bill fraud, product), `ecomm_mart.*` (bill traffic, attribution, entitlement type), `dp_enterprise.dim_reseller`, `customer360.dim_customer_history_vw`, `customers.customer_id_mapping_snapshot`, `finance_cln.manual_paid_subscription`, External S3 `ads_bill_line_ext`

**C2: Direct Upstream Tables (in target PySpark)**
- FILL: 16 total: 3 intermediate (`customer_ttm_payment_driver`, `customer_active_subscription_detail_driver`, `active_customer_stg`) + 12 lake tables + 1 external S3.
  See gather.md Section 3 for full enumerated list with filter conditions.

**C3: Downstream / Consumers**
- FILL: `customer360.customer_life_cycle_vw` Redshift table (loaded via staging copy). Multiple BI consumers via lake catalog permissions. `customer360.customer_metric_daily_agg` is a known downstream (separate DAG `customer_metric_daily_agg_dag.py` in same repo reads `customer_life_cycle_vw`).
- Evidence: DAG task `insert_customer_life_cycle`; lake catalog permissions; `customer_metric_daily_agg_dag.py` exists in same folder

**C4: Intermediate Table Resolution**
- FILL: See Step 3 lineage resolution table above. All 4 intermediate tables fully resolved.
- `customer_core_conformed` schema is the staging/landing namespace; all tables are non-public implementation details.

### D — Quality & Operations

**D1: SLA / Refresh Schedule**
- FILL: Daily. DAG schedule: `"20 7 * * *"` = 7:20 AM MST. SLO delivery: `cron(00 15 * * ? *)` = 8:00 AM MST. maxDurationMins = 120. TIER_4. retries=1.
- Evidence: DAG `customer_life_cycle_dag.py`; policy `customer_life_cycle_dag.yaml`; lake catalog `table.yaml` SLA block

**D2: Data Quality Checks**
- FILL: DQ constraint: PK uniqueness check on `(partition_eval_mst_date, shopper_id)` for both internal and lake tables. Enforced via Airflow tasks `dq_check_customer_life_cycle_local` (pre-lake) and `dq_check_customer_life_cycle_lake` (post-lake).
- Evidence: `customer_life_cycle.json`, `customer_life_cycle_vw.json`

**D3: Always-On Filters Embedded in ETL**
- FILL:
  - Internal shoppers excluded (via `customer360.dim_customer_history_vw.internal_shopper_flag=true` anti-join) — applies to TTM payment driver and subscription detail driver
  - Leka shoppers (merged_shopper_id IN ('554670720','554671405')) handled via special CASE logic for shopper_id assignment and included despite `subscription_billing_shopper_differ_flag=true`
  - `analytic_feature.shopper_acquisition` filtered to `partition_evaluation_mst_date = eval_mst_date` (no back-fill lookback)
  - `analytic_feature.customer_type_history`: `record_start_mst_date ≤ eval_mst_date ≤ record_end_mst_date`
  - `analytic_feature.shopper_merge`: `shopper_merge_start_mst_date ≤ eval_mst_date ≤ shopper_merge_end_mst_date`
  - `finance360.dim_country_vw`: `current_record_flag = true`
  - `enterprise.dim_subscription_history` / `enterprise.dim_entitlement_history`: partition = `eval_mst_date + 1` (tribal knowledge: subscription partitions are one day ahead)
  - Legacy acquisition channel (`ads_bill_line_ext`): `partition_bill_mst_year_month < '2022-08'` only
- Evidence: `customer_life_cycle.py` various query functions

**D4: Known Issues / Caveats**
- FILL:
  1. `finance360.dim_country_vw` has no DAG sensor — late delivery of this dim would not block the job
  2. Legacy S3 path `s3://gd-ckpetlbatch-prod-analytic/analytic/ads_bill_line_ext/` is hardcoded prod bucket — will fail in non-prod
  3. `customer_tenure_year_count` is integer floor division — customers 0–364 days old show as 0 years
  4. `customer_acquisition_mst_date` can be NULL for existing customers with no traceable past acquisition date
  5. `ttm_gcr_usd_amt` is set to 0 for intraday customers (not NULL)
  6. Churned customers' subscription/payment data is from d-1 (previous day), not eval date
  7. Lake catalog lineage still lists 8 legacy upstream tables not used in current code (stale)
- Evidence: code logic + gather.md conflicts section

### E — Metrics & Usage

**E1: Key Business Metrics Computed**
- FILL:
  | Metric | Column | Definition | Grain |
  |---|---|---|---|
  | TTM GCR (USD) | `ttm_gcr_usd_amt` | SUM of `fact_bill_line.gcr_usd_amt` over 12 months where net_positive=true and currency≠'N/A' | Per customer per eval date |
  | PNL Category Count | `product_pnl_category_qty` | COUNT(DISTINCT `dim_product_vw.product_pnl_category_name`) across active paid subscriptions | Per customer per eval date |
  | Customer Tenure | `customer_tenure_year_count` | `DATEDIFF(eval_date, acq_date)/365` cast to int | Per customer per eval date |
  | Customer State | `customer_state_enum` | 6-value enum: intraday/merged/churned/reactivated/new/active | Per customer per eval date |
  | Active Status | `active_status_flag` | `customer_state_enum NOT IN ('churned','intraday')` | Per customer per eval date |

**E2: Recommended Query Patterns**
- FILL:
  - ALWAYS filter on `partition_eval_mst_date` (partitioned column)
  - For current state: `WHERE partition_eval_mst_date = '<date>' AND active_status_flag = true`
  - For churn analysis: `WHERE partition_eval_mst_date = '<date>' AND customer_state_enum = 'churned'`
  - For new customer cohorts: `WHERE customer_acquisition_mst_date = '<date>'` (scan across partitions needed)
  - Do NOT join to this table without a partition filter — full table scan will be very large
  - Note: `legacyLookBackEnabled: true` in lake catalog — historical partitions are available

**E3: Computed / Derived Columns — Special Handling**
- FILL:
  - `customer_acquisition_country_code`: normalized — 'UK' → 'GB' (UK normalization applied in Spark `.withColumn()` at L1012-1019)
  - `customer_type_name` / `customer_type_reason_desc`: '123 Reg' override applied when `private_label_id = 587240` (regardless of `customer_type_history` value)
  - `customer_state_enum`: priority-ordered derivation — intraday > merged > churned > reactivated > new > active
  - `customer_reactivate_mst_date`: populated only when `customer_status='new' AND acq_date < eval_date` (i.e., returning customer showing as "new" because they were inactive yesterday)
  - `ttm_gcr_usd_amt`: COALESCE with 0 — never NULL in output; intraday customers always get 0
  - `active_paid_subscription_list` / `product_pnl_category_list` / `product_pnl_line_list` / `ttm_all_bill_list` / `brand_name_list`: SORT_ARRAY applied — arrays are always sorted, enabling string equality comparison

---

## Step 6: Do Not Claim List

The following items are **tempting but not proven** by the current code or available artifacts:

1. **"Data Tier 2"** — Confluence mentions Tier 2 for dim tables; the lake catalog and policy file say **TIER_4** for customer_life_cycle. Do not claim Tier 2.
2. **Any of the 8 stale upstream tables in lake catalog lineage** (`customers.customer_id_mapping_snapshot` IS in current code as a source for the ttm_payment_driver; the other 7 legacy tables — `ecomm_mart.entitlement_bill_type`, `enterprise.dim_bill_shopper_id_xref`, `enterprise.dim_entitlement_history`, `enterprise.fact_bill_line`, `enterprise.fact_entitlement_bill`, `finance360.dim_product_vw`, `finance_cln.manual_paid_subscription` — are used via intermediate scripts so they ARE valid upstream lake sources. The truly stale ones from the earlier architecture (in old lake catalog) are `enterprise.fact_entitlement_bill` being listed separately as "stale" is incorrect — it is real. The genuinely stale ones from the old architecture are NOT in the current code at all; confirm before claiming they are in scope.
3. **SLA "N/A"** — DAG doc_md says "SLA: N/A"; DO NOT claim there is no SLA. The policy file and lake catalog confirm SLA = maxDurationMins=120, TIER_4, delivery by 8:00 AM MST.
4. **"customer_id is the primary key"** — DDL comment says `@PrimaryKey` on `customer_id`, but DQ enforces `(partition_eval_mst_date, shopper_id)`. The actual grain key involves `shopper_id`, not `customer_id` alone.
5. **DDL PK comment about entitlement columns** — DDL has a stale comment "Primary Key: resource_id, product_family_name, entitlement_addon_id, partition_eval_mst_date" — copy-paste from another DDL. NOT the actual key for this table.
6. **Confluence design doc source tables** (shopper_status_v2, fact_active_entitlement_last_payment_detail, shopper_churn_v2, analytic_feature.shopper_tenure) — superseded. NOT in current code.
7. **customer_tenure formula from Confluence** ("shopper_tenure.shopper_tenure_days_count / 365") — outdated. Current code uses `datediff(partition_eval_mst_date, customer_acquisition_mst_date) / 365`.
8. **`finance360.dim_bill_fraud_history_vw` format** — policy file lists it twice (parquet + iceberg conflicting); do not claim a definitive format until validated.
9. **Alation metadata** — Alation lookup was skipped (no credentials). No Alation-derived facts should be claimed.


**The agent's final response to the user was:**
Both files are correct. Here is a summary of everything researched and produced:

---

## Analyze Stage Summary

### What was done

**Target table resolved (high confidence):**
- Internal landing: `customer_core_conformed.customer_life_cycle`
- **Lake/public table: `customer360.customer_life_cycle_vw`** — path `catalog/config/prod/dlms-api/us-west-2/customer360/customer-life-cycle-vw/`
- Evidence: `insertInto` in PySpark, `SuccessNotificationOperator` in DAG, DQ constraints, lake catalog DDL/YAML all agree.

**Recursive lineage fully resolved — 0 UNRESOLVED entries:**

All 4 intermediate `customer_core_conformed.*` tables were traced to their upstream scripts and then to lake tables:

| Intermediate | Built By |
|---|---|
| `customer_core_conformed.customer_ttm_payment_driver` | `customer_ttm_payment_driver.py` → `enterprise.fact_bill_line`, `enterprise.dim_bill_shopper_id_xref`, `customer360.dim_customer_history_vw`, `customers.customer_id_mapping_snapshot` |
| `customer_core_conformed.customer_active_subscription_detail_driver` | `customer_active_subscription_detail_driver.py` → 9 lake sources including `enterprise.dim_subscription_history`, `enterprise.dim_entitlement_history`, `finance360.dim_product_vw`, `ecomm_mart.entitlement_bill_type`, `finance_cln.manual_paid_subscription` |
| `customer_core_conformed.active_customer_stg` | `active_customer_stg.py` → inherits from the two above + `subscription_grace_policy` |
| `customer_core_conformed.subscription_grace_policy` | `subscription_grace_policy.py` → `enterprise.dim_subscription_history`, `enterprise.dim_entitlement_history`, `customer360.dim_customer_history_vw`, `finance360.dim_product_vw` |

**Total authoritative lake sources: 20 distinct lake tables + 1 external S3 (legacy `ads_bill_line_ext`)**

**Column-level lineage:** All 35 columns in the target table traced to their ultimate lake sources with formulas documented.

**`RESOLVED_TARGET.json`** written with schema=`customer360`, table=`customer-life-cycle-vw`, confidence=`high`, 7 evidence references.