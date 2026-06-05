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

## Gather Report — customer_life_cycle

**Gathered by:** Data Governance analyst stage  
**Date:** 2026-06-05  
**Git ref verified:** main (HEAD on origin/main, already up-to-date)

---

### 1. PySpark Job Identity

| Field | Value |
|---|---|
| Repo | `dof-dpaas-customer-feature` |
| Ref | `main` |
| File path | `customer360/customer-metrics/src/pyspark/customer_life_cycle.py` |
| FEED_NAME | `customer_life_cycle` |
| Initial author | aghosh, 10/31/2025 |
| Destination DATABASE_NAME | `customer_core_conformed` |
| Destination TABLE_NAME | `customer_life_cycle` |
| Qualified write target | `customer_core_conformed.customer_life_cycle` |
| Write mode | `df.repartition(30).write.insertInto(QUALIFIED_TABLE_NAME, overwrite=True)` |
| Partition column | `partition_eval_mst_date` |
| S3 location | `s3://gd-ckpetlbatch-{AWS_ENV}-customer-core-conformed/customer_core_conformed/customer_life_cycle/` |
| Purpose (from file header) | Driver table for customer life cycle; keeps track of customer life cycle details for active and churned customers; main driver table for customer aggregated metrics |

---

### 2. DAG Identity

| Field | Value |
|---|---|
| File | `customer360/customer-metrics/src/dag/customer_life_cycle_dag.py` |
| DAG ID | `customer-life-cycle` |
| DATA_PIPELINE_NAME | `customer-life-cycle` |
| Schedule | `"20 7 * * *"` (cron; disabled in dev-private) |
| Schedule note | DAG comment says "7:20 AM MST daily" but cron `20 7` is UTC — see Conflicts section |
| Start date | `2026-01-01` (America/Phoenix tz) |
| Catchup | `False` |
| Max active runs | `15` |
| Owner | `customer360` |
| Retries | `1`, retry delay 3 min |
| Slack alert channel (prod) | `edt-airflow-alerts` |
| On-call email | `dl-bi-enterprise-data@godaddy.com` |
| On-call SNOW | `DEV-EDT-OnCall` |
| Team | `EDT` |
| MWAA environment | `dof-customers` |
| EMR release | `emr-7.10.0` |
| Core instances | `15 × m6g.16xlarge` |
| Master instance | `m6g.xlarge` |
| Spark submit | `customer_life_cycle.py` via spark-submit on EMR Serverless |
| DDL file passed | `customer_life_cycle.ddl` |
| DAG tags | `domain:customer`, `sub-domain:active-customer`, `layer:enterprise`, `team:EDT`, `pipeline-group:active-customer`, `special:daily` |
| DQ check (local) | `DataQualityOperator` on `customer_core_conformed.customer_life_cycle` partitioned by `partition_eval_mst_date` |
| DQ check (lake) | `DataQualityOperator` on `customer360.customer_life_cycle_vw` partitioned by `partition_eval_mst_date` |
| Lake API call | `SuccessNotificationOperator` → `customer360.customer_life_cycle_vw` (prod only) |
| Redshift staging load | `S3ToRedshiftOperator` → `customer_core_conformed_prod.customer_life_cycle_vw_stg` |
| Redshift final insert | SQL file `insert_customer_life_cycle.sql` → `customer360.customer_life_cycle_vw` |

**DAG upstream dependencies (S3 success-file sensors):**

| Table | Success key prefix |
|---|---|
| customer_core_conformed.customer_ttm_payment_driver | local_process/customer_core_conformed/customer_ttm_payment_driver |
| customer_core_conformed.customer_active_subscription_detail_driver | local_process/customer_core_conformed/customer_active_subscription_detail_driver |
| customer_core_conformed.active_customer_stg | local_process/customer_core_conformed/active_customer_stg |
| analytic_feature.shopper_acquisition | analytic_feature/shopper_acquisition |
| analytic_feature.customer_type_history | analytic_feature/customer_type_history |
| customer360.dim_customer_history_vw | customer360/dim_customer_history_vw |
| dp_enterprise.dim_reseller | dp_enterprise/dim_reseller |
| enterprise.dim_new_acquisition_shopper | enterprise/dim_new_acquisition_shopper |
| ecomm_mart.bill_line_traffic_ext | ecomm_mart/bill_line_traffic_ext |
| ecomm_mart.dim_bill_line_purchase_attribution | ecomm_mart/dim_bill_line_purchase_attribution |
| finance360.dim_bill_fraud_history_vw | finance360/dim_bill_fraud_history_vw |
| analytic_feature.customer_fraud | analytic_feature/customer_fraud |
| analytic_feature.shopper_merge | analytic_feature/shopper_merge |
| enterprise.dim_subscription_history | enterprise/dim_subscription_history |

