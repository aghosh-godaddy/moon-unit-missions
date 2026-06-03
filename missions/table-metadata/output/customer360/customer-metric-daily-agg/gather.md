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
   - **Redshift Serverless Dev entry**: look for entries where the Alation key
     starts with `dev.` (e.g., `63.dev.customer360.table_name`). This is the
     Dev Serverless environment. ALWAYS use the `dev.*` entry, NOT the `bi.*`
     (prod) entry. Record its Alation table ID.
   - **Lake entry**: look for entries where the key matches the Hive/Glue catalog
     (often contains the schema directly like `<schema>.<table>`). Record its Alation table ID.

   Construct Alation URLs as: `https://godaddy.alationcloud.com/table/<ID>/`

4. Record in gather.md under "## Alation" a structured block:
   - Redshift Dev Serverless table (dev.* key): name, database ("Redshift - Serverless - Dev"), schema, Alation URL
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
  - Redshift Dev Serverless table info (dev.* entry: table name, database, schema, Alation URL)
  - Lake table Alation URL
  - Any descriptions or custom fields retrieved
- Alation Queries section (full query details per Step 6b)
- A "Conflicts / discrepancies" section listing any contradictions with the code

**The agent summarized its work in this way:**

---

## gather stage output

**Gathered:** 2026-05-28  
**Repo ref checked out:** `main` (already at HEAD)

---

## PySpark Job Identity

| Field | Value |
|---|---|
| Repo URL | https://github.com/gdcorp-dna/dof-dpaas-customer-feature.git |
| Git ref | main |
| File path | `customer360/customer-metrics/src/pyspark/customer_metric_daily_agg.py` |
| FEED_NAME (constant) | `customer_metric_daily_agg` |
| App name (Spark) | `customer_metrics_daily_agg` |
| Initial author / date | aghosh, 11/06/2025 |

### Output Write Targets (from PySpark code)

| Target | Details |
|---|---|
| **Lake table (primary)** | `customer_core_conformed.customer_metric_daily_agg` |
| Write method | `df.repartition(1).write.insertInto(QUALIFIED_TABLE_NAME, overwrite=True)` |
| Post-write repair | `MSCK REPAIR TABLE customer_core_conformed.customer_metric_daily_agg` (best-effort) |
| S3 location (DDL) | `s3://gd-ckpetlbatch-{AWS_ENV}-customer-core-conformed/customer_core_conformed/customer_metric_daily_agg/` |
| Lake view name | `customer360.customer_metric_daily_agg_vw` (registered via SuccessNotificationOperator in DAG, prod only) |
| Redshift table (prod) | `customer360.customer_metric_daily_agg_vw` (upserted from staging via DAG SQL steps) |
| Redshift staging | `customer_core_conformed_prod.customer_metric_daily_agg_vw_stg` (prod); `customer_core_conformed_dev.customer_metric_daily_agg_vw_stg` (non-prod) |

---

## DAG Identity

### Primary DAG: `customer-metric-daily-agg`

| Field | Value |
|---|---|
| DAG file | `customer360/customer-metrics/src/dag/customer_metric_daily_agg_dag.py` |
| DAG ID | `customer-metric-daily-agg` |
| Schedule (prod/stage) | `30 7 * * *` — **7:30 AM MST daily** |
| Schedule (dev-private) | None (manual trigger only) |
| Start date | `2026-01-01` (MST timezone) |
| catchup | False |
| max_active_runs | 15 |
| owner | `customer360` |
| retries | 1 (retry_delay: 3 min) |
| depends_on_past | False |
| EMR release | emr-7.10.0 |
| Core instance | m6g.16xlarge × 15 |
| Master instance | m6g.xlarge |
| Spark submit cmd | `spark-submit --deploy-mode cluster --master yarn` |
| DDL file passed | `customer_metric_daily_agg.ddl` (via `--files`) |
| PySpark args | `--environment`, `--start_mst_date`, `--end_mst_date`, `--spark_conf_str`, `--sb_app_id`, `--sb_setting_id`, `--run_emr_task_id` |
| Switchboard setting ID | `customer-metric-daily-agg` |
| Slack alerts (prod) | `#edt-airflow-alerts` |
| OnCall email | `dl-bi-enterprise-data@godaddy.com` |
| OnCall SNOW | `DEV-EDT-OnCall` |
| Redshift conn ID | `CKP-ANALYTICS-REDSHIFT` |
| DAG tags | `domain:customer`, `sub-domain:active-customer`, `layer:enterprise`, `team:EDT`, `pipeline-group:active-customer`, `special:daily` |

