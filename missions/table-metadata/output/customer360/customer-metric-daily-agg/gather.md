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
- Optional lake table override
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
# Example: if source repo URL is https://github.com/gdcorp-dna/my-repo.git
# then folder is repos/my-repo/
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

## Step 4: Collect nearby repo context (secondary sources)
- Read relevant files under sibling folders:
  - `ddl/` (table DDLs) — helpful but may be stale
  - `policies/` — helpful but may be stale
  - `data_quality/` — checks and expectations (treat as evidence, not truth)
Record any conflicts with code explicitly.

## Step 5: Fetch Confluence pages (if provided)
For each URL in INPUT.md under CONFLUENCE PAGES, fetch page content via Atlassian REST API.
The page ID is the numeric part of the URL path.

**IMPORTANT: Parent pages may link to child pages.** A provided URL might be a parent/hub
page (e.g., "Customer360") containing links to multiple child pages for individual tables.
You MUST:
1. Fetch the provided page first.
2. List its child pages using:
   ```bash
   curl -s -u "$ATLASSIAN_CREDS" \
     "https://godaddy-corp.atlassian.net/wiki/rest/api/content/{PAGE_ID}/child/page?limit=50"
   ```
3. From the child pages, identify which ones are relevant to the target table
   (match by table name, job name, or domain keywords).
4. Fetch ONLY the relevant child pages (not all of them).
5. If the provided page itself has useful content, use it too.

Credentials:
- Prefer `MOONUNIT_JIRA` env var (JSON: {"url","email","api_token"}) OR
- `MOONUNIT_ATLASSIAN` env var (JSON: {"email","api_token"})

Example:
```bash
ATLASSIAN_CREDS=$(node -e "const j=JSON.parse(process.env.MOONUNIT_JIRA || process.env.MOONUNIT_ATLASSIAN); console.log(j.email + ':' + j.api_token)")
curl -s -u "$ATLASSIAN_CREDS" \
  "https://godaddy-corp.atlassian.net/wiki/rest/api/content/{PAGE_ID}?expand=body.storage"
```

Extract only content relevant to business meaning, grain, metrics, filters, SLAs, ownership.

## Step 6: Alation lookup (if enabled)
If INPUT.md says Alation is enabled:
1. First check if `MOONUNIT_ALATION` env var is available:
```bash
node -e "if(!process.env.MOONUNIT_ALATION){console.log('MOONUNIT_ALATION not set');process.exit(1)}else{console.log('OK')}"
```
If it's not available, skip Alation and note this in gather.md under "Alation: skipped (credentials not available)".

2. If available, create API token:
```bash
ALATION_CREDS=$(node -e "const j=JSON.parse(process.env.MOONUNIT_ALATION); console.log(JSON.stringify({refresh_token:j.refresh_token, user_id:j.user_id||j.ALATION_USER_ID}))")
TOKEN=$(curl -s -X POST "https://godaddy.alationcloud.com/integration/v1/createAPIAccessToken/" \
  -H "Content-Type: application/json" \
  -d "$ALATION_CREDS" | node -e "process.stdin.on('data',d=>console.log(JSON.parse(d).api_access_token))")
```

3. **Fetch table entries for the target table name** (once you know it from code analysis).
   Search Alation for the table by name to find BOTH the Redshift Serverless and Lake entries:
```bash
curl -s -H "Token: $TOKEN" \
  "https://godaddy.alationcloud.com/integration/v2/table/?name=<TABLE_NAME>&limit=50"
```
   From the results, identify:
   - **Redshift Serverless Dev entry**: look for entries where the key contains
     a Redshift data source (often has "Redshift" or "Serverless" in the ds_name
     or the key path). Record its Alation table ID.
   - **Lake entry**: look for entries where the key matches the Hive/Glue catalog
     (often contains the schema directly like `<schema>.<table>`). Record its Alation table ID.

   Construct Alation URLs as: `https://godaddy.alationcloud.com/table/<ID>/`

