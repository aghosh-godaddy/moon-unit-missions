# Business Context: customer360.customer_life_cycle_vw

## Pillar A: WHAT Is It? — Identity & Purpose

### A1. Table Overview

| Attribute | Value |
|---|---|
| Schema | `customer360` |
| Table | `customer_life_cycle_vw` |
| Internal Landing Table | `customer_core_conformed.customer_life_cycle` |
| **Grain** | **One row per customer (`shopper_id`) per evaluation date (`partition_eval_mst_date`)** |
| Partition Key | `partition_eval_mst_date` (STRING, format YYYY-MM-DD) |
| Column Count | 35 (34 data + 1 partition) |
| Data Tier | 4 |
| Storage Format | Parquet (zstd compression) |
| Refresh Cadence | Daily |
| SLO Delivery | 8:00 AM MST |
| Historical Lookback | Enabled (`legacyLookBackEnabled: true`) |
| Redshift Replica | `customer360.customer_life_cycle_vw` (loaded via S3 COPY from staging) |

---

### A2. What This Table Is About

`customer360.customer_life_cycle_vw` is a daily customer-state snapshot table. For each evaluation date, it captures one record per GoDaddy customer encoding their lifecycle state (active, new, churned, reactivated, merged, or intraday), their acquisition history, active product portfolio, trailing 12-month revenue, and segmentation attributes.

The table consolidates subscription, billing, fraud, acquisition, and geography data into a single customer-level record. It is described in Confluence as the "primary OSI and OWL target" for the Customer360 domain and carries a 35% weight in the Customer360 coverage matrix.

Key concepts captured per customer per day:
- **Lifecycle state**: whether the customer is newly acquired, active and returning, churned, reactivated, merged into another account, or intraday (subscription created same day but not yet settled)
- **Acquisition identity**: first net-positive bill ID, date, country, and marketing channel
- **Active product portfolio**: list of active paid subscription IDs, PNL categories, and brands
- **Trailing 12-month revenue**: gross cash received (USD) from net-positive billing events
- **Segmentation**: customer type, reseller type, fraud flags, and geographic hierarchy

---

### A3. Organizational Context & Ownership

| Attribute | Value |
|---|---|
| Data Product | Customer360 |
| Domain | Customer |
| Organization | DNA |
| Engineering Team | Customer360 / EDT |
| On-Call Channel | `#marketing-data-product-engineering` |
| On-Call Email | `dl-bi-enterprise-data@godaddy.com` |
| SNOW On-Call Group | `DEV-EDT-OnCall` |
| Stakeholder Help Channel | `#marketing-data-products-help` |
| Airflow Alert Channel (prod) | `#edt-airflow-alerts` |

<!-- REQUIRES_MANUAL_INPUT: BA -->
Named Business Analyst owner and formal data steward are not identified in available sources (DAG, policy file, Confluence). Please confirm from the Customer360 / EDT team roster.

**Declared consumers (lake catalog):** `ckpetlbatch` (dev/prod), `data_lab` (dev), `analytics` (prod), `data_platform` (stage/prod), `care_analytics`, `martech_data` (dev/stage/prod), `revenue_and_relevance` (dev/stage/prod/test), `partners` (stage/prod).

---

## Pillar B: WHY Does It Matter? — Value & Use Cases

### B1. Key Business Value

`customer360.customer_life_cycle_vw` is the foundational customer-state driver for GoDaddy Finance and Marketing analytics. Originally built at the request of Finance to support customer metrics, it enables:

- **Churn and retention tracking**: daily attribution of customers who churned, reactivated, or merged, with product context for each event
- **Acquisition cohort construction**: every customer carries their acquisition date, channel, country, and bill ID, enabling precise historical cohort slicing
- **Revenue attribution per customer**: pre-aggregated trailing 12-month gross cash received (USD) aligned to lifecycle state on each day
- **Product portfolio visibility**: sorted arrays of active subscription IDs, PNL categories, and brand names eliminate the need to join to subscription tables for common portfolio questions
- **Fraud-aware analysis**: two independent fraud signals (shopper-level and acquisition-bill-level) allow clean-vs-fraud cohort segmentation
- **Reseller and brand segmentation**: customer type and reseller classification carried on every row, including a hardcoded 123 Reg override for private-label customers

---

### B2. Primary Use Cases

Questions this table directly answers:

- How many customers were active on a given date, by country and customer type?
- Which customers churned yesterday, and what products did they hold?
- How many customers are genuinely new acquisitions vs. reactivated returning customers?
- What is the total trailing 12-month gross revenue for the active customer base by region?
- Which customers acquired in a given month are still active after one year?
- How many customers are classified as resellers, and by what reseller type?
- What is the distribution of PNL product categories across the active base?
- How many intraday customers were created today but are not yet in the settled active base?
- Which customers carry a shopper-level fraud flag at acquisition?
- What is the customer tenure distribution (in years) for churned customers?

---

### B3. Advanced Analytics Use Cases

- **Survival and hazard modeling**: use the daily series of `customer_state_enum` values per cohort (grouped by `customer_acquisition_mst_month`, `customer_acquisition_country_code`, or `customer_acquisition_channel_name`) to compute survival curves and model time-to-churn
- **Revenue at risk forecasting**: combine `ttm_gcr_usd_amt` trends across consecutive partitions with `customer_state_enum` transitions to estimate near-term revenue at risk from high-value churning customers
- **Marketing channel effectiveness**: join `customer_acquisition_bill_id` to `ecomm_mart.bill_line_traffic_ext` for full-funnel attribution linking acquisition channel to long-term customer value and churn behavior
- **Fraud impact quantification**: use `customer_fraud_flag` and `customer_acquisition_bill_fraud_flag` together to measure the revenue impact (`ttm_gcr_usd_amt`) of customers with fraud signals at or after acquisition
- **Geographic expansion analysis**: track `customer_acquisition_country_code`, `customer_region_1_name`, and `customer_domestic_international_name` over time to assess international customer growth and regional cohort retention rates

---

## Pillar C: HOW Do I Use It Correctly? — Schema, Rules & Guidance

### C1. Complete Column Reference with Data Insights