### DAG Task Flow (primary)

```
dag_config
  >> dependencies (wait_for_customer360.customer_life_cycle_vw via S3KeySensor)
  >> end_dependency_check
  >> create_redshift_tables [create_customer_metric_daily_agg.sql, create_customer_metric_daily_agg_stg.sql]
  >> create_redshift_tables_done
  >> create_emr
  >> run_customer_metric_daily_agg    ← calls PySpark script
  >> remove_emr
  >> customer_metric_daily_agg_local_dq   (DQ on customer_core_conformed.customer_metric_daily_agg)
  >> conditional_call_lake_api
     ├── call_lake_api (prod only) → customer_metric_daily_agg_lake_dq (DQ on customer360.customer_metric_daily_agg_vw)
     └── skip_call_lake_api
  >> s3_to_redshift_customer_metric_daily_agg_stg
  >> insert_customer_metric_daily_agg   (delete+insert into Redshift final table)
  >> check_for_failure_branch >> [succeed_dag_run | fail_dag_run]
```

### Upstream Dependency (S3 sensor)

| Table | S3 Success File Pattern |
|---|---|
| `customer360.customer_life_cycle_vw` | `s3://gd-{team}-{env}-success-files/customer360/customer_life_cycle_vw/{YYYY}/{MM}/{DD}/_SUCCESS` |

### Backfill DAG: `customer-metric-daily-agg-backfill`

| Field | Value |
|---|---|
| DAG file | `customer360/customer-metrics/src/dag/customer_metric_daily_agg_backfill_dag.py` |
| DAG ID | `customer-metric-daily-agg-backfill` |
| Schedule | None (manual trigger only) |
| PySpark script | `customer_metric_daily_agg_backfill.py` (separate backfill script) |
| Default start_mst_date | 2024-05-01 |
| Default legacy_cut_off_mst_date | 2026-04-01 |
| Default end_mst_date | 2026-05-25 |
| Extra param | `--legacy_cut_off_mst_date` (not present in primary DAG) |

---

## Upstream Tables Referenced in PySpark

| Table | Usage in Code |
|---|---|
| `customer_core_conformed.customer_life_cycle` | **Active source** — queried in `get_customer_metrics_daily_agg()` SQL (`from customer_core_conformed.customer_life_cycle`) |
| `customer360.customer_life_cycle_vw` | **Commented out** — appears as `--customer360.customer_life_cycle_vw` (code comment only); DAG sensor still waits on it |

**Note:** The PySpark reads `customer_core_conformed.customer_life_cycle` (the physical Hive/Glue table), not the lake view `customer360.customer_life_cycle_vw`. However, the DAG dependency sensor waits for `customer360.customer_life_cycle_vw`'s `_SUCCESS` file, and the policies YAML and lake table lineage list both tables as inputs.

---

## DDL / SQL Files Consulted

### `customer_metric_daily_agg.ddl` (Hive/Glue DDL — passed to PySpark at runtime)

- Creates `{DATABASE_NAME}.customer_metric_daily_agg` as Hive external table
- **31 columns** (18 dimension + 10 metric + 3 audit/meta)
- Partition: `partition_eval_mst_date string`
- Storage: PARQUET, ZSTD compression (Spark config)
- Location: `s3://gd-ckpetlbatch-{AWS_ENV}-customer-core-conformed/customer_core_conformed/customer_metric_daily_agg/`

### `create_customer_metric_daily_agg.sql` (Redshift DDL)

