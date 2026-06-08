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
- **Materialized direct-reads table**: | Lake Table | materialized_in_fields | evidence | — lake tables read by the PySpark job whose values are fully denormalized onto the fact (no join key back to source)
- **Excluded dimensions table**: | Lake Table | reason | fields_on_fact | — direct-read lake tables NOT included as OSI datasets (e.g. no FK in fact)
- **Relationship table**: | name | from | to | from_columns | to_columns | evidence |
- **Field inventory per dataset**: columns, types, is_time, descriptions
- **Metrics table**: | name | expression | description | evidence |
- **Semantic model metadata**: name, description, ai_context draft
- **Do-not-claim table**: | item | reason | preserve_as | — items that must NOT become OSI datasets, relationships, or metrics; `preserve_as` is one or more of: `field_description`, `ai_context`, `custom_extensions`

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

## Step 11: Write PROVENANCE.json (required)
Create `PROVENANCE.json` in workspace root. This is the machine-readable contract for
preserving do-not-claim lineage in the OSI YAML without adding non-joinable datasets.
See `docs/osi-spec-reference.md` for the GODADDY custom_extensions schema.

```json
{
  "grain": "one row per (shopper_id, partition_eval_mst_date)",
  "primary_key_notes": "Composite PK; customer_id is not unique and may be null",
  "partition_filter": "partition_eval_mst_date",
  "intermediate_tables": [
    {
      "table": "customer_core_conformed.active_customer_stg",
      "role": "staging",
      "upstream_pyspark": "customer360/active-customer/src/pyspark/active_customer_stg.py"
    }
  ],
  "transitive_sources": [
    {
      "table": "enterprise.dim_subscription_history",
      "via": "customer_core_conformed.customer_active_subscription_detail_driver",
      "materialized_in_fields": ["active_paid_subscription_list"]
    }
  ],
  "materialized_direct_reads": [
    {
      "table": "analytic_feature.customer_type_history",
      "materialized_in_fields": ["customer_type_name", "customer_type_reason_desc"]
    }
  ],
  "excluded_dimensions": [
    {
      "table": "analytic_feature.customer_fraud",
      "reason": "no_join_key_in_fact",
      "fields_on_fact": ["customer_fraud_flag", "customer_fraud_mst_date"]
    }
  ],
  "array_fields": [
    {
      "field": "active_paid_subscription_list",
      "scalar_proxy": "product_pnl_category_qty",
      "note": "not suitable for OSI aggregate metrics; use scalar proxy fields instead"
    }
  ],
  "legacy_sources": [
    {
      "path": "s3://gd-ckpetlbatch-prod-analytic/analytic/ads_bill_line_ext/",
      "equivalent": "ecomm_mart.bill_line_traffic_ext",
      "condition": "pre-2022-08 partitions only"
    }
  ],
  "do_not_claim": [
    {
      "item": "customer_core_conformed.active_customer_stg as OSI dataset",
      "reason": "intermediate staging table not in lake catalog",
      "preserve_as": "custom_extensions"
    }
  ]
}
```

Use empty arrays `[]` for sections with no entries. Every do-not-claim item from Step 9
must appear in `do_not_claim` with a `preserve_as` value.

**The agent summarized its work in this way:**

---

## Stage: Analyze — customer360 / customer-metric-daily-agg-vw

**Date:** 2026-06-05
**PySpark:** `customer360/customer-metrics/src/pyspark/customer_metric_daily_agg.py`
**OSI Spec:** v0.2.0.dev0

---

### Step 2: Target Table Resolution