| Column | Type | Description | Source Table(s) |
|---|---|---|---|
| `shopper_id` | string | eCommerce shopper profile ID; the grain key for this table | `enterprise.dim_subscription_history`, `enterprise.dim_bill_shopper_id_xref` |
| `customer_id` | string | Customer UUID bridging eCommerce and back-office systems | `enterprise.dim_subscription_history` |
| `customer_acquisition_bill_id` | string | Bill ID of the customer's first net-positive event. For new/intraday: COALESCE(acquisition bill, original subscription bill) | `enterprise.dim_new_acquisition_shopper`, `enterprise.dim_subscription_history` |
| `customer_acquisition_mst_date` | date | Date of first net-positive bill (MST). NULL for customers with no traceable acquisition event | `enterprise.dim_new_acquisition_shopper`, `enterprise.dim_subscription_history` |
| `customer_acquisition_mst_month` | string | Acquisition month truncated to first day of month (YYYY-MM-DD format) | Derived from `customer_acquisition_mst_date` |
| `customer_acquisition_country_code` | string | Country code at acquisition. 'UK' is normalized to 'GB' in ETL | `enterprise.dim_new_acquisition_shopper` |
| `customer_acquisition_channel_name` | string | Marketing channel at acquisition. Source changes by date: `bill_line_traffic_ext` for ≥ 2022-08; legacy S3 `ads_bill_line_ext` for < 2022-08 | `ecomm_mart.bill_line_traffic_ext`; S3 direct read (legacy `ads_bill_line_ext`, pre-2022-08 only) |
| `customer_tenure_year_count` | int | Integer floor of years since acquisition: `FLOOR(DATEDIFF(eval_date, acq_date) / 365)`. Customers < 1 year show as 0 | Derived from `enterprise.dim_new_acquisition_shopper`, `enterprise.dim_subscription_history` |
| `customer_acquisition_country_name` | string | Full country name at acquisition, looked up from geography dimension | `finance360.dim_country_vw` |
| `customer_region_1_name` | string | Reporting region level 1 based on acquisition country | `finance360.dim_country_vw` |
| `customer_region_2_name` | string | Reporting region level 2 | `finance360.dim_country_vw` |
| `customer_region_3_name` | string | Reporting region level 3 | `finance360.dim_country_vw` |
| `customer_domestic_international_name` | string | 'Domestic' or 'International' classification based on acquisition country | `finance360.dim_country_vw` |
| `reseller_type_id` | int | Reseller type numeric ID. NULL for non-reseller customers | `dp_enterprise.dim_reseller`; join key via `customer360.dim_customer_history_vw` |
| `reseller_type_name` | string | Reseller type label corresponding to `reseller_type_id` | `dp_enterprise.dim_reseller` |
| `customer_type_name` | string | Customer segment label. Hardcoded to '123 Reg' if `private_label_id = 587240`; otherwise from `customer_type_history`, defaulting to 'Not Evaluated' | `analytic_feature.customer_type_history`, `customer360.dim_customer_history_vw` |
| `customer_type_reason_desc` | string | Reason or description for the customer type classification. Same 123 Reg override logic as `customer_type_name` | `analytic_feature.customer_type_history`, `customer360.dim_customer_history_vw` |
| `customer_fraud_flag` | boolean | TRUE if the shopper was flagged as fraudulent at acquisition | `analytic_feature.shopper_acquisition` |
| `active_paid_subscription_list` | array\<string\> | Sorted array of active paid subscription IDs (`finance_payable_resource_flag = true`) | `enterprise.dim_subscription_history` |
| `product_pnl_category_list` | array\<string\> | Sorted array of distinct PNL category names across active paid subscriptions | `finance360.dim_product_vw` |
| `product_pnl_category_qty` | int | COUNT of distinct PNL categories held by the customer | `finance360.dim_product_vw` |
| `product_pnl_line_list` | array\<string\> | Sorted array of distinct PNL line names across active paid subscriptions | `finance360.dim_product_vw` |
| `ttm_all_bill_list` | array\<string\> | Sorted array of bill IDs from the trailing 12 months (net-positive, non-'N/A' currency only) | `enterprise.fact_bill_line` |
| `brand_name_list` | array\<string\> | Sorted union of brand names from active subscriptions and TTM payment records | `enterprise.dim_bill_shopper_id_xref` |
| `ttm_gcr_usd_amt` | decimal(18,2) | Sum of gross cash received (USD) over trailing 12 months; net-positive bills only, currency ≠ 'N/A'. Set to 0 (not NULL) for intraday customers | `enterprise.fact_bill_line` |
| `customer_churn_mst_date` | date | Set to `partition_eval_mst_date` when the customer churned on that date. NULL if not churned | Derived from `enterprise.dim_subscription_history`, `enterprise.fact_bill_line` |
| `customer_reactivate_mst_date` | date | Set to `partition_eval_mst_date` when a returning customer appears as 'new' with an earlier acquisition date. NULL otherwise | Derived from `enterprise.dim_new_acquisition_shopper` |
| `customer_merge_mst_date` | date | Date shopper account was merged into another account. Populated when customer churned due to a merge event | `analytic_feature.shopper_merge` |
| `customer_fraud_mst_date` | date | Date fraud flag was set; populated when shopper is in customer_fraud, not reinstated, and `acq_fraud_flag = true` | `analytic_feature.customer_fraud` |
| `customer_state_enum` | string | Priority-ordered lifecycle state enum: `intraday > merged > churned > reactivated > new > active` | Derived from `enterprise.dim_subscription_history`, `enterprise.fact_bill_line`, `analytic_feature.shopper_merge`, `analytic_feature.customer_fraud` |
| `active_status_flag` | boolean | TRUE if `customer_state_enum NOT IN ('churned', 'intraday')` | Derived |
| `point_of_purchase_name` | string | Point of purchase from the acquisition bill; selected by highest `bill_line_num` | `ecomm_mart.dim_bill_line_purchase_attribution` |
| `customer_acquisition_bill_fraud_flag` | boolean | TRUE if the acquisition bill ID is present in the bill fraud history table | `finance360.dim_bill_fraud_history_vw` |
| `etl_build_mst_ts` | timestamp | Timestamp when this partition was written (MST). Derived at ETL runtime | ETL runtime (no source table) |
| `partition_eval_mst_date` | string | Partition key. All customer facts in this record are computed as of end-of-day for this date (YYYY-MM-DD) | DAG input parameter `eval_mst_date` |

---

### C2. Primary Key & Performance

**Composite key:** `(partition_eval_mst_date, shopper_id)`

No physical primary key is enforced at the storage layer (Parquet/Hive). Uniqueness is validated by a dedicated Airflow DQ task (`dq_check_customer_life_cycle_local` and `dq_check_customer_life_cycle_lake`) after each run.

> **Note:** The Hive DDL contains a `@PrimaryKey` annotation on `customer_id`. This is misleading — `customer_id` is not unique per partition. The DQ-enforced and code-authoritative grain key is `(partition_eval_mst_date, shopper_id)`.

**Partitioning:**
- Partitioned by `partition_eval_mst_date` (STRING).
- **Always include a `partition_eval_mst_date` predicate** — queries without it will scan all historical partitions.
- Each partition is written as 30 Parquet files.
- The Redshift replica uses `partition_eval_mst_date` as both DISTKEY and SORTKEY.

