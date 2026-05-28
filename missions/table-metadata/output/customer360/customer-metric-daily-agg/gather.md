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
ALATION_CREDS=$(node -e "const j=JSON.parse(process.env.MOONUNIT_ALATION); console.log(JSON.stringify({refresh_token:j.refresh_token, user_id:j.user_id}))")
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
   - Redshift table: name, database, schema, Alation URL
   - Lake table: name, schema, Alation URL
   - Any descriptions or custom fields found

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
- A "Conflicts / discrepancies" section listing any contradictions with the code

**The agent summarized its work in this way:**

---

## Gather Stage Report — customer_metric_daily_agg

**Generated:** 2026-05-28  
**Target identifier:** customer360 / customer-metric-daily-agg  
**Source repo:** https://github.com/gdcorp-dna/dof-dpaas-customer-feature.git  
**Git ref checked out:** main (confirmed current)

---

## 1. PySpark Job Identity

| Field | Value |
|---|---|
| Repo | dof-dpaas-customer-feature |
| Ref | main |
| File path | `customer360/customer-metrics/src/pyspark/customer_metric_daily_agg.py` |
| Script header name | `customer_metrics_daily_agg.py` (note: filename on disk differs from internal name by 's') |
| FEED_NAME constant | `customer_metric_daily_agg` |
| Initial author | aghosh, 11/06/2025 |

### Output Write Targets (from PySpark code)

| Target | Details |
|---|---|
| **Primary Lake table** | `customer_core_conformed.customer_metric_daily_agg` |
| **Write mode** | `insertInto(..., overwrite=True)` — partition overwrite |
| **Partition column** | `partition_eval_mst_date` (string) |
| **S3 location** | `s3://gd-ckpetlbatch-{AWS_ENV}-customer-core-conformed/customer_core_conformed/customer_metric_daily_agg/` |
| **Format** | Parquet (zstd compression) |
| **Post-write** | `MSCK REPAIR TABLE customer_core_conformed.customer_metric_daily_agg` (best-effort) |

The write is guarded by `if not args.dry_run`. In dry-run mode, the job computes but does not persist.

---

## 2. DAG Identity (Authoritative)

**Primary DAG file:** `customer360/customer-metrics/src/dag/customer_metric_daily_agg_dag.py`

| Field | Value |
|---|---|
| DAG ID | `customer-metric-daily-agg` |
| Data Pipeline Name | `customer-metric-daily-agg` |
| Schedule | `"30 7 * * *"` (7:30 AM MST daily) — disabled (`None`) in dev-private |
| Catchup | `False` |
| Max active runs | 15 |
| Start date | `datetime(2026, 1, 1, tzinfo=America/Phoenix)` |
| Timezone | `pendulum.timezone("America/Phoenix")` (MST) |
| Owner | `customer360` |
| Retries | 1 (retry_delay: 3 minutes) |
| Slack alerts (prod) | `#edt-airflow-alerts` |
| Slack alerts (non-prod) | `#edt-airflow-alerts-low-priority` |
| On-call Slack | `#marketing-data-product-engineering` |
| On-call email | `dl-bi-enterprise-data@godaddy.com` |
| SNOW queue | `DEV-EDT-OnCall` |
| Stakeholders | `#marketing-data-products-help` |

**DAG tags:**  
`domain:customer`, `sub-domain:active-customer`, `layer:enterprise`, `team:EDT`, `pipeline-group:active-customer`, `special:daily`

**EMR cluster spec (from DAG):**  
- Release: `emr-7.10.0`, ARM architecture (`m6g` family)  
- Master: `m6g.xlarge`, Core: `m6g.16xlarge` × 15 nodes  
- Roles: `dof-customers-EMRInstanceRole` / `dof-customers-EMRServiceRole` (prod)

