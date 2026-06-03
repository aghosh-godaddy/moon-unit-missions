**Stage name:** analyze
**The coding agent was given these instructions:** You are a Data Engineering analyst mapping a PySpark ETL job to an OSI semantic model.
Your job is to resolve lineage, classify tables, extract relationships and metrics,
and produce a structured analysis for OSI YAML generation.

Read `docs/osi-spec-reference.md` in the workspace for the OSI schema contract.

## Step 1: Read INPUT.md and gather.md
- Read `INPUT.md` and `gather.md`.
- If INPUT.md contains USER NOTES, factor them into your analysis (expert-provided,
  priority over Confluence/Alation text).

## Step 2: Identify the target table
Determine the final output lake table populated by this PySpark job.
- Prefer direct evidence in code: write targets, insertInto, saveAsTable, etc.
- If `lake_table_override` is provided, use it only if it does not contradict code.
- Record grain (what one row represents) with evidence.

## Step 3: Deep lineage resolution — MANDATORY for EVERY source table
For EACH table referenced in the PySpark:
1. Check if it exists as a lake table in `repos/lake/catalog/config/prod/`.
   Try both `us-west-2/<schema>/<table-hyphenated>/` and
   `dlms-api/us-west-2/<schema>/<table-hyphenated>/`.
2. If NOT a lake table, recursively trace upstream PySpark scripts until you reach
   a lake table or external system.
3. If traversal fails: record `UNRESOLVED: <table> — <reason>`

**CRITICAL:** OSI dataset `source` values must be lake tables only (schema.table form).
Never use intermediate/staging tables as dataset sources.

## Step 4: Classify datasets (fact vs dimension)
For each resolved lake table included in the semantic model:
- **Target table** = primary fact dataset (the table this PySpark populates)
- **Upstream tables joined TO** = dimension datasets
- Record classification with evidence (join direction in PySpark)

## Step 5: Extract relationships
From PySpark join conditions in gather.md:
- Map each join to an OSI relationship: `from` (many side) → `to` (one side)
- Record `from_columns` and `to_columns` with matching order
- Name relationships descriptively (e.g., `orders_to_customers`)

## Step 6: Map fields for each dataset
For each dataset, list fields from lake `table.ddl`:
- Column name → OSI field name (use snake_case)
- Scalar expression (column reference or computed scalar)
- `dimension.is_time: true` for date/timestamp/partition date columns
- Description from DDL comments, Alation, or Confluence (if available)
- Candidate synonyms for `ai_context` from business docs

## Step 7: Identify metrics
From PySpark aggregations, Alation queries, and Confluence docs:
- Name each metric (snake_case)
- ANSI_SQL aggregate expression (may reference `dataset.column`)
- Description and synonyms
- Only include metrics with evidence — do not invent

## Step 8: Determine semantic model metadata
- Model name: use `semantic_model_name` from INPUT.md if provided, else derive from
  schema + table (e.g., `customer360_customer_life_cycle_analytics`)
- Model description: from Confluence, Alation, or code comments
- ai_context: instructions, synonyms, example questions the model answers

## Step 9: Output (append to analyze.md)
Append:
- Target table resolution with evidence
- Lineage resolution table (intermediate → lake)
- **Dataset classification table**: | Lake Table | OSI Dataset Name | Role (fact/dim) | source | primary_key |
- **Relationship table**: | name | from | to | from_columns | to_columns | evidence |
- **Field inventory per dataset**: columns, types, is_time, descriptions
- **Metrics table**: | name | expression | description | evidence |
- **Semantic model metadata**: name, description, ai_context draft
- "Do not claim" list: items tempting but not proven

## Step 10: Write RESOLVED_TARGET.json (required)
Create `RESOLVED_TARGET.json` in workspace root:
```json
{
  "schema": "customer360",
  "table_hyphen": "customer-life-cycle-vw",
  "table_underscore": "customer_life_cycle_vw",
  "lake_table_path": "customer360/customer-life-cycle-vw",
  "semantic_model_name": "customer360_customer_life_cycle_analytics",
  "confidence": "high",
  "evidence": ["file/line references"]
}
```

**The agent summarized its work in this way:**

---

## Stage: analyze — customer_life_cycle (customer360)
**Analyzed:** 2026-06-03

---

### Step 2: Target Table Resolution

**Target lake table:** `customer360.customer_life_cycle_vw`