**Historical availability:** `legacyLookBackEnabled: true` — historical partitions are available. Earliest partition subject to operational retention policy.

---

### C3. Key Features, Capabilities & Limitations

**Features:**
- Complete daily customer-state snapshot: all customers who were active, new, churned, reactivated, merged, or intraday on a given date
- Acquisition provenance: bill ID, date, channel, and country carried on every row, enabling cohort analysis without additional joins
- Pre-aggregated product portfolio: array columns (`active_paid_subscription_list`, `product_pnl_category_list`, `product_pnl_line_list`, `ttm_all_bill_list`, `brand_name_list`) cover common portfolio questions without joining to subscription tables
- Dual fraud signals: shopper-level (`customer_fraud_flag`) and bill-level (`customer_acquisition_bill_fraud_flag`) serve different fraud analysis needs
- Available in both Hive/Glue (for Spark and Athena) and Redshift

**Limitations:**
- Churned customers' subscription and payment data reflects the *prior day* (d-1), not the churn date itself
- `customer_acquisition_mst_date` can be NULL for existing customers with no traceable acquisition event
- `customer_tenure_year_count` uses integer floor division — customers 0–364 days old all show as `0`
- `ttm_gcr_usd_amt` is `0` (not NULL) for intraday customers; exclude intraday rows for revenue analysis
- `customer_acquisition_channel_name` stitches two data sources at the 2022-08 boundary; pre-boundary values come from a legacy S3 source with no dependency gate
- `finance360.dim_country_vw` has no DAG dependency sensor — if this dimension loads late or fails, geography columns will silently be NULL

---

### C4. Important Notes & Pitfalls

1. **Partition filter is mandatory.** Without `WHERE partition_eval_mst_date = '...'`, queries scan all historical partitions. This is very expensive at scale.

2. **Churned customer data is from the prior day.** When a customer churns, `active_paid_subscription_list`, `product_pnl_category_list`, and `ttm_gcr_usd_amt` reflect *yesterday's* values, not the churn date's state.

3. **`customer_id` is not the grain key.** Despite a `@PrimaryKey` DDL annotation, `customer_id` is not unique per partition. The grain is `(shopper_id, partition_eval_mst_date)`.

4. **Country code normalization.** The ETL normalizes 'UK' → 'GB' for `customer_acquisition_country_code`. If joining to tables that use 'UK', this will cause silent mismatches.

5. **123 Reg type override.** Customers with `private_label_id = 587240` always receive `customer_type_name = '123 Reg'` regardless of what `analytic_feature.customer_type_history` contains.

6. **No dependency gate for `finance360.dim_country_vw`.** This geography dimension is LEFT JOINed without a DAG S3 sensor. Late or failed delivery of this table will result in NULL region/country fields, with no pipeline alert triggered.

7. **Legacy S3 path is hardcoded to prod.** The `ads_bill_line_ext` source reads from `s3://gd-ckpetlbatch-prod-analytic/analytic/ads_bill_line_ext/` — this hardcoded bucket reference will fail in non-prod environments.

8. **`customer_state_enum` is priority-ordered.** A customer can only appear in one state per partition. The priority is `intraday > merged > churned > reactivated > new > active`. "Merged" always overrides "churned" — filter carefully when analyzing churn vs. merge attrition.

9. **`ttm_gcr_usd_amt` is 0, not NULL, for intraday.** Do not interpret `ttm_gcr_usd_amt = 0` as "no revenue" without also checking `customer_state_enum != 'intraday'`.

---

### C5. Always-On Column Filters

These filters are embedded in the ETL and apply to every row in the table. They define the scope of the data; they cannot be reversed by the consumer.