**Spark submit command (from DAG run_customer_metric_daily_agg step):**
- Script: `{CODE_BUCKET}/pyspark/customer360/customer-metrics/src/pyspark/customer_metric_daily_agg.py`
- DDL file passed via `--files`: `{DDLS_LOC}/customer_metric_daily_agg.ddl`
- Args: `--environment`, `--start_mst_date`, `--end_mst_date`, `--spark_conf_str`, `--sb_app_id`, `--sb_setting_id`, `--run_emr_task_id`
- Spark config (fallback): `executor.memory=16G, executor.cores=4, memoryOverhead=512, driver.memory=4G, driver.cores=2, dynamicAllocation.maxExecutors=10`

**Backfill DAG:** `customer_metric_daily_agg_backfill_dag.py`  
- DAG ID: `customer-metric-daily-agg-backfill`  
- Schedule: `None` (manual trigger only)  
- Uses: `customer_metric_daily_agg_backfill.py` (separate PySpark script)  
- Parameters include `legacy_cut_off_mst_date` (hardcoded default: `2026-04-01`)

---

## 3. DAG Task Flow

```
dag_config
  → dependencies (wait_for_customer360.customer_life_cycle_vw via S3KeySensor)
  → end_dependency_check
  → create_redshift_tables_done (create_customer_metric_daily_agg + create_customer_metric_daily_agg_stg in Redshift)
  → create_emr
  → run_customer_metric_daily_agg   ← PySpark job
  → remove_emr
  → customer_metric_daily_agg_local_dq (DataQualityOperator on customer_core_conformed.customer_metric_daily_agg)
  → conditional_call_lake_api
      ├─ call_lake_api (SuccessNotificationOperator → customer360.customer_metric_daily_agg_vw) [prod only]
      │    └─ customer_metric_daily_agg_lake_dq (DataQualityOperator on customer360.customer_metric_daily_agg_vw)
      └─ skip_call_lake_api [non-prod]
  → s3_to_redshift_customer_metric_daily_agg_stg (S3→Redshift staging copy)
  → insert_customer_metric_daily_agg (Redshift delete+insert from stg to final)
  → check_for_failure_branch → [succeed_dag_run | fail_dag_run]
```

**Upstream S3 dependency sensor:**  
`s3://gd-{AWS_ACCOUNT_NAME}-{AWS_ENV}-success-files/customer360/customer_life_cycle_vw/{date}/_SUCCESS`  
(poke_interval=30s, timeout=12h)

---

## 4. Upstream Tables Referenced in PySpark

| Table | Role | Source |
|---|---|---|
| `customer_core_conformed.customer_life_cycle` | Direct SQL read in `get_customer_metrics_daily_agg()` | Primary upstream |
| `customer360.customer_life_cycle_vw` | Commented out alternative (`--customer360.customer_life_cycle_vw`) — NOT currently used | Code comment |

**Note:** The policies YAML lists both `customer360.customer_life_cycle_vw` (datalake, parquet) and `customer_core_conformed.customer_life_cycle` (s3-ckpetlbatch) as inputs. The active PySpark code only queries `customer_core_conformed.customer_life_cycle`. The `customer_life_cycle_vw` reference remains commented out.

**Date range filter:** `partition_eval_mst_date BETWEEN '{start_mst_date_minus_1}' AND '{end_mst_date}'`  
(reads one extra prior day to compute `beginning_customer_qty` via LAG window)

---

## 5. Business Logic Summary (from PySpark code)

The job produces **daily aggregated customer counts and movement metrics** grouped by a set of reporting dimensions.

**Step 1 — Base aggregation** from `customer_core_conformed.customer_life_cycle`:
- Groups by ~18 dimensions (country, region, type, channel, tenure, product lists, fraud flags, etc.)
- Computes per-group: `ttm_gcr_usd_amt`, `ending_customer_qty`, `churn_customer_qty`, `merge_customer_qty`, `new_customer_qty`, `reactivate_customer_qty`

**Step 2 — Gap-fill**: Projects prior-day dimension combinations into the target date and inserts zero-metric rows for any combos that dropped out (prevents window function gaps).

**Step 3 — Window function**: Computes `beginning_customer_qty` using `LAG(ending_customer_qty)` over `(PARTITION BY <all_dims> ORDER BY partition_eval_mst_date)`.