| Evidence item | Source |
|---|---|
| DAG `SuccessNotificationOperator` fires lake view update for `customer360.customer_life_cycle_vw` (prod only) | `customer360/customer-metrics/src/dag/customer_life_cycle_dag.py` |
| Lake registry folder exists: `dlms-api/us-west-2/customer360/customer-life-cycle-vw/` | `repos/lake/catalog/config/prod/` |
| `table.yaml` description: `"Analytic Dataset for Customer Life Cycle"`, data_tier: 4, SLA cron `00 15 * * ? *` | `repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/customer-life-cycle-vw/table.yaml` |
| PySpark `insertInto('customer_core_conformed.customer_life_cycle', overwrite=True)` → DAG promotes to lake view | `customer360/customer-metrics/src/pyspark/customer_life_cycle.py` |

**Lake override:** Not provided in INPUT.md; determination from code is unambiguous.

**Internal staging table (NOT the OSI target):** `customer_core_conformed.customer_life_cycle`
- This is the Parquet S3 write target for the EMR job (`s3://gd-ckpetlbatch-{env}-customer-core-conformed/...`)
- Not in lake catalog; not a valid OSI dataset `source`
- The DAG's `conditional_call_lake_api` step promotes it to the lake view `customer360.customer_life_cycle_vw`

**Grain:** One row per `(customer_id, partition_eval_mst_date)`
- Lake DDL `customer_id` comment: `@PrimaryKey: Combination of Customer ID and partition_eval_mst_date`
- DQ constraint: `.isPrimaryKey("partition_eval_mst_date", "shopper_id")` — code-authoritative; `shopper_id` is the unique key
- Confluence: "one row per customer per eval date"
- **Authoritative grain for OSI:** `[customer_id, partition_eval_mst_date]` (lake DDL); `[shopper_id, partition_eval_mst_date]` as unique_key per DQ constraint

---

### Step 3: Lineage Resolution

All 15 named source tables + 1 legacy S3 path from PySpark `get_tables(aws_env)`:

| # | PySpark Logical Key | Resolved Prod Table | Lake Registry Path | Status |
|---|---|---|---|---|
| 1 | `analytic_feature__shopper_acquisition` | `analytic_feature.shopper_acquisition` | `us-west-2/analytic-feature/shopper-acquisition/table.ddl` | ✅ LAKE TABLE |
| 2 | `analytic_feature__customer_type_history` | `analytic_feature.customer_type_history` | `us-west-2/analytic-feature/customer-type-history/table.ddl` | ✅ LAKE TABLE |
| 3 | `customer360__dim_customer_history_vw` | `customer360.dim_customer_history_vw` | `dlms-api/us-west-2/customer360/dim-customer-history-vw/table.ddl` | ✅ LAKE TABLE |
| 4 | `finance360__dim_country_vw` | `finance360.dim_country_vw` | `dlms-api/us-west-2/finance360/dim-country-vw/table.ddl` | ✅ LAKE TABLE |
| 5 | `dp_enterprise__dim_reseller` | `dp_enterprise.dim_reseller` | `us-west-2/dp-enterprise/dim-reseller/table.ddl` | ✅ LAKE TABLE |
| 6 | `enterprise_dim_new_acquisition_shopper` | `enterprise.dim_new_acquisition_shopper` | `us-west-2/enterprise/dim-new-acquisition-shopper/table.ddl` | ✅ LAKE TABLE |
| 7 | `enterprise__dim_subscription_history` | `enterprise.dim_subscription_history` | `us-west-2/enterprise/dim-subscription-history/table.ddl` | ✅ LAKE TABLE |
| 8 | `ecomm_mart_bill_line_traffic_ext` | `ecomm_mart.bill_line_traffic_ext` | `us-west-2/ecomm-mart/bill-line-traffic-ext/table.ddl` | ✅ LAKE TABLE |
| 9 | `ecomm_mart__dim_bill_line_purchase_attribution` | `ecomm_mart.dim_bill_line_purchase_attribution` | `us-west-2/ecomm-mart/dim-bill-line-purchase-attribution/table.ddl` | ✅ LAKE TABLE |
| 10 | `finance360__dim_bill_fraud_history_vw` | `finance360.dim_bill_fraud_history_vw` | `dlms-api/us-west-2/finance360/dim-bill-fraud-history-vw/table.ddl` | ✅ LAKE TABLE |
| 11 | `customer360__customer_ttm_payment_driver` | `customer_core_conformed.customer_ttm_payment_driver` | Not in lake registry | ❌ INTERNAL DRIVER — DDL at `active-customer-drivers/src/ddls/customer_ttm_payment_driver.ddl` |
| 12 | `customer360__customer_active_subscription_detail_driver` | `customer_core_conformed.customer_active_subscription_detail_driver` | Not in lake registry | ❌ INTERNAL DRIVER — DDL at `active-customer-drivers/src/ddls/customer_active_subscription_detail_driver.ddl` |
| 13 | `customer360__active_customer` | `customer_core_conformed.active_customer_stg` | Not in lake registry | ❌ INTERNAL DRIVER — DDL at `active-customer/src/ddls/active_customer_stg.ddl` |
| 14 | `analytic_feature__customer_fraud` | `analytic_feature.customer_fraud` | `us-west-2/analytic-feature/customer-fraud/table.ddl` | ✅ LAKE TABLE |
| 15 | `analytic_feature__shopper_merge` | `analytic_feature.shopper_merge` | `us-west-2/analytic-feature/shopper-merge/table.ddl` | ✅ LAKE TABLE |
| 16 | *(legacy, hardcoded S3)* | `s3://gd-ckpetlbatch-prod-analytic/analytic/ads_bill_line_ext/` | N/A | ❌ UNRESOLVED — External/legacy S3 path, hardcoded prod, not a lake table |