| Filter | Applied Source | Effect on Output |
|---|---|---|
| `internal_shopper_flag = true` rows excluded (anti-join: `iss.shopper_id IS NULL`) | `customer360.dim_customer_history_vw` → subscription detail driver + TTM payment driver | Internal GoDaddy shoppers are fully excluded from all subscription and TTM payment calculations; they never appear in the output |
| `finance_payable_resource_flag = true` | Active subscription selection | Only finance-payable subscriptions are counted as "active" |
| `net_positive_ttm_payment_flag = true AND trxn_currency_code <> 'N/A'` | TTM payment aggregation | Only net-positive, valid-currency payments contribute to `ttm_gcr_usd_amt` and `ttm_all_bill_list` |
| `partition_evaluation_mst_date = eval_mst_date` | `analytic_feature.shopper_acquisition` | Acquisition data is point-in-time for the eval date; no historical lookback |
| `record_start_mst_date ≤ eval_mst_date ≤ record_end_mst_date` | `analytic_feature.customer_type_history` | Customer type reflects the record effective on the evaluation date |
| `shopper_merge_start_mst_date ≤ eval_mst_date ≤ shopper_merge_end_mst_date` | `analytic_feature.shopper_merge` | Only merge records active on the evaluation date are considered |
| `current_record_flag = true` | `finance360.dim_country_vw` | Only current geography records are used |
| Partition = `eval_mst_date + 1` | `enterprise.dim_subscription_history`, `enterprise.dim_entitlement_history` | These tables use a partition convention one day ahead of the business date |
| `partition_bill_mst_year_month < '2022-08'` | S3 `ads_bill_line_ext` | Legacy acquisition channel source covers pre-August 2022 data only |

---

### C6. Common Business Metrics

| Metric | Column | Definition | Notes |
|---|---|---|---|
| TTM Gross Cash Received (USD) | `ttm_gcr_usd_amt` | SUM of `enterprise.fact_bill_line.gcr_usd_amt` for net-positive bills in the trailing 12 months; currency ≠ 'N/A' | Set to `0` (not NULL) for intraday customers |
| PNL Category Count | `product_pnl_category_qty` | COUNT(DISTINCT PNL category name) across active finance-payable subscriptions | Reflects current-day subscription state; churned customers reflect d-1 |
| Customer Tenure (Years) | `customer_tenure_year_count` | `FLOOR(DATEDIFF(eval_date, acquisition_date) / 365)` cast to integer | Customers < 1 year show as 0; use `customer_acquisition_mst_date` for sub-year precision |
| Active Customer Indicator | `active_status_flag` | TRUE when `customer_state_enum NOT IN ('churned', 'intraday')` | Use for active customer base counts |
| Customer Lifecycle State | `customer_state_enum` | 6-value ordered enum: `intraday`, `merged`, `churned`, `reactivated`, `new`, `active` | Derived with priority ordering; see C7 for definitions |

---

### C7. Glossary & Term Definitions

| Term | Definition |
|---|---|
| **shopper_id** | The eCommerce platform's account identifier for a GoDaddy customer |
| **customer_id** | A UUID that bridges the eCommerce (`shopper_id`) and back-office systems |
| **net-positive** | A bill or customer where gross cash received exceeds zero (not refunded or voided) |
| **evaluation date** | The `partition_eval_mst_date` value — the business date as of which all facts in that partition are computed |
| **intraday** | A customer whose subscription carries `intraday_flag = true`, was acquired on the evaluation date, and has not yet appeared in the settled active customer snapshot |
| **new** | A customer who was not active on the prior day, is active on the evaluation date, and whose `customer_acquisition_mst_date = eval_date` |
| **active** | A customer who was active on the prior day and remains active on the evaluation date (all cases not covered by other states) |
| **churned** | A customer who was active on the prior day but has no active paid subscriptions on the evaluation date |
| **reactivated** | A customer who appears as "new" on the evaluation date but whose `customer_acquisition_mst_date` predates the evaluation date (previously churned and now returning) |
| **merged** | A customer who churned because their shopper account was merged into another account (`customer_merge_mst_date IS NOT NULL`) |
| **TTM** | Trailing Twelve Months — the 12-month window ending on (and including) the evaluation date |
| **PNL category** | Finance-defined profit-and-loss category used to classify GoDaddy products |
| **finance_payable_resource** | A subscription that is recognized by finance as a billable/payable resource (`finance_payable_resource_flag = true`) |
| **private_label_id** | An identifier for white-label or reseller brand association (e.g., `587240` = 123 Reg) |
| **OSI / OWL** | Internal GoDaddy reporting frameworks; `customer_life_cycle_vw` is documented in Confluence as their primary data target |

---

### C8. Example Queries & Patterns

**Pattern 1 — Active customer count on a specific date**
```sql
-- Always start with a partition filter
SELECT COUNT(DISTINCT shopper_id) AS active_customer_count
FROM customer360.customer_life_cycle_vw
WHERE partition_eval_mst_date = '2026-05-01'
  AND active_status_flag = true;
```