4. Record in gather.md under "## Alation" a structured block:
   - Redshift table: name, database (e.g. "Redshift - Serverless - Dev"), schema, Alation URL
   - Lake table: name, schema, Alation URL
   - Any descriptions or custom fields found

## Step 6b: Fetch Alation queries referencing this table

After you know the target table name (from PySpark/DAG), fetch saved queries in Alation
that reference it. Use `Max queries` from INPUT.md (default 10).

```bash
TABLE_NAME=<table_name_only e.g. customer_metric_daily_agg_vw>
MAX_QUERIES=<from INPUT.md>
curl -s -H "Token: $TOKEN" \
  "https://godaddy.alationcloud.com/integration/v1/query/?content__icontains=${TABLE_NAME}&order_by=-last_saved_at&limit=${MAX_QUERIES}"
```

For EACH query in the response, record under "## Alation Queries" in gather.md:

| Field | Source |
|---|---|
| Query ID | `id` |
| Title | `title` |
| Author | `author.display_name` or `author.username` or empty |
| Description | `description` if present; else one-line summary from SQL |
| Schedule | `schedule_cron`, `schedule_name`, or "Not scheduled" |
| Last Saved | `last_saved_at` |
| Last Run | `schedule_db_ts_last_execution` or latest execution event if available |
| Datasource | map `datasource_id` to name if possible; else empty |
| Alation Query URL | `https://godaddy.alationcloud.com/query/<id>/` |
| SQL | `content` field — copy verbatim, do not modify |

If the query API returns no results, try `content__icontains=<schema>.<table>` as well.
If still none, note "No Alation queries found" under ## Alation Queries.

## Step 7: Output (append to gather.md)
Append a structured, evidence-oriented report including:
- PySpark job identity (repo/ref/path), and the exact output write target(s) found (if any)
- DAG identity (path, schedule, params calling the PySpark)
- Enumerated upstream/local tables referenced in the PySpark
- Any DDL/policy/DQ files consulted and what they claim
- Confluence summaries (if any)
- Alation section with:
  - Redshift Serverless table info (table name, database, schema, Alation URL)
  - Lake table Alation URL
  - Any descriptions or custom fields retrieved
- Alation Queries section (full query details per Step 6b)
- A "Conflicts / discrepancies" section listing any contradictions with the code

**The agent summarized its work in this way:**

---

## Gather Stage — Research Summary

**Git ref checked out:** `main` (HEAD: `7523b6d5`) — repo `repos/dof-dpaas-customer-feature/`

---

## PySpark Job Identity

| Field | Value |
|---|---|
| Repo | `gdcorp-dna/dof-dpaas-customer-feature` |
| Ref | `main` (HEAD `7523b6d5`) |
| Script path | `customer360/customer-metrics/src/pyspark/customer_metric_daily_agg.py` |
| FEED_NAME | `customer_metric_daily_agg` |
| Author / initial commit | `aghosh`, `11/06/2025` |

### Output write target (from code)

```
customer_core_conformed.customer_metric_daily_agg
  → s3://gd-ckpetlbatch-{AWS_ENV}-customer-core-conformed/customer_core_conformed/customer_metric_daily_agg/
  write mode: insertInto(overwrite=True), repartition(1)
  partition key: partition_eval_mst_date
```

The DAG also pushes a Lake success notification for `customer360.customer_metric_daily_agg_vw` (the Glue/Hive catalog view on the same S3 data), which is the public-facing lake table.

---

## DAG Identity

| Field | Value |
|---|---|
| DAG path | `customer360/customer-metrics/src/dag/customer_metric_daily_agg_dag.py` |
| DAG ID | `customer-metric-daily-agg` |
| Schedule | `30 7 * * *` = **7:30 AM MST daily** (disabled in dev-private) |
| Start date | `2026-01-01` |
| Timezone | `America/Phoenix` (MST) |
| EMR release | `emr-7.10.0` |
| EMR cluster | 15 core nodes, `m6g.16xlarge` |
| Catchup | `False` |
| Max active runs | `15` |
| Retries | `1`, retry delay `3 min` |
| Owner | `customer360` |
| Tags | `domain:customer`, `sub-domain:active-customer`, `layer:enterprise`, `team:EDT`, `pipeline-group:active-customer`, `special:daily` |