**Internal driver tables resolution note:**
Tables 11–13 (`customer_ttm_payment_driver`, `customer_active_subscription_detail_driver`, `active_customer_stg`) are internal ETL staging tables within the `customer_core_conformed` schema. They are produced by sibling PySpark pipelines in the same repo (`customer360/active-customer-drivers/` and `customer360/active-customer/`), which themselves read from lake tables. Their outputs are already aggregated and denormalized into the fact table `customer_life_cycle_vw`. They are NOT valid OSI dataset sources.

---

### Step 4: Dataset Classification

| Lake Table | OSI Dataset Name | Role | source | primary_key | Include in OSI Model |
|---|---|---|---|---|---|
| `customer360.customer_life_cycle_vw` | `customer_life_cycle_vw` | **FACT** | `customer360.customer_life_cycle_vw` | `[customer_id, partition_eval_mst_date]` | ✅ Yes — primary fact |
| `analytic_feature.shopper_acquisition` | `shopper_acquisition` | **DIMENSION** | `analytic_feature.shopper_acquisition` | `[shopper_id]` | ✅ Yes — FK-annotated in lake DDL |
| `dp_enterprise.dim_reseller` | `dim_reseller` | **DIMENSION** | `dp_enterprise.dim_reseller` | `[private_label_id]` | ✅ Yes — FK-annotated in lake DDL, BROADCAST hint |
| `finance360.dim_country_vw` | `dim_country_vw` | **DIMENSION** | `finance360.dim_country_vw` | `[country_code]` | ✅ Yes — geographic lookup, BROADCAST hint |
| `customer360.dim_customer_history_vw` | `dim_customer_history_vw` | **DIMENSION** | `customer360.dim_customer_history_vw` | `[customer_id, effective_start_mst_ts]` | ✅ Yes — SCD2 customer profile, join #3 |
| `enterprise.dim_subscription_history` | `dim_subscription_history` | **DIMENSION** | `enterprise.dim_subscription_history` | `[subscription_id]` | ✅ Yes — FK-annotated (array FK), join #7 |
| `analytic_feature.customer_type_history` | `customer_type_history` | DIMENSION | `analytic_feature.customer_type_history` | `[shopper_id, record_start_mst_date]` | ⚠️ Omit — `customer_type_name` already denormalized into fact |
| `analytic_feature.customer_fraud` | `customer_fraud` | DIMENSION | `analytic_feature.customer_fraud` | `[shopper_id, customer_id]` | ⚠️ Omit — `customer_fraud_flag`, `customer_fraud_mst_date` already in fact |
| `analytic_feature.shopper_merge` | `shopper_merge` | DIMENSION | `analytic_feature.shopper_merge` | `[original_shopper_id, shopper_merge_start_mst_date]` | ⚠️ Omit — identity resolution; `customer_merge_mst_date` already in fact |
| `enterprise.dim_new_acquisition_shopper` | `dim_new_acquisition_shopper` | DIMENSION | `enterprise.dim_new_acquisition_shopper` | `[bill_shopper_id]` | ⚠️ Omit — ETL computation input, acquisition data denormalized into fact |
| `ecomm_mart.bill_line_traffic_ext` | `bill_line_traffic_ext` | DIMENSION | `ecomm_mart.bill_line_traffic_ext` | `[bill_id, bill_line_num]` | ⚠️ Omit — granular bill/traffic table; `customer_acquisition_channel_name` already in fact |
| `ecomm_mart.dim_bill_line_purchase_attribution` | `dim_bill_line_purchase_attribution` | DIMENSION | `ecomm_mart.dim_bill_line_purchase_attribution` | `[bill_id, bill_line_num]` | ⚠️ Omit — `point_of_purchase_name` already in fact |
| `finance360.dim_bill_fraud_history_vw` | `dim_bill_fraud_history_vw` | DIMENSION | `finance360.dim_bill_fraud_history_vw` | `[bill_id, effective_start_mst_ts]` | ⚠️ Omit — `customer_acquisition_bill_fraud_flag` already in fact |