**Pattern 2 — Daily churn summary by region and product breadth**
```sql
-- Customers who churned on a given date; product_pnl_category_qty reflects d-1 for churned rows
SELECT
  customer_region_1_name,
  product_pnl_category_qty,
  COUNT(*) AS churned_customer_count,
  SUM(ttm_gcr_usd_amt) AS churned_ttm_gcr_usd
FROM customer360.customer_life_cycle_vw
WHERE partition_eval_mst_date = '2026-05-01'
  AND customer_state_enum = 'churned'
GROUP BY 1, 2
ORDER BY churned_ttm_gcr_usd DESC;
```

**Pattern 3 — New acquisition cohort by channel and country**
```sql
-- Distinguish 'new' (first-time) from 'reactivated' (returning) customers
SELECT
  customer_state_enum,
  customer_acquisition_channel_name,
  customer_acquisition_country_code,
  COUNT(*) AS customers
FROM customer360.customer_life_cycle_vw
WHERE partition_eval_mst_date = '2026-05-01'
  AND customer_state_enum IN ('new', 'reactivated')
GROUP BY 1, 2, 3
ORDER BY customers DESC;
```

**Pattern 4 — TTM revenue by customer type for active base**
```sql
-- Exclude intraday (their ttm_gcr_usd_amt is always 0)
SELECT
  customer_type_name,
  reseller_type_name,
  COUNT(DISTINCT shopper_id)  AS customer_count,
  SUM(ttm_gcr_usd_amt)        AS total_ttm_gcr_usd
FROM customer360.customer_life_cycle_vw
WHERE partition_eval_mst_date = '2026-05-01'
  AND active_status_flag = true
GROUP BY 1, 2
ORDER BY total_ttm_gcr_usd DESC;
```

**Pattern 5 — Historical reactivation trend (multi-partition scan; scope narrowly)**
```sql
-- CAUTION: each additional partition adds cost; keep date ranges tight
SELECT
  partition_eval_mst_date,
  customer_region_1_name,
  COUNT(*) AS reactivations
FROM customer360.customer_life_cycle_vw
WHERE partition_eval_mst_date BETWEEN '2026-01-01' AND '2026-05-01'
  AND customer_state_enum = 'reactivated'
GROUP BY 1, 2
ORDER BY 1, 3 DESC;
```

---

## Pillar D: HOW Is It Built? — Pipeline & Provenance

### D1. Data Source Reference

The table is built from 20 authoritative lake tables and one external S3 source. Four intermediate `customer_core_conformed.*` tables are used inside the ETL as staging layers; they are not listed here as they are implementation details.

| Lake Table | Role |
|---|---|
| `enterprise.dim_subscription_history` | Active subscription state, subscription IDs, shopper/customer IDs, original bill IDs |
| `enterprise.dim_entitlement_history` | Entitlement-level billing flags used in active subscription driver |
| `enterprise.dim_new_acquisition_shopper` | First net-positive bill date, country, and bill ID per shopper |
| `enterprise.fact_bill_line` | Line-level billing events; primary source for TTM GCR calculation |
| `enterprise.fact_entitlement_bill` | Entitlement-to-bill cross-reference used in subscription detail driver |
| `enterprise.dim_bill_shopper_id_xref` | Maps billing shopper IDs; handles merged and Leka shopper scenarios |
| `analytic_feature.shopper_acquisition` | Acquisition-time metadata and fraud flag per shopper |
| `analytic_feature.customer_type_history` | Customer segment classification over time |
| `analytic_feature.customer_fraud` | Shopper-level fraud flag and event dates |
| `analytic_feature.shopper_merge` | Shopper account merge event records |
| `ecomm_mart.bill_line_traffic_ext` | Marketing channel attribution per bill line (acquisition channel ≥ 2022-08) |
| `ecomm_mart.dim_bill_line_purchase_attribution` | Point of purchase per bill line |
| `ecomm_mart.entitlement_bill_type` | Entitlement billing type classification used in subscription detail driver |
| `finance360.dim_country_vw` | Country name and regional hierarchy |
| `finance360.dim_bill_fraud_history_vw` | Bill-level fraud history for acquisition bill fraud flag |
| `finance360.dim_product_vw` | Product PNL category and line name mapping |
| `dp_enterprise.dim_reseller` | Reseller type ID and name definitions |
| `customer360.dim_customer_history_vw` | Customer private label ID and internal shopper flags |
| `customers.customer_id_mapping_snapshot` | eCommerce-to-UUID shopper identity mapping |
| `finance_cln.manual_paid_subscription` | Manually curated paid subscription overrides used in subscription detail driver |
| S3 `ads_bill_line_ext` (external) | Legacy acquisition channel data; covers pre-August 2022 acquisitions only; hardcoded prod S3 path |