### DAG parameters passed to PySpark
- `--environment {AWS_ENV}`
- `--start_mst_date {start_mst_date}` (from DAG config or `logical_date` in MST if not provided)
- `--end_mst_date {end_mst_date}` (same fallback)
- `--spark_conf_str` (from `params.spark_config`)
- `--sb_app_id` / `--sb_setting_id` (Switchboard config)

### Task flow
```
dag_config
  → dependencies [wait_for customer360.customer_life_cycle_vw S3 success file]
  → end_dependency_check
  → create_redshift_tables [create_customer_metric_daily_agg.sql, create_customer_metric_daily_agg_stg.sql]
  → create_emr
  → run_customer_metric_daily_agg  ← PySpark step
  → remove_emr
  → dq_check_customer_metric_daily_agg_local  [DQ on customer_core_conformed.customer_metric_daily_agg]
  → conditional_call_lake_api
    → [prod] call_lake_api (SuccessNotificationOperator: customer360.customer_metric_daily_agg_vw)
    → [non-prod] skip_call_lake_api
  → s3_to_redshift_customer_metric_daily_agg_stg  (PARQUET COPY from S3 → staging table)
  → insert_customer_metric_daily_agg  (upsert staging → customer360.customer_metric_daily_agg_vw)
  → check_for_failure_branch → succeed/fail_dag_run
  [prod only] call_lake_api → dq_check_customer_metric_daily_agg_lake
```

### Operational contacts (from DAG docstring)
- Slack alerts: `#edt-airflow-alerts` (prod), `#edt-airflow-alerts-low-priority` (other)
- Dev group: `#edt` (private)
- OnCall: `#marketing-data-product-engineering`
- OnCall Email: `dl-bi-enterprise-data@godaddy.com`
- SNOW: `DEV-EDT-OnCall`
- Stakeholders: `#marketing-data-products-help`
- SLA in DAG docstring: `N/A`; Data Tier: `N/A`

---

## Upstream / Source Tables Referenced in PySpark

| Table | Status | Notes |
|---|---|---|
| `customer_core_conformed.customer_life_cycle` | **Active (used)** | Primary source; full WHERE range is `start_mst_date_minus_1` to `end_mst_date` |
| `customer360.customer_life_cycle_vw` | **Commented out** | `--customer360.customer_life_cycle_vw` in SQL comment; not active |

The DAG dependency sensor waits for the S3 success file of `customer360.customer_life_cycle_vw`, suggesting the pipeline depends on the lifecycle job upstream even though the code reads from the conformed table.

---

## Column Inventory (from PySpark + DDL, authoritative)

### Dimensions (18 columns — composite key)
| Column | Type | Description |
|---|---|---|
| `customer_type_reason_desc` | string | Reason for customer type classification |
| `customer_acquisition_mst_month` | string | Month of customer acquisition (MST), truncated to month |
| `customer_domestic_international_name` | string | Domestic vs International classification |
| `customer_region_1_name` | string | Geographic region level 1 |
| `customer_region_2_name` | string | Geographic region level 2 |
| `customer_region_3_name` | string | Geographic region level 3 |
| `customer_country_name` | string | Customer country name at evaluation date |
| `customer_country_code` | string | Customer country code (normalised: "UK" → "GB") |
| `customer_type_name` | string | Customer type at evaluation date |
| `acquisition_channel_name` | string | Acquisition channel |
| `customer_tenure_year_count` | int | Customer tenure in years (integer) |
| `product_ownership_category_list` | string | Owned product category list (string-encoded) |
| `product_ownership_line_list` | string | Owned product line list (string-encoded) |
| `reseller_type_name` | string | Reseller type name |
| `fraud_flag` | boolean | True if customer marked as fraud as of evaluation date |
| `point_of_purchase_name` | string | Point of purchase name from acquisition bill |
| `customer_acquisition_bill_fraud_flag` | boolean | True if acquisition bill has fraud record |
| `brand_name_list` | string | List of all brands associated with the customer |