---

### Step 5: Relationships

| Name | From (many) | To (one) | from_columns | to_columns | Evidence |
|---|---|---|---|---|---|
| `customer_life_cycle_to_shopper_acquisition` | `customer_life_cycle_vw` | `shopper_acquisition` | `[shopper_id]` | `[shopper_id]` | PySpark join #1: `ac.shopper_id = acq.shopper_id`; lake DDL `@ForeignKey (analytic_feature.shopper_acquisition)` on `customer_acquisition_bill_id` |
| `customer_life_cycle_to_dim_reseller` | `customer_life_cycle_vw` | `dim_reseller` | `[reseller_type_id]` | `[reseller_type_id]` | Lake DDL `@ForeignKey (dp_enterprise.dim_reseller)` on `reseller_type_id`; PySpark get_reseller_df join #12 (BROADCAST) |
| `customer_life_cycle_to_dim_country_vw` | `customer_life_cycle_vw` | `dim_country_vw` | `[customer_acquisition_country_code]` | `[country_code]` | PySpark join #14: `acq.bill_country_code = geo.country_code AND geo.current_record_flag = true` (BROADCAST) |
| `customer_life_cycle_to_dim_customer_history_vw` | `customer_life_cycle_vw` | `dim_customer_history_vw` | `[customer_id]` | `[customer_id]` | PySpark join #3 (`ac.shopper_id = pl.shopper_id` to get `private_label_id`); SCD2 dimension — consumers should additionally filter `current_record_flag = true` |
| `customer_life_cycle_to_dim_subscription_history` | `customer_life_cycle_vw` | `dim_subscription_history` | `[active_paid_subscription_list]` | `[subscription_id]` | Lake DDL `@ForeignKey (enterprise.dim_subscription_history)` on `active_paid_subscription_list`; **ARRAY FK** — requires UNNEST/LATERAL in queries; flag for YAML generation stage |

**Array FK note for YAML generation:** `active_paid_subscription_list` is an `array<string>` column. Standard OSI relationship semantics use scalar column joins. This relationship should be included with an `ai_context` note explaining the UNNEST pattern. The relationship is valid semantically; execution requires: `CROSS JOIN UNNEST(customer_life_cycle_vw.active_paid_subscription_list) AS t(subscription_id_ref) JOIN dim_subscription_history ON t.subscription_id_ref = dim_subscription_history.subscription_id`.

---

### Step 6: Field Inventory

#### Dataset: customer_life_cycle_vw (FACT)
Source: `customer360.customer_life_cycle_vw` | DDL: `repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/customer-life-cycle-vw/table.ddl`

| Column | Type | is_time | Description |
|---|---|---|---|
| customer_id | string | false | @PrimaryKey (with partition_eval_mst_date): UUID representing the customer entity across GoDaddy systems |
| shopper_id | string | false | @UniqueKey: Numeric shopper profile ID used in eCommerce transactions |
| customer_acquisition_bill_id | string | false | @FK analytic_feature.shopper_acquisition: Bill ID triggering first net positive status |
| customer_acquisition_mst_date | date | **true** | Date of first net positive acquisition bill (MST) |
| customer_acquisition_mst_month | string | **true** | Acquisition month truncated to month (TRUNC to MONTH) |
| customer_acquisition_country_code | string | false | Country code where customer was acquired |
| customer_acquisition_channel_name | string | false | Channel through which customer was acquired |
| customer_tenure_year_count | int | false | Tenure in years: CAST(DATEDIFF(eval_date, acq_date) / 365 AS INT) |
| customer_acquisition_country_name | string | false | Country name where customer was acquired |
| customer_region_1_name | string | false | Geographic reporting region 1 |
| customer_region_2_name | string | false | Geographic reporting region 2 |
| customer_region_3_name | string | false | Geographic reporting region 3 |
| customer_domestic_international_name | string | false | Domestic vs. international indicator |
| reseller_type_id | int | false | @FK dp_enterprise.dim_reseller: Reseller type numeric ID |
| reseller_type_name | string | false | Reseller type name |
| customer_type_name | string | false | Customer type label at evaluation date; overridden to '123 Reg' if private_label_id=587240 |
| customer_type_reason_desc | string | false | Customer type reason description |
| customer_fraud_flag | boolean | false | True if customer is flagged as fraud at evaluation date |
| active_paid_subscription_list | array<string> | false | @FK enterprise.dim_subscription_history: COLLECT_SET of active paid subscription_ids (finance-payable) |
| product_pnl_category_list | array<string> | false | COLLECT_SET of product P&L categories owned by customer |
| product_pnl_category_qty | int | false | COUNT(DISTINCT product_pnl_category) for active subscriptions |
| product_pnl_line_list | array<string> | false | COLLECT_SET of product P&L lines owned by customer |
| ttm_all_bill_list | array<string> | false | COLLECT_SET of bill IDs from trailing twelve months (TTM) |
| brand_name_list | array<string> | false | SORT_ARRAY(ARRAY_UNION of subscription and TTM brands) |
| ttm_gcr_usd_amt | decimal(18,2) | false | SUM(ttm_total_gcr_usd_amt) for TTM window; excludes trxn_currency_code='N/A' |
| customer_churn_mst_date | date | **true** | MST date when customer most recently churned; null if not churned |
| customer_reactivate_mst_date | date | **true** | MST date when customer was most recently reactivated |
| customer_merge_mst_date | date | **true** | MST date when customer was merged into another account |
| customer_fraud_mst_date | date | **true** | MST date when fraud flag was set on customer |
| customer_state_enum | string | false | @Enumerated(active, churned, merged, reactivated, intraday): Customer state at eval date |
| active_status_flag | boolean | false | True if customer_state_enum NOT IN ('churned', 'intraday') |
| point_of_purchase_name | string | false | Point of purchase name for the acquisition bill |
| customer_acquisition_bill_fraud_flag | boolean | false | True if acquisition bill has a record in dim_bill_fraud_history_vw |
| etl_build_mst_ts | timestamp | **true** | Timestamp when record was built by ETL (from_utc_timestamp(current_timestamp(), 'MST')) |
| partition_eval_mst_date | string | **true** | PARTITION KEY: Evaluation date in YYYY-MM-DD format |