---

### 3. Table Inventory

#### 3a. Write Target — `customer_core_conformed.customer_life_cycle`

**Role:** WRITE (primary Hive/Parquet table)  
**DDL source:** `src/ddls/customer_life_cycle.ddl` (Hive DDL, used by PySpark at runtime)  
**Partition key:** `partition_eval_mst_date STRING`  
**Storage:** PARQUET, `s3://gd-ckpetlbatch-{AWS_ENV}-customer-core-conformed/customer_core_conformed/customer_life_cycle/`

| Column | Type | Comment |
|---|---|---|
| shopper_id | string | PK: shopper id |
| customer_id | string | PK: Customer ID |
| customer_acquisition_bill_id | string | Bill ID that triggered first net positive status for customer |
| customer_acquisition_mst_date | date | Date of bill that triggered first net positive status for customer (MST) |
| customer_acquisition_mst_month | string | Month of customer acquisition (MST), truncated to month |
| customer_acquisition_country_code | string | Country code where customer was acquired |
| customer_acquisition_channel_name | string | Channel through which customer was acquired |
| customer_tenure_year_count | int | Tenure of the customer in years |
| customer_acquisition_country_name | string | Country name where customer was acquired |
| customer_region_1_name | string | Geographic region 1 for the customer |
| customer_region_2_name | string | Geographic region 2 for the customer |
| customer_region_3_name | string | Geographic region 3 for the customer |
| customer_domestic_international_name | string | Whether customer is domestic or international |
| reseller_type_id | int | Type ID of reseller organization |
| reseller_type_name | string | Name of the reseller |
| customer_type_name | string | Customer type label at evaluation date |
| customer_type_reason_desc | string | Customer type reason |
| customer_fraud_flag | boolean | True if customer is flagged as fraud at evaluation date |
| active_paid_subscription_list | array<string> | List of active paid subscriptions |
| product_pnl_category_list | array<string> | List of product PNL categories owned by customer |
| product_pnl_category_qty | int | Number of distinct product PNL categories owned by customer |
| product_pnl_line_list | array<string> | List of product PNL lines owned by customer |
| ttm_all_bill_list | array<string> | List of all bill IDs from trailing twelve months (TTM) |
| brand_name_list | array<string> | List of all brands associated with the customer |
| ttm_gcr_usd_amt | decimal(18,2) | Total gross cash received (GCR) USD in trailing twelve months |
| customer_churn_mst_date | date | MST date when customer most recently churned, null if not churned |
| customer_reactivate_mst_date | date | MST date when customer was most recently reactivated (after churn) |
| customer_merge_mst_date | date | MST date when the customer was merged into another account |
| customer_fraud_mst_date | date | MST date when a fraud flag was set on customer |
| customer_state_enum | string | customer states as of evaluation date (active, churned, merged, reactivated) |
| active_status_flag | boolean | True if customer is currently active at evaluation date |
| point_of_purchase_name | string | Point of purchase name from the customer acquisition bill |
| customer_acquisition_bill_fraud_flag | boolean | True if acquisition bill has fraud record in dim_bill_fraud_history_vw |
| etl_build_mst_ts | timestamp | Time when this record was built by ETL system |
| partition_eval_mst_date | string | PARTITION: data collection end date; all facts as of end of this day |

**Note:** The Lake-facing table is `customer360.customer_life_cycle_vw` (registered via SuccessNotificationOperator and DLMS). The DDL in `repos/lake/.../customer-life-cycle-vw/table.ddl` has identical column definitions (42 columns, no partition column in DDL body — partition is managed by Lake).