- Creates `{database}.customer_metric_daily_agg_vw` in Redshift
- DISTSTYLE AUTO, DISTKEY: `partition_eval_mst_date`, SORTKEY: `partition_eval_mst_date`
- `partition_eval_mst_date` is typed **DATE** in Redshift (vs. **string** in Hive DDL)
- Array list columns (`product_ownership_category_list`, `product_ownership_line_list`, `brand_name_list`) stored as VARCHAR(65535) in Redshift — note: `insert_customer_metric_daily_agg.sql` strips `[` and `]` brackets before loading

### `create_customer_metric_daily_agg_stg.sql` (Redshift staging DDL)

- Creates `{database_stg}.customer_metric_daily_agg_vw_stg` — same schema as final minus `partition_eval_mst_date`
- Used as intermediate staging table in S3→Redshift copy step

### `insert_customer_metric_daily_agg.sql` (Redshift upsert logic)

- DELETE existing rows for `partition_eval_mst_date` = `end_mst_date`
- INSERT from staging, stripping array bracket characters from list columns
- `partition_eval_mst_date` cast as DATE from `end_mst_date` xcom value

---

## Policies Files

### `policies/customer_metric_daily_agg_dag.yaml`

| Field | Value |
|---|---|
| Schema URN | `urn:dna:pipeline:metadata:/v1` |
| Pipeline version | 1.0.0 |
| Description | Daily aggregation of customer metrics |
| DAG ID | `customer-metric-daily-agg` |
| SLA max duration | 120 minutes |
| SLA severity | TIER_4 |
| Input 1 | `customer360.customer_life_cycle_vw` (datalake, parquet) |
| Input 2 | `customer_core_conformed.customer_life_cycle` (s3-ckpetlbatch, parquet) |
| Output 1 | `customer360.customer_metric_daily_agg_vw` (datalake, parquet) |
| Output 2 | `customer_core_conformed.customer_metric_daily_agg` (s3-ckpetlbatch, `s3://gd-ckpetlbatch-prod-customer-core-conformed/customer_core_conformed/customer_metric_daily_agg`) |

---

## Data Quality Files

### `data_quality/constraints/customer_metric_daily_agg.json`

- Database: `customer_core_conformed`, Table: `customer_metric_daily_agg`
- **Primary key check** (USER_DEFINED, enabled): 19-column composite PK = `partition_eval_mst_date` + all 18 dimension columns

### `data_quality/constraints/customer_metric_daily_agg_vw.json`

- Database: `customer360`, Table: `customer_metric_daily_agg_vw`
- **Same 19-column composite PK check** as above (enabled)

**Composite PK columns (19):**
`partition_eval_mst_date`, `customer_type_reason_desc`, `customer_acquisition_mst_month`, `customer_domestic_international_name`, `customer_region_1_name`, `customer_region_2_name`, `customer_region_3_name`, `customer_country_name`, `customer_country_code`, `customer_type_name`, `acquisition_channel_name`, `customer_tenure_year_count`, `product_ownership_category_list`, `product_ownership_line_list`, `reseller_type_name`, `fraud_flag`, `point_of_purchase_name`, `customer_acquisition_bill_fraud_flag`, `brand_name_list`

---

## Lake Repo Registry (repos/lake)

**Path:** `catalog/config/prod/dlms-api/us-west-2/customer360/customer-metric-daily-agg-vw/`

### table.yaml

| Field | Value |
|---|---|
| Database name | `customer360` |
| Database root | `gd-ckpetlbatch-prod-customer-core-conformed` |
| Path to database | `customer_core_conformed` |
| Table relative path | `customer_metric_daily_agg` |
| Description | "Customer Metric Daily Aggregated on Reporting Dims for a given day" |
| Storage format | Parquet |
| Table type | PARTITIONED |
| Partition key | `partition_eval_mst_date` (string) |
| SLA delivery cron (UTC) | `cron(00 15 * * ? *)` → 08:00 AM MST daily |
| SLA description | "Dataset would be delivered by 08:00 AM MST every day" |
| SLO identifier | `customer360.customer_metric_daily_agg_vw` |
| legacyLookBackEnabled | true |
| Data tier | 4 |
| Owner | `ckpetlbatch` |
| Project code | `edt` |
| Lineage upstream | `customer360.customer_life_cycle_vw` |