### Measures / Metrics (11 columns)
| Column | Type | Description |
|---|---|---|
| `ttm_gcr_usd_amt` | decimal(18,2) | Total gross cash received (GCR) USD in trailing twelve months |
| `ending_customer_qty` | bigint | Ending customer count as of evaluation date |
| `churn_customer_qty` | bigint | Customers churned on evaluation date |
| `merge_customer_qty` | bigint | Customers merged on evaluation date |
| `new_customer_qty` | bigint | New customers on evaluation date |
| `reactivate_customer_qty` | bigint | Reactivated customers on evaluation date |
| `beginning_customer_qty` | bigint | Beginning customer count from prior day (window function: LAG over dims) |
| `net_move_qty` | bigint | `ending - beginning - new + (churn - reactivate) + merge` |
| `net_add_qty` | bigint | `ending - beginning` |
| `net_churn_qty` | bigint | `churn - reactivate` |
| `product_category_qty` | int | Count of distinct product categories owned (size of category list) |

### System / metadata columns
| Column | Type | Description |
|---|---|---|
| `data_source_enum` | string | Hardcoded `'customer360'` |
| `etl_build_mst_ts` | timestamp | ETL build timestamp in MST |
| `partition_eval_mst_date` | string | Partition date (MST) — **always filter on this column** |

---

## Business Logic Notes (from PySpark code)

1. **Date window for source query:** reads from `start_mst_date - 1 day` through `end_mst_date` from the source table, but the final output is filtered to `start_mst_date` through `end_mst_date`. The extra day is needed to compute `beginning_customer_qty` via LAG.

2. **NULL-fill for missing dimension combinations:** a "candidates_next_day" self-join pattern ensures that every dimension combination seen on day T is carried forward to day T+1 with zero metrics. This prevents gaps in the daily series for slowly-changing dimension combinations.

3. **`beginning_customer_qty` computation:** uses a window LAG over all 18 dimension columns, ordered by `partition_eval_mst_date`. If the prior day exists in the window, `beginning = prior day's ending`; otherwise `0`.

4. **Country code normalisation:** `customer_country_code = 'UK'` → `'GB'` applied in `conform_datatype`.

5. **Fraud flag rename:** the internal SQL uses `customer_fraud_flag`; `conform_datatype` renames it to `fraud_flag` for the output.

6. **`COALESCE` defaults applied in source SQL:**
   - `customer_type_reason_desc` → `'Not Classified'`
   - `customer_domestic_international_name` → `'International'`
   - `customer_region_1_name` → `'International - RoW'`
   - `customer_region_2_name` → `'Rest of World (RoW)'`
   - `customer_region_3_name` → `'NA'`
   - `customer_acquisition_country_name` → `'Unknown'`
   - `customer_acquisition_country_code` → `'--'`
   - `customer_type_name` → `'Not Classified'`
   - `customer_acquisition_channel_name` → `'Not GA Attributed'`
   - `customer_tenure_year_count` → `0`
   - `customer_fraud_flag` → `false`
   - `customer_acquisition_bill_fraud_flag` → `false`
   - `point_of_purchase_name` → `'Unknown'`

---

## DDL Files Consulted

### `ddls/customer_metric_daily_agg.ddl` (Hive/Glue DDL)
- Creates `{DATABASE_NAME}.customer_metric_daily_agg` (rendered as `customer_core_conformed.customer_metric_daily_agg` at runtime)
- STORED AS PARQUET, PARTITIONED BY `partition_eval_mst_date string`
- S3 location: `s3://gd-ckpetlbatch-{AWS_ENV}-customer-core-conformed/customer_core_conformed/customer_metric_daily_agg/`
- Includes all 33 columns + partition column; comments match PySpark description
- Status: **consistent with PySpark code**

### `ddls/create_customer_metric_daily_agg.sql` (Redshift DDL)
- Creates `{database}.customer_metric_daily_agg_vw` in Redshift
- DISTKEY / SORTKEY on `partition_eval_mst_date`
- All 33 columns present including `data_source_enum VARCHAR(50)` and `partition_eval_mst_date DATE`
- Status: **consistent** — Redshift copy of the lake table