#### 3b. Source Tables (READ)

| Table | Role | Join Keys Used | Notes |
|---|---|---|---|
| analytic_feature.shopper_acquisition | READ | shopper_id (joined on bill_shopper_id) | Filtered by partition_evaluation_mst_date = eval_mst_date |
| analytic_feature.customer_type_history | READ | shopper_id | Filtered: record_start_mst_date <= eval AND record_end_mst_date >= eval |
| customer360.dim_customer_history_vw | READ | shopper_id | SCD2; filtered by effective_start/end_mst_ts; used for private_label_id and 123Reg detection |
| finance360.dim_country_vw | READ | country_code (joined on bill_country_code), current_record_flag=true | Broadcast hint applied |
| dp_enterprise.dim_reseller | READ | private_label_id | Grouped by private_label_id |
| enterprise.dim_new_acquisition_shopper | READ | bill_shopper_id | Provides acquisition bill info |
| enterprise.dim_subscription_history | READ | shopper_id | Filtered by partition_history_mst_date = eval_mst_date + 1; first subscription per shopper |
| ecomm_mart.bill_line_traffic_ext | READ | original_shopper_id→shopper_id | Filtered: bill_modified_mst_date <= eval AND new_acquisition_bill_mst_date=bill_modified_mst_date AND bill_id=new_acquisition_bill_id |
| customer_core_conformed.customer_ttm_payment_driver | READ | shopper_id, customer_id | Filtered by partition_eval_mst_date BETWEEN eval-1 AND eval; trxn_currency_code <> 'N/A' AND net_positive_ttm_payment_flag = true |
| customer_core_conformed.customer_active_subscription_detail_driver | READ | subscription_shopper_id→shopper_id, subscription_customer_id→customer_id | Filtered: finance_payable_resource_flag = true |
| customer_core_conformed.active_customer_stg | READ | shopper_id | Filtered by partition_eval_mst_date IN (eval-1, eval) |
| analytic_feature.customer_fraud | READ | shopper_id, customer_id | No partition filter — full scan |
| analytic_feature.shopper_merge | READ | original_shopper_id | Filtered: shopper_merge_start_mst_date <= eval AND shopper_merge_end_mst_date >= eval |
| ecomm_mart.dim_bill_line_purchase_attribution | READ | bill_id | ROW_NUMBER() OVER (PARTITION BY bill_id ORDER BY bill_line_num DESC) |
| finance360.dim_bill_fraud_history_vw | READ | bill_id | SELECT DISTINCT bill_id only |
| s3://gd-ckpetlbatch-prod-analytic/analytic/ads_bill_line_ext/ | READ | original_shopper_id→shopper_id, bill_id, new_acquisition_bill_id | **HARDCODED PROD S3 path** — legacy pre-2022-08 data; not environment-aware |

#### 3c. Write Targets (secondary)

| Table | Role | Mechanism |
|---|---|---|
| customer360.customer_life_cycle_vw | WRITE (Lake) | SuccessNotificationOperator + Lake API registration; Redshift insert from stg |
| customer_core_conformed_prod.customer_life_cycle_vw_stg | WRITE (Redshift staging) | S3ToRedshiftOperator (PARQUET, SERIALIZETOJSON) |

---

### 4. Join Conditions (Explicit)

All joins in the final assembly (`get_combined_customer_life_cycle_df`):