#### Dataset: shopper_acquisition (DIMENSION)
Source: `analytic_feature.shopper_acquisition` | DDL: `repos/lake/catalog/config/prod/us-west-2/analytic-feature/shopper-acquisition/table.ddl`

| Column | Type | is_time | Description |
|---|---|---|---|
| shopper_id | string | false | PK: Shopper identifier |
| evaluation_mst_date | date | **true** | Evaluation date for this acquisition record |
| acq_bill_mst_date | date | **true** | Date of acquisition bill (MST) |
| acq_bill_mst_ts | timestamp | **true** | Timestamp of acquisition bill (MST) |
| acq_bill_id | string | false | Acquisition bill ID |
| acq_isc_source_code | string | false | ISC source code at acquisition |
| acq_isc_channel_name | string | false | Acquisition channel name |
| acq_country_code | string | false | Country code at acquisition |
| acq_reseller_type_name | string | false | Reseller type name at acquisition |
| acq_private_label_id | int | false | Private label ID at acquisition |
| acq_fraud_flag | boolean | false | Fraud flag on acquisition |
| acq_gcr_usd_amt | decimal(18,2) | false | GCR in USD at acquisition |
| acq_product_list_price_usd_amt | decimal(18,2) | false | Product list price in USD at acquisition |
| acq_point_of_purchase_name | string | false | Point of purchase at acquisition |
| acq_viral_flag | boolean | false | Viral acquisition indicator |
| acq_product_names | string | false | Product names at acquisition |
| load_date | date | **true** | ETL load date |

#### Dataset: dim_reseller (DIMENSION)
Source: `dp_enterprise.dim_reseller` | DDL: `repos/lake/catalog/config/prod/us-west-2/dp-enterprise/dim-reseller/table.ddl`

| Column | Type | is_time | Description |
|---|---|---|---|
| private_label_id | int | false | PK: Reseller private label ID |
| reseller_shopper_id | string | false | Reseller's shopper ID |
| reseller_type_id | int | false | Reseller type numeric ID (join key from fact) |
| reseller_type_name | string | false | Reseller type name |
| reseller_name | string | false | Reseller name |
| reseller_country_code | string | false | Reseller country code |
| reseller_country_name | string | false | Reseller country name |
| reseller_domestic_international_name | string | false | Domestic/international indicator |
| reseller_region_1_name | string | false | Reseller geographic region 1 |
| reseller_region_2_name | string | false | Reseller geographic region 2 |

#### Dataset: dim_country_vw (DIMENSION)
Source: `finance360.dim_country_vw` | DDL: `repos/lake/catalog/config/prod/dlms-api/us-west-2/finance360/dim-country-vw/table.ddl`

