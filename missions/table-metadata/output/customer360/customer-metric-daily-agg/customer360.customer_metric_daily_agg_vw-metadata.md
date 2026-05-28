# Business Context: customer360.customer_metric_daily_agg_vw

## Pillar A: WHAT Is It? — Identity & Purpose

### A1. Table Overview

| Field | Value |
|---|---|
| **Table Name** | `customer_metric_daily_agg_vw` |
| **Database** | Redshift – customer360 schema (prod) |
| **Schema** | `customer360` |
| **Alation URL** | *(Skipped — Alation credentials not available at generation time)* |
| **Lake Alation URL** | *(Skipped — Alation credentials not available at generation time)* |
| **Lake Table** | `customer360.customer_metric_daily_agg_vw` |
| **Intermediate Hive Table** | `customer_core_conformed.customer_metric_daily_agg` |
| **Grain** | One row per `partition_eval_mst_date` × unique combination of all 18 reporting dimension columns |
| **Partition Key** | `partition_eval_mst_date` (string, YYYY-MM-DD) |
| **Storage Format** | Parquet (zstd compression) |
| **Data Tier** | 4 |
| **SLA Delivery** | By 08:00 AM MST daily |
| **Refresh Cadence** | Daily — DAG triggers at 07:30 AM MST |
| **Lake Registry Path** | `catalog/config/prod/dlms-api/us-west-2/customer360/customer-metric-daily-agg-vw/` |
| **DAG ID** | `customer-metric-daily-agg` |
| **Domain / Sub-domain** | Customer / Active Customer |

### A2. What This Table Is About

`customer_metric_daily_agg_vw` is a daily aggregated customer metrics table that captures how a company's active customer population changes each day. For each unique combination of reporting dimensions (geography, customer type, acquisition channel, product ownership, tenure, fraud flags, etc.), it records how many customers were active at the start and end of each day, how many were newly acquired, churned, reactivated, or merged, and what their aggregate trailing-twelve-month gross cash received (TTM GCR) was.

**Official description (lake registry):** "Customer Metric Daily Aggregated on Reporting Dims for a given day."

The table is part of the **Customer360 Business Metrics Layer**, which provides business-ready metrics for reporting and analytics. It supersedes the legacy datasets `customer_mart.daily_active_customers` and `customer_mart.monthly_active_customers`. Per the Customer360 Confluence guidance: *"use 360 barring hour latency needs."*

**Key characteristics:**
- **Gap-fill rows** are included: dimension combinations present on the prior day but absent on the current day receive zero-valued metric rows. This ensures continuous time-series integrity for window computations.
- Country code "UK" is normalized to "GB" as a permanent ETL correction.
- `data_source_enum` is always `'customer360'` (a hardcoded constant identifying this pipeline as the source).

**In-progress feature (as of generation date):** NRU (New Registered User) and Lapsed user metrics are planned to co-exist with the current externally-reported metrics (Confluence page 3779199819, marked 🟡 in progress).

### A3. Organizational Context & Ownership

| Field | Value |
|---|---|
| **Team** | EDT (Enterprise Data Team) |
| **DAG Owner** | `customer360` |
| **Pipeline Group** | `active-customer` |
| **Domain Tag** | `domain:customer`, `sub-domain:active-customer`, `layer:enterprise` |
| **On-Call Slack** | `#marketing-data-product-engineering` |
| **Stakeholder Slack** | `#marketing-data-products-help` |
| **Alerts Channel (prod)** | `#edt-airflow-alerts` |
| **On-Call Email** | `dl-bi-enterprise-data@godaddy.com` |
| **SNOW Queue** | `DEV-EDT-OnCall` |
| **Business Stewards** | Finance, Marketing, DAP (per Confluence page 3779199819) |
| **Technical Stewards** | FORGE team / Data Products PgM (per Confluence page 3779199819) |

---

## Pillar B: WHY Does It Matter? — Value & Use Cases

### B1. Key Business Value

`customer_metric_daily_agg_vw` is the authoritative daily-resolution customer movement dataset for GoDaddy's Customer360 platform. It enables stakeholders to:

- **Monitor the active customer base** day-by-day across geography, product, acquisition channel, and customer type — without touching the full customer-level detail table.
- **Track customer lifecycle events** (acquisition, churn, reactivation, merge) aggregated by reporting dimension, at a much smaller query footprint than row-level tables.
- **Reconcile customer movements** using the `net_move_qty` metric (a bookkeeping identity: ending = beginning + new − churn + reactivate − merge + net_move).
- **Understand revenue concentration** across dimension groups via TTM GCR (`ttm_gcr_usd_amt`).
- **Replace two legacy tables** (`customer_mart.daily_active_customers`, `customer_mart.monthly_active_customers`) with a single, dimensionally richer, standardized dataset.

This table carries a **15% weight** in the overall Customer360 coverage matrix (Confluence page 4387965088), making it one of the four core datasets in the platform.

### B2. Primary Use Cases

- How many active customers does GoDaddy have today, broken down by country?
- How many new customers were acquired in a given date range, by acquisition channel?
- What is the daily churn count by customer type and geographic region?
- How does the active customer base in a specific country change month-over-month?
- Which product ownership categories have the highest TTM gross cash received?
- How many customers reactivated this week, grouped by customer tenure?
- What is the net change in the active customer base for a given country between two dates?
- Which reseller types have the highest customer acquisition volumes?
- How does fraud prevalence vary across customer segments day-by-day?
- What is the beginning-to-ending customer movement for a given dimension combination?

### B3. Advanced Analytics Use Cases

- **Cohort analysis:** Use `customer_acquisition_mst_month` to track customer retention and churn rates for acquisition cohorts over time.
- **Customer lifecycle funnel modeling:** Combine `new_customer_qty`, `churn_customer_qty`, `reactivate_customer_qty`, and `ending_customer_qty` to model lifecycle stage transitions per segment.
- **Revenue–customer correlation:** Join `ttm_gcr_usd_amt` with customer counts to derive revenue per customer estimates across dimensions.
- **Time-series anomaly detection:** The gap-fill design guarantees a continuous daily time series for every active dimension combination, making this table well-suited for ML-based anomaly detection on customer movement patterns.
- **Legacy migration validation:** Compare against `customer_mart.daily_active_customers` / `customer_mart.monthly_active_customers` to validate migration completeness during the transition period.

---

## Pillar C: HOW Do I Use It Correctly? — Schema, Rules & Guidance

### C1. Complete Column Reference with Data Insights

All columns originate from `customer360.customer_life_cycle_vw` except where noted. Column renames from the source are indicated in parentheses.