| # | Left | Right | Join Type | Keys |
|---|---|---|---|---|
| 1 | combined_customer_base ac | shopper_acquisition acq | LEFT | ac.shopper_id = acq.shopper_id |
| 2 | combined_customer_base ac | shopper_subscription ss | LEFT | ac.shopper_id = ss.shopper_id |
| 3 | combined_customer_base ac | private_label pl | LEFT | ac.shopper_id = pl.shopper_id |
| 4 | combined_customer_base ac | customer_type_history ct | LEFT | ac.shopper_id = ct.shopper_id |
| 5 | combined_customer_base ac | reg123_shopper gd | LEFT | ac.shopper_id = gd.shopper_id |
| 6 | combined_customer_base ac | combined_bill_line blt | LEFT | ac.shopper_id = blt.shopper_id |
| 7 | combined_customer_base ac | shopper_merge sm | LEFT | ac.shopper_id = sm.original_shopper_id |
| 8 | combined_customer_base ac | customer_fraud cf | LEFT | ac.shopper_id = cf.shopper_id AND ac.customer_id = cf.customer_id |
| 9 | combined_customer_base ac | point_of_purchase pop | LEFT | pop.bill_id = COALESCE(acq.bill_id, ss.original_bill_id) [if new/intraday] else acq.bill_id |
| 10 | combined_customer_base ac | bill_fraud bf | LEFT | bf.bill_id = COALESCE(acq.bill_id, ss.original_bill_id) [if new/intraday] else acq.bill_id |

Intermediate joins within helper functions:

| # | Left | Right | Join Type | Keys |
|---|---|---|---|---|
| 11 | enterprise.dim_new_acquisition_shopper acq | shopper_acquisition_source sa | LEFT | acq.bill_shopper_id = sa.shopper_id |
| 12 | enterprise.dim_new_acquisition_shopper acq | finance360.dim_country_vw geo | LEFT (BROADCAST) | acq.bill_country_code = geo.country_code AND geo.current_record_flag = true |
| 13 | date_filtered df (dim_customer_history_vw) | latest_record lr (dim_customer_history_vw) | FULL OUTER | df.shopper_id = lr.shopper_id |
| 14 | combined c (from dim_customer_history_vw) | dim_reseller res | LEFT (BROADCAST) | c.private_label_id = res.private_label_id |
| 15 | active_customer_non_churned ac | subscription_detail_eval_date sd | LEFT | ac.shopper_id = sd.shopper_id AND COALESCE(ac.customer_id,'na') = COALESCE(sd.customer_id,'na') |
| 16 | active_customer_non_churned ac | ttm_payment_eval_date ttm | LEFT | ac.shopper_id = ttm.shopper_id AND COALESCE(ac.customer_id,'na') = COALESCE(ttm.customer_id,'na') |
| 17 | active_customer_churned ac | subscription_detail_previous_day sd | LEFT | ac.shopper_id = sd.shopper_id AND COALESCE(ac.customer_id,'na') = COALESCE(sd.customer_id,'na') |
| 18 | active_customer_churned ac | ttm_payment_previous_day ttm | LEFT | ac.shopper_id = ttm.shopper_id AND COALESCE(ac.customer_id,'na') = COALESCE(ttm.customer_id,'na') |
| 19 | intraday_shopper_details isd | enterprise.dim_new_acquisition_shopper acq | LEFT | acq.bill_shopper_id = isd.shopper_id |
| 20 | intraday_shopper_details isd | customer_core_conformed.active_customer_stg ac | LEFT | isd.shopper_id = ac.shopper_id (filter: acq.new_acquisition_bill_mst_date = eval_mst_date AND ac.shopper_id IS NULL) |

---

### 5. Aggregation Expressions

#### `get_ttm_payment_df` — TTM payment rollup
```
GROUP BY partition_eval_mst_date, shopper_id, customer_id
  sort_array(collect_set(last_net_positive_bill_id))  AS ttm_all_bill_list
  sort_array(collect_set(brand_name))                  AS brand_name_list
  SUM(ttm_total_gcr_usd_amt)                           AS ttm_gcr_usd_amt
```
Filters: trxn_currency_code <> 'N/A' AND net_positive_ttm_payment_flag = true

#### `get_subscription_detail_df` — Active subscription rollup
```
GROUP BY partition_eval_mst_date, subscription_shopper_id, subscription_customer_id
  SORT_ARRAY(COLLECT_SET(subscription_id))      AS active_paid_subscription_list
  SORT_ARRAY(COLLECT_SET(product_pnl_category)) AS product_pnl_category_list
  SORT_ARRAY(COLLECT_SET(product_pnl_line))     AS product_pnl_line_list
  SORT_ARRAY(COLLECT_SET(brand_name))           AS brand_name_list (also merged with TTM brands)
  COUNT(DISTINCT product_pnl_category)          AS product_pnl_category_qty
```
Filters: finance_payable_resource_flag = true AND (subscription_billing_shopper_differ_flag = false OR bill_merged_shopper_id IN ('554670720','554671405') OR domain_payment_override_flag = true)