| Column | Type | is_time | Description |
|---|---|---|---|
| country_code | string | false | PK: Country code (some non-ISO GoDaddy-specific codes; UK → GB normalized in fact) |
| country_name | string | false | Country name |
| iso_country_code | string | false | ISO 2-character country code |
| iso_country3_code | string | false | ISO 3-character country code |
| region_name | string | false | Region name (e.g., Europe, Asia) |
| domestic_international_ind | string | false | Domestic/International enum |
| report_region_1_name | string | false | Reporting region hierarchy level 1 |
| report_region_2_name | string | false | Reporting region hierarchy level 2 |
| report_region_3_name | string | false | Reporting region hierarchy level 3 |
| report_focal_country_name | string | false | Reporting country/language grouping |
| fin_region_1_name | string | false | Finance region hierarchy level 1 |
| fin_region_2_name | string | false | Finance region hierarchy level 2 |
| marketing_region_name | string | false | Marketing region name |
| marketing_region_group_name | string | false | Marketing region group name |
| finance_region_name | string | false | Finance region name |
| eu_flag | boolean | false | EU membership indicator |
| active_flag | boolean | false | Country code active indicator |
| current_record_flag | boolean | false | SCD2 current record flag (join with `= true`) |
| etl_insert_utc_ts | timestamp | **true** | ETL insert timestamp (UTC) |
| etl_update_utc_ts | timestamp | **true** | ETL update timestamp (UTC) |

#### Dataset: dim_customer_history_vw (DIMENSION)
Source: `customer360.dim_customer_history_vw` | DDL: `repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/dim-customer-history-vw/table.ddl`

| Column | Type | is_time | Description |
|---|---|---|---|
| customer_id | string | false | PK: Customer UUID (SCD2 PK with effective_start_mst_ts) |
| shopper_id | string | false | Shopper numeric ID |
| external_reseller_customer_id | int | false | External reseller customer ID |
| federation_partner_id | string | false | Federation partner ID (FPID) for brand-to-GoDaddy federation |
| federation_partner_name | string | false | Brand name associated with FPID |
| parent_customer_id | string | false | Parent customer UUID |
| parent_shopper_id | string | false | Parent shopper ID |
| private_label_id | int | false | Reseller/private label ID |
| company_flag | boolean | false | True if customer is a company |
| internal_shopper_flag | boolean | false | True if internal shopper |
| temporary_shopper_flag | boolean | false | True if temporary shopper |
| closed_shopper_flag | boolean | false | True if shopper account is closed |
| city_name | string | false | Customer city |
| state_code | string | false | Customer state code |
| zip_code | string | false | Customer ZIP code |
| country_code | string | false | Customer country code |
| email_domain_name | string | false | Customer email domain |
| email_hash | string | false | SHA hash of customer email |
| primary_phone_flag | boolean | false | Primary phone on file |
| mobile_phone_flag | boolean | false | Mobile phone on file |
| default_currency_code | string | false | Customer default currency |
| market_code | string | false | Customer market code |
| created_mst_ts | timestamp | **true** | Account creation timestamp (MST) |
| updated_mst_ts | timestamp | **true** | Account last updated timestamp (MST) |
| closed_mst_ts | timestamp | **true** | Account closed timestamp (MST) |
| effective_start_mst_ts | timestamp | **true** | SCD2 effective start timestamp |
| effective_end_mst_ts | timestamp | **true** | SCD2 effective end timestamp |
| current_record_flag | boolean | false | SCD2 current record flag (filter = true for current) |
| etl_build_mst_ts | timestamp | **true** | ETL build timestamp |
| etl_insert_mst_ts | timestamp | **true** | ETL insert timestamp |
| etl_update_mst_ts | timestamp | **true** | ETL update timestamp |

#### Dataset: dim_subscription_history (DIMENSION)
Source: `enterprise.dim_subscription_history` | DDL: `repos/lake/catalog/config/prod/us-west-2/enterprise/dim-subscription-history/table.ddl`

| Column | Type | is_time | Description |
|---|---|---|---|
| subscription_id | string | false | @UniqueKey: Native subscription identifier (PK for OSI join) |
| resource_id | bigint | false | Legacy CES resource identifier |
| product_type_id | int | false | Product type numeric ID |
| product_type_desc | string | false | Product type description (e.g., Domain Registration, Web Hosting) |
| product_family_name | string | false | Product family grouping name |
| shopper_id | string | false | Shopper owning the subscription |
| customer_id | string | false | @FK customer360.dim_customer_history_vw: Customer UUID |
| original_bill_id | string | false | @FK ecomm360.fact_bill_line_vw: Originating purchase bill ID |
| subscription_status_id | int | false | Subscription lifecycle status numeric code |
| subscription_status_name | string | false | Subscription lifecycle status name (e.g., active, cancelled, expired) |
| subscription_sub_status_name | string | false | Granular sub-status name |
| subscription_bill_due_mst_ts | timestamp | **true** | Next billing due date timestamp (MST) |
| subscription_bill_due_mst_date | date | **true** | Next billing due date (MST) |
| subscription_paid_through_mst_date | date | **true** | Paid-through date (end of active billing period) |
| auto_renewal_flag | boolean | false | Auto-renewal configured |
| subscription_cancel_mst_date | date | **true** | Cancellation date (null if not cancelled) |
| subscription_create_mst_ts | timestamp | **true** | Subscription creation timestamp (MST) |
| subscription_create_mst_date | date | **true** | Subscription creation date (MST) |
| transaction_currency_code | string | false | ISO 4217 transaction currency code |
| source_system_name | string | false | Source eCommerce system name |
| exclude_reason_desc | string | false | Exclusion reason for non-standard analyses |