---

### D2. Data Pipeline & Infrastructure

| Attribute | Value |
|---|---|
| Source Repository | `gdcorp-dna/dof-dpaas-customer-feature` (branch: `main`) |
| PySpark Script | `customer360/customer-metrics/src/pyspark/customer_life_cycle.py` |
| DAG File | `customer360/customer-metrics/src/dag/customer_life_cycle_dag.py` |
| DAG ID | `customer-life-cycle` |
| Orchestration | Apache Airflow (MWAA) |
| Compute | Amazon EMR 7.10.0; core nodes: `m6g.16xlarge × 15` (ARM) |
| Spark Package | `emr7_package_arm.tar.gz` + `smart_spark_common-latest-py3-none-any.whl` |
| Switchboard App | `customer-life-cycle` |
| DDL Files | `src/ddls/customer_life_cycle.ddl` (Hive/Glue), `src/ddls/create_customer_life_cycle.sql` (Redshift), `src/ddls/create_customer_life_cycle_stg.sql` (Redshift staging) |
| Policy File | `src/policies/customer_life_cycle_dag.yaml` |
| DQ Constraint Files | `src/data_quality/constraints/customer_life_cycle.json`, `src/data_quality/constraints/customer_life_cycle_vw.json` |
| Lake Catalog Path | `repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/customer-life-cycle-vw/` |

**DAG task flow (summary):**
1. Configure DAG parameters (`dag_config`)
2. Wait on 14 upstream S3 success-file sensors (12-hour timeout each) → `end_dependency_check`
3. Create Redshift target tables if not exists (two SQL files)
4. Launch EMR cluster → execute PySpark via `spark-submit` → terminate EMR
5. DQ uniqueness check on internal Hive table (`customer_core_conformed.customer_life_cycle`)
6. In prod: call Lake API (`SuccessNotificationOperator`) to register `customer360.customer_life_cycle_vw` → DQ check on lake table
7. Load Redshift: S3 COPY to staging table → insert into final Redshift table
8. `check_for_failure_branch` → `succeed_dag_run` or `fail_dag_run`

---

### D3. SLA & Refresh Schedule

| Attribute | Value |
|---|---|
| DAG Schedule | `20 7 * * *` = 7:20 AM MST, daily |
| SLO Delivery Target | `cron(00 15 * * ? *)` = 8:00 AM MST |
| Max Runtime (SLA) | 120 minutes |
| Data Tier | TIER_4 |
| Retries | 1 (retry delay: 3 minutes) |
| Catchup | Disabled |
| Max Active DAG Runs | 15 |
| DAG `start_date` | 2026-01-01 (America/Phoenix timezone) |

**Upstream dependency gating:** 14 of 16 upstream sources are gated by S3 success-file sensors with a 12-hour timeout. Two sources — `finance360.dim_country_vw` and the legacy `ads_bill_line_ext` S3 path — are read without dependency sensors; late delivery of either will not block the DAG.

---

### D4. Table Creation & ETL Implementation

The PySpark script (`customer_life_cycle.py`, ~1,099 lines) performs the following logical steps:

1. **Parameter intake**: accepts `eval_mst_date` (YYYY-MM-DD) as input; defaults to the Airflow `logical_date` in Phoenix timezone if not supplied.
2. **Source reads with partition and business filters**: reads 14 upstream tables — 3 intermediate driver tables (themselves built from lake sources) and 11 lake/external tables direct — applying filters at read time (see C5).
3. **Customer status derivation**: joins previous-day and current-day active customer snapshots to classify each shopper as new, existing, churned, or intraday.
4. **Acquisition enrichment**: joins `enterprise.dim_new_acquisition_shopper` and the legacy S3 channel source to assign acquisition bill ID, date, country, and marketing channel.
5. **Enrichment joins**: LEFT JOINs to fraud (`shopper_acquisition`, `customer_fraud`), customer type (`customer_type_history`), reseller (`dim_reseller` via `dim_customer_history_vw`), and geography (`dim_country_vw`) tables.
6. **Portfolio aggregation**: COLLECT_SET + SORT_ARRAY over the subscription detail driver to build sorted arrays for active subscriptions, PNL categories, PNL lines, and brands.
7. **TTM revenue aggregation**: SUM and COLLECT_SET over the TTM payment driver filtered to net-positive, valid-currency records.
8. **Derived column computation**: `customer_state_enum` (priority-ordered), `active_status_flag`, churn/reactivation/merge/fraud event dates, tenure years.
9. **Schema conformance**: `conform_datatype()` function enforces declared column types for all 35 columns.
10. **Write**: `repartition(30).write.insertInto(customer_core_conformed.customer_life_cycle, overwrite=True)` for the eval date partition.
11. **Post-write repair**: `MSCK REPAIR TABLE` (best-effort; failure is logged but does not fail the job).