#### `get_active_customer_status` — Customer status pivot
```
GROUP BY shopper_id
  MAX(customer_id)                                                                              AS customer_id
  MAX(CASE WHEN partition_eval_mst_date = eval-1 THEN 1 ELSE 0 END)                           AS active_prev
  MAX(CASE WHEN partition_eval_mst_date = eval    THEN 1 ELSE 0 END)                           AS active_curr
→ CASE new/existing/churned based on active_prev, active_curr
```

#### `get_reseller_df` — Reseller type dedup
```
GROUP BY private_label_id (COALESCE NULL → 1)
  MIN(reseller_type_id)   AS reseller_type_id
  MIN(reseller_type_name) AS reseller_type_name
```

#### `get_shopper_subscription_df` — First subscription
```
ROW_NUMBER() OVER (PARTITION BY shopper_id ORDER BY subscription_create_mst_date ASC) AS rn
→ WHERE rn = 1
```

#### `get_point_of_purchase_df` — Latest bill line
```
ROW_NUMBER() OVER (PARTITION BY bill_id ORDER BY bill_line_num DESC) AS rn
→ WHERE rn = 1
```

#### `final_customer_life_cycle_df` — Derived fields
```
TRUNC(customer_acquisition_mst_date, 'MONTH')                          AS customer_acquisition_mst_month
CAST(datediff(partition_eval_mst_date, customer_acquisition_mst_date) / 365 AS INT) AS customer_tenure_year_count
CASE customer_status='new' AND customer_acquisition_mst_date < partition_eval_mst_date → partition_eval_mst_date END AS customer_reactivate_mst_date
CASE customer_state_enum: intraday/merged/churned/reactivated/new/active END
WHEN UPPER(customer_acquisition_country_code) = 'UK' THEN 'GB' ELSE UPPER(...) END  (UK→GB normalization)
```

---

### 6. DDL and Policy Files Consulted

| File | Type | Notes |
|---|---|---|
| `src/ddls/customer_life_cycle.ddl` | Hive DDL | Runtime DDL passed to EMR; 44 columns + partition_eval_mst_date; starts with shopper_id |
| `src/ddls/create_customer_life_cycle.sql` | Redshift DDL | `customer360.customer_life_cycle_vw`; 36 columns (no partition col in body); DISTSTYLE AUTO DISTKEY/SORTKEY = partition_eval_mst_date |
| `src/ddls/create_customer_life_cycle_stg.sql` | Redshift DDL | `customer_core_conformed_prod.customer_life_cycle_vw_stg`; staging table without partition |
| `src/ddls/insert_customer_life_cycle.sql` | Redshift SQL | Insert logic from stg → final Redshift table |
| `repos/lake/.../customer-life-cycle-vw/table.ddl` | Lake DDL | 42 columns; starts with customer_id; used by DLMS for Lake catalog registration |
| `repos/lake/.../customer-life-cycle-vw/table.yaml` | Lake metadata | PARTITIONED, Parquet, data_tier=4, SLA cron(00 15 * * ? *) = 08:00 AM MST |
| `src/policies/customer_life_cycle_dag.yaml` | Policy YAML | Lists all 17 input tables, 2 outputs, SLA maxDurationMins=120, severity=TIER_4 |
| `src/policies/environment.prod.yaml` | Environment policy | Team=EDT, AWS accounts: Airflow=688051721285, EMR=664289052486, Redshift=561403605607 |
| `src/data_quality/constraints/customer_life_cycle.json` | DQ constraint | isPrimaryKey("partition_eval_mst_date","shopper_id") on customer_core_conformed.customer_life_cycle |
| `src/data_quality/constraints/customer_life_cycle_vw.json` | DQ constraint | isPrimaryKey("partition_eval_mst_date","shopper_id") on customer360.customer_life_cycle_vw |

---

### 7. Confluence Summary