**Step 4 — Derived metrics**:
- `net_move_qty = ending - beginning - new + (churn - reactivate) + merge`
- `net_add_qty = ending - beginning`
- `net_churn_qty = churn - reactivate`
- `data_source_enum = 'customer360'` (hardcoded literal)

**Step 5 — Data fix**: `customer_country_code` "UK" → "GB" normalization applied via `withColumn`.

**Step 6 — Type conformance**: `conform_datatype()` casts all columns to declared types, sets `etl_build_mst_ts = from_utc_timestamp(current_timestamp(), 'MST')`.

**Output filter**: Final result is filtered to `partition_eval_mst_date BETWEEN start_mst_date AND end_mst_date` (extra prior-day row excluded from write).

**Write**: `repartition(1).write.insertInto(customer_core_conformed.customer_metric_daily_agg, overwrite=True)` — single partition file per run date.

---

## 6. DDL Files Consulted

### 6a. Hive/Glue DDL — `src/ddls/customer_metric_daily_agg.ddl` (Lake storage layer)

**Table:** `{DATABASE_NAME}.customer_metric_daily_agg`  
(DATABASE_NAME resolved to `customer_core_conformed` at runtime)  
**Location:** `s3://gd-ckpetlbatch-{AWS_ENV}-customer-core-conformed/customer_core_conformed/customer_metric_daily_agg/`  
**Format:** PARQUET  
**Partition:** `partition_eval_mst_date string`

Columns (32 total + partition):

| Column | Type | DDL Comment |
|---|---|---|
| customer_type_reason_desc | string | Reason for customer type classification |
| customer_acquisition_mst_month | string | Month of customer acquisition (MST), truncated to month |
| customer_domestic_international_name | string | Domestic vs International classification |
| customer_region_1_name | string | Geographic region level 1 |
| customer_region_2_name | string | Geographic region level 2 |
| customer_region_3_name | string | Geographic region level 3 |
| customer_country_name | string | Customer country name at evaluation date |
| customer_country_code | string | Customer country code at evaluation date |
| customer_type_name | string | Customer type at evaluation date |
| acquisition_channel_name | string | Acquisition channel |
| customer_tenure_year_count | int | Customer tenure in years (integer) |
| product_ownership_category_list | string | Owned product category list (string-encoded) |
| product_ownership_line_list | string | Owned product line list (string-encoded) |
| reseller_type_name | string | Reseller type name |
| fraud_flag | boolean | True if customer marked as fraud as of evaluation date |
| point_of_purchase_name | string | Point of purchase name from acquisition bill |
| customer_acquisition_bill_fraud_flag | boolean | True if acquisition bill has fraud record |
| brand_name_list | string | List of all brands associated with the customer |
| product_category_qty | int | Number of owned product categories |
| ttm_gcr_usd_amt | decimal(18,2) | Total gross cash received (GCR) USD in trailing twelve months |
| ending_customer_qty | bigint | Ending customer count as of evaluation date |
| churn_customer_qty | bigint | Customers churned on evaluation date |
| merge_customer_qty | bigint | Customers merged on evaluation date |
| new_customer_qty | bigint | New customers on evaluation date |
| reactivate_customer_qty | bigint | Reactivated customers on evaluation date |
| beginning_customer_qty | bigint | Beginning customer count from prior day |
| net_move_qty | bigint | Net move quantity |
| net_add_qty | bigint | Net additions (ending - beginning) |
| net_churn_qty | bigint | Net churn (churned - reactivated) |
| data_source_enum | string | Indicates the source used to populate the data. Possible values are c360 and legacy_dac |
| etl_build_mst_ts | timestamp | ETL build timestamp in MST |
| **partition_eval_mst_date** | string | Partition date (MST) of evaluation |

### 6b. Redshift DDL — `src/ddls/create_customer_metric_daily_agg.sql`