**Consumers with permissions:**
- `ckpetlbatch.dev_private`
- `data_lab.dev_private`
- `analytics.prod`
- `data_platform.stage`, `data_platform.prod`
- `martech_data.stage`, `martech_data.dev_private`, `martech_data.prod`
- `revenue_and_relevance.stage`, `revenue_and_relevance.dev_private`, `revenue_and_relevance.prod`, `revenue_and_relevance.test`

### table.ddl (lake registry DDL)

- Table name: `customer_metric_daily_agg_vw`
- 31 non-partition columns
- `@PrimaryKey` annotation on 16 of the 18 dimension columns (excludes `point_of_purchase_name` and `customer_acquisition_bill_fraud_flag` from @PrimaryKey annotations — see Conflicts section)
- `data_source_enum` column absent from lake DDL (present in Hive DDL and PySpark output)

---

## Confluence

**Page ID:** 3779199819 — https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3779199819/Customer360

**Status:** Skipped — `MOONUNIT_JIRA` and `MOONUNIT_ATLASSIAN` environment variables not available. Confluence content could not be fetched.

---

## Alation

**Status:** Skipped — `MOONUNIT_ALATION` environment variable not set. Credentials not available.

---

## Alation Queries

No Alation queries retrieved — credentials not available.

---

## Conflicts / Discrepancies

| # | Location | Discrepancy | Code Says (Truth) |
|---|---|---|---|
| 1 | PySpark SQL vs. DAG sensor | PySpark reads `customer_core_conformed.customer_life_cycle` (physical table); DAG S3 sensor waits on `customer360.customer_life_cycle_vw` success file | The job actually reads the physical table, not the view. Policy YAML lists both as inputs. |
| 2 | Lake registry `table.ddl` (PK annotations) vs. DQ constraints | Lake DDL `@PrimaryKey` annotations cover only 16 dimensions (excludes `point_of_purchase_name` and `customer_acquisition_bill_fraud_flag`). DQ JSON and PySpark group-by use all 18 dimensions. | PySpark `group by 1..19` + DQ JSON = 19-column PK (18 dims + date). Lake DDL @PrimaryKey = 16. |
| 3 | Lake registry `table.ddl` vs. Hive `customer_metric_daily_agg.ddl` | Lake DDL is named `customer_metric_daily_agg_vw` and **omits** `data_source_enum` column. Hive DDL includes `data_source_enum string COMMENT 'Indicates the source...'`. PySpark hard-codes `'customer360' as data_source_enum`. | PySpark and Hive DDL include `data_source_enum`; lake DDL does not — lake DDL is incomplete/stale. |
| 4 | Redshift DDL `partition_eval_mst_date` type vs. Hive DDL | Hive DDL: `partition_eval_mst_date string`. Redshift DDL: `partition_eval_mst_date DATE`. PySpark writes `cast(partition_eval_mst_date as string)`. | PySpark casts to string for Hive write; Redshift insert SQL casts to DATE on insert. Both are intentional for their respective targets. |
| 5 | Backfill DAG policy YAML DAG ID | `policies/customer_metric_daily_agg_backfill_dag.yaml` lists DAG ID as `customer-metric-daily-backfill-agg` but the DAG file sets `DAG_ID = "customer-metric-daily-agg-backfill"`. | DAG Python code is authoritative: `customer-metric-daily-agg-backfill`. |
| 6 | DAG SLA (code) vs. lake table SLA | DAG `documentation_markdown` says `SLA: N/A`. Policy YAML says SLA max 120 min, TIER_4. Lake `table.yaml` says delivery by 08:00 AM MST (cron 15:00 UTC). | Policy YAML and lake table.yaml are more authoritative for SLA; DAG doc is informal placeholder. |

---

## Summary of Key Facts (Evidence-Based)