**Page 3779199819 — Customer360** (main product page)  
- Customer360 is GoDaddy's foundational data product for the Customer domain.  
- Provides trusted, unified view of customers for analytics, reporting, data science.  
- `customer_life_cycle_vw` is listed under "Customer Lifecycle Dataset":  
  > "SSOT of customer's lifecycle holistically — compresses states and logic spread across 3 marts built with SCD2 to understand change over time easily. Includes ALL customers."  
- Status: 🟡 In Progress (Committed for Current Quarter)  
- Replaces/supersedes customer lifecycle data previously spread across multiple marts.

**Page 4387965088 — Customer360 Business Context Structure**  
- `customer_life_cycle_vw`: Type=PARTITIONED, Tier=4, Grain="One row per customer per eval date"  
- Coverage matrix: `customer_life_cycle_vw` weighted 35% (highest of all Customer360 datasets) — described as "primary OSI and OWL target"  
- Schema: `customer360`, Domain: Customer, Organization: DNA, Data Tier: 2 (dim) / 4 (lifecycle, agg)

---

### 8. Alation Section

**Table record:** `customer360.customer_life_cycle_vw`  
**Alation ID:** 7038345  
**Connector:** Athena  
**Auto title status:** HIGH_CONFIDENCE  

**Description (from Alation):**  
> A comprehensive snapshot table that tracks the complete lifecycle journey of customers from acquisition through various lifecycle states. This table captures daily snapshots of customer status, enabling analysis of state transitions, and changes between consecutive evaluation periods.
>
> Key Features:
> - Lifecycle tracking (acquisition, churn, reactivation, merge, fraud)
> - Active subscription product tracking
> - Multi-dimensional state tracking through Foreign Keys
> - Trailing twelve month (TTM) GCR

**Custom field "Business Context":** Present in schema (id 10045, RICH_TEXT type). Value not extracted in detail.

**Saved queries referencing this table (max 5):**

| Query ID | Author | Title | SQL |
|---|---|---|---|
| 1 | Sharon Graves (shgraves@godaddy.com) | (none) | Empty — content unavailable via API |
| 27 | Michael Valeri (mvaleri@godaddy.com) | (none) | Empty — content unavailable via API |
| 130 | Sharon Graves (shgraves@godaddy.com) | (none) | Empty — content unavailable via API |
| 226 | Daniel Vargo (dvargo@godaddy.com) | (none) | Empty — content unavailable via API |
| 324 | Douglas Diamant (ddiamant@godaddy.com) | (none) | Empty — content unavailable via API |

**Note:** The Alation `/api/query/` endpoint returned 5 query records but all had empty `content`/`sql` fields. The query IDs appear to be counter-based (1, 27, 130, 226, 324), suggesting these are environment-level query IDs. No SQL was recoverable.

---

### 9. Conflicts / Discrepancies

| # | Location | Discrepancy | Code (authoritative) |
|---|---|---|---|
| 1 | DAG comment | "Runs 7:20 AM MST daily" but cron `20 7 * * *` is UTC (= 00:20 AM MST / 1:20 AM MST) | cron `20 7 * * *` UTC is authoritative |
| 2 | DAG doc_md | "SLA: N/A" | policies/customer_life_cycle_dag.yaml says maxDurationMins=120, severity=TIER_4 |
| 3 | Lake table.yaml DDL (table.ddl) | Column order starts with `customer_id` | Hive DDL (customer_life_cycle.ddl) starts with `shopper_id` — PySpark conform_datatype() confirms shopper_id is first column written |
| 4 | Lake table.yaml lineage | Lists additional upstream tables: customers.customer_id_mapping_snapshot, ecomm_mart.entitlement_bill_type, enterprise.dim_bill_shopper_id_xref, enterprise.dim_entitlement_history, enterprise.fact_bill_line, enterprise.fact_entitlement_bill, finance360.dim_product_vw, finance_cln.manual_paid_subscription | These tables are NOT directly read by customer_life_cycle.py — they appear to be indirect dependencies (of the driver tables). Treat PySpark code as authoritative for direct lineage. |
| 5 | PySpark — legacy S3 read | `spark.read.parquet("s3://gd-ckpetlbatch-prod-analytic/analytic/ads_bill_line_ext/")` is HARDCODED to prod regardless of AWS_ENV | All other reads are environment-parameterized. This is a code defect (non-blocking). |
| 6 | policies/customer_life_cycle_dag.yaml | Lists `analytic_local.ads_bill_line_ext` as an input | PySpark reads it via hardcoded S3 path, not as a Hive table. Policy label is approximate. |
| 7 | DAG markdown doc | "Confluence Link: Todo" | Actual Confluence page is https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3779199819/Customer360 |
| 8 | Hive DDL PK comment | "Primary Key: resource_id, product_family_name, entitlement_addon_id, partition_eval_mst_date" | DQ constraints (and Lake DDL comments) confirm actual PK is (partition_eval_mst_date, shopper_id). The comment appears copy-pasted from another table's DDL. |
| 9 | Lake table.yaml SLA | `deliveryCadenceUTC: "cron(00 15 * * ? *)"` = 08:00 AM MST | DAG schedule `20 7 * * *` UTC = 00:20 AM MST. Gap between pipeline run and Lake delivery SLA = ~8 hours (expected). |