Creates `{database}.customer_metric_daily_agg_vw` in Redshift.  
**DISTSTYLE:** AUTO  **DISTKEY:** `partition_eval_mst_date`  **SORTKEY:** `partition_eval_mst_date`  
Schema matches the Hive DDL with type equivalents (VARCHAR/BIGINT/DECIMAL/BOOLEAN). `partition_eval_mst_date` is `DATE` in Redshift (vs `string` in Hive).  
**Database (prod):** `customer360` / **Database (non-prod):** `customer_core_conformed_dev`

### 6c. Lake Registry DDL — `repos/lake/.../customer360/customer-metric-daily-agg-vw/table.ddl`

Creates `customer_metric_daily_agg_vw` (view name) in the lake catalog.  
**Note:** This DDL is missing two columns present in the Hive DDL and Redshift DDL: `point_of_purchase_name` and `customer_acquisition_bill_fraud_flag` are present but listed near the end, while `data_source_enum` is absent from the lake DDL. See Conflicts section.

---

## 7. Policies File

**File:** `src/policies/customer_metric_daily_agg_dag.yaml`

```
schemaUrn: urn:dna:pipeline:metadata:/v1
pipeline:
  pipelineVersion: 1.0.0
  description: Customer Metrics Daily Aggregation
  job:
    facets:
      - documentation: Daily aggregation of customer metrics.
      - runner:
          orchestrator: airflow (dagId: customer-metric-daily-agg)
          sla:
            maxDurationMins: 120
            severity: TIER_4
  inputs:
    - customer360.customer_life_cycle_vw  [platform: datalake]
    - customer_core_conformed.customer_life_cycle  [platform: s3-ckpetlbatch]
  outputs:
    - customer360.customer_metric_daily_agg_vw  [platform: datalake]
    - customer_core_conformed.customer_metric_daily_agg  [platform: s3-ckpetlbatch]
```

**SLA from policy:** maxDurationMins=120, severity=TIER_4

---

## 8. Data Quality Constraints

### `customer_metric_daily_agg` (customer_core_conformed — Lake layer)
Single constraint:
- **Type:** USER_DEFINED
- **Description:** primary key check
- **PK columns:** `partition_eval_mst_date`, `customer_type_reason_desc`, `customer_acquisition_mst_month`, `customer_domestic_international_name`, `customer_region_1_name`, `customer_region_2_name`, `customer_region_3_name`, `customer_country_name`, `customer_country_code`, `customer_type_name`, `acquisition_channel_name`, `customer_tenure_year_count`, `product_ownership_category_list`, `product_ownership_line_list`, `reseller_type_name`, `fraud_flag`, `point_of_purchase_name`, `customer_acquisition_bill_fraud_flag`, `brand_name_list`

### `customer_metric_daily_agg_vw` (customer360 — Lake API layer)
Identical PK constraint as above. Note: `data_source_enum` is NOT included in the PK in either DQ file.

---

## 9. Lake Registry Metadata (`repos/lake`)

**Path:** `catalog/config/prod/dlms-api/us-west-2/customer360/customer-metric-daily-agg-vw/`

| Field | Value |
|---|---|
| Table name | `customer_metric_daily_agg_vw` |
| Database | `customer360` |
| Schema path | `customer360/customer_metric_daily_agg` (table_relative_path) |
| Description | "Customer Metric Daily Aggregated on Reporting Dims for a given day" |
| Storage format | Parquet |
| Table type | PARTITIONED |
| Partition keys | `partition_eval_mst_date` (string) |
| Data tier | 4 |
| SLA delivery | `cron(00 15 * * ? *)` → by 08:00 AM MST daily |
| SLA identifier | `customer360.customer_metric_daily_agg_vw` |
| legacyLookBackEnabled | true |

**Consumer permissions (prod/non-prod):**  
`ckpetlbatch.dev_private`, `data_lab.dev_private`, `analytics.prod`, `data_platform.stage`, `data_platform.prod`, `martech_data.stage/dev_private/prod`, `revenue_and_relevance.stage/dev_private/prod/test`

**Lineage (lake registry):** upstream → `customer360.customer_life_cycle_vw`