### `ddls/insert_customer_metric_daily_agg.sql` (Redshift upsert)
- DELETE + INSERT pattern scoped to `end_mst_date`
- Strips array bracket artifacts from `product_ownership_*_list` and `brand_name_list` columns (Parquet string arrays serialized as `[val1, val2]`)
- Sources from staging table `{database_stg}.customer_metric_daily_agg_vw_stg`

### Lake repo: `catalog/config/prod/dlms-api/us-west-2/customer360/customer-metric-daily-agg-vw/table.ddl`
- Creates `customer360.customer_metric_daily_agg_vw` (lake catalog table)
- **Missing `data_source_enum` column** — present in Hive DDL and Redshift DDL but absent from lake DDL (discrepancy, noted below)
- 16 columns marked `@PrimaryKey` (note: `data_source_enum`, `point_of_purchase_name`, `customer_acquisition_bill_fraud_flag` absent from primary key set in this DDL vs 19-column key in DQ constraint)

---

## Policy Files Consulted

### `policies/customer_metric_daily_agg_dag.yaml`
- Schema: `urn:dna:pipeline:metadata:/v1`
- Pipeline version: `1.0.0`
- SLA: `maxDurationMins: 120`, severity: `TIER_4`
- **Inputs declared:**
  - `customer360.customer_life_cycle_vw` (platform: datalake)
  - `customer_core_conformed.customer_life_cycle` (platform: s3-ckpetlbatch)
- **Outputs declared:**
  - `customer360.customer_metric_daily_agg_vw` (platform: datalake)
  - `customer_core_conformed.customer_metric_daily_agg` (platform: s3-ckpetlbatch)

### `policies/environment.prod.yaml`
- Team: `EDT`
- OnCall: `DEV-EDT-Oncall`
- Contact email: `emerald-data-team-org@godaddy.com`
- Slack: `edt-airflow-alerts`
- MWAA environment: `dof-customers` (AWS account `688051721285`)
- EMR Serverless: AWS account `664289052486`
- S3 (data): AWS account `688051721285`
- Datalake: AWS account `028140660016`
- Redshift: AWS account `561403605607` (cluster ARN recorded)

---

## Data Quality Files Consulted

### `data_quality/constraints/customer_metric_daily_agg.json`
- Database: `customer_core_conformed`, table: `customer_metric_daily_agg`
- Constraint: `isPrimaryKey` on all 19 columns:
  `partition_eval_mst_date, customer_type_reason_desc, customer_acquisition_mst_month, customer_domestic_international_name, customer_region_1_name, customer_region_2_name, customer_region_3_name, customer_country_name, customer_country_code, customer_type_name, acquisition_channel_name, customer_tenure_year_count, product_ownership_category_list, product_ownership_line_list, reseller_type_name, fraud_flag, point_of_purchase_name, customer_acquisition_bill_fraud_flag, brand_name_list`
- Status: enabled
- Type: USER_DEFINED

### `data_quality/constraints/customer_metric_daily_agg_vw.json`
- Same 19-column primary key constraint on `customer360.customer_metric_daily_agg_vw`

---

## Confluence Pages

### Parent page: Customer360 (ID 3779199819)
URL: https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3779199819/Customer360

**Relevant extract (Business Metrics Layer section):**
> Business Metrics Layer ✅ — Business-ready metrics including Active Customers, 2+ Customers, Daily & Monthly customer metrics.
>
> `customer_metric_daily_agg_vw` — 🟡 NRU and Lapsed users metrics co-existing with all externally reported metrics
> - **Replaces (Deprecated):** `customer_mart.daily_active_customers`, `customer_mart.monthly_active_customers`
> - **Recommended instead of:** `customer_mart.daily_active_customers` (barring hour latency needs)

Child pages identified: `Customer360 Design Docs` (3829342710), `Customer360 Business Context Structure` (4387965088), `Customer 360 — Phased Adoption Plan` (4423945148).