---

### 10. Summary

The `customer_core_conformed.customer_life_cycle` table (Lake-facing: `customer360.customer_life_cycle_vw`) is a daily-partitioned customer lifecycle snapshot table. It joins 15 source tables to produce one row per shopper per `partition_eval_mst_date`. Key dimensions include customer state enum (active/churned/merged/reactivated/new/intraday), acquisition attributes (bill, date, country, channel, geography), reseller classification, customer type, fraud flags, active subscription lists, and TTM GCR revenue. The table is produced by EMR Serverless job `customer_life_cycle.py` triggered by Airflow DAG `customer-life-cycle` at 07:20 UTC daily. The primary key (per DQ constraints) is `(partition_eval_mst_date, shopper_id)`. Data tier is 4. SLA: delivered by 08:00 AM MST.


**The agent's final response to the user was:**
The gather stage is complete. Here is a summary of everything collected and appended to `gather.md`:

---

## Gather Summary — `customer_life_cycle`

### Sources checked
- **PySpark script** (`customer_life_cycle.py`, 1,098 lines) — fully read, all logic extracted
- **DAG** (`customer_life_cycle_dag.py`) — schedule, dependencies, DQ checks, Redshift load operators
- **DDL files** — Hive DDL (runtime), Redshift prod/staging DDLs, Lake registry DDL/YAML
- **Policy YAML** — input/output table list, SLA, environment config
- **Data quality constraints** — primary key definitions for both local and lake tables
- **Confluence** — main Customer360 page (3779199819) + Business Context page (4387965088)
- **Alation** — table ID 7038345 retrieved with description; 5 saved query records found (SQL content empty via API)

### Key facts extracted

| Fact | Value |
|---|---|
| Write target | `customer_core_conformed.customer_life_cycle` / Lake: `customer360.customer_life_cycle_vw` |
| Grain | One row per shopper per `partition_eval_mst_date` |
| PK (per DQ) | `(partition_eval_mst_date, shopper_id)` |
| Schedule | `20 7 * * *` UTC (07:20 UTC = ~00:20 MST) daily |
| Data tier | 4 |
| Lake SLA | 08:00 AM MST (`cron(00 15 * * ? *)`) |
| Source tables (direct reads) | 15 tables + 1 hardcoded S3 legacy path |
| All joins | 20 explicit join conditions extracted |
| Aggregations | TTM GCR SUM, COLLECT_SET subscription/brand/bill lists, COUNT DISTINCT PNL categories, ROW_NUMBER dedup patterns |

### Notable conflicts (9 total)
- DAG comment says "7:20 AM MST" but cron is UTC (= ~00:20 MST)
- Hive DDL has copy-pasted PK comment from another table (actual PK is shopper_id, not resource_id)
- Legacy S3 read is hardcoded to prod bucket regardless of environment
- Lake lineage YAML lists 8 additional indirect upstream tables not directly read by this script
- DAG doc says "SLA: N/A" but policy YAML specifies TIER_4 / 120-min max duration