The lake table `customer360.customer_life_cycle_vw` is registered by the DAG's `SuccessNotificationOperator` after the Hive write succeeds in prod.

---

## Pillar E: HOW Is It Governed? — Quality, Standards & Ecosystem

### E1. Data Quality Checks

| Check | Scope | Airflow Task | Timing |
|---|---|---|---|
| Primary key uniqueness on `(partition_eval_mst_date, shopper_id)` | `customer_core_conformed.customer_life_cycle` | `dq_check_customer_life_cycle_local` | After EMR write; before lake registration |
| Primary key uniqueness on `(partition_eval_mst_date, shopper_id)` | `customer360.customer_life_cycle_vw` | `dq_check_customer_life_cycle_lake` | After lake registration (prod only) |

DQ constraint definitions: `src/data_quality/constraints/customer_life_cycle.json` and `customer_life_cycle_vw.json`.

The DAG routes to `fail_dag_run` if either DQ check fails or any upstream task fails.

<!-- REQUIRES_MANUAL_INPUT: DG -->
Only primary key uniqueness checks were found in the DQ constraint files. No row-count thresholds, null-rate checks, or referential integrity validations were identified in the available sources. Confirm with the Data Governance team whether additional checks exist in an external data quality platform.

---

### E2. Best Practices & Tips

1. **Always filter on `partition_eval_mst_date` first.** This is the most impactful performance step.
2. **Active customer base:** `WHERE partition_eval_mst_date = '<date>' AND active_status_flag = true` is the standard filter for the settled active customer count.
3. **Exclude intraday from revenue analysis:** `customer_state_enum = 'intraday'` rows always have `ttm_gcr_usd_amt = 0`. Add `AND customer_state_enum != 'intraday'` to revenue queries.
4. **Churn vs. merge attrition:** `customer_state_enum = 'churned'` and `customer_state_enum = 'merged'` are distinct. If you want total attrition (churn + merge), filter `active_status_flag = false AND customer_state_enum NOT IN ('intraday')`.
5. **Do not use tenure = 0 as a proxy for "new."** `customer_tenure_year_count = 0` covers all customers with < 1 year of tenure. Use `customer_state_enum = 'new'` for same-day acquisitions or `customer_acquisition_mst_date` for exact cohort slicing.
6. **Use `customer_acquisition_mst_month` for monthly cohorts.** It is pre-truncated to the first of month and avoids ad hoc date truncation.
7. **Array columns are sorted.** All array columns (`active_paid_subscription_list`, `product_pnl_category_list`, etc.) use `SORT_ARRAY`. String equality comparisons between different partitions are reliable.
8. **Historical partition scans should be scoped narrowly.** `legacyLookBackEnabled = true` means history is available, but wide date range queries are expensive. Add tight `partition_eval_mst_date BETWEEN` bounds.
9. **Country code for UK:** Use 'GB' not 'UK' when filtering `customer_acquisition_country_code` — the ETL normalizes 'UK' to 'GB'.

---

### E3. Related Articles & Documentation

| Resource | Reference |
|---|---|
| Customer360 Confluence Hub | https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3779199819/Customer360 |
| Customer Lifecycle Design Doc (Confluence) | https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3970861345 |
| Customer360 Business Context Structure (Confluence) | https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/4387965088 |
| Churned Customer Definition (Alation article) | https://godaddy.alationcloud.com/article/98/churned-customer |
| PySpark Source File | `gdcorp-dna/dof-dpaas-customer-feature` → `customer360/customer-metrics/src/pyspark/customer_life_cycle.py` |
| DAG Source File | `gdcorp-dna/dof-dpaas-customer-feature` → `customer360/customer-metrics/src/dag/customer_life_cycle_dag.py` |
| Lake Catalog (table.yaml + table.ddl) | `repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/customer-life-cycle-vw/` |

<!-- REQUIRES_MANUAL_INPUT: DG -->
Alation table and column documentation was not retrievable — `MOONUNIT_ALATION` credentials were not available during the gather stage. If Alation contains additional business stewardship metadata, column descriptions, or usage statistics for `customer360.customer_life_cycle_vw`, those should be incorporated manually.