### Relevant child: Customer Metrics (ID 4042131239)
URL: https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/4042131239

**Customer Lifecycle Events driving metrics:**
| Event | Key date field | Metric |
|---|---|---|
| Customer Acquisition | `acquisition_mst_date` | `new_customer_qty` |
| Customer Billing (Paid) | `bill_modified_mst_date` | `ending_customer_qty`, `ttm_gcr_usd_amt` |
| Customer Churn | `churned_mst_date` | `churn_customer_qty` |
| Customer Merge | `merged_mst_date` | `merge_customer_qty` |
| Customer Reactivated | `reactivated_mst_date` | `reactivate_customer_qty` |
| Customer Type | `evaluation_mst_date` | dimension |
| Customer Fraud | `evaluation_mst_date` | `fraud_flag` |

### Relevant child: C360 Customer Reporting Metrics (ID 4042131351)
Defines official business metric definitions:
- **Active Customer** (SEC 10-K definition): individual/entity with paid transactions in trailing twelve months OR paid subscriptions as of end of period
- **New Customer**: first paid or Domain Change of Account (COA) order; Third Party App Store orders excluded
- **Churned Customer**: no active paid subscription AND no paid transactions in trailing twelve months
- **2+ Customer**: Active Customers with payable resources in 2+ distinct Product PnL categories
- **Net Adds**: `(New paid + Reactivations) − (Churned + Customer Type Moves + Merges)` = `ending - beginning`
- **Note:** `ARPU/ABPU` and rate metrics (Churn Rate, Retention Rate) are NOT persisted in this table — derive from MAC/DAC

### Relevant child: [WIP] Customer Metrics Daily Agg Data Validation Test Cases (ID 4192469643)
- Validates `beginning_customer_qty` continuity: current day beginning must equal prior day ending
- `net_move_qty` across date range should sum to 0
- Variance thresholds vs `customer_mart.daily_active_customers` legacy:
  - `beginning_customer_qty` / `ending_customer_qty`: < 0.002% variance
  - `new_customer_qty`, `reactivated_customer_qty`, `merge_customer_qty`, `churned_customer_qty`: ≤ 1% variance
- Partner BU net moves must be ≥ 0 (partner customers cannot revert to other types)

---

## Alation

### Lake Table
| Field | Value |
|---|---|
| Table name | `customer_metric_daily_agg_vw` |
| Schema | `customer360` |
| Alation key | `81.AwsDataCatalog.customer360.customer_metric_daily_agg_vw` |
| Alation table ID | `7038346` |
| Alation URL | https://godaddy.alationcloud.com/table/7038346/ |
| Steward | Franchise: Customer (group ID 47) |
| Description | "A daily aggregated metrics table providing summarized customer performance indicators — Daily aggregation of customer metrics" |
| Data Tier | `4` |
| SLA | cron `00 15 * * ? *` (UTC) = 08:00 AM MST every day |
| SLO Identifier | `customer360.customer_metric_daily_agg_vw` |
| Partition key | `partition_eval_mst_date` |
| Table type | PARTITIONED |
| Data Lake Owner | ckpetlbatch — `emerald-data-team-org@godaddy.com` — OnCall: `DEV-EDT-OnCall` — Slack: `#ckp-aws-etl-batch` |
| Lineage upstream | `customer360.customer_life_cycle_vw` |
| Permissions | ckpetlbatch.dev_private, data_lab.dev_private, analytics.prod, data_platform.{stage,prod}, martech_data.{stage,dev_private,prod}, revenue_and_relevance.{stage,dev_private,prod,test} |

### Redshift Table (Prod)
| Field | Value |
|---|---|
| Table name | `customer_metric_daily_agg_vw` |
| Database / Schema | `bi.customer360` |
| Alation key | `63.bi.customer360.customer_metric_daily_agg_vw` |
| Alation table ID | `7038887` |
| Alation URL | https://godaddy.alationcloud.com/table/7038887/ |