| Field | Value | Evidence |
|---|---|---|
| Intermediate Hive table | `customer_core_conformed.customer_metric_daily_agg` | PySpark `insertInto('customer_core_conformed.customer_metric_daily_agg', overwrite=True)` |
| **Lake-registered table (OSI target)** | **`customer360.customer_metric_daily_agg_vw`** | DAG `SuccessNotificationOperator`; lake catalog path confirmed |
| Lake catalog path | `dlms-api/us-west-2/customer360/customer-metric-daily-agg-vw/` | `repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/customer-metric-daily-agg-vw/table.yaml` |
| Non-dlms path | Does NOT exist | Checked `us-west-2/customer360/customer-metric-daily-agg-vw/` — absent |
| Lake table override | None provided in INPUT.md | No conflict |
| Grain | One row per `partition_eval_mst_date` × unique combination of 18 dimension columns | PySpark GROUP BY on 19 columns; DQ `isPrimaryKey` check on 19 columns |
| Partition column | `partition_eval_mst_date` (string) | `table.yaml` `partition_keys`; PySpark `insertInto` overwrite |
| S3 location | `s3://gd-ckpetlbatch-prod-customer-core-conformed/customer_core_conformed/customer_metric_daily_agg/` | `gather.md` §1, `environment.prod.yaml` |

---

### Step 3: Lineage Resolution

| Table Reference in PySpark | Role | Lake Table | Lake Catalog Path | Status |
|---|---|---|---|---|
| `customer_core_conformed.customer_metric_daily_agg` | WRITE target (Hive staging) | `customer360.customer_metric_daily_agg_vw` | `dlms-api/us-west-2/customer360/customer-metric-daily-agg-vw/` | ✅ RESOLVED |
| `customer_core_conformed.customer_life_cycle` | READ source | `customer360.customer_life_cycle_vw` | `dlms-api/us-west-2/customer360/customer-life-cycle-vw/` | ✅ RESOLVED |

**Resolution notes:**
- `customer_core_conformed.customer_metric_daily_agg` is NOT in the lake catalog directly. Its lake-registered public view is `customer360.customer_metric_daily_agg_vw` (confirmed by lake `table.yaml`, DAG `SuccessNotificationOperator`, and gather.md §1).
- `customer_core_conformed.customer_life_cycle` is NOT in the lake catalog directly. Its lake-registered public view is `customer360.customer_life_cycle_vw` (confirmed by lake `table.yaml` at `dlms-api/us-west-2/customer360/customer-life-cycle-vw/`).
- PySpark line 228 has a **commented-out** reference to `customer360.customer_life_cycle_vw`; the active read is `customer_core_conformed.customer_life_cycle`. Code is authoritative.
- DAG S3KeySensor waits for `customer360/customer_life_cycle_vw/{YYYY}/{MM}/{DD}/_SUCCESS` as a readiness gate — this is not the actual PySpark read target.
- No staging tables, transitive upstream sources, or legacy S3 paths used by this PySpark script beyond the single source table.

---

### Step 4: Dataset Classification

| Lake Table | OSI Dataset Name | Role (fact/dim) | source | primary_key |
|---|---|---|---|---|
| `customer360.customer_metric_daily_agg_vw` | `customer_metric_daily_agg` | **fact** — primary write target; contains all pre-aggregated metrics | `customer360.customer_metric_daily_agg_vw` | Composite 19-column PK (see Step 6) |
| `customer360.customer_life_cycle_vw` | — | **excluded** — upstream aggregation source; no FK from fact | — | — |

**Classification reasoning:**
- `customer_metric_daily_agg_vw` is the primary fact dataset: it holds all pre-aggregated customer metrics (counts, GCR, churn, acquisitions, etc.) broken down by 18 reporting dimensions.
- `customer_life_cycle_vw` is the upstream source from which the fact was aggregated via GROUP BY. It has **no FK relationship** into the fact table — the fact table has no `customer_id` or `shopper_id` column. A full join back to `customer_life_cycle_vw` would require all 18 dimension columns including array columns needing `cast(sort_array(...) as string)` — this is not a standard FK join. Excluded from OSI datasets.

---

### Materialized Direct-Reads Table

| Lake Table | materialized_in_fields | evidence |
|---|---|---|
| *(none)* | — | No direct-read lake tables identified. The only source is `customer_core_conformed.customer_life_cycle` (= `customer360.customer_life_cycle_vw`), which is GROUP BY aggregated — not denormalized — into the fact. All dimension values in the fact originate from this single source. |