---

## 10. Confluence Summary

### Page 3779199819 — Customer360 (parent hub page)

Key findings for `customer_metric_daily_agg_vw`:

- **Business category:** "Business Metrics Layer" (marked ✅ Completed)
- **Description:** "Business-ready metrics including Active Customers, 2+ Customers (customers with multiple subscriptions), Daily & Monthly customer metrics"
- **Replaces (deprecated):** `customer_mart.daily_active_customers`, `customer_mart.monthly_active_customers`
- **New feature in progress (🟡):** NRU (New Registered User) and Lapsed users metrics co-existing with all externally reported metrics
- **Recommendation:** "use 360 barring hour latency needs"
- **Coverage weight in business context matrix:** 15% (customer_metric_daily_agg_vw is one of four datasets; customer_life_cycle_vw is weighted 35%)

**Contacts:**  
- Finance: Business Stewards (Stakeholders → Finance Requirements, Analytics, Data Acceptance)  
- Marketing: Stakeholders (Requirements, Data Acceptance)  
- DAP: Business Stewards (Business Requirements Intake, Analytics, Data Acceptance)  
- FORGE: Data Products PgM (High Level Design), Technical Stewards (Low Level Design, Implementation, Monitoring)

### Page 4387965088 — Customer360 Business Context Structure

- Confirms grain of `customer_metric_daily_agg_vw`: **"One row per date × reporting dimension combo"**
- Data tier: 4 (agg tables)
- Schema: `customer360`
- Coverage matrix shows this table at 15% weight in the overall C360 context

---

## 11. Alation

**Status:** Skipped — `MOONUNIT_ALATION` environment variable is not set; credentials not available.

---

## 12. Conflicts / Discrepancies

| # | Discrepancy | Source A (Code/DDL) | Source B (Other) | Verdict |
|---|---|---|---|---|
| 1 | Lake registry DDL (`table.ddl`) is missing `data_source_enum` column | Hive DDL (`customer_metric_daily_agg.ddl`) has `data_source_enum string` | Lake registry `table.ddl` does not include `data_source_enum` | **Code is authoritative**; lake registry DDL is stale |
| 2 | Active PySpark reads `customer_core_conformed.customer_life_cycle` but the policies YAML and DAG dependency sensor reference `customer360.customer_life_cycle_vw` | PySpark SQL reads `customer_core_conformed.customer_life_cycle` (uncommented); `customer_life_cycle_vw` is commented out | Policies YAML lists both; DAG dependency sensor waits on `customer360.customer_life_cycle_vw/_SUCCESS` | **Code is authoritative for what is read**; DAG still gates on the view's success file even though code reads the underlying table. Requires validation. |
| 3 | DDL comment for `data_source_enum` says "Possible values are c360 and legacy_dac" but code always writes `'customer360'` as a literal | PySpark: `'customer360' as data_source_enum` | DDL comment: "c360 and legacy_dac" | **Code is authoritative**; DDL comment appears to reference an older or planned value set |
| 4 | `partition_eval_mst_date` type: Hive DDL = `string`; Redshift DDL = `DATE`; Lake registry DDL = not declared (partition) | Hive DDL: string partition | Redshift: DATE column | By design (different systems); not a conflict per se but worth noting for consumers |
| 5 | Policy YAML SLA severity is `TIER_4`; lake registry `data_tier` is `4` — these are consistent | Policy: TIER_4 | Lake YAML: data_tier=4 | Consistent — no conflict |
| 6 | DAG documentation_markdown says "SLA: N/A" and "Data Tier: N/A" | DAG doc_md | Policy YAML (maxDurationMins=120, TIER_4) and lake YAML (data_tier=4) | **Policy YAML and lake YAML are more precise**; DAG doc_md placeholders not filled in |
| 7 | Lake registry `table.ddl` primary key annotation marks 16 columns with `@PrimaryKey`; DQ constraint file uses 19 columns including `point_of_purchase_name`, `customer_acquisition_bill_fraud_flag`, and does not omit `data_source_enum` | Lake DDL: 16 PK columns | DQ JSON: 19 PK columns | **DQ JSON is more likely current**; lake DDL may be ahead-of-sync; validate with team |