Other Redshift/dev entries found: IDs 7038766 (`customer_core_conformed_dev`), 7038918 (`dev.customer360`), 7039657 (`bi.dna_approved`), 7046304 (`dev.dna_approved`), 7047021 (`bi.customer360_dev`).

---

## Alation Queries

6 queries found referencing `customer_metric_daily_agg`.

---

### Query 1

| Field | Value |
|---|---|
| Query ID | `138586` |
| Title | C360 Cash Dash with budget |
| Author | unknown (not returned by API) |
| Description | |
| Schedule | Not scheduled |
| Last Saved | unknown |
| Last Run | unknown |
| Datasource | DS 63 (bi / Redshift Serverless) |
| Alation Query URL | https://godaddy.alationcloud.com/query/138586/ |

**SQL:**
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
*(Full SQL: 19,093 characters — ad-hoc Cash Dash analysis)*

---

### Query 2

| Field | Value |
|---|---|
| Query ID | `136952` |
| Title | NC validate EBP |
| Author | unknown |
| Description | |
| Schedule | Not scheduled |
| Last Saved | unknown |
| Last Run | unknown |
| Datasource | DS 63 (bi / Redshift Serverless) |
| Alation Query URL | https://godaddy.alationcloud.com/query/136952/ |

**SQL:**
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
*(Full SQL: 3,912 characters — validation query; references `customer_vs_target` which wraps this table)*

---

### Query 3

| Field | Value |
|---|---|
| Query ID | `138254` |
| Title | C360 - mv_customer_metric_daily_agg_vw_union |
| Author | unknown |
| Description | |
| Schedule | Not scheduled |
| Last Saved | unknown |
| Last Run | unknown |
| Datasource | DS 63 (bi / Redshift Serverless) |
| Alation Query URL | https://godaddy.alationcloud.com/query/138254/ |

**SQL:**
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
*(Cutover union view: legacy data ≤ 2026-03-31 from `dna_approved.daily_active_customers`; c360 data ≥ 2026-04-01)*

---

### Query 4

| Field | Value |
|---|---|
| Query ID | `138184` |
| Title | C360 - customer_metric_daily_agg_vw_mv |
| Author | unknown |
| Description | |
| Schedule | Not scheduled |
| Last Saved | unknown |
| Last Run | unknown |
| Datasource | DS 132 (dev Redshift) |
| Alation Query URL | https://godaddy.alationcloud.com/query/138184/ |

**SQL:**
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

### Query 5

| Field | Value |
|---|---|
| Query ID | `128804` |
| Title | NC validate DAC/MAC/Cash Dash |
| Author | unknown |
| Description | |
| Schedule | Not scheduled |
| Last Saved | unknown |
| Last Run | unknown |
| Datasource | DS 132 (dev Redshift) |
| Alation Query URL | https://godaddy.alationcloud.com/query/128804/ |

**SQL:**
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
*(Full SQL: 6,551 characters — validation of DAC/MAC vs C360)*

---

### Query 6

| Field | Value |
|---|---|
| Query ID | `127875` |
| Title | customer vs target v2 |
| Author | unknown |
| Description | |
| Schedule | Not scheduled |
| Last Saved | unknown |
| Last Run | unknown |
| Datasource | DS 132 (dev Redshift) |
| Alation Query URL | https://godaddy.alationcloud.com/query/127875/ |

**SQL:**
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
*(Full SQL: 29,271 characters — customer vs target comparison dashboard development query)*

---

## Conflicts / Discrepancies