---

### Excluded Dimensions Table

| Lake Table | reason | fields_on_fact |
|---|---|---|
| `customer360.customer_life_cycle_vw` | `no_join_key_in_fact` — fact has no customer_id/shopper_id; full join requires 18-column composite key including `product_ownership_category_list`, `product_ownership_line_list`, `brand_name_list` with `cast(sort_array(...) as string)` — not a standard FK | customer_type_reason_desc, customer_acquisition_mst_month, customer_domestic_international_name, customer_region_1_name, customer_region_2_name, customer_region_3_name, customer_country_name, customer_country_code, customer_type_name, acquisition_channel_name, customer_tenure_year_count, product_ownership_category_list, product_ownership_line_list, reseller_type_name, fraud_flag, point_of_purchase_name, customer_acquisition_bill_fraud_flag, brand_name_list, partition_eval_mst_date |

---

### Step 5: Relationship Table

| name | from | to | from_columns | to_columns | evidence |
|---|---|---|---|---|---|
| *(none)* | — | — | — | — | The only join in the PySpark is a LEFT ANTI JOIN on two intermediate CTEs (`candidates_next_day` LEFT ANTI JOIN `daily_metrics`) — both derived from `customer_core_conformed.customer_life_cycle` itself (self-join). No cross-table FK join exists between distinct lake tables. `customer_life_cycle_vw` feeds the fact via GROUP BY aggregation, not via FK. |

**OSI impact:** The `relationships` array in the YAML will be omitted (empty).

---

### Step 6: Field Inventory

#### Dataset: `customer_metric_daily_agg` (source: `customer360.customer_metric_daily_agg_vw`)

DDL source: `repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/customer-metric-daily-agg-vw/table.ddl` (authoritative for lake schema)
Supplemented by: in-repo `src/ddls/customer_metric_daily_agg.ddl` and PySpark `conform_datatype()` for `data_source_enum` discrepancy.

