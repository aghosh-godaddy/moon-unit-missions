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
curl -s -X POST "https://godaddy.alationcloud.com/integration/v1/createAPIAccessToken/" \
  -H "Content-Type: application/json" \
  -d "$ALATION_CREDS"
```
3. Fetch table + columns once you have the target table name (or a candidate).
   If you cannot determine the target table yet, capture what you can (search results,
   existing descriptions) but do not assume.

## Step 7: Output (append to gather.md)
Append a structured, evidence-oriented report including:
- PySpark job identity (repo/ref/path), and the exact output write target(s) found (if any)
- DAG identity (path, schedule, params calling the PySpark)
- Enumerated upstream/local tables referenced in the PySpark
- Any DDL/policy/DQ files consulted and what they claim
- Confluence summaries (if any)
- Alation summaries (if any)
- A “Conflicts / discrepancies” section listing any contradictions with the code

**The agent summarized its work in this way:**

---

## Gather Stage Report — customer_life_cycle

**Generated:** 2026-05-28  
**Target identifier:** customer360 / customer-life-cycle  
**Source of truth:** PySpark + DAG (code wins over all other sources)

---

### 1. PySpark Job Identity

| Field | Value |
|---|---|
| Repo | `gdcorp-dna/dof-dpaas-customer-feature` |
| Git ref | `main` (HEAD: 7523b6d5) |
| File path | `customer360/customer-metrics/src/pyspark/customer_life_cycle.py` |
| Script name constant | `FEED_NAME = "customer_life_cycle"` |
| Initial author | aghosh, 2025-10-31 |

**Output write target (code-authoritative):**

| Field | Value |
|---|---|
| Hive/Glue table | `customer_core_conformed.customer_life_cycle` |
| Write mode | `insertInto(overwrite=True)` per `partition_eval_mst_date` partition |
| S3 location | `s3://gd-ckpetlbatch-{AWS_ENV}-customer-core-conformed/customer_core_conformed/customer_life_cycle/` |
| File format | Parquet (zstd compression) |
| Repartition on write | 30 partitions |
| Post-write | `MSCK REPAIR TABLE` (best-effort, logged if fails) |
| Lake (public) table | `customer360.customer_life_cycle_vw` (registered via SuccessNotificationOperator in prod) |
| Redshift table | `customer360.customer_life_cycle_vw` (loaded via S3 COPY from `customer_core_conformed_prod.customer_life_cycle_vw_stg`) |

---

### 2. DAG Identity

| Field | Value |
|---|---|
| DAG file | `customer360/customer-metrics/src/dag/customer_life_cycle_dag.py` |
| DAG ID | `customer-life-cycle` |
| Schedule (prod/stage) | `"20 7 * * *"` — 7:20 AM MST daily |
| Schedule (dev-private) | `None` (manual trigger only) |
| start_date | 2026-01-01 (America/Phoenix) |
| catchup | False |
| max_active_runs | 15 |
| retries | 1 (retry_delay 3 min) |
| EMR release | emr-7.10.0, core: m6g.16xlarge × 15 |
| Spark package | `emr7_package_arm.tar.gz` + `smart_spark_common-latest-py3-none-any.whl` |
| Switchboard app | `get_mwaa_team_name()` / setting_id = `customer-life-cycle` |
| Input param | `eval_mst_date` (YYYY-MM-DD); defaults to `logical_date` in Phoenix TZ if blank |
| Slack alert | `#edt-airflow-alerts` (prod), `#edt-airflow-alerts-low-priority` (other) |
| On-call group | `#marketing-data-product-engineering`, `dl-bi-enterprise-data@godaddy.com`, SNOW: DEV-EDT-OnCall |
| Stakeholders | `#marketing-data-products-help` |

**DAG task flow:**
```
dag_config
  → dependencies (14 × S3KeySensor, timeout 12h)
  → end_dependency_check
  → create_redshift_tables (create_customer_life_cycle.sql + create_customer_life_cycle_stg.sql)
  → create_emr
  → run_customer_life_cycle  (PySpark spark-submit on EMR)
  → remove_emr
  → dq_check_customer_life_cycle_local  (customer_core_conformed.customer_life_cycle)
  → conditional_call_lake_api
      ├─ [prod] call_lake_api  (SuccessNotificationOperator → customer360.customer_life_cycle_vw)
      │          → dq_check_customer_life_cycle_lake
      └─ [non-prod] skip_call_lake_api
  → s3_to_redshift_customer_life_cycle_stg
  → insert_customer_life_cycle
  → check_for_failure_branch → succeed_dag_run | fail_dag_run
```