---

### Step 7: Metrics

| Name | ANSI_SQL Expression | Description | Evidence |
|---|---|---|---|
| `total_ttm_gcr_usd` | `SUM(customer_life_cycle_vw.ttm_gcr_usd_amt)` | Total trailing twelve-month gross cash received (GCR) in USD across all customers | PySpark: `SUM(ttm_total_gcr_usd_amt)` aggregation (WHERE trxn_currency_code <> 'N/A'); Alation description: "Trailing twelve month (TTM) GCR" listed as key feature |
| `active_customer_count` | `COUNT(DISTINCT CASE WHEN customer_life_cycle_vw.active_status_flag = TRUE THEN customer_life_cycle_vw.customer_id END)` | Number of distinct active customers at evaluation date (not churned or intraday) | PySpark: `active_status_flag = customer_status NOT IN ('churned','intraday')`; Confluence: active customer lifecycle state; Alation: lifecycle state tracking |
| `churned_customer_count` | `COUNT(DISTINCT CASE WHEN customer_life_cycle_vw.customer_state_enum = 'churned' THEN customer_life_cycle_vw.customer_id END)` | Number of customers with churned lifecycle state at evaluation date | PySpark: `customer_state_enum` explicit 'churned' enum value; Confluence: churn = "user turns from Paid to Free trial, or service lapses" |
| `avg_customer_tenure_years` | `AVG(customer_life_cycle_vw.customer_tenure_year_count)` | Average customer tenure in years across all customers | PySpark: `CAST(DATEDIFF(eval_date, acq_date) / 365 AS INT)` → `customer_tenure_year_count`; Confluence: `customer_tenure_year_count` = shopper_tenure_days / 365 |
| `unique_customer_count` | `COUNT(DISTINCT customer_life_cycle_vw.customer_id)` | Total distinct customers in snapshot for a given evaluation date | Grain is one row per customer per eval date; DQ PK constraint: (partition_eval_mst_date, shopper_id) |

---

### Step 8: Semantic Model Metadata

**Model name:** `customer360_customer_life_cycle_analytics`
- Derived from schema `customer360` + table `customer_life_cycle` + suffix `analytics`
- No `semantic_model_name` override provided in INPUT.md

**Model description:**
> Daily snapshot model tracking the complete lifecycle journey of GoDaddy customers from acquisition through active, churned, reactivated, merged, and fraud states. Captures per-customer trailing twelve-month GCR, active subscription inventory, reseller context, geographic attributes, and lifecycle event dates. Primary OSI and OWL target in the Customer360 domain (35% domain weight). Stakeholders: Finance and Marketing (business stewards), DAP, FORGE. Data tier: 4. Delivered daily by 08:00 AM MST.

**ai_context draft:**
```
instructions: >
  Use this model to analyze GoDaddy customer lifecycle states, acquisition channels,
  retention/churn, trailing twelve-month revenue (TTM GCR), and active subscription
  inventory. The fact dataset is partitioned by partition_eval_mst_date — always filter
  on this column for performance. customer_state_enum enumerates five states:
  active, churned, reactivated, merged, intraday. For geographic analysis, join
  dim_country_vw on customer_acquisition_country_code = country_code (and filter
  current_record_flag = true). For reseller analysis, join dim_reseller on reseller_type_id.
  For customer profile details, join dim_customer_history_vw on customer_id (filter
  current_record_flag = true for current state). The active_paid_subscription_list column
  is an array — use UNNEST/LATERAL to join to dim_subscription_history.
  Do NOT use customer_core_conformed.* staging tables as data sources.
synonyms:
  - "customer lifecycle"
  - "customer churn"
  - "active customers"
  - "customer acquisition"
  - "customer retention"
  - "TTM GCR"
  - "trailing twelve month revenue"
  - "customer 360"
  - "customer state"
  - "customer cohort"
  - "C360"
examples:
  - "How many customers churned last month?"
  - "What is the average customer tenure by acquisition channel?"
  - "What is the total TTM GCR for US customers?"
  - "Show me the count of active customers by reseller type"
  - "Which acquisition channels produce the highest-tenure customers?"
  - "What percentage of customers acquired this quarter are still active?"
  - "How many customers were reactivated in Q1 2026?"
  - "What is the product P&L category mix for active customers in Europe?"
```

