# Business Context: customer360.customer_metric_daily_agg_vw

## Pillar A: WHAT Is It? — Identity & Purpose

### A1. Table Overview

| Field | Value |
|---|---|
| Table Name | `customer_metric_daily_agg_vw` |
| Database | Redshift - Serverless - Dev |
| Schema | `customer360` |
| Alation URL | [customer_metric_daily_agg_vw (Redshift Dev)](https://godaddy.alationcloud.com/table/7038918/) |
| Lake Alation URL | [customer_metric_daily_agg_vw (Lake)](https://godaddy.alationcloud.com/table/7038346/) |
| Lake Table | `customer360.customer_metric_daily_agg_vw` |
| Grain | One row per unique combination of `partition_eval_mst_date` (evaluation day, MST) × 18 reporting dimensions |
| Partition Key | `partition_eval_mst_date` |
| Storage Format | Parquet (ZSTD compression) |
| Data Tier | 4 |
| SLA | 08:00 AM MST daily (`cron(00 15 * * ? *)` UTC) |
| Refresh Cadence | Daily — DAG trigger `30 7 * * *` America/Phoenix (7:30 AM MST) |
| Physical Write Target | `customer_core_conformed.customer_metric_daily_agg` (S3 Parquet) |
| DAG ID | `customer-metric-daily-agg` |
| Upstream Dependency | `customer360.customer_life_cycle_vw` (S3 success file) |

### A2. What This Table Is About

`customer360.customer_metric_daily_agg_vw` is the authoritative **daily roll-up of customer lifecycle metrics** segmented by 18 reporting dimensions. It is the official replacement for the legacy `customer_mart.daily_active_customers` table and is the primary source for enterprise-level daily active customer (DAC) reporting.

Each row represents the aggregate customer counts and revenue metrics for one unique combination of 18 customer reporting dimensions on one evaluation date (MST). The 18 dimensions span customer geography (country, region hierarchy, domestic/international), customer type and classification, acquisition channel, tenure, product ownership profile, reseller type, fraud status, point of purchase, and brand associations.

The table captures five key lifecycle events per dimension combination per day:
- **Acquisition** (`new_customer_qty`): customers first acquired on that date
- **Churn** (`churn_customer_qty`): customers who left
- **Reactivation** (`reactivate_customer_qty`): customers who returned
- **Merge** (`merge_customer_qty`): customers whose accounts were merged
- **Stock counts** (`beginning_customer_qty`, `ending_customer_qty`): opening and closing active customer counts

It also carries trailing-twelve-month gross cash received (`ttm_gcr_usd_amt`) aggregated per dimension group, enabling revenue analysis alongside lifecycle event analysis.

**This table replaces `customer_mart.daily_active_customers`.** Consumers migrating from the legacy table must use `partition_eval_mst_date` instead of the legacy column `evaluation_mst_date`, and must account for renamed dimension columns (see C4).

### A3. Organizational Context & Ownership

| Field | Value |
|---|---|
| Team | EDT (Emerald Data Team) |
| DAG Owner | `customer360` |
| Owner Email | `emerald-data-team-org@godaddy.com` |
| OnCall (SNOW) | `DEV-EDT-OnCall` |
| OnCall (Slack) | `#marketing-data-product-engineering` |
| Stakeholder Channel | `#marketing-data-products-help` |
| Prod Alerts Slack | `#edt-airflow-alerts` |
| Alation Steward | Franchise: Customer (group ID 47) |
| Domain | Customer |
| Sub-domain | Active Customer |
| Layer | Enterprise |
| Pipeline Group | `active-customer` |
| MWAA Environment | `dof-customers` (AWS account `688051721285`) |

<!-- REQUIRES_MANUAL_INPUT: DG --> Individual data steward name not available; Alation shows only group-level steward (Franchise: Customer, group ID 47).

<!-- REQUIRES_MANUAL_INPUT: DG --> Data classification (PII sensitivity level) not documented in code or lake registry artifacts.

---

## Pillar B: WHY Does It Matter? — Value & Use Cases

### B1. Key Business Value

Per the table owner: this table is a **daily roll-up of customer lifecycle metrics by 18 reporting dimensions** and **replaces the legacy `customer_mart.daily_active_customers`**.

Key business values:

- **Authoritative daily active customer (DAC) reporting**: official enterprise metric for SEC 10-K Active Customer disclosures using the defined Active Customer standard (individual or entity with paid transactions in TTM or active paid subscriptions at period end).
- **Unified lifecycle view**: captures five lifecycle events (acquisition, churn, reactivation, merge, stock) in a single row, enabling cohort transitions to be tracked without joining multiple fact tables.
- **18-dimension segmentation**: enables analysis across geography (country, region, domestic/international), customer classification (type, tenure), acquisition attributes (channel, point of purchase, acquisition month), product ownership (category/line lists, brand list), and risk signals (fraud flags, reseller type).
- **Migration from legacy DAC**: designed as the replacement for `customer_mart.daily_active_customers`; data validation confirms < 0.002% variance for stock metrics and ≤ 1% variance for flow metrics vs. legacy.
- **Data Tier 4 enterprise asset**: governed under the Business Metrics Layer with SLA delivery by 08:00 AM MST daily, supporting corporate dashboards (Cash Dash, customer vs. target).

### B2. Primary Use Cases

**Questions this table answers:**

- How many active customers does GoDaddy have on a given day, segmented by country, region, or customer type?
- What were the daily new, churned, reactivated, and merged customer counts for a given segment?
- What is the net customer count change (net adds, net churn, net move) over a date range for a segment?
- Does the beginning count today equal the ending count from yesterday for each dimension combination (stock-flow continuity)?
- How much TTM gross cash received is attributed to each customer segment?
- Which acquisition channels, countries, or customer types drove the most new customers in a period?
- How does the current active customer base compare to targets (feeding corporate dashboards)?

**Alation Queries**

#### Query: C360 Cash Dash with budget

| Field | Value |
|---|---|
| Query ID | 138586 |
| Title | C360 Cash Dash with budget |
| Author | |
| Description | Ad-hoc Cash Dash customer analysis with budget overlay; creates sandbox table `dna_sandbox.c360_test_sz_2` |
| Schedule | Not scheduled |
| Last Saved | |
| Last Run | |
| Datasource | DS 63 (Redshift Serverless, bi) |
| Alation Query URL | https://godaddy.alationcloud.com/query/138586/ |

```sql
DROP TABLE IF EXISTS dna_sandbox.c360_test_sz_2;

CREATE TABLE dna_sandbox.c360_test_sz_2 AS
(

WITH base AS
(
SELECT
evaluation_mst_date,
date_trunc('quarter', evaluation_mst_date) AS q_start,
dateadd(quarter,1,date_trunc('quarter',evaluation_mst_date)) AS nq_start,
datediff(day,date_trunc('quarter',evaluation_mst_date),evaluation_mst_date) AS day_in_q,
...
```

*(SQL truncated in source — full text available at Alation query URL; ~19,093 characters total)*

---

#### Query: NC validate EBP

| Field | Value |
|---|---|
| Query ID | 136952 |
| Title | NC validate EBP |
| Author | |
| Description | Validation query for Cash Dash Customer View; reads via `customer_vs_target` wrapper view |
| Schedule | Not scheduled |
| Last Saved | |
| Last Run | |
| Datasource | DS 63 (Redshift Serverless, bi) |
| Alation Query URL | https://godaddy.alationcloud.com/query/136952/ |

```sql
-- Cash Dash Customer View
select date_trunc('day',evaluation_mst_date),
sum(beginning_customer_qty) as begin,
sum(new_customer_qty) as new,
sum(net_churn_qty) as net_churn,
sum(net_adds_qty)as net_add,
sum(churned_customer_qty)as churn
from  bi.bi_dashboards_prod.customer_vs_target
where evaluation_mst_date between '2026-01-01' and current_date
```

*(SQL truncated in source — full text available at Alation query URL; ~3,912 characters total)*

---

#### Query: C360 - mv_customer_metric_daily_agg_vw_union

| Field | Value |
|---|---|
| Query ID | 138254 |
| Title | C360 - mv_customer_metric_daily_agg_vw_union |
| Author | |
| Description | Migration union view: legacy data (≤ 2026-03-31) from `dna_approved.daily_active_customers`; C360 data (≥ 2026-04-01) from `customer_metric_daily_agg_vw` |
| Schedule | Not scheduled |
| Last Saved | |
| Last Run | |
| Datasource | DS 63 (Redshift Serverless, bi) |
| Alation Query URL | https://godaddy.alationcloud.com/query/138254/ |

```sql
DROP TABLE IF EXISTS bi.ba_usi.mv_customer_metric_daily_agg_vw_union;

CREATE TABLE bi.ba_usi.mv_customer_metric_daily_agg_vw_union AS
	WITH legacy_final AS (
		SELECT * FROM bi.dna_approved.daily_active_customers
		WHERE evaluation_mst_date <= '2026-03-31'
	),
	c360_final AS (
	    SELECT DAC.*,
	        trunc(date_trunc('month', dac.partition_eval_mst_date)) AS evaluation_mst_month,
	        rd.relative_month, rd.relative_month_period_name
	    FROM bi.customer360.customer_metric_daily_agg_vw AS DAC
	    LEFT JOIN (SELECT calendar_date, relative_month, relative_month_period_name
	        FROM bi_prod.dim_relative_date
	        WHERE max_date = (SELECT MAX(partition_eval_mst_date) FROM bi.customer360.customer_metric_daily_agg_vw)) rd
	    ON dac.partition_eval_mst_date = rd.calendar_date
	    WHERE DAC.partition_eval_mst_date >= '2026-04-01'
	)
SELECT ... FROM legacy_final UNION ALL SELECT ... FROM c360_final;
```

---

#### Query: C360 - customer_metric_daily_agg_vw_mv

| Field | Value |
|---|---|
| Query ID | 138184 |
| Title | C360 - customer_metric_daily_agg_vw_mv |
| Author | |
| Description | Dev materialized view of `customer_metric_daily_agg_vw` enriched with relative date dimensions |
| Schedule | Not scheduled |
| Last Saved | |
| Last Run | |
| Datasource | DS 132 (dev Redshift) |
| Alation Query URL | https://godaddy.alationcloud.com/query/138184/ |

```sql
DROP TABLE IF EXISTS dev.ba_usi.customer_metric_daily_agg_vw_mv;

CREATE TABLE dev.ba_usi.customer_metric_daily_agg_vw_mv AS
    SELECT
        DAC.*,
        trunc(date_trunc('month', dac.partition_eval_mst_date)) AS evaluation_mst_month,
        rd.relative_month, rd.relative_month_period_name
    FROM ckp_analytic_share.customer360.customer_metric_daily_agg_vw AS DAC
    LEFT JOIN (
        SELECT calendar_date, relative_month, relative_month_period_name
        FROM bi_prod.dim_relative_date
        WHERE max_date = (SELECT MAX(partition_eval_mst_date)
        FROM ckp_analytic_share.customer360.customer_metric_daily_agg_vw)) rd
    ON dac.partition_eval_mst_date = rd.calendar_date;
```

---

#### Query: NC validate DAC/MAC/Cash Dash

| Field | Value |
|---|---|
| Query ID | 128804 |
| Title | NC validate DAC/MAC/Cash Dash |
| Author | |
| Description | Validation of daily active customers, monthly active customers, and Cash Dash metrics |
| Schedule | Not scheduled |
| Last Saved | |
| Last Run | |
| Datasource | DS 132 (dev Redshift) |
| Alation Query URL | https://godaddy.alationcloud.com/query/128804/ |

```sql
-- Cash Dash Customer View
select date_trunc('day',evaluation_mst_date),
sum(beginning_customer_qty) as begin,
sum(new_customer_qty) as new,
sum(net_churn_qty) as net_churn,
sum(net_adds_qty)as net_add,
sum(churned_customer_qty)as churn
from  ba_corporate.customer_vs_target
where evaluation_mst_date between '2026-01-01' and '2026-04-30'
```

*(SQL truncated in source — full text available at Alation query URL; ~6,551 characters total)*

---

#### Query: customer vs target v2

| Field | Value |
|---|---|
| Query ID | 127875 |
| Title | customer vs target v2 |
| Author | |
| Description | Customer vs target comparison dashboard development; references this table directly |
| Schedule | Not scheduled |
| Last Saved | |
| Last Run | |
| Datasource | DS 132 (dev Redshift) |
| Alation Query URL | https://godaddy.alationcloud.com/query/127875/ |

```sql
select top 1 * from customer360.customer_metric_daily_agg_vw;

-- test the date
drop table if exists day;
create temp table day as
select
    evaluation_mst_date,
    date_trunc('quarter', evaluation_mst_date) as q_start,
    ...
```

*(SQL truncated in source — full text available at Alation query URL; ~29,271 characters total)*

---

### B3. Advanced Analytics Use Cases

- **Customer cohort transitions**: combine beginning/ending/churn/reactivation counts by `customer_acquisition_mst_month` and `customer_type_name` to track cohort health over time.
- **Geographic revenue analysis**: aggregate `ttm_gcr_usd_amt` by `customer_country_code`, `customer_region_1_name`, and `customer_domestic_international_name` for market-level financial reporting.
- **Churn modeling inputs**: extract daily churn and reactivation flows by tenure (`customer_tenure_year_count`), product profile (`product_ownership_category_list`), and channel (`acquisition_channel_name`) to feed predictive churn models.
- **Product affinity analysis**: use `product_ownership_category_list` and `product_category_qty` to identify cross-sell opportunity segments (single-product vs. multi-product customers).
- **Legacy migration validation**: `net_move_qty` summing to zero over a closed date range provides a built-in reconciliation check, enabling validation of the cutover from `customer_mart.daily_active_customers`.

---

## Pillar C: HOW Do I Use It Correctly? — Schema, Rules & Guidance

### C1. Complete Column Reference with Data Insights

| Column | Type | Description | Source Table(s) |
|---|---|---|---|
| `customer_type_reason_desc` | string | Reason for customer type classification. COALESCE default: `'Not Classified'` | `customer360.customer_life_cycle_vw` |
| `customer_acquisition_mst_month` | string | Month of customer acquisition (MST), truncated to first of month. COALESCE default: `''` | `customer360.customer_life_cycle_vw` |
| `customer_domestic_international_name` | string | Domestic vs. International classification. COALESCE default: `'International'` | `customer360.customer_life_cycle_vw` |
| `customer_region_1_name` | string | Geographic region level 1. COALESCE default: `'International - RoW'` | `customer360.customer_life_cycle_vw` |
| `customer_region_2_name` | string | Geographic region level 2. COALESCE default: `'Rest of World (RoW)'` | `customer360.customer_life_cycle_vw` |
| `customer_region_3_name` | string | Geographic region level 3. COALESCE default: `'NA'` | `customer360.customer_life_cycle_vw` |
| `customer_country_name` | string | Customer country name at evaluation date. Renamed from `customer_acquisition_country_name`. COALESCE default: `'Unknown'` | `customer360.customer_life_cycle_vw` |
| `customer_country_code` | string | Customer country code, normalized (`'UK'` → `'GB'`). Renamed from `customer_acquisition_country_code`. COALESCE default: `'--'` | `customer360.customer_life_cycle_vw` |
| `customer_type_name` | string | Customer type classification at evaluation date. COALESCE default: `'Not Classified'` | `customer360.customer_life_cycle_vw` |
| `acquisition_channel_name` | string | Acquisition channel. Renamed from `customer_acquisition_channel_name`. COALESCE default: `'Not GA Attributed'` | `customer360.customer_life_cycle_vw` |
| `customer_tenure_year_count` | int | Customer tenure in full years at evaluation date. COALESCE default: `0` | `customer360.customer_life_cycle_vw` |
| `product_ownership_category_list` | string | Owned product PnL category list (serialized array). Renamed from `product_pnl_category_list` | `customer360.customer_life_cycle_vw` |
| `product_ownership_line_list` | string | Owned product PnL line list (serialized array). Renamed from `product_pnl_line_list` | `customer360.customer_life_cycle_vw` |
| `reseller_type_name` | string | Reseller type name | `customer360.customer_life_cycle_vw` |
| `fraud_flag` | boolean | True if customer was marked as fraud at evaluation date. Renamed from `customer_fraud_flag`. COALESCE default: `false` | `customer360.customer_life_cycle_vw` |
| `point_of_purchase_name` | string | Point of purchase name from acquisition bill. COALESCE default: `'Unknown'` | `customer360.customer_life_cycle_vw` |
| `customer_acquisition_bill_fraud_flag` | boolean | True if the acquisition bill has a fraud record. COALESCE default: `false` | `customer360.customer_life_cycle_vw` |
| `brand_name_list` | string | All brands associated with the customer (serialized array) | `customer360.customer_life_cycle_vw` |
| `ttm_gcr_usd_amt` | decimal(18,2) | SUM of trailing-twelve-month gross cash received (USD) for all customers in this dimension group | `customer360.customer_life_cycle_vw` |
| `ending_customer_qty` | bigint | Count of customers with `active_status_flag = true` at end of evaluation date | `customer360.customer_life_cycle_vw` |
| `churn_customer_qty` | bigint | Count of customers who churned on evaluation date (`customer_churn_mst_date IS NOT NULL`) | `customer360.customer_life_cycle_vw` |
| `merge_customer_qty` | bigint | Count of customers merged on evaluation date (`customer_merge_mst_date IS NOT NULL`) | `customer360.customer_life_cycle_vw` |
| `new_customer_qty` | bigint | Count of customers first acquired on evaluation date. Third Party App Store excluded upstream | `customer360.customer_life_cycle_vw` |
| `reactivate_customer_qty` | bigint | Count of customers reactivated on evaluation date (`customer_reactivate_mst_date IS NOT NULL`) | `customer360.customer_life_cycle_vw` |
| `beginning_customer_qty` | bigint | Prior day's `ending_customer_qty` for the same 18-dimension combination (LAG window); `0` if no prior day exists in the table | `customer360.customer_life_cycle_vw` |
| `net_move_qty` | bigint | `ending − beginning − new + (churn − reactivate) + merge`. Derived arithmetic. | Derived from target columns |
| `net_add_qty` | bigint | `ending − beginning`. Derived arithmetic. | Derived from target columns |
| `net_churn_qty` | bigint | `churn − reactivate`. Derived arithmetic. | Derived from target columns |
| `product_category_qty` | int | Count of distinct product PnL categories owned (`SIZE(product_ownership_category_list)`); COALESCE default: `0` | `customer360.customer_life_cycle_vw` |
| `data_source_enum` | string | Hardcoded literal `'customer360'` — identifies this table's domain in multi-source joins | Hardcoded (no source table) |
| `etl_build_mst_ts` | timestamp | Timestamp when the ETL job populated this partition (MST) | System (`current_timestamp` at build time) |
| `partition_eval_mst_date` | string | Evaluation date (MST, `YYYY-MM-DD`). Partition key — **always filter on this column** | `customer360.customer_life_cycle_vw` |

### C2. Primary Key & Performance

**Composite primary key (19 columns):** `partition_eval_mst_date` + 18 dimension columns.

The 19-column PK is enforced by a `isPrimaryKey` (USER_DEFINED) data quality constraint applied in the ETL pipeline. No surrogate key exists.

**Full primary key column list:**
`partition_eval_mst_date`, `customer_type_reason_desc`, `customer_acquisition_mst_month`, `customer_domestic_international_name`, `customer_region_1_name`, `customer_region_2_name`, `customer_region_3_name`, `customer_country_name`, `customer_country_code`, `customer_type_name`, `acquisition_channel_name`, `customer_tenure_year_count`, `product_ownership_category_list`, `product_ownership_line_list`, `reseller_type_name`, `fraud_flag`, `point_of_purchase_name`, `customer_acquisition_bill_fraud_flag`, `brand_name_list`

**Performance guidance:**
- Always filter on `partition_eval_mst_date` — queries without this filter will full-scan all partitions.
- In Redshift, `partition_eval_mst_date` is both the DISTKEY and SORTKEY.
- Each partition contains exactly 1 Parquet file (`repartition(1)` in PySpark).

> **Known discrepancy:** The lake registry `table.ddl` annotates only 16 columns with `@PrimaryKey` (missing `point_of_purchase_name` and `customer_acquisition_bill_fraud_flag`). The authoritative 19-column key is defined in the DQ constraint JSON files and is the correct definition.

### C3. Key Features, Capabilities & Limitations

**Features:**
- Daily grain with 18 segmentation dimensions enables fine-grained lifecycle analysis.
- `beginning_customer_qty` provides a stock-flow reconciliation anchor (should equal prior day's `ending_customer_qty` for the same dimension combination).
- **Dimension forward-fill**: dimension combinations seen on day T are automatically carried forward to day T+1 with zero flow metrics (`candidates_next_day` CTE pattern), preventing gaps in the daily series for slowly-changing dimension combinations.

**Limitations:**
- Data availability starts **2026-01-01** (DAG `start_date`). Pre-2026 data remains in `customer_mart.daily_active_customers`.
- **ARPU/ABPU and rate metrics (Churn Rate, Retention Rate) are not persisted** in this table. Derive from `ttm_gcr_usd_amt` / `ending_customer_qty` as needed.
- Once-daily refresh — no intraday updates.
- `beginning_customer_qty` = `0` for the first day a new dimension combination appears (no LAG predecessor).
- `product_ownership_category_list`, `product_ownership_line_list`, and `brand_name_list` are array-encoded strings. In Redshift, bracket artifacts from Parquet serialization are stripped during load; use string pattern matching. In the Lake (Parquet), query as arrays.
- Third Party App Store customers are excluded from `new_customer_qty` — this exclusion is applied upstream in acquisition logic, not in this PySpark script.

### C4. Important Notes & Pitfalls

> **USER NOTE (table owner):** Always filter on `partition_eval_mst_date`.

1. **Always filter on `partition_eval_mst_date`**: without this filter, every query will full-scan all partitions. This is the most critical performance requirement.

2. **Partition column renamed from legacy**: the date column was renamed:
   - Legacy (`customer_mart.daily_active_customers`): `evaluation_mst_date`
   - This table: `partition_eval_mst_date`
   All queries migrated from the legacy table must update this filter.

3. **Additional column renames vs. legacy:**

   | This table | Legacy / upstream equivalent |
   |---|---|
   | `customer_country_name` | `customer_acquisition_country_name` |
   | `customer_country_code` | `customer_acquisition_country_code` |
   | `acquisition_channel_name` | `customer_acquisition_channel_name` |
   | `product_ownership_category_list` | `product_pnl_category_list` |
   | `product_ownership_line_list` | `product_pnl_line_list` |
   | `fraud_flag` | `customer_fraud_flag` |

4. **`net_move_qty` ≠ `net_add_qty`**: `net_move_qty` incorporates reactivation and merge adjustments; `net_add_qty` is simply `ending − beginning`. Use `net_add_qty` for straight stock reconciliation.

5. **Country code normalization**: `'UK'` is stored as `'GB'`. Filtering on `customer_country_code = 'UK'` will return zero rows.

6. **`data_source_enum` absent from lake DDL**: the lake registry `table.ddl` is missing `data_source_enum` (it is present in the PySpark output, Hive DDL, and Redshift DDL). The column does exist in the physical table; the lake DDL is stale.

7. **Legacy cutover context**: some Alation ad-hoc queries show a union pattern using legacy data for dates ≤ 2026-03-31 and C360 data for ≥ 2026-04-01. This reflects a transition-period usage pattern; no cutover date is hardcoded in the ETL.

### C5. Always-On Column Filters

| Filter | Effect | Applied By |
|---|---|---|
| `partition_eval_mst_date BETWEEN :start_mst_date AND :end_mst_date` | ETL writes only the requested date range to output; source data is read from `start_mst_date − 1` for LAG computation but that extra day is not written | PySpark final SQL `WHERE` clause |

No global tenant, brand, or country restrictions are hardcoded in the ETL. All dimension values are included in the output.

### C6. Common Business Metrics

| Metric Column | Definition | Formula |
|---|---|---|
| `ending_customer_qty` | Active customers at close of evaluation date (SEC 10-K Active Customer definition) | `COUNT_IF(active_status_flag = true)` |
| `new_customer_qty` | Customers first acquired on this date; Third Party App Store excluded upstream | `COUNT_IF(customer_acquisition_mst_date = partition_eval_mst_date)` |
| `churn_customer_qty` | Customers who churned on this date | `COUNT_IF(customer_churn_mst_date IS NOT NULL)` |
| `reactivate_customer_qty` | Customers who reactivated on this date | `COUNT_IF(customer_reactivate_mst_date IS NOT NULL)` |
| `merge_customer_qty` | Customers whose accounts were merged on this date | `COUNT_IF(customer_merge_mst_date IS NOT NULL)` |
| `beginning_customer_qty` | Opening stock for the day; equals prior day's `ending_customer_qty` for the same dimension combination | `LAG(ending_customer_qty) OVER (PARTITION BY <18-dims> ORDER BY partition_eval_mst_date)` |
| `net_add_qty` | Net stock change | `ending_customer_qty − beginning_customer_qty` |
| `net_churn_qty` | Net churn flow | `churn_customer_qty − reactivate_customer_qty` |
| `net_move_qty` | Full lifecycle reconciliation metric | `ending − beginning − new + (churn − reactivate) + merge` |
| `ttm_gcr_usd_amt` | Aggregate TTM gross cash received (USD) for the dimension group | `SUM(ttm_gcr_usd_amt)` over GROUP BY 18 dims |
| `product_category_qty` | Count of distinct product PnL categories owned | `SIZE(product_ownership_category_list)` COALESCE `0` |

**Note:** ARPU/ABPU and rate metrics (Churn Rate, Retention Rate) are **not persisted** in this table per Confluence documentation.

### C7. Glossary & Term Definitions

**Official business definitions (source: Confluence C360 Customer Reporting Metrics, page 4042131351):**

| Term | Definition |
|---|---|
| **Active Customer** | Individual or entity with paid transactions in the trailing twelve months OR active paid subscriptions at end of period (SEC 10-K definition) |
| **New Customer** | Customer making their first paid order or Domain Change of Account (COA) order; Third Party App Store orders excluded |
| **Churned Customer** | Customer with no active paid subscription AND no paid transactions in the trailing twelve months |
| **2+ Customer** | Active Customer with payable resources in 2 or more distinct Product PnL categories |
| **Net Adds** | `(New paid + Reactivations) − (Churned + Customer Type Moves + Merges)` — equivalent to `ending − beginning` in this table |
| **TTM GCR** | Trailing Twelve Month Gross Cash Received (USD) |
| **Evaluation Date** | The date as of which customer status and lifecycle events are assessed; stored as `partition_eval_mst_date` in this table |
| **partition_eval_mst_date** | This table's partition column and date filter (replaces `evaluation_mst_date` from legacy tables) |

**COALESCE / NULL-fill defaults applied by ETL (from PySpark `conform_datatype`):**

| Column | NULL replaced with |
|---|---|
| `customer_type_reason_desc` | `'Not Classified'` |
| `customer_acquisition_mst_month` | `''` (empty string) |
| `customer_domestic_international_name` | `'International'` |
| `customer_region_1_name` | `'International - RoW'` |
| `customer_region_2_name` | `'Rest of World (RoW)'` |
| `customer_region_3_name` | `'NA'` |
| `customer_country_name` | `'Unknown'` |
| `customer_country_code` | `'--'` |
| `customer_type_name` | `'Not Classified'` |
| `acquisition_channel_name` | `'Not GA Attributed'` |
| `customer_tenure_year_count` | `0` |
| `fraud_flag` | `false` |
| `customer_acquisition_bill_fraud_flag` | `false` |
| `point_of_purchase_name` | `'Unknown'` |
| `beginning_customer_qty` | `0` (if prior day not in table) |
| `product_category_qty` | `0` (if product list is null) |

### C8. Example Queries & Patterns

**Pattern 1 — Ending active customers by country for the most recent date**

```sql
-- Always filter on partition_eval_mst_date
SELECT
    customer_country_name,
    customer_country_code,
    SUM(ending_customer_qty) AS ending_customers
FROM customer360.customer_metric_daily_agg_vw
WHERE partition_eval_mst_date = (
    SELECT MAX(partition_eval_mst_date)
    FROM customer360.customer_metric_daily_agg_vw)
GROUP BY 1, 2
ORDER BY ending_customers DESC;
```

**Pattern 2 — Net adds by acquisition channel over a date range**

```sql
SELECT
    acquisition_channel_name,
    SUM(new_customer_qty)        AS new_customers,
    SUM(churn_customer_qty)      AS churned_customers,
    SUM(reactivate_customer_qty) AS reactivated_customers,
    SUM(net_add_qty)             AS net_adds
FROM customer360.customer_metric_daily_agg_vw
WHERE partition_eval_mst_date BETWEEN '2026-04-01' AND '2026-04-30'
GROUP BY 1
ORDER BY net_adds DESC;
```

**Pattern 3 — TTM GCR by region and customer type for a single date**

```sql
SELECT
    customer_region_1_name,
    customer_type_name,
    SUM(ttm_gcr_usd_amt)     AS ttm_gcr_usd,
    SUM(ending_customer_qty) AS ending_customers
FROM customer360.customer_metric_daily_agg_vw
WHERE partition_eval_mst_date = '2026-04-30'
GROUP BY 1, 2
ORDER BY ttm_gcr_usd DESC;
```

**Pattern 4 — Stock-flow continuity check (beginning today = ending yesterday)**

```sql
-- Spot-check: aggregate beginning vs prior day ending (simplified, top-level)
SELECT
    a.partition_eval_mst_date,
    SUM(a.beginning_customer_qty)                         AS total_beginning,
    SUM(b.ending_customer_qty)                            AS prior_day_ending,
    SUM(a.beginning_customer_qty - b.ending_customer_qty) AS discrepancy
FROM customer360.customer_metric_daily_agg_vw a
JOIN customer360.customer_metric_daily_agg_vw b
    ON  a.customer_type_name         = b.customer_type_name
    AND a.customer_country_code      = b.customer_country_code
    AND a.acquisition_channel_name   = b.acquisition_channel_name
    -- join on all 18 dimension columns for a complete check
    AND a.partition_eval_mst_date    = DATEADD(day, 1, b.partition_eval_mst_date)
WHERE a.partition_eval_mst_date BETWEEN '2026-04-01' AND '2026-04-30'
GROUP BY 1;
```

---

## Pillar D: HOW Is It Built? — Pipeline & Provenance

### D1. Data Source Reference

| Source Table (Lake) | Description | Role |
|---|---|---|
| `customer360.customer_life_cycle_vw` | Daily customer lifecycle event table — one row per customer per day with active status, lifecycle event flags, dimension attributes, and TTM GCR | Primary source for all data columns |

The PySpark script reads from `customer_core_conformed.customer_life_cycle` (an intermediate S3-backed copy of the lifecycle data). This conformed table is built by the upstream lifecycle pipeline and is registered in the lake catalog as `customer360.customer_life_cycle_vw`. All column-level lineage for this table traces to that lake table.

The lifecycle table is itself sourced from 15+ lake tables across 7 schemas:

| Schema | Lake Tables |
|---|---|
| `enterprise` | `dim_subscription_history`, `dim_entitlement_history`, `fact_bill_line`, `fact_entitlement_bill`, `dim_bill_shopper_id_xref`, `dim_new_acquisition_shopper` |
| `analytic_feature` | `shopper_acquisition`, `customer_type_history`, `customer_fraud`, `shopper_merge` |
| `customer360` | `dim_customer_history_vw` |
| `finance360` | `dim_country_vw`, `dim_bill_fraud_history_vw`, `dim_product_vw` |
| `dp_enterprise` | `dim_reseller` |
| `ecomm_mart` | `bill_line_traffic_ext`, `dim_bill_line_purchase_attribution`, `entitlement_bill_type` |
| `customers` | `customer_id_mapping_snapshot` |
| `finance_cln` | `manual_paid_subscription` |

### D2. Data Pipeline & Infrastructure

| Field | Value |
|---|---|
| Source Repository | `gdcorp-dna/dof-dpaas-customer-feature` |
| PySpark Script | `customer360/customer-metrics/src/pyspark/customer_metric_daily_agg.py` |
| DAG File | `customer360/customer-metrics/src/dag/customer_metric_daily_agg_dag.py` |
| DAG ID | `customer-metric-daily-agg` |
| Orchestration | Apache Airflow (MWAA environment: `dof-customers`, AWS account `688051721285`) |
| Compute | EMR 7.10.0 — 15 core nodes, `m6g.16xlarge` |
| Write Mode | `insertInto(overwrite=True)` — overwrites partitions in the requested date range |
| Output (S3 / Hive) | `s3://gd-ckpetlbatch-{env}-customer-core-conformed/customer_core_conformed/customer_metric_daily_agg/` |
| Output (Lake) | `customer360.customer_metric_daily_agg_vw` (registered via `SuccessNotificationOperator`) |
| Output (Redshift) | `bi.customer360.customer_metric_daily_agg_vw` (S3 COPY + upsert) |

**Pipeline task flow (high level):**

1. Wait for upstream `customer360.customer_life_cycle_vw` S3 success file
2. Create/refresh Redshift tables (DDL)
3. Launch EMR cluster → run PySpark job → terminate EMR cluster
4. Data quality check on local conformed table (`dq_check_customer_metric_daily_agg_local`)
5. *(Prod only)* Register success with Lake API (`call_lake_api`)
6. Load to Redshift staging table → upsert to production Redshift table
7. *(Prod only)* Data quality check on lake table (`dq_check_customer_metric_daily_agg_lake`)

### D3. SLA & Refresh Schedule

| Field | Value |
|---|---|
| Cron schedule | `30 7 * * *` — 7:30 AM MST (America/Phoenix, no DST) |
| SLA delivery target | `cron(00 15 * * ? *)` UTC = **08:00 AM MST** daily |
| Max pipeline duration | 120 minutes (TIER_4) |
| Start date | `2026-01-01` |
| Catchup | Disabled (`catchup=False`) |
| Upstream dependency | `customer360.customer_life_cycle_vw` S3 success file must be available before job starts |
| Retries | 1 retry, 3-minute delay |
| Prod alerts | `#edt-airflow-alerts` |

> **Note:** The DAG docstring states SLA as `N/A` — this is stale. The authoritative SLA is in the lake `table.yaml` (`deliveryCadenceUTC: cron(00 15 * * ? *)`) and policy YAML (`maxDurationMins: 120`, `TIER_4`).

<!-- REQUIRES_MANUAL_INPUT: DG --> Data retention policy not documented in code, lake registry, or policy YAML artifacts.

### D4. Table Creation & ETL Implementation

High-level logic in `customer_metric_daily_agg.py`:

1. **Source query**: reads `customer_core_conformed.customer_life_cycle` for `[start_mst_date − 1, end_mst_date]`. The extra day is required to compute `beginning_customer_qty` via LAG; it is read but not written to the output.

2. **Dimension normalization** (`conform_datatype`): applies COALESCE defaults to 14 dimension columns, normalizes `customer_country_code` (`'UK'` → `'GB'`), renames 6 columns to their output names, and casts array columns to strings.

3. **Metric aggregation**: groups by `partition_eval_mst_date` + 18 dimensions; computes `ending_customer_qty` (`COUNT_IF active_status_flag`), four flow event counts, and `SUM(ttm_gcr_usd_amt)`.

4. **Beginning count / forward-fill** (`candidates_next_day` CTE): dimension combinations present on day T are carried forward to day T+1 with zero flow metrics. `beginning_customer_qty` is then computed via `LAG(ending_customer_qty) OVER (PARTITION BY <18-dims> ORDER BY partition_eval_mst_date)`.

5. **Derived metrics**: `net_move_qty`, `net_add_qty`, `net_churn_qty`, and `product_category_qty` are computed as arithmetic expressions on the aggregated values.

6. **Write**: `repartition(1)` then `insertInto('customer_core_conformed.customer_metric_daily_agg', overwrite=True)` partitioned by `partition_eval_mst_date`. Final `WHERE` restricts output to `[start_mst_date, end_mst_date]`.

---

## Pillar E: HOW Is It Governed? — Quality, Standards & Ecosystem

### E1. Data Quality Checks

| Check | Type | Scope | Applied To |
|---|---|---|---|
| `isPrimaryKey` | USER_DEFINED | All 19 PK columns (18 dims + `partition_eval_mst_date`) | `customer_core_conformed.customer_metric_daily_agg` (local) and `customer360.customer_metric_daily_agg_vw` (lake) |

**DQ constraint files:**
- Local: `customer360/customer-metrics/src/data_quality/constraints/customer_metric_daily_agg.json`
- Lake: `customer360/customer-metrics/src/data_quality/constraints/customer_metric_daily_agg_vw.json`

**DAG-enforced DQ tasks:**
- `dq_check_customer_metric_daily_agg_local` — runs after PySpark write, before Redshift load
- `dq_check_customer_metric_daily_agg_lake` — runs in prod only, after Lake API notification

**Validation rules documented in Confluence (not ETL-enforced):**
- `beginning_customer_qty` for day T must equal `ending_customer_qty` for day T−1 (same dimension combination)
- `net_move_qty` must sum to zero across a full closed date range
- Variance vs. legacy `customer_mart.daily_active_customers`: beginning/ending < 0.002%; new/reactivated/merge/churn ≤ 1%
- Partner BU net moves must be ≥ 0 (partner customers cannot revert to non-partner types)

### E2. Best Practices & Tips

1. **Always filter on `partition_eval_mst_date`** — required for partition pruning; full table scans will be slow and costly.
2. **Use this table instead of `customer_mart.daily_active_customers`** — it is the official replacement. For analysis spanning pre-2026 data, union with the legacy table.
3. **Use `partition_eval_mst_date`, not `evaluation_mst_date`** — the column was renamed. Legacy queries must be updated.
4. **Derive ARPU/ABPU from this table**: `ttm_gcr_usd_amt / NULLIF(ending_customer_qty, 0)` per segment per date.
5. **Validate stock-flow continuity**: `beginning_customer_qty` today should equal `ending_customer_qty` yesterday for the same 18-dimension combination. A discrepancy indicates a data issue or a newly appeared dimension combination.
6. **`net_move_qty` summing to zero** over a long closed period is a useful sanity check — customers entering a period must balance with customers exiting over the same period.
7. **List columns in Redshift**: `product_ownership_category_list`, `product_ownership_line_list`, and `brand_name_list` are stored as strings (bracket notation stripped during load). Use `LIKE '%<value>%'` for filtering in Redshift; use array functions in the Lake.
8. **`data_source_enum = 'customer360'`** is always `'customer360'` — useful as a constant join key in multi-source query patterns.

### E3. Related Articles & Documentation

| Asset | Path / URL | Notes |
|---|---|---|
| PySpark script | `customer360/customer-metrics/src/pyspark/customer_metric_daily_agg.py` | Authoritative ETL (repo: `gdcorp-dna/dof-dpaas-customer-feature`) |
| DAG | `customer360/customer-metrics/src/dag/customer_metric_daily_agg_dag.py` | Schedule, dependencies, task flow |
| Hive DDL | `customer360/customer-metrics/src/ddls/customer_metric_daily_agg.ddl` | Physical S3/Hive table DDL |
| Redshift DDL | `customer360/customer-metrics/src/ddls/create_customer_metric_daily_agg.sql` | Redshift table creation |
| DQ constraint (local) | `customer360/customer-metrics/src/data_quality/constraints/customer_metric_daily_agg.json` | 19-column PK constraint |
| DQ constraint (lake) | `customer360/customer-metrics/src/data_quality/constraints/customer_metric_daily_agg_vw.json` | 19-column PK constraint |
| Policy YAML | `customer360/customer-metrics/src/policies/customer_metric_daily_agg_dag.yaml` | SLA, I/O declarations (note: input listing is stale — lists `customer_life_cycle_vw` but code reads conformed table) |
| Lake registry YAML | `repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/customer-metric-daily-agg-vw/table.yaml` | SLA, permissions, lineage |
| Lake registry DDL | `repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/customer-metric-daily-agg-vw/table.ddl` | Note: missing `data_source_enum` column; `@PrimaryKey` annotations incomplete |
| Confluence — Customer360 hub | https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3779199819/Customer360 | Business Metrics Layer overview; deprecation notice for legacy tables |
| Confluence — Customer Metrics | https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/4042131239 | Lifecycle event → metric mapping |
| Confluence — Reporting Metrics definitions | https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/4042131351 | Official Active Customer, New, Churn, Net Adds definitions |
| Confluence — Data Validation Test Cases | https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/4192469643 | Variance thresholds vs. legacy; continuity checks |
| Alation — Lake table | https://godaddy.alationcloud.com/table/7038346/ | Lake catalog entry (ID 7038346) |
| Alation — Redshift table (prod) | https://godaddy.alationcloud.com/table/7038887/ | Redshift `bi.customer360` entry (ID 7038887) |
| Upstream lake table | `customer360.customer_life_cycle_vw` | Direct data source; lake path: `dlms-api/us-west-2/customer360/customer-life-cycle-vw/` |