---

### 3. Upstream / Input Tables

The following are authoritative from the DAG `dependencies` task group (S3 success-file sensors), cross-checked against PySpark `SRC_TABLES` dict:

| Table | DAG sensor? | PySpark reference | Notes |
|---|---|---|---|
| `customer_core_conformed.customer_ttm_payment_driver` | Yes (local_process) | Yes | Filtered: net_positive_ttm_payment_flag=true, trxn_currency_code <> 'N/A' |
| `customer_core_conformed.customer_active_subscription_detail_driver` | Yes (local_process) | Yes | Filtered: finance_payable_resource_flag=true; LEKA and domain override conditions |
| `customer_core_conformed.active_customer_stg` | Yes (local_process) | Yes | Used for prev-day / curr-day active flags |
| `analytic_feature.shopper_acquisition` | Yes | Yes | Filtered: partition_evaluation_mst_date = eval_mst_date |
| `analytic_feature.customer_type_history` | Yes | Yes | Filtered: record_start ≤ eval_mst_date ≤ record_end |
| `customer360.dim_customer_history_vw` | Yes | Yes | Used for private_label_id (reseller and 123 Reg); effective date filter + fallback to latest record |
| `dp_enterprise.dim_reseller` | Yes | Yes | Reseller type mapping from private_label_id |
| `enterprise.dim_new_acquisition_shopper` | Yes | Yes | Acquisition bill, date, country; no partition filter (full scan) |
| `enterprise.dim_subscription_history` | Yes | Yes | Filtered: partition_history_mst_date = eval_mst_date + 1 |
| `ecomm_mart.bill_line_traffic_ext` | Yes | Yes | Filtered: bill_modified_mst_date ≤ eval_mst_date AND new_acquisition_bill_mst_date = bill_modified_mst_date |
| `ecomm_mart.dim_bill_line_purchase_attribution` | Yes | Yes | Latest record per bill_id by bill_line_num |
| `finance360.dim_bill_fraud_history_vw` | Yes | Yes | DISTINCT bill_id only |
| `analytic_feature.customer_fraud` | Yes | Yes | Full table (no date filter) |
| `analytic_feature.shopper_merge` | Yes | Yes | Filtered: merge_start ≤ eval_mst_date ≤ merge_end |
| `s3://gd-ckpetlbatch-prod-analytic/analytic/ads_bill_line_ext/` | No | Yes (direct S3 read) | Legacy acquisition channel data; filtered: partition_bill_mst_year_month < '2022-08' |
| `finance360.dim_country_vw` | No | Yes | Geography enrichment; filtered: current_record_flag = true |

---

### 4. Output Table Schema (from DDL + `conform_datatype()` — authoritative)

**Table:** `customer_core_conformed.customer_life_cycle` (Hive/Glue)  
**Partition:** `partition_eval_mst_date STRING`  
**Primary Key (from DQ):** `(partition_eval_mst_date, shopper_id)`