**Ownership / SLA (for custom_extensions):**
- Owner: `customer360` team, `dl-bi-enterprise-data@godaddy.com`
- On-call Slack: `#marketing-data-product-engineering`
- DAG ID: `customer-life-cycle`
- Schedule: `20 7 * * *` (7:20 AM MST daily)
- SLA delivery: `cron(00 15 * * ? *)` — by 08:00 AM MST
- Data tier: 4 (TIER_4 severity)

---

### Step 9: "Do Not Claim" List

Items tempting but NOT proven or not appropriate for OSI model:

| Item | Why Excluded |
|---|---|
| `customer_core_conformed.*` tables as OSI dataset sources | Not in lake catalog; internal ETL drivers; violates OSI lake-table-only rule |
| `customer_type_history` as an OSI dimension | `customer_type_name` and `customer_type_reason_desc` already denormalized into fact; redundant dimension |
| `customer_fraud` as an OSI dimension | `customer_fraud_flag` and `customer_fraud_mst_date` already in fact; no additive value |
| `shopper_merge` as an OSI dimension | Identity resolution detail; `customer_merge_mst_date` already in fact |
| `ecomm_mart.bill_line_traffic_ext` as OSI dimension | Granular bill-level traffic table; `customer_acquisition_channel_name` already in fact |
| `ecomm_mart.dim_bill_line_purchase_attribution` as OSI dimension | `point_of_purchase_name` already in fact |
| `finance360.dim_bill_fraud_history_vw` as OSI dimension | `customer_acquisition_bill_fraud_flag` already in fact |
| `enterprise.dim_new_acquisition_shopper` as OSI dimension | Acquisition computation input; acquisition attributes already denormalized |
| Legacy S3 `ads_bill_line_ext` as data source | Hardcoded prod S3 path; not a lake table; pre-2022-08 legacy data only |
| Redshift `customer360.customer_life_cycle` as OSI target | Downstream copy; not a lake table |
| `customer_tenure_year_count` as string | Alation reports string type, but DDL and PySpark cast to int; Alation is stale |
| Extra upstream tables in `table.yaml` lineage | `customers.customer_id_mapping_snapshot`, `ecomm_mart.entitlement_bill_type`, etc. appear in lake lineage YAML but NOT in current PySpark code; likely historical artifacts |
| SLA = N/A | DAG documentation markdown says N/A; contradicted by policy YAML (120 min) and lake table.yaml SLA cron; documentation is incomplete |
| Array FK as standard OSI scalar relationship | `active_paid_subscription_list → dim_subscription_history.subscription_id` requires UNNEST; not a standard scalar FK; flag for careful YAML treatment |


**The agent's final response to the user was:**
The analysis stage is complete. Here's a summary of what was done:

---

## Analysis Summary

### Target Table Resolved
**`customer360.customer_life_cycle_vw`** — confirmed `high` confidence from:
- Lake registry at `dlms-api/us-west-2/customer360/customer-life-cycle-vw/`
- DAG `SuccessNotificationOperator` (prod-only lake view promotion)
- Internal staging table `customer_core_conformed.customer_life_cycle` is **not** the OSI target

### Lineage Resolution (16 sources)
- **12 lake tables** confirmed in `repos/lake/` (analytic_feature, enterprise, ecomm_mart, finance360, dp_enterprise, customer360)
- **3 internal driver tables** (`customer_core_conformed.*`) — NOT lake tables; produced by sibling pipelines; excluded from OSI sources
- **1 legacy S3 path** — hardcoded prod S3; unresolved/excluded

### OSI Datasets (6)
| Dataset | Role | Source |
|---|---|---|
| `customer_life_cycle_vw` | FACT | `customer360.customer_life_cycle_vw` |
| `shopper_acquisition` | DIM | `analytic_feature.shopper_acquisition` |
| `dim_reseller` | DIM | `dp_enterprise.dim_reseller` |
| `dim_country_vw` | DIM | `finance360.dim_country_vw` |
| `dim_customer_history_vw` | DIM | `customer360.dim_customer_history_vw` |
| `dim_subscription_history` | DIM | `enterprise.dim_subscription_history` |

### 5 Relationships, 5 Metrics, Full Field Inventory
All documented in `analyze.md` with DDL-sourced column types and `is_time` flags.

### Outputs Written
- `analyze.md` — full structured analysis appended (Steps 2–9)
- `RESOLVED_TARGET.json` — high-confidence target resolution for downstream YAML generation