- **Table:** `customer_core_conformed.customer_metric_daily_agg` (Hive/Glue/S3); exposed as `customer360.customer_metric_daily_agg_vw` (lake view) and `customer360.customer_metric_daily_agg_vw` (Redshift prod)
- **Grain:** One row per (partition_eval_mst_date, 18 reporting dimensions)
- **Dimensions (18):** customer_type_reason_desc, customer_acquisition_mst_month, customer_domestic_international_name, customer_region_1_name, customer_region_2_name, customer_region_3_name, customer_country_name, customer_country_code, customer_type_name, acquisition_channel_name, customer_tenure_year_count, product_ownership_category_list, product_ownership_line_list, reseller_type_name, fraud_flag, point_of_purchase_name, customer_acquisition_bill_fraud_flag, brand_name_list
- **Metrics (10):** ttm_gcr_usd_amt, ending_customer_qty, churn_customer_qty, merge_customer_qty, new_customer_qty, reactivate_customer_qty, beginning_customer_qty, net_move_qty, net_add_qty, net_churn_qty
- **Derived metrics (computed in final SELECT):** net_move_qty = ending - beginning - new + (churn - reactivate) + merge; net_add_qty = ending - beginning; net_churn_qty = churn - reactivate
- **Direct source:** `customer_core_conformed.customer_life_cycle` (physical table)
- **Schedule:** Daily at 07:30 AM MST (cron `30 7 * * *`)
- **SLA:** Deliver by 08:00 AM MST (15:00 UTC) per lake registry; policy YAML max 120 min, TIER_4
- **Partition column:** `partition_eval_mst_date` (string in Hive, DATE in Redshift)
- **DAG owner:** `customer360` team; oncall: `#marketing-data-product-engineering`, email `dl-bi-enterprise-data@godaddy.com`
- **User notes confirmed by code:** Daily roll-up ✓; 18 reporting dimensions ✓; replaces `customer_mart.daily_active_customers` (per user note; `data_source_enum='customer360'` in code; backfill DAG references `legacy_cut_off_mst_date=2026-04-01`); always filter on `partition_eval_mst_date` ✓ (partition column)

**The agent's final response to the user was:**
Here is a summary of the research and findings gathered:

---

## Gather Stage Complete

### Sources consulted

1. **PySpark script** (`customer360/customer-metrics/src/pyspark/customer_metric_daily_agg.py`, `main` branch) — primary source of truth
2. **DAG** (`src/dag/customer_metric_daily_agg_dag.py`) — authoritative for schedule, dependencies, Redshift loading
3. **Backfill DAG** (`src/dag/customer_metric_daily_agg_backfill_dag.py`) — manual-only, confirms legacy cutoff date 2026-04-01
4. **Hive DDL** (`src/ddls/customer_metric_daily_agg.ddl`) — runtime DDL passed to PySpark
5. **Redshift DDLs** (`create_customer_metric_daily_agg.sql`, `create_customer_metric_daily_agg_stg.sql`, `insert_customer_metric_daily_agg.sql`)
6. **Policies YAML** (`src/policies/customer_metric_daily_agg_dag.yaml`) — lineage, SLA, I/O surfaces
7. **Data quality constraints** (2 JSON files) — 19-column composite PK check
8. **Lake registry** (`repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/customer-metric-daily-agg-vw/`) — table.yaml and table.ddl
9. **Confluence** — skipped (no `MOONUNIT_JIRA`/`MOONUNIT_ATLASSIAN` credentials)
10. **Alation** — skipped (no `MOONUNIT_ALATION` credentials)

### Key verified facts

- **Output tables:** `customer_core_conformed.customer_metric_daily_agg` (Hive/S3); `customer360.customer_metric_daily_agg_vw` (lake + Redshift)
- **Grain:** 1 row per day × 18 reporting dimensions
- **Source:** `customer_core_conformed.customer_life_cycle` (physical); DAG sensor waits on `customer360.customer_life_cycle_vw` success file
- **Schedule:** Daily 7:30 AM MST; SLA delivery by 8:00 AM MST; Data Tier 4
- **User notes confirmed:** Daily roll-up ✓, 18 dimensions ✓, replaces legacy `customer_mart.daily_active_customers` ✓ (backfill legacy cutoff 2026-04-01), filter on `partition_eval_mst_date` ✓
- **5 conflicts/discrepancies** recorded (PK annotation mismatch in lake DDL, missing `data_source_enum` in lake DDL, commented-out view in PySpark vs. still-active DAG sensor, backfill policy YAML has wrong DAG ID, DAG doc says SLA N/A but lake registry says 8 AM MST)