| # | Column | Type | Description | Source Table(s) | Notes |
|---|---|---|---|---|---|
| 1 | `customer_type_reason_desc` | string | Reason for customer type classification | `customer360.customer_life_cycle_vw` | Coalesced to `'Not Classified'` when null |
| 2 | `customer_acquisition_mst_month` | string | Month of customer acquisition (MST), truncated to month | `customer360.customer_life_cycle_vw` | Coalesced to `''` when null; exact format (YYYY-MM vs. YYYY-MM-01) should be verified |
| 3 | `customer_domestic_international_name` | string | Domestic vs. International classification | `customer360.customer_life_cycle_vw` | Coalesced to `'International'` when null |
| 4 | `customer_region_1_name` | string | Geographic region level 1 | `customer360.customer_life_cycle_vw` | Coalesced to `'International - RoW'` when null |
| 5 | `customer_region_2_name` | string | Geographic region level 2 | `customer360.customer_life_cycle_vw` | Coalesced to `'Rest of World (RoW)'` when null |
| 6 | `customer_region_3_name` | string | Geographic region level 3 | `customer360.customer_life_cycle_vw` | Coalesced to `'NA'` when null |
| 7 | `customer_country_name` | string | Customer country name at evaluation date | `customer360.customer_life_cycle_vw` | Source column: `customer_acquisition_country_name`; coalesced to `'Unknown'` |
| 8 | `customer_country_code` | string | Customer country code at evaluation date | `customer360.customer_life_cycle_vw` | Source column: `customer_acquisition_country_code`; uppercased; "UK" → "GB" normalization applied |
| 9 | `customer_type_name` | string | Customer type at evaluation date | `customer360.customer_life_cycle_vw` | Coalesced to `'Not Classified'` when null |
| 10 | `acquisition_channel_name` | string | Acquisition channel | `customer360.customer_life_cycle_vw` | Source column: `customer_acquisition_channel_name`; coalesced to `'Not GA Attributed'` |
| 11 | `customer_tenure_year_count` | int | Customer tenure in years (integer) | `customer360.customer_life_cycle_vw` | Coalesced to `0` when null |
| 12 | `product_ownership_category_list` | string | Owned product category list (string-encoded) | `customer360.customer_life_cycle_vw` | Source column: `product_pnl_category_list` |
| 13 | `product_ownership_line_list` | string | Owned product line list (string-encoded) | `customer360.customer_life_cycle_vw` | Source column: `product_pnl_line_list` |
| 14 | `reseller_type_name` | string | Reseller type name | `customer360.customer_life_cycle_vw` | Pass-through |
| 15 | `fraud_flag` | boolean | True if customer marked as fraud as of evaluation date | `customer360.customer_life_cycle_vw` | Source column: `customer_fraud_flag`; coalesced to `false` |
| 16 | `point_of_purchase_name` | string | Point of purchase name from acquisition bill | `customer360.customer_life_cycle_vw` | Coalesced to `'Unknown'` when null |
| 17 | `customer_acquisition_bill_fraud_flag` | boolean | True if acquisition bill has fraud record | `customer360.customer_life_cycle_vw` | Coalesced to `false` when null |
| 18 | `brand_name_list` | string | List of all brands associated with the customer | `customer360.customer_life_cycle_vw` | Pass-through |
| 19 | `product_category_qty` | int | Number of distinct product categories owned | `customer360.customer_life_cycle_vw` | Derived: `coalesce(size(product_ownership_category_list), 0)` |
| 20 | `ttm_gcr_usd_amt` | decimal(18,2) | Total trailing-twelve-month gross cash received (USD) | `customer360.customer_life_cycle_vw` | Aggregated: `SUM(ttm_gcr_usd_amt)` |
| 21 | `ending_customer_qty` | bigint | Active customer count at end of evaluation date | `customer360.customer_life_cycle_vw` | Derived: `COUNT_IF(active_status_flag = true)` |
| 22 | `churn_customer_qty` | bigint | Customers who churned on evaluation date | `customer360.customer_life_cycle_vw` | Derived: `COUNT_IF(customer_churn_mst_date IS NOT NULL)` |
| 23 | `merge_customer_qty` | bigint | Customers merged on evaluation date | `customer360.customer_life_cycle_vw` | Derived: `COUNT_IF(customer_merge_mst_date IS NOT NULL)` |
| 24 | `new_customer_qty` | bigint | New customers on evaluation date | `customer360.customer_life_cycle_vw` | Derived: `COUNT_IF(customer_acquisition_mst_date = partition_eval_mst_date)` |
| 25 | `reactivate_customer_qty` | bigint | Customers who reactivated on evaluation date | `customer360.customer_life_cycle_vw` | Derived: `COUNT_IF(customer_reactivate_mst_date IS NOT NULL)` |
| 26 | `beginning_customer_qty` | bigint | Active customer count at start of evaluation date (i.e., prior day's ending count) | `customer360.customer_life_cycle_vw` | Derived via LAG window over dim partition; returns 0 if no prior-day row exists |
| 27 | `net_move_qty` | bigint | Reconciliation metric: unexplained net movement | `customer360.customer_life_cycle_vw` | Derived: `ending − beginning − new + (churn − reactivate) + merge` |
| 28 | `net_add_qty` | bigint | Net change in active customer base | `customer360.customer_life_cycle_vw` | Derived: `ending − beginning` |
| 29 | `net_churn_qty` | bigint | Net customer loss (churn minus reactivations) | `customer360.customer_life_cycle_vw` | Derived: `churn − reactivate` |
| 30 | `data_source_enum` | string | Identifies the pipeline that produced this data | *(No upstream lake source)* | Hardcoded constant `'customer360'`; DDL comment mentioning "c360 or legacy_dac" is stale |
| 31 | `etl_build_mst_ts` | timestamp | ETL build timestamp in MST | *(No upstream lake source)* | System timestamp: `from_utc_timestamp(current_timestamp(), 'MST')` |
| 32 | `partition_eval_mst_date` | string | Partition date (MST) of evaluation (YYYY-MM-DD) | `customer360.customer_life_cycle_vw` | Partition column; always filter on this column for performance |

> **Note on lake DDL completeness:** The lake registry `table.ddl` is missing `data_source_enum` compared to the Hive DDL and the PySpark `conform_datatype()` function. The Hive DDL and PySpark code are authoritative for the full schema.

### C2. Primary Key & Performance

**Composite primary key (DQ-enforced, 19 columns):**

| PK Column | Type |
|---|---|
| `partition_eval_mst_date` | string |
| `customer_type_reason_desc` | string |
| `customer_acquisition_mst_month` | string |
| `customer_domestic_international_name` | string |
| `customer_region_1_name` | string |
| `customer_region_2_name` | string |
| `customer_region_3_name` | string |
| `customer_country_name` | string |
| `customer_country_code` | string |
| `customer_type_name` | string |
| `acquisition_channel_name` | string |
| `customer_tenure_year_count` | int |
| `product_ownership_category_list` | string |
| `product_ownership_line_list` | string |
| `reseller_type_name` | string |
| `fraud_flag` | boolean |
| `point_of_purchase_name` | string |
| `customer_acquisition_bill_fraud_flag` | boolean |
| `brand_name_list` | string |

> The lake registry `table.ddl` annotates only 16 columns as `@PrimaryKey` (excludes `point_of_purchase_name` and `customer_acquisition_bill_fraud_flag`). The **DQ constraint file is more current** and should be treated as authoritative for PK enforcement.

**Performance notes:**
- The table is partitioned by `partition_eval_mst_date`. Always include a partition filter in queries.
- Each partition contains exactly **1 Parquet file** (ETL writes `repartition(1)` before the partition overwrite).
- Redshift representation uses `DISTSTYLE AUTO` with `DISTKEY` and `SORTKEY` on `partition_eval_mst_date`.

### C3. Key Features, Capabilities & Limitations

**Features:**
- **Daily partition overwrite:** Each run overwrites the targeted date partitions completely. No append accumulation; each partition is idempotent.
- **Gap-fill rows:** Dimension combinations present the prior day but absent on the current day receive zero-metric rows. This ensures a gapless daily time series for every active dimension group.
- **LAG-based beginning count:** `beginning_customer_qty` is computed via a window function over the prior calendar day. If no prior row exists for a given dimension combination, the value is `0` (not null).
- **Country code normalization:** "UK" is permanently normalized to "GB" in `customer_country_code`.
- **Dry-run mode:** The ETL supports a `--dry_run` flag that computes but does not write; useful for testing.
- **Backfill DAG:** A separate `customer-metric-daily-agg-backfill` DAG (manual trigger) handles historical backfills. Legacy data cut-off default is `2026-04-01`.

**Limitations:**
- **Hourly latency:** Data is available by ~08:00 AM MST at earliest. Not suitable for near-real-time use cases.
- **Single-file partitions:** Each partition contains one file. High-volume parallel reads may benefit from redistribution.
- **`data_source_enum` is always `'customer360'`:** The DDL comment references historical values (`c360`, `legacy_dac`) that no longer apply. The current pipeline always writes the literal `'customer360'`.
- **Lake DDL is stale:** The `table.ddl` in the lake registry is missing `data_source_enum`. Rely on the Hive DDL (`src/ddls/customer_metric_daily_agg.ddl`) for the complete schema.

### C4. Important Notes & Pitfalls

1. **Gap-fill rows are valid data, not errors.** Rows where all metric columns are `0` (and `ending_customer_qty = 0`) represent dimension groups that had zero active customers on that day. Do not filter these out unless intentional.

2. **`beginning_customer_qty = 0` does not always mean no customers.** For the very first date a dimension combination appears in the table, there is no prior-day anchor, so `beginning_customer_qty` will be `0` by design.

3. **`data_source_enum` DDL comment is stale.** The DDL comment reads "Possible values are c360 and legacy_dac," but the ETL code always writes the literal string `'customer360'`. Do not filter on `c360`.

4. **`customer_acquisition_mst_month` is a string.** The exact format (e.g., `YYYY-MM` vs. `YYYY-MM-01`) should be verified against actual data before string comparison or date casting.

5. **Country code normalization.** `customer_country_code = 'UK'` will never appear; it is permanently rewritten to `'GB'` by the ETL. Historical lookups expecting 'UK' will return no results.

6. **Partition key type differs by system.** In Hive/Parquet, `partition_eval_mst_date` is stored as a `string`. In Redshift, it is a `DATE` column. Cast accordingly when comparing across systems.

7. **PySpark reads the intermediate Hive table.** The active code reads `customer_core_conformed.customer_life_cycle`, not `customer360.customer_life_cycle_vw` directly (the latter reference is commented out). The DAG dependency sensor gates on `customer_life_cycle_vw`'s `_SUCCESS` file. Both reference the same underlying S3 data.

### C5. Always-On Column Filters

| Column | Recommendation | Reason |
|---|---|---|
| `partition_eval_mst_date` | **Always filter** | Table is partitioned by this column; omitting it triggers a full table scan. Single-file-per-partition design makes date range filtering critical for performance. |

The ETL itself filters the output to `partition_eval_mst_date BETWEEN start_mst_date AND end_mst_date` — the extra prior-day row read for LAG computation is excluded from the written output.

### C6. Common Business Metrics

| Metric Column | Definition | Notes |
|---|---|---|
| `ending_customer_qty` | Count of customers with active subscriptions at end of the evaluation date | Primary "active customer" measure |
| `beginning_customer_qty` | Count of active customers at the start of the day (= prior day's ending count) | Returns 0 if no prior-day row for the dimension combo |
| `new_customer_qty` | Customers whose first active date (`customer_acquisition_mst_date`) equals the evaluation date | |
| `churn_customer_qty` | Customers who churned on the evaluation date | |
| `reactivate_customer_qty` | Customers who reactivated on the evaluation date | |
| `merge_customer_qty` | Customers who were merged on the evaluation date | |
| `net_add_qty` | `ending − beginning` — net change in active customer base | Positive = growth; negative = decline |
| `net_churn_qty` | `churn − reactivate` — net customer loss from churn activity | Positive = more churn than reactivation |
| `net_move_qty` | `ending − beginning − new + (churn − reactivate) + merge` — reconciliation check | Should be 0 in a fully reconciled dataset; non-zero indicates data movement not captured by the named event columns |
| `ttm_gcr_usd_amt` | Total trailing-twelve-month gross cash received (USD), summed across customers in the dimension group | |
| `product_category_qty` | Number of distinct product categories owned by customers in the dimension group | Derived from the size of `product_ownership_category_list` |

### C7. Glossary & Term Definitions

| Term | Definition |
|---|---|
| **Active customer** | A customer with at least one active subscription as of the evaluation date (`active_status_flag = true` in source) |
| **Evaluation date** (`partition_eval_mst_date`) | The calendar date (MST) for which the snapshot of customer state and events is recorded |
| **Churn** | A customer who had their last active subscription lapse or cancel on the evaluation date |
| **Reactivation** | A previously churned customer who regained an active subscription on the evaluation date |
| **Merge** | A customer account merged into another customer account on the evaluation date |
| **TTM GCR** | Trailing Twelve Month Gross Cash Received — total revenue collected from a customer over the preceding 12 months |
| **Gap-fill row** | A zero-metric row inserted for a dimension combination that existed the prior day but produced no records on the current day; ensures time-series continuity |
| **Dimension combination** | The unique cross product of all 18 grouping dimension columns that defines the grain of each row |
| **Beginning customer qty** | Active customer count carried forward from the prior day's ending count via a LAG window function |
| **Data tier 4** | GoDaddy's classification for aggregated/derived datasets (not raw or conformed) |
| **`customer360` pipeline** | The ETL pipeline family (`domain:customer`, `layer:enterprise`) replacing legacy `customer_mart.*` tables |

### C8. Example Queries & Patterns

**Pattern 1 — Active customer count by country for a single date**
```sql
SELECT
    customer_country_code,
    customer_country_name,
    SUM(ending_customer_qty) AS active_customers
FROM customer360.customer_metric_daily_agg_vw
WHERE partition_eval_mst_date = '2026-05-01'
GROUP BY 1, 2
ORDER BY active_customers DESC;
```

**Pattern 2 — Daily new vs. churned customers over a date range (aggregate view)**
```sql
SELECT
    partition_eval_mst_date,
    SUM(new_customer_qty)        AS new_customers,
    SUM(churn_customer_qty)      AS churned_customers,
    SUM(reactivate_customer_qty) AS reactivated_customers,
    SUM(net_add_qty)             AS net_adds
FROM customer360.customer_metric_daily_agg_vw
WHERE partition_eval_mst_date BETWEEN '2026-04-01' AND '2026-04-30'
GROUP BY 1
ORDER BY 1;
```
> Always provide a `partition_eval_mst_date` range predicate. Avoid full table scans.

**Pattern 3 — Customer movement by acquisition channel for a single date**
```sql
SELECT
    acquisition_channel_name,
    SUM(beginning_customer_qty)  AS beginning,
    SUM(new_customer_qty)        AS new_customers,
    SUM(churn_customer_qty)      AS churned,
    SUM(ending_customer_qty)     AS ending,
    SUM(net_add_qty)             AS net_adds
FROM customer360.customer_metric_daily_agg_vw
WHERE partition_eval_mst_date = '2026-05-01'
GROUP BY 1
ORDER BY ending DESC;
```

**Pattern 4 — Exclude gap-fill rows when counting non-zero segments**
```sql
-- Gap-fill rows have ending_customer_qty = 0; exclude to count only active dimension groups
SELECT COUNT(*) AS active_dimension_groups
FROM customer360.customer_metric_daily_agg_vw
WHERE partition_eval_mst_date = '2026-05-01'
  AND ending_customer_qty > 0;
```

**Pattern 5 — Revenue per active customer by customer type**
```sql
SELECT
    customer_type_name,
    SUM(ending_customer_qty)                        AS active_customers,
    SUM(ttm_gcr_usd_amt)                            AS total_ttm_gcr,
    SUM(ttm_gcr_usd_amt) / NULLIF(SUM(ending_customer_qty), 0) AS ttm_gcr_per_customer
FROM customer360.customer_metric_daily_agg_vw
WHERE partition_eval_mst_date = '2026-05-01'
  AND ending_customer_qty > 0
GROUP BY 1
ORDER BY total_ttm_gcr DESC;
```

---

## Pillar D: HOW Is It Built? — Pipeline & Provenance

### D1. Data Source Reference

| Source Table | Type | Role |
|---|---|---|
| `customer360.customer_life_cycle_vw` | Lake table (authoritative) | Sole upstream source; provides all customer-level dimension attributes and lifecycle event dates |

The ETL reads the physical equivalent `customer_core_conformed.customer_life_cycle` (same underlying S3 data confirmed via `table_relative_path` in the lake registry). The authoritative lake-registered identity is `customer360.customer_life_cycle_vw`.

`customer_life_cycle_vw` is itself built from multiple upstream lake tables (including `analytic_feature.*`, `enterprise.*`, `finance360.*`, `ecomm_mart.*`, and others) — see the `customer360.customer_life_cycle_vw` metadata document for its full lineage.

### D2. Data Pipeline & Infrastructure

| Field | Value |
|---|---|
| **Source repo** | `dof-dpaas-customer-feature` (GitHub: `gdcorp-dna/dof-dpaas-customer-feature`) |
| **PySpark script** | `customer360/customer-metrics/src/pyspark/customer_metric_daily_agg.py` |
| **DAG file** | `customer360/customer-metrics/src/dag/customer_metric_daily_agg_dag.py` |
| **Policies file** | `customer360/customer-metrics/src/policies/customer_metric_daily_agg_dag.yaml` |
| **DQ files** | `customer360/customer-metrics/src/data_quality/` (constraints on both Hive and lake tables) |
| **Hive DDL** | `customer360/customer-metrics/src/ddls/customer_metric_daily_agg.ddl` |
| **Redshift DDL** | `customer360/customer-metrics/src/ddls/create_customer_metric_daily_agg.sql` |
| **Orchestration** | Apache Airflow (DAG ID: `customer-metric-daily-agg`) |
| **Compute platform** | AWS EMR 7.10.0 — ARM (Graviton) `m6g` family |
| **EMR master** | `m6g.xlarge` × 1 |
| **EMR core nodes** | `m6g.16xlarge` × 15 |
| **Spark memory (default)** | executor: 16 GB, 4 cores; driver: 4 GB, 2 cores |
| **Max executors (default)** | `dynamicAllocation.maxExecutors=10` |
| **EMR IAM roles (prod)** | `dof-customers-EMRInstanceRole` / `dof-customers-EMRServiceRole` |
| **Backfill DAG** | `customer-metric-daily-agg-backfill` (manual trigger; script: `customer_metric_daily_agg_backfill.py`) |

**DAG task flow (summary):**
```
dag_config
  → dependencies (S3KeySensor: customer_life_cycle_vw/_SUCCESS, 12h timeout)
  → end_dependency_check
  → create_redshift_tables_done
  → create_emr
  → run_customer_metric_daily_agg  ← PySpark job
  → remove_emr
  → customer_metric_daily_agg_local_dq  (DQ on Hive layer)
  → conditional_call_lake_api
      ├─ call_lake_api → customer360.customer_metric_daily_agg_vw  [prod only]
      │    └─ customer_metric_daily_agg_lake_dq  (DQ on lake layer)
      └─ skip_call_lake_api  [non-prod]
  → s3_to_redshift_customer_metric_daily_agg_stg
  → insert_customer_metric_daily_agg  (Redshift delete+insert)
  → check_for_failure_branch
```

### D3. SLA & Refresh Schedule

| Field | Value |
|---|---|
| **DAG schedule** | `30 7 * * *` — 07:30 AM MST daily (prod and stage) |
| **Dev-private schedule** | Disabled (`None`) — manual trigger only |
| **Dependency gate** | S3 success file sensor on `customer360/customer_life_cycle_vw/{date}/_SUCCESS` (poke interval: 30s, timeout: 12h) |
| **SLA delivery commitment** | By 08:00 AM MST (`cron(00 15 * * ? *)` UTC) — from lake registry |
| **Max job duration (policy)** | 120 minutes (`maxDurationMins: 120`) |
| **SLA severity** | TIER_4 |
| **Catchup** | `False` |
| **Retries** | 1 (retry delay: 3 minutes) |
| **Max active runs** | 15 |
| **Start date** | 2026-01-01 (America/Phoenix timezone) |
| **legacyLookBackEnabled** | `true` (lake registry) |

### D4. Table Creation & ETL Implementation

The ETL follows a multi-step aggregation pattern, all within a single PySpark job (`customer_metric_daily_agg.py`):

1. **Base aggregation:** Reads `customer_core_conformed.customer_life_cycle` filtered to `partition_eval_mst_date BETWEEN (start_date − 1) AND end_date`. Groups by the 18 dimension columns and computes 5 event count measures (`COUNT_IF` for active, churn, merge, new, reactivate) and `SUM(ttm_gcr_usd_amt)`.

2. **Gap-fill:** Identifies dimension combinations present in the prior day's output but absent in today's. Inserts zero-metric rows for those combos at today's date, ensuring gapless LAG window computation.

3. **Window function:** Computes `beginning_customer_qty` using `LAG(ending_customer_qty)` partitioned by all 18 dimensions, ordered by `partition_eval_mst_date`. Returns 0 if the prior calendar day has no row for the combination.

4. **Derived metrics:** Calculates `net_move_qty`, `net_add_qty`, `net_churn_qty`, and `product_category_qty` from the base measure columns.

5. **Data corrections:** Normalizes `customer_country_code` "UK" → "GB" via `withColumn`.

6. **Type conformance:** `conform_datatype()` casts all columns to declared types; appends `etl_build_mst_ts` (system timestamp) and `data_source_enum = 'customer360'`.

7. **Write:** Filters to `partition_eval_mst_date BETWEEN start_date AND end_date` (drops extra prior-day row), repartitions to 1, and writes via `insertInto(customer_core_conformed.customer_metric_daily_agg, overwrite=True)`. A best-effort `MSCK REPAIR TABLE` is run post-write.

The DDL file is passed to the Spark job via `--files` argument during EMR submission.

---

## Pillar E: HOW Is It Governed? — Quality, Standards & Ecosystem

### E1. Data Quality Checks

A composite primary key uniqueness check is enforced on both layers after each run:

| Check | Type | Applied To | PK Columns Enforced |
|---|---|---|---|
| Primary key uniqueness | USER_DEFINED | `customer_core_conformed.customer_metric_daily_agg` (Hive/lake layer) | 19 columns (see C2) |
| Primary key uniqueness | USER_DEFINED | `customer360.customer_metric_daily_agg_vw` (lake API layer) | 19 columns (identical constraint) |

Both DQ checks (`customer_metric_daily_agg_local_dq` and `customer_metric_daily_agg_lake_dq`) run after write as part of the Airflow DAG. The lake-layer DQ runs in production only (after `call_lake_api`).

> `data_source_enum` is **not** included in the PK constraint in either DQ file, despite being a column in the output table.

### E2. Best Practices & Tips

1. **Always filter `partition_eval_mst_date`.** This is a partitioned table; unfiltered queries will scan all historical data.

2. **Sum metrics, don't count rows.** Rows represent dimension groups, not individual customers. To get total active customers, use `SUM(ending_customer_qty)`, not `COUNT(*)`.

3. **Account for gap-fill rows.** When computing averages or per-segment statistics, consider whether dimension groups with `ending_customer_qty = 0` should be included or excluded.

4. **Use `beginning_customer_qty` for reconciliation.** The identity `ending = beginning + new − churn + reactivate − merge + net_move` should hold. Non-zero `net_move_qty` values indicate movements not captured by the named event columns.

5. **Do not filter on `data_source_enum = 'c360'`.** The value is always `'customer360'`. DDL comments referencing `'c360'` or `'legacy_dac'` are stale.

6. **For backfills**, use the dedicated `customer-metric-daily-agg-backfill` DAG (manual trigger). The legacy cut-off date governs which logic path is used for historical dates.

7. **Consumer permissions** are governed by the lake registry. Current authorized consumer groups include: `analytics.prod`, `martech_data.prod`, `revenue_and_relevance.prod`, `data_platform.prod`, and others. Contact the EDT team for access requests via `#marketing-data-products-help`.

### E3. Related Articles & Documentation

- **Customer360 Confluence hub page (parent):** [https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3779199819/Customer360](https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3779199819/Customer360)
  - Contains the C360 table inventory, business context matrix, ownership matrix, and links to child pages per dataset.
- **Customer360 Business Context Structure (child page ID 4387965088):** Confirms grain, data tier, schema, and coverage weights for all Customer360 tables.
- **Source PySpark script:** `customer360/customer-metrics/src/pyspark/customer_metric_daily_agg.py` in repo `dof-dpaas-customer-feature` (main branch)
- **DAG:** `customer360/customer-metrics/src/dag/customer_metric_daily_agg_dag.py`
- **Lake registry:** `repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/customer-metric-daily-agg-vw/`
- **Upstream table:** `customer360.customer_life_cycle_vw` — see its metadata document for full lineage into the Customer360 ecosystem.

<!-- REQUIRES_MANUAL_INPUT: DG -->
Alation URLs for both the Redshift Serverless and Lake entries could not be retrieved — `MOONUNIT_ALATION` credentials were not available at generation time. Once Alation access is configured, search for table name `customer_metric_daily_agg_vw` and populate the **Alation URL** and **Lake Alation URL** rows in A1.