| # | column_name | type | PK | partition | is_time | expression | description |
|---|---|---|---|---|---|---|---|
| 1 | customer_type_reason_desc | string | ✓ | | | customer_type_reason_desc | Reason for customer type classification; default `'Not Classified'` |
| 2 | customer_acquisition_mst_month | string | ✓ | | ✓ | customer_acquisition_mst_month | Month of customer acquisition (MST), as yyyy-MM; default `''` |
| 3 | customer_domestic_international_name | string | ✓ | | | customer_domestic_international_name | Domestic vs International classification; default `'International'` |
| 4 | customer_region_1_name | string | ✓ | | | customer_region_1_name | Geographic region level 1; default `'International - RoW'` |
| 5 | customer_region_2_name | string | ✓ | | | customer_region_2_name | Geographic region level 2; default `'Rest of World (RoW)'` |
| 6 | customer_region_3_name | string | ✓ | | | customer_region_3_name | Geographic region level 3; default `'NA'` |
| 7 | customer_country_name | string | ✓ | | | customer_country_name | Customer country name at evaluation date; source: customer_acquisition_country_name; default `'Unknown'` |
| 8 | customer_country_code | string | ✓ | | | customer_country_code | Customer country code at evaluation date (ISO; UK normalized to GB); source: customer_acquisition_country_code; default `'--'` |
| 9 | customer_type_name | string | ✓ | | | customer_type_name | Customer type at evaluation date; default `'Not Classified'` |
| 10 | acquisition_channel_name | string | ✓ | | | acquisition_channel_name | Acquisition channel; source: customer_acquisition_channel_name; default `'Not GA Attributed'` |
| 11 | customer_tenure_year_count | int | ✓ | | | customer_tenure_year_count | Customer tenure in years (integer); default 0 |
| 12 | product_ownership_category_list | string | ✓ | | | product_ownership_category_list | Owned product category list (string-encoded sorted array); source: product_pnl_category_list |
| 13 | product_ownership_line_list | string | ✓ | | | product_ownership_line_list | Owned product line list (string-encoded sorted array); source: product_pnl_line_list |
| 14 | reseller_type_name | string | ✓ | | | reseller_type_name | Reseller type name; default `'na'` (coalesced in join) |
| 15 | fraud_flag | boolean | ✓ | | | fraud_flag | True if customer marked as fraud as of evaluation date; source: customer_fraud_flag; default false |
| 16 | brand_name_list | string | ✓ | | | brand_name_list | List of all brands associated with the customer (string-encoded sorted array) |
| 17 | product_category_qty | int | | | | product_category_qty | Number of owned product categories; coalesce(size(product_ownership_category_list), 0) |
| 18 | ttm_gcr_usd_amt | decimal(18,2) | | | | ttm_gcr_usd_amt | Total gross cash received (GCR) in USD over trailing twelve months; SUM-aggregated from life_cycle |
| 19 | ending_customer_qty | bigint | | | | ending_customer_qty | Active customer count at end of evaluation date; COUNT_IF(active_status_flag = true) |
| 20 | churn_customer_qty | bigint | | | | churn_customer_qty | Customers churned on evaluation date; COUNT_IF(customer_churn_mst_date is not null) |
| 21 | merge_customer_qty | bigint | | | | merge_customer_qty | Customers merged on evaluation date; COUNT_IF(customer_merge_mst_date is not null) |
| 22 | new_customer_qty | bigint | | | | new_customer_qty | New customers on evaluation date; COUNT_IF(customer_acquisition_mst_date = partition_eval_mst_date) |
| 23 | reactivate_customer_qty | bigint | | | | reactivate_customer_qty | Reactivated customers on evaluation date; COUNT_IF(customer_reactivate_mst_date is not null) |
| 24 | beginning_customer_qty | bigint | | | | beginning_customer_qty | Active customer count at beginning of evaluation date (prior day's ending); LAG(ending_customer_qty, 1) |
| 25 | net_move_qty | bigint | | | | net_move_qty | Net customer movement: ending - beginning - new + (churn - reactivate) + merge |
| 26 | net_add_qty | bigint | | | | net_add_qty | Net additions: ending - beginning |
| 27 | net_churn_qty | bigint | | | | net_churn_qty | Net churn: churned - reactivated |
| 28 | point_of_purchase_name | string | ✓ | | | point_of_purchase_name | Point of purchase name from acquisition bill; default `'Unknown'` |
| 29 | customer_acquisition_bill_fraud_flag | boolean | ✓ | | | customer_acquisition_bill_fraud_flag | True if acquisition bill has fraud record; default false |
| 30 | etl_build_mst_ts | timestamp | | | ✓ | etl_build_mst_ts | ETL build timestamp in MST; from_utc_timestamp(current_timestamp(), 'MST') |
| 31 | partition_eval_mst_date | string | ✓ | ✓ | ✓ | partition_eval_mst_date | Evaluation date in MST (yyyy-MM-dd); partition key; required filter for point-in-time queries |

**Primary key discrepancy note:** Lake DDL `@PrimaryKey` annotations cover only 16 columns (columns 1–16; omits `point_of_purchase_name`, `customer_acquisition_bill_fraud_flag`, and `partition_eval_mst_date`). DQ constraint `isPrimaryKey` (both local and lake JSON files) and PySpark GROUP BY are authoritative — all 19 columns form the composite PK. OSI model uses 19-column PK.

**Missing column — `data_source_enum`:** Present in in-repo DDL (`src/ddls/customer_metric_daily_agg.ddl`) and PySpark `conform_datatype()` as hardcoded `'customer360'`. **Absent from lake-registered DDL** (`table.ddl`). Not included as an OSI field. See do-not-claim table.

---

### Step 7: Metrics Table

All metrics computed over dataset `customer_metric_daily_agg` (source: `customer360.customer_metric_daily_agg_vw`).

| # | name | expression (ANSI_SQL) | description | additivity | evidence |
|---|---|---|---|---|---|
| 1 | ending_customer_qty | `SUM(customer_metric_daily_agg.ending_customer_qty)` | Total active customers at end of evaluation date | **Point-in-time** — additive across dimension combinations for a single date; do NOT sum across multiple dates (double-counting) | PySpark: `COUNT_IF(active_status_flag = true)` |
| 2 | beginning_customer_qty | `SUM(customer_metric_daily_agg.beginning_customer_qty)` | Total active customers at beginning of evaluation date (prior day's ending count) | **Point-in-time** — same additivity caution as ending_customer_qty | PySpark: `LAG(ending_customer_qty, 1) OVER (PARTITION BY <18 dims> ORDER BY partition_eval_mst_date)` |
| 3 | new_customer_qty | `SUM(customer_metric_daily_agg.new_customer_qty)` | Total new customers acquired on evaluation date | **Period-additive** — can be summed across date ranges | PySpark: `COUNT_IF(customer_acquisition_mst_date = partition_eval_mst_date)` |
| 4 | churn_customer_qty | `SUM(customer_metric_daily_agg.churn_customer_qty)` | Total customers churned on evaluation date | **Period-additive** | PySpark: `COUNT_IF(customer_churn_mst_date is not null)` |
| 5 | reactivate_customer_qty | `SUM(customer_metric_daily_agg.reactivate_customer_qty)` | Total customers reactivated on evaluation date | **Period-additive** | PySpark: `COUNT_IF(customer_reactivate_mst_date is not null)` |
| 6 | merge_customer_qty | `SUM(customer_metric_daily_agg.merge_customer_qty)` | Total customers merged (account merge) on evaluation date | **Period-additive** | PySpark: `COUNT_IF(customer_merge_mst_date is not null)` |
| 7 | net_add_qty | `SUM(customer_metric_daily_agg.net_add_qty)` | Net customer additions over period (ending minus beginning) | **Period-additive** | PySpark derived: `ending_customer_qty - beginning_customer_qty` |
| 8 | net_churn_qty | `SUM(customer_metric_daily_agg.net_churn_qty)` | Net churn (churned minus reactivated) | **Period-additive** | PySpark derived: `churn_customer_qty - reactivate_customer_qty` |
| 9 | net_move_qty | `SUM(customer_metric_daily_agg.net_move_qty)` | Net customer movement: ending − beginning − new + (churn − reactivate) + merge | **Period-additive** | PySpark derived formula |
| 10 | ttm_gcr_usd_amt | `SUM(customer_metric_daily_agg.ttm_gcr_usd_amt)` | Total trailing 12-month gross cash received in USD | **NOT date-additive** — TTM windows overlap across dates. Use only with a single-date filter on partition_eval_mst_date. | PySpark: `SUM(ttm_gcr_usd_amt)` from life_cycle; Confluence: "business-ready GCR metrics" |
| 11 | product_category_qty | `SUM(customer_metric_daily_agg.product_category_qty)` | Total distinct product categories owned across dimension group | **Additive across dimension groups** for a single date | PySpark: `coalesce(size(product_ownership_category_list), 0)` |

---

### Step 8: Semantic Model Metadata

| Field | Value | Source |
|---|---|---|
| Model name | `customer360_customer_metric_daily_agg` | Derived: schema=customer360 + table=customer_metric_daily_agg_vw; no override in INPUT.md |
| Description | "Daily aggregated customer performance metrics by reporting dimensions. Provides KPIs including active, new, churned, reactivated, and merged customer counts; net movement; and trailing 12-month gross cash received (GCR), segmented by customer type, geography, product ownership, acquisition channel, tenure, reseller type, and fraud status." | Confluence (Business Metrics Layer), Alation description, lake `table.yaml` description |
| Domain | Customer | DAG tags: `domain:customer` |
| Sub-domain | Active Customer | DAG tags: `sub-domain:active-customer` |
| Data tier | 4 | lake `table.yaml` `data_tier: 4` |
| Refresh cadence | Daily at 07:30 MST (`30 7 * * *`) | DAG schedule |
| SLA delivery | 08:00 AM MST (`cron(00 15 * * ? *)` UTC) | lake `table.yaml` SLA |
| Owner | customer360 (EDT — Emerald Data Team) | DAG owner + tags |

**ai_context draft:**

```yaml
ai_context:
  instructions: >
    Use this model for analyzing pre-aggregated daily customer performance metrics.
    Always filter by partition_eval_mst_date to avoid full table scans (required
    partition filter). Ending and beginning customer counts are point-in-time snapshots
    — do not sum across multiple dates (double-counts). Flow metrics (new_customer_qty,
    churn_customer_qty, reactivate_customer_qty, merge_customer_qty, net_add_qty,
    net_churn_qty, net_move_qty) are period-additive and may be summed across date
    ranges. ttm_gcr_usd_amt reflects a trailing 12-month window from each evaluation
    date — do not sum across multiple dates. Dimension columns represent GROUP BY
    attributes from the customer life-cycle base table; product_ownership_category_list,
    product_ownership_line_list, and brand_name_list are string-encoded sorted arrays,
    not filterable as lists.
  synonyms:
    - "customer metrics"
    - "daily customer KPIs"
    - "customer scorecard"
    - "active customers"
    - "customer churn metrics"
    - "customer acquisition metrics"
    - "GCR by customer segment"
    - "customer lifecycle metrics"
    - "customer health metrics"
    - "business metrics layer"
  examples:
    - "How many customers churned last month by region?"
    - "What is the ending active customer count by customer type as of yesterday?"
    - "Show net new customer additions by acquisition channel for Q1 2025"
    - "What is the TTM gross cash received by country for the most recent date?"
    - "How many customers were reactivated last week by reseller type?"
    - "What is the daily net add trend for domestic customers over the past 90 days?"
    - "Which customer type had the highest churn rate on a given date?"
```

---

### Step 9: Do-Not-Claim Table

| item | reason | preserve_as |
|---|---|---|
| `customer_core_conformed.customer_metric_daily_agg` as OSI dataset | Intermediate Hive staging table; NOT in lake catalog; lake-registered equivalent is `customer360.customer_metric_daily_agg_vw` | `custom_extensions` |
| `customer_core_conformed.customer_life_cycle` as OSI dataset | Intermediate Hive table; NOT in lake catalog; lake-registered equivalent is `customer360.customer_life_cycle_vw` | `custom_extensions` |
| `customer360.customer_life_cycle_vw` as OSI dataset | Upstream aggregation source with no FK in fact table (fact has no customer_id/shopper_id); join requires 18-column composite key with complex array cast/sort_array expressions — not a standard FK join; including it would create a non-joinable orphan dataset | `custom_extensions` |
| `data_source_enum` as OSI field | Hardcoded `'customer360'` in PySpark `conform_datatype()` and in-repo DDL; absent from lake-registered DDL (`table.ddl`); not a useful dimension or metric | `field_description` |
| `active_paid_subscription_list` (life_cycle field) as OSI field or metric | Array field in source `customer_life_cycle_vw`; aggregated away in GROUP BY — not present in fact table; not suitable for OSI aggregate metrics | `ai_context` |
| `ttm_all_bill_list` (life_cycle field) as OSI field or metric | Array field in source `customer_life_cycle_vw`; aggregated away in GROUP BY — not present in fact table | `ai_context` |
| Redshift staging tables (`customer360.customer_metric_daily_agg` in Redshift) as OSI dataset | Redshift analytic copy; not a lake table; ETL staging target only | `custom_extensions` |
| LEFT ANTI JOIN self-join pattern as OSI relationship | Internal ETL pattern to backfill zero-valued rows for dimension combinations missing on a given date; not a semantic dataset-to-dataset relationship | `ai_context` |
| `customer_fraud_mst_date` as OSI field or metric | Column exists in `customer_life_cycle_vw` but NOT in `customer_metric_daily_agg_vw`; aggregated away in GROUP BY | `ai_context` |
| `customer_state_enum` as OSI field or metric | Column exists in `customer_life_cycle_vw` but NOT in `customer_metric_daily_agg_vw`; aggregated away | `ai_context` |

---

### Conflicts / Discrepancies Carried Forward

| # | Description | Impact on OSI model |
|---|---|---|
| 1 | Lake DDL omits `data_source_enum`; in-repo DDL and PySpark include it as hardcoded `'customer360'` | Excluded from OSI fields; recorded in do-not-claim and PROVENANCE.json |
| 2 | Lake DDL `@PrimaryKey` marks 16 columns; DQ constraints and PySpark GROUP BY use 19 | OSI uses 19-column PK (DQ + code are authoritative) |
| 3 | Lake DDL column order differs from in-repo DDL for `brand_name_list`, `point_of_purchase_name`, `customer_acquisition_bill_fraud_flag` | OSI field order follows lake DDL (authoritative for lake schema) |
| 4 | Policy YAML and lake `table.yaml` lineage list `customer360.customer_life_cycle_vw` as upstream; PySpark reads `customer_core_conformed.customer_life_cycle` | Code is authoritative for lineage; both resolve to same lake table |
| 5 | Alation description uses stale column names (`shopper_tenure_year_count`, `churned_customer_qty`, `reactivated_customer_qty`) | Alation text not used for OSI field names; code/DDL is authoritative |

---

*Analysis completed by: Analyze agent — 2026-06-05*

**The agent's final response to the user was:**
Here is a summary of the research and analysis performed:

---

## Analysis Summary — `customer360 / customer-metric-daily-agg-vw`

### What was done

**Step 2 — Target table resolved (high confidence):**
- PySpark writes to `customer_core_conformed.customer_metric_daily_agg` (Hive/Parquet)
- Lake-registered equivalent: **`customer360.customer_metric_daily_agg_vw`** — confirmed in `repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/customer-metric-daily-agg-vw/`
- Grain: one row per `partition_eval_mst_date` × 18-dimension combination (19-column composite PK)

**Step 3 — Lineage fully resolved:**
- Both referenced tables (`customer_core_conformed.customer_metric_daily_agg` and `customer_core_conformed.customer_life_cycle`) have no lake catalog entries directly, but both map to lake tables in `dlms-api/us-west-2/customer360/`: `customer_metric_daily_agg_vw` and `customer_life_cycle_vw` respectively.

**Step 4 — Dataset classification:**
- **1 fact dataset**: `customer360.customer_metric_daily_agg_vw`
- **`customer360.customer_life_cycle_vw` excluded**: it's the upstream aggregation source but has no FK in the fact table. A join back would require an 18-column composite key including array columns with `cast(sort_array(...) as string)` — not a standard FK. Excluded from OSI datasets.

**Step 5 — No OSI relationships:** The only join in the PySpark is a LEFT ANTI self-join between intermediate CTEs (to fill zero-rows for missing days). No cross-table FK joins exist.

**Step 6 — 31 fields mapped** (30 from lake DDL + `partition_eval_mst_date`). `data_source_enum` (present in in-repo DDL/PySpark but absent from lake DDL) goes to do-not-claim.

**Step 7 — 11 metrics identified** from PySpark aggregations: 5 direct COUNT_IF measures, 1 SUM, 3 derived post-aggregation calculations, plus `product_category_qty` and LAG-based `beginning_customer_qty`. Additivity cautions documented for point-in-time vs. period-additive metrics.

**Steps 10–11 — Artifacts written:**
- `RESOLVED_TARGET.json` — `customer360/customer-metric-daily-agg-vw`, high confidence, 6 evidence citations
- `PROVENANCE.json` — 2 intermediate tables, 1 excluded dimension, 3 array fields, 10 do-not-claim items