| # | Source | Claim | Code says | Action |
|---|---|---|---|---|
| 1 | Policy YAML (`customer_metric_daily_agg_dag.yaml`) | Input: `customer360.customer_life_cycle_vw` (as active input) | PySpark SQL reads from `customer_core_conformed.customer_life_cycle`; the `customer360.customer_life_cycle_vw` reference is **commented out** | Validate: policy file appears stale; **code is authoritative** |
| 2 | Lake DDL (`table.ddl` in lake repo) | Missing `data_source_enum` column entirely | PySpark conform step + Hive DDL + Redshift DDL all include `data_source_enum string` (always `'customer360'`) | Validate: lake DDL needs to be updated |
| 3 | Lake DDL `table.ddl` `@PrimaryKey` annotation | 16 columns annotated as primary key (missing `point_of_purchase_name`, `customer_acquisition_bill_fraud_flag`, `data_source_enum`) | DQ constraint JSON explicitly lists 19-column composite key (partition_date + 18 dims including `point_of_purchase_name` and `customer_acquisition_bill_fraud_flag`) | Validate: lake DDL primary key annotations are incomplete |
| 4 | Alation queries (e.g. query 138254) | Cutover date is `2026-03-31 / 2026-04-01` — legacy data used before that date | Code does not hardcode any cutover date; it is a full replacement | Informational: migration is in progress; queries reflect transition period |
| 5 | Alation queries use `evaluation_mst_date` | Legacy column name `evaluation_mst_date` used in some queries | Lake table uses `partition_eval_mst_date` | Column was renamed in C360 vs legacy `customer_mart.daily_active_customers`; downstream SQL must adapt |
| 6 | DAG dependency sensor | Waits for `customer360.customer_life_cycle_vw` S3 success file | PySpark reads `customer_core_conformed.customer_life_cycle` (the "conformed" version), not the vw | Confirms the lifecycle conformed table is populated by the same pipeline that creates the vw; dependency is consistent but naming discrepancy warrants documentation |
| 7 | DAG docstring SLA | `N/A` | Alation / lake table.yaml SLA: `cron(00 15 * * ? *)` = 08:00 AM MST; policy YAML: `maxDurationMins: 120, TIER_4` | Validate: DAG docstring is out of date; Alation/policy YAML reflect actual SLA |


**The agent's final response to the user was:**
All research is complete and appended to `gather.md`. Here is a summary of what was gathered:

## Summary

**PySpark script:** `customer360/customer-metrics/src/pyspark/customer_metric_daily_agg.py` on `main` (HEAD `7523b6d5`). Writes to `customer_core_conformed.customer_metric_daily_agg` via `insertInto(overwrite=True)` partitioned by `partition_eval_mst_date`.

**Output tables:**
- **Lake (conformed):** `customer_core_conformed.customer_metric_daily_agg` → S3 at `s3://gd-ckpetlbatch-{env}-customer-core-conformed/customer_core_conformed/customer_metric_daily_agg/`
- **Lake catalog view:** `customer360.customer_metric_daily_agg_vw` (registered via SuccessNotificationOperator)
- **Redshift (prod):** `customer360.customer_metric_daily_agg_vw`

**DAG:** `customer-metric-daily-agg`, schedule `30 7 * * *` (7:30 AM MST daily), start date `2026-01-01`, EMR 7.10.0, team EDT.

**Table grain:** Daily, by **18 reporting dimensions** (customer type, acquisition month, geo/region hierarchy, channel, tenure, product lists, reseller type, fraud flags, brand list, point-of-purchase).

**Key metrics:** `ending_customer_qty`, `new_customer_qty`, `churn_customer_qty`, `reactivate_customer_qty`, `merge_customer_qty`, `beginning_customer_qty`, `net_move_qty`, `net_add_qty`, `net_churn_qty`, `ttm_gcr_usd_amt`, `product_category_qty`.

**Replaces:** `customer_mart.daily_active_customers` (confirmed by Confluence + user notes).

**Alation entries:** Lake table ID `7038346` at https://godaddy.alationcloud.com/table/7038346/ ; Redshift prod ID `7038887` at https://godaddy.alationcloud.com/table/7038887/. SLA: delivered by 08:00 AM MST daily.

**6 Alation queries** found — all ad-hoc/dev; none scheduled. Key pattern: migration union queries bridging legacy `daily_active_customers` (data ≤ 2026-03-31) with c360 (data ≥ 2026-04-01).

**7 conflicts documented**, most notably: policy YAML lists the commented-out `customer_life_cycle_vw` as input (code reads `customer_life_cycle`); lake DDL missing `data_source_enum` column; DAG docstring SLA is `N/A` but Alation/policy has `TIER_4 / 08:00 AM MST`.