| Column | Type | Description |
|---|---|---|
| shopper_id | string | Shopper ID (eCommerce profile) |
| customer_id | string | Customer UUID across GoDaddy systems |
| customer_acquisition_bill_id | string | Bill that triggered first net-positive status; for 'new'/'intraday' = coalesce(acq.bill_id, subscription.original_bill_id) |
| customer_acquisition_mst_date | date | Date of first net-positive bill (MST); NULL for existing customers with no past acquisition date |
| customer_acquisition_mst_month | string | Acquisition month truncated to first day of month |
| customer_acquisition_country_code | string | Country code at acquisition (UK normalized → GB) |
| customer_acquisition_channel_name | string | Marketing channel at acquisition (from bill_line_traffic_ext) |
| customer_tenure_year_count | int | `datediff(partition_eval_mst_date, customer_acquisition_mst_date) / 365` |
| customer_acquisition_country_name | string | Country name at acquisition |
| customer_region_1_name | string | Reporting region 1 |
| customer_region_2_name | string | Reporting region 2 |
| customer_region_3_name | string | Reporting region 3 |
| customer_domestic_international_name | string | Domestic or International flag |
| reseller_type_id | int | Reseller type ID from dp_enterprise.dim_reseller |
| reseller_type_name | string | Reseller type name |
| customer_type_name | string | Customer type label; '123 Reg' overrides if private_label_id=587240 |
| customer_type_reason_desc | string | Customer type reason; '123 Reg' overrides if private_label_id=587240 |
| customer_fraud_flag | boolean | Fraud flag from shopper_acquisition |
| active_paid_subscription_list | array<string> | Active paid subscription_ids |
| product_pnl_category_list | array<string> | Distinct PNL categories across active subscriptions |
| product_pnl_category_qty | int | COUNT(DISTINCT product_pnl_category) |
| product_pnl_line_list | array<string> | Distinct PNL lines across active subscriptions |
| ttm_all_bill_list | array<string> | Bill IDs from trailing 12 months |
| brand_name_list | array<string> | Union of brands from subscriptions + TTM payments |
| ttm_gcr_usd_amt | decimal(18,2) | Sum of TTM gross cash received (USD); 0 for intraday |
| customer_churn_mst_date | date | Eval date if status='churned' AND not merged; eval date if 'intraday' |
| customer_reactivate_mst_date | date | Eval date if status='new' AND acq_date < eval_date |
| customer_merge_mst_date | date | shopper_merge_start_mst_date if status='churned' AND merged |
| customer_fraud_mst_date | date | fraud_flag_mst_date if shopper fraud + not reinstated + acq_fraud_flag=true |
| customer_state_enum | string | Enum: intraday / merged / churned / reactivated / new / active |
| active_status_flag | boolean | True if customer_status NOT IN ('churned','intraday') |
| point_of_purchase_name | string | Point of purchase from acquisition bill |
| customer_acquisition_bill_fraud_flag | boolean | True if acquisition bill exists in finance360.dim_bill_fraud_history_vw |
| etl_build_mst_ts | timestamp | `from_utc_timestamp(current_timestamp(), 'MST')` |
| partition_eval_mst_date | string | Partition; all facts as of end of this day |

**Customer status derivation:**
- `new`: not active day-1, active on eval date
- `existing`: active day-1, active on eval date
- `churned`: active day-1, not active on eval date
- `intraday`: subscription flagged intraday_flag=true, acquired on eval date, not in active_customer_stg

**customer_state_enum derivation:**
```
intraday  → customer_status = 'intraday'
merged    → customer_merge_mst_date IS NOT NULL (churned + merged)
churned   → customer_churn_mst_date IS NOT NULL (churned + not merged)
reactivated → customer_status='new' AND acq_date < eval_date
new       → acq_date = eval_date
active    → all other cases
```