---

## Summary

The `customer_metric_daily_agg` table in `customer_core_conformed` (Hive/Lake) and its downstream view `customer360.customer_metric_daily_agg_vw` are produced by a daily Airflow DAG (`customer-metric-daily-agg`) running at **7:30 AM MST** on an EMR cluster (emr-7.10.0, m6g.16xlarge × 15). The PySpark job reads from `customer_core_conformed.customer_life_cycle`, aggregates customer counts and movement metrics across ~18 reporting dimensions, applies gap-filling and LAG window logic to produce `beginning_customer_qty`, and derives `net_move_qty`, `net_add_qty`, `net_churn_qty`. The table grain is **one row per calendar date × reporting dimension combination**. Data tier is 4. SLA (from lake registry) is delivery by 08:00 AM MST daily. The table replaces legacy datasets `customer_mart.daily_active_customers` and `customer_mart.monthly_active_customers`.


**The agent's final response to the user was:**
Here is a summary of what I researched and recorded in `gather.md`:

---

## Research Summary

**Source repo:** `dof-dpaas-customer-feature` (main branch, confirmed current)

### PySpark Script
- **File:** `customer360/customer-metrics/src/pyspark/customer_metric_daily_agg.py`
- **Output table:** `customer_core_conformed.customer_metric_daily_agg` (Hive/Glue, Parquet, partitioned by `partition_eval_mst_date`)
- **S3 location:** `s3://gd-ckpetlbatch-{env}-customer-core-conformed/customer_core_conformed/customer_metric_daily_agg/`
- **Source table read:** `customer_core_conformed.customer_life_cycle` (the `customer_life_cycle_vw` is commented out)
- **Logic:** Base aggregation → gap-fill → LAG window (`beginning_customer_qty`) → derived metrics (`net_move_qty`, `net_add_qty`, `net_churn_qty`) → country code normalization (UK→GB)

### DAG (Authoritative)
- **DAG ID:** `customer-metric-daily-agg`
- **Schedule:** `30 7 * * *` → 7:30 AM MST daily (prod/stage); None in dev-private
- **Dependency gate:** S3 success file sensor on `customer360.customer_life_cycle_vw`
- **Post-EMR:** Lake API notification (prod only), Redshift load via S3→Redshift staging
- **Team/Owner:** EDT (`customer360`), on-call via `#marketing-data-product-engineering`

### DDL / Policies / DQ
- Hive DDL: 32 columns + 1 partition; full column set with comments
- Redshift DDL: `customer360.customer_metric_daily_agg_vw` (prod); DATE distkey/sortkey on `partition_eval_mst_date`
- Policy YAML: SLA maxDurationMins=120, TIER_4; lists both inputs/outputs
- DQ constraints: 19-column composite primary key enforced on both lake and view tables

### Lake Registry
- Path: `catalog/config/prod/dlms-api/us-west-2/customer360/customer-metric-daily-agg-vw/`
- Description: "Customer Metric Daily Aggregated on Reporting Dims for a given day"
- SLA delivery cron: `cron(00 15 * * ? *)` → by 08:00 AM MST daily; Data Tier 4

### Confluence
- **Parent page (3779199819):** Confirms business purpose: replaces `customer_mart.daily_active_customers` and `customer_mart.monthly_active_customers`; NRU/lapsed metrics in progress
- **Business Context Structure (4387965088):** Grain confirmed as "One row per date × reporting dimension combo"; weight 15% in C360 coverage matrix

### Alation
- Skipped — `MOONUNIT_ALATION` environment variable not set

### Key Conflicts Recorded
7 discrepancies documented, most notably: lake registry DDL missing `data_source_enum`; PySpark reads underlying table but DAG sensors on the view; DDL comment shows stale values for `data_source_enum`; lake DDL PK (16 cols) vs DQ constraint PK (19 cols).