**Churned customers:** subscription/payment data taken from d-1 (previous day's partition); non-churned from eval date.

---

### 5. DDL / Policy / DQ Files Consulted

| File | Path | Claims |
|---|---|---|
| `customer_life_cycle.ddl` | `src/ddls/` | Hive DDL; S3 location `s3://gd-ckpetlbatch-{AWS_ENV}-customer-core-conformed/customer_core_conformed/customer_life_cycle/`; PARTITIONED BY partition_eval_mst_date STRING |
| `create_customer_life_cycle.sql` | `src/ddls/` | Redshift DDL for `customer_life_cycle_vw`; DISTSTYLE AUTO; DISTKEY + SORTKEY = partition_eval_mst_date |
| `create_customer_life_cycle_stg.sql` | `src/ddls/` | Redshift staging table DDL |
| `customer_life_cycle_dag.yaml` | `src/policies/` | Pipeline metadata; SLA maxDurationMins=120, severity=TIER_4; lists 16 inputs, 2 outputs |
| `customer_life_cycle.json` | `src/data_quality/constraints/` | PK check on (partition_eval_mst_date, shopper_id) for `customer_core_conformed.customer_life_cycle` |
| `customer_life_cycle_vw.json` | `src/data_quality/constraints/` | Same PK check for `customer360.customer_life_cycle_vw` |

---

### 6. Lake Catalog (repos/lake)

| Field | Value |
|---|---|
| Path | `catalog/config/prod/dlms-api/us-west-2/customer360/customer-life-cycle-vw/` |
| Description | "Analytic Dataset for Customer Life Cycle" |
| Data tier | 4 |
| Table type | PARTITIONED |
| Partition key | partition_eval_mst_date (string) |
| Storage format | Parquet |
| SLA delivery | `cron(00 15 * * ? *)` = 8:00 AM MST daily |
| SLO identifier | `customer360.customer_life_cycle_vw` |
| legacyLookBackEnabled | true |

**Consumers declared in lake catalog:**
ckpetlbatch (dev/prod), data_lab (dev), analytics (prod), data_platform (stage/prod), care_analytics, martech_data (dev/stage/prod), revenue_and_relevance (dev/stage/prod/test), partners (stage/prod)

**Upstream lineage declared in lake catalog (may be stale):**
analytic_feature.customer_fraud, analytic_feature.customer_type_history, analytic_feature.shopper_acquisition, analytic_feature.shopper_merge, customer360.dim_customer_history_vw, **customers.customer_id_mapping_snapshot**, dp_enterprise.dim_reseller, ecomm_mart.bill_line_traffic_ext, ecomm_mart.dim_bill_line_purchase_attribution, **ecomm_mart.entitlement_bill_type**, **enterprise.dim_bill_shopper_id_xref**, **enterprise.dim_entitlement_history**, enterprise.dim_new_acquisition_shopper, enterprise.dim_subscription_history, **enterprise.fact_bill_line**, **enterprise.fact_entitlement_bill**, finance360.dim_bill_fraud_history_vw, finance360.dim_country_vw, **finance360.dim_product_vw**, **finance_cln.manual_paid_subscription**

(Bold = present in lake catalog lineage but NOT referenced in current PySpark code)

---

### 7. Confluence Summary

**Parent page:** Customer360 (ID 3779199819) — hub page listing contacts for Finance, and other teams.  
Child pages include: Customer360 Design Docs → Customer Lifecycle (ID 3970861345), Customer Metrics, etc.

**"Customer Lifecycle" design doc (ID 3970861345):**
- "Physical Model for Customer Lifecycle table which will act as driver for Customer Metrics requested by Finance."
- References column mapping spreadsheet on SharePoint.
- Key confirmed facts: acquisition_bill_id from enterprise.dim_new_acquisition_shopper + shopper_acquisition; reseller from dim_reseller via private_label_id; customer_type from analytic_feature.customer_type_history; ttm_gcr_usd_amt from fact_customer_ttm_payment; churn logic references https://godaddy.alationcloud.com/article/98/churned-customer.

**"Customer360 Business Context Structure" (ID 4387965088):**
- Data Product schema: `customer360`, Domain: Customer, Org: DNA
- Data Tier: 2 (dim tables) · 4 (lifecycle, agg)
- `customer_life_cycle_vw` grain: "One row per customer per eval date" (confirmed by code)
- customer_life_cycle_vw has 35% weight in coverage matrix; described as "primary OSI and OWL target"

---

### 8. Alation

**Status:** Skipped — `MOONUNIT_ALATION` env var not set (credentials not available).

---

### 9. Conflicts / Discrepancies

| # | Source | Claim | Code Says | Action |
|---|---|---|---|---|
| 1 | Lake catalog lineage | 8 additional upstream tables: customers.customer_id_mapping_snapshot, ecomm_mart.entitlement_bill_type, enterprise.dim_bill_shopper_id_xref, enterprise.dim_entitlement_history, enterprise.fact_bill_line, enterprise.fact_entitlement_bill, finance360.dim_product_vw, finance_cln.manual_paid_subscription | None of these appear in current PySpark SRC_TABLES or SQL | Lake lineage is stale (likely from pre-re-architecture pipeline); validate and update lake catalog |
| 2 | Policy file (customer_life_cycle_dag.yaml) | `finance360.dim_bill_fraud_history_vw` listed TWICE — once as `format: parquet`, once as `format: iceberg` | Code reads it as a Hive table (no explicit format specified) | Duplicate entry in policy; need to deduplicate and confirm format |
| 3 | Confluence "Customer Lifecycle" design doc | Upstream includes: shopper_status_v2, fact_active_entitlement_last_payment_detail, shopper_churn_v2, analytic_feature.shopper_tenure | None present in current PySpark code | Design doc is from earlier architecture; outdated |
| 4 | Confluence "Customer Lifecycle" design doc | customer_tenure_year_count = "shopper_tenure.shopper_tenure_days_count / 365" | Code: `datediff(partition_eval_mst_date, customer_acquisition_mst_date) / 365` cast as int | Doc outdated; code is authoritative |
| 5 | DDL file (`customer_life_cycle.ddl`) comment | "Primary Key: resource_id, product_family_name, entitlement_addon_id, partition_eval_mst_date" | DQ constraints + code grain: (partition_eval_mst_date, shopper_id) | Copy-paste artifact from entitlement driver DDL; DDL comment is wrong |
| 6 | DAG doc_md | "SLA: N/A" and "Data Tier: N/A" | Policy file: maxDurationMins=120, severity=TIER_4; lake catalog: data_tier=4 | DAG doc_md is a placeholder; policy file and lake catalog are authoritative for SLA/tier |
| 7 | finance360.dim_country_vw | No DAG sensor / no S3 success-file wait | Referenced in PySpark via LEFT JOIN | Dependency not tracked by DAG; late delivery of dim_country_vw would not block the job |
| 8 | Legacy S3 `ads_bill_line_ext` | No DAG sensor | Referenced in PySpark as direct `spark.read.parquet("s3://gd-ckpetlbatch-prod-analytic/analytic/ads_bill_line_ext/")` (hardcoded prod path) | No dependency gate; hardcoded bucket path will fail in non-prod; confirm if intentional |

---

### 10. Summary of Key Facts

| Attribute | Value (Code-Authoritative) |
|---|---|
| **Business purpose** | Driver/fact table tracking GoDaddy customer life-cycle state daily; supports Finance-requested customer metrics |
| **Grain** | One row per (shopper_id, partition_eval_mst_date); DQ enforces uniqueness on (partition_eval_mst_date, shopper_id) |
| **Internal (landing) table** | `customer_core_conformed.customer_life_cycle` |
| **Public (lake) table** | `customer360.customer_life_cycle_vw` |
| **Partition** | `partition_eval_mst_date` STRING |
| **Coverage** | Active, churned, merged, reactivated, new, intraday customers per evaluation date |
| **Schedule** | Daily at 7:20 AM MST; data available by 8:00 AM MST (per SLO) |
| **SLA** | maxDurationMins=120, TIER_4 |
| **Data tier** | 4 |
| **Team / owner** | customer360 / EDT |
| **14 upstream tables** | See Section 3 |
| **Key metrics** | ttm_gcr_usd_amt, product_pnl_category_qty, active_paid_subscription_list |
| **Key dimensions** | customer_state_enum, customer_type_name, reseller_type_name, customer_acquisition_channel_name, geography (region 1/2/3, country) |


**The agent's final response to the user was:**
The gather stage is complete. Here is a summary of everything researched and written to `gather.md`:

---

## What was gathered

### Sources read

1. **PySpark script** (`customer360/customer-metrics/src/pyspark/customer_life_cycle.py`, `main` branch, HEAD `7523b6d5`) — fully read (1,099 lines)
2. **DAG** (`src/dag/customer_life_cycle_dag.py`) — full task flow, schedule, EMR config, dependencies
3. **DDLs** — `customer_life_cycle.ddl` (Hive/Glue), `create_customer_life_cycle.sql` (Redshift), `create_customer_life_cycle_stg.sql`
4. **Policy file** — `src/policies/customer_life_cycle_dag.yaml` (SLA, inputs, outputs)
5. **Data quality** — `customer_life_cycle.json` + `customer_life_cycle_vw.json` (PK constraints)
6. **Lake catalog** — `repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/customer-life-cycle-vw/table.yaml` + `table.ddl`
7. **Confluence** — Parent page 3779199819, child page "Customer Lifecycle" (3970861345), "Customer360 Business Context Structure" (4387965088)
8. **Alation** — Skipped (`MOONUNIT_ALATION` not set)

### Key findings

- **Output tables:** `customer_core_conformed.customer_life_cycle` (Hive) → replicated to `customer360.customer_life_cycle_vw` (lake) and `customer360.customer_life_cycle_vw` (Redshift)
- **Grain:** One row per `(shopper_id, partition_eval_mst_date)`; DQ-enforced PK
- **Schedule:** Daily 7:20 AM MST; SLO delivery by 8:00 AM MST; TIER_4
- **14 upstream dependencies** fully enumerated with filter logic
- **Business purpose:** Driver table for customer lifecycle state (new/existing/churned/merged/reactivated/intraday) for Finance-requested customer metrics

### Conflicts flagged (8 total)
- Lake catalog lineage contains 8 stale upstream tables not in current code
- Confluence design doc references superseded source tables and an incorrect tenure formula
- DDL PK comment is a copy-paste error from a different table
- `finance360.dim_bill_fraud_history_vw` listed twice in policy with conflicting formats
- Legacy S3 `ads_bill_line_ext` read with hardcoded prod bucket path, no DAG sensor