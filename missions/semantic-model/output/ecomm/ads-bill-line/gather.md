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

## gather stage — ads-bill-line (analytic.ads_bill_line)

**Gathered:** 2026-06-04  
**Source repo:** `dof-ecomm-customer` @ `main` (cloned, branch already current)  
**PySpark path:** `ecomm/analytic-bill-line/src/pyspark/ads_bill_line.py`

---

### 1. PySpark Job Identity

| Field | Value |
|---|---|
| Repo | `gdcorp-dna/dof-ecomm-customer` |
| Git ref | `main` |
| File path | `ecomm/analytic-bill-line/src/pyspark/ads_bill_line.py` |
| Script description | "ADS Bill Line" — augments core Enterprise Fact Bill / Fact Bill Line entities with common dimensions |
| Database constant | `DATABASE_NAME = "analytic_local"` |
| Table constant | `TABLE_NAME = "ads_bill_line"` |
| Qualified target | `analytic_local.ads_bill_line` (in-job name); Lake catalog name: `analytic.ads_bill_line` |
| S3 location (prod) | `s3://gd-ckpetlbatch-prod-analytic/analytic/ads_bill_line/` |
| Partition key | `partition_bill_mst_year_month` (string, derived `YYYY-MM` from `bill_modified_mst_date`) |
| Date range processed | `1999-07-01` → current date (yesterday) |

---

### 2. DAG Identity

| Field | Value |
|---|---|
| DAG file | `ecomm/analytic-bill-line/src/dag/analytic_bill_line_dag.py` |
| DAG ID | `ecomm_analytic_bill_line_core` |
| Schedule | `"30 3 * * *"` (prod only; non-prod: None / manual) |
| Schedule interpretation | 3:30 AM UTC = ~8:30 PM MST previous day; delivery SLA 7:00 AM MST |
| Start date | 2023-10-01 (America/Phoenix timezone) |
| Retries | 0 (job level); load step has `retries=1` |
| Max active runs | 1 |
| Catchup | False |
| EMR release | `emr-7.2.0` |
| Orchestrator | `mwaa-dof-ecomm-cust` |
| Owner (domain) | `ecomm` |
| Tags | `[ecomm, analytic, bill-line]` |
| Alert Slack | `#edt-airflow-alerts` |
| Dev Slack | `#dna-franchise-enterprise` |
| OnCall Slack | `#edt-scrum` |
| OnCall Email | `dl-bi-enterprise-data@godaddy.com` |
| SLA (policy) | 7:00 AM MST, maxDurationMins: 150, severity: TIER_2 |
| Data Tier | 2 |

**DAG parameters (configurable at trigger time):**
- `dim_product_table` — `dim_product_snap` (default) or `dim_product_hist_cln`
- `reflow` — if `"true"`, full overwrite to Redshift instead of delta upsert

**DAG task flow:**
```
start → dependencies (S3 success sensors) → dag_config → create_emr → load_ads_bill_line → [stop_emr, data_quality]
data_quality → lake_api → end
data_quality → redshift (create_staging → branch → [delta_upsert | full_reload] → views → end)
stop_emr → end
```

---

### 3. Table Grain

- **Grain:** One row per `(bill_id, bill_line_num)` — one row per line item (product) per bill (order/receipt).
- **DQ constraint confirms:** `isPrimaryKey("bill_id", "bill_line_num")` in `data_quality/constraints/ads_bill_line.json`.
- **Note:** `bill_id` is `order_id` on receipt; `bill_line_num` is `row_id` (line item number) on receipt.

---

### 4. Source Tables (READ)

All reads are authoritative from `config_ads_bill_line.py`:

| Table | Role | Join Key(s) | Notes |
|---|---|---|---|
| `ecomm360.fact_bill_line_vw` | READ (primary) | `bill_id`, `bill_line_num`, `pf_id`, `subaccount_customer_id` | Core fact table with line-level financial amounts |
| `ecomm360.dim_bill_vw` | READ | `bill_id`, `original_customer_id`, `merged_customer_id` | Bill header dimension; also used for shopper xref |
| `bigreporting.dim_product_snap` | READ | `pf_id`, `pnl_subline` | Product dimension; default version |
| `bigreporting.dim_product_hist_cln` | READ (alternate) | `pf_id`, `pnl_subline` | Alternative product table via `--dim-product-table` flag |
| `callcenterreporting.rpt_c3_orders_ordersource_snap` | READ | `order_id = bill_id` | C3 order source details |
| `callcenterreporting.rpt_c3_orders_snap` | READ | `order_id = bill_id` | C3 rep version lookup |
| `godaddycpl.gdshop_common_purchase_log_snap` | READ | `order_id = bill_id` | Payment processor / CPL data |
| `fraud_cln.fraud_note_cln` | READ | `fraud_review_id` (self-join via explode) | Fraud note text with refunded order IDs |
| `fraud_cln.fraud_review_history_cln` | READ | `fraud_review_id` | Fraud review history (manager, action) |
| `reference_cln.tld_registry_reference_cln` | READ | `tld_name = pnl_subline` | TLD registry info for domain products |
| `dm_reference.dim_geography` | READ | `country_code = bill_country_code` | Geography hierarchy; BROADCAST in join |
| `gd_pro_mart.web_pro_shopper_client` | READ | `parent_shopper_id`, `client_shopper_id` | Web Pro shopper/client relationships |
| `dp_stage.ref_order_constant_currency` | READ | `transaction_currency_code = trxn_currency_code` | Exchange rate for constant currency; BROADCAST |
| `dp_stage.ref_commission_products` | READ | `pf_id` | Commission product flag reference; BROADCAST |
| `dp_enterprise.dim_isc_source_code` | READ | `isc_source_code = bill_isc_source_code` | ISC marketing attribution; BROADCAST |
| `partner360.dim_reseller_vw` | READ | `reseller_customer_id`, `private_label_id` | Reseller dimension |
| `enterprise.free_entitlement` | READ | `free_bill_id/paid_bill_id = bill_id`, `bill_line_num` | Free trial entitlement data |
| `ecomm_core_conformed.dim_customer_registration_acquisition` | READ | `shopper_id`, `customer_id` | Customer registration/acquisition; read via Iceberg directly from S3 `gd-ckpetlbatch-prod-ecomm-core-conformed` |
| `ecomm_mart.dim_bill_line_purchase_attribution` | READ | `bill_id`, `bill_line_num` | Purchase path attribution |
| `analytic_feature.customer_type_history` | READ | `shopper_id` (mapped as `merged_shopper_id`) | Customer type classification |
| `analytic_feature.shopper_crm_portfolio` | READ | `shopper_id = original_shopper_id`, `partition_evaluation_mst_date = bill_modified_mst_date` | CRM portfolio type at bill time |
| `analytic_feature.shopper_domain_portfolio` | READ | `shopper_id = merged_shopper_id`, `evaluation_mst_date = bill_modified_mst_date` | Domain portfolio at bill time |
| `care_mart.rev_attribution` | READ | `order_id = bill_id`, date filter | C3 revenue attribution type |
| `gmode.customer_type_gcr_logic_lookup` | READ | `[customer_type_name, product_pnl_new_renewal_name, product_pnl_category_name, product_pnl_line_name, product_pnl_version_name, product_pnl_subline_name, bill_report_region_2_name]` | GCR PnL segment logic flags; BROADCAST |
| `customers.customer_id_mapping_snapshot` | READ | `customerid`, `id` (shopper_id) | Shopper↔customer ID mapping |
| `care_mart.employee_master_snap_v3` | READ | `rep_version_id` | C3 employee/rep details |
| `customer360.dim_customer_vw` | READ | `customer_id`, `shopper_id` | Customer dimension; for subaccount and reseller |
| `customer360.dim_customer_history_vw` | READ | `customer_id`, `shopper_id` | Internal shopper detection |
| `finance360.dim_country_vw` | READ | `country_code = payment_country_code` | Country name for reseller |

---

### 5. Output Tables (WRITE)

| Table | Platform | Notes |
|---|---|---|
| `analytic_local.ads_bill_line` (= `analytic.ads_bill_line` in Lake catalog) | Data Lake (Parquet, AWS Glue/Athena) | Primary output; partitioned by `partition_bill_mst_year_month`; full overwrite per partition |
| `analytic_local.tmp_ads_bill_line` | Data Lake temp | Intermediate table for delta calculation; dropped after use |
| S3 delta path: `s3://gd-ckpetlbatch-{ENV}-analytic/analytic/rs_ads_bill_line/` | S3 (Parquet) | Delta records for Redshift incremental load |
| `ecomm_prod.ads_bill_line` | Redshift | Replicated from Lake; delta upsert or full reload via `upsert_to_prod.sql`/`promote_to_prod.sql` |
| `dna_approved.bill_line` | Redshift (materialized view) | Redshift view on `ecomm_prod.ads_bill_line` |
| `dna_approved.uds_order` | Redshift (materialized view) | Redshift view on `ecomm_prod.ads_bill_line` (legacy compatibility) |

---

### 6. Join Conditions (Explicit)

Listed in order of construction in the PySpark script:

1. **fraud: note ↔ history** — `fraud_note_filtered.join(fraud_history_filtered, how="left", on=["fraud_review_id"])`

2. **fact_bill_denorm (bill-level join)**:
   - `cte_fb_distinct` LEFT JOIN `cte_dim_bill` ON `bill_id`
   - LEFT JOIN `dp_enterprise.dim_isc_source_code` ON `fb.bill_isc_source_code = isc.isc_source_code`
   - LEFT JOIN `care_mart.rev_attribution` ON `fb.bill_id = rev.order_id` AND date-range filter on `rev.rpt_mst_date`
   - LEFT JOIN `employee_master_snap_v3` ON `db.rep_version_id = rep.rep_version_id`
   - LEFT JOIN `dim_reseller` ON `fb.private_label_id = res.private_label_id`
   - LEFT JOIN `cte_fraud_order` ON `fb.bill_id = frd.bill_id`
   - LEFT JOIN `callcenterreporting.rpt_c3_orders_ordersource_snap` ON `fb.bill_id = c3.order_id` AND date-range filter on `c3.order_date`
   - LEFT JOIN `dp_stage.ref_order_constant_currency` ON `fb.trxn_currency_code = cc.transaction_currency_code`
   - LEFT JOIN `cte_payment_processor` ON `fb.bill_id = pp.bill_id`

3. **dim_reseller construction**:
   - `partner360.dim_reseller_vw` LEFT JOIN `ecomm_core_conformed.dim_customer_registration_acquisition` ON `rs.reseller_customer_id = cr.customer_id`
   - LEFT JOIN `customer360.dim_customer_vw` ON `rs.reseller_customer_id = c.customer_id` AND `c.current_record_flag = TRUE`
   - LEFT JOIN `finance360.dim_country_vw` ON `cr.payment_country_code = f.country_code` AND `f.current_record_flag = TRUE`

4. **fact_bill_core**: `fact_bill_denorm.join(F.broadcast(dim_geography), how="left", on=["bill_country_code"])`

5. **dim_product_snap**: `bigreporting.dim_product_snap` LEFT JOIN `reference_cln.tld_registry_reference_cln` ON `dp.pnl_subline = tld.tld_name` AND `dp.pnl_line IN ('Domain Name Registration', 'Domain Name Auction', 'Domain Name Transfer')`

6. **fact_bill_line_core** (line-level join):
   - `ecomm360.fact_bill_line_vw` LEFT JOIN `customers.customer_id_mapping_snapshot` ON `fbl.subaccount_customer_id = c.customerid` AND `subaccount_customer_id IS NOT NULL`
   - LEFT JOIN `cte_dim_product_snap` ON `fbl.pf_id = dp.pf_id` (BROADCAST hint)
   - LEFT JOIN `cte_free_entitlements` ON `fbl.bill_id = free.bill_id` AND `fbl.bill_line_num = free.bill_line_num`
   - LEFT JOIN `dp_stage.ref_commission_products` ON `fbl.pf_id = com.pf_id` (BROADCAST hint)
   - LEFT JOIN `ecomm_mart.dim_bill_line_purchase_attribution` ON `fbl.bill_id = pa.bill_id` AND `fbl.bill_line_num = pa.bill_line_num` AND partition date filter

7. **dim_bill_shopper_id_xref** (shopper resolution):
   - `ecomm360.dim_bill_vw` LEFT JOIN `customers.customer_id_mapping_snapshot` ON `a.original_customer_id = b.customerid`
   - LEFT JOIN `customers.customer_id_mapping_snapshot` ON `a.merged_customer_id = c.customerid`
   - LEFT JOIN (subq: `customer360.dim_customer_history_vw` WHERE `internal_shopper_flag=TRUE`, ROW_NUMBER partitioned by `customer_id`) ON `COALESCE(a.original_shopper_id, b.id) = s.shopper_id`

8. **dim_shopper_core**:
   - `cte_shopper_base` LEFT JOIN `ecomm_core_conformed.dim_customer_registration_acquisition` ON `b.original_shopper_id = nas.shopper_id`
   - LEFT JOIN `cte_shopper_federation_partner` ON `b.original_shopper_id = fed.original_shopper_id`
   - LEFT JOIN `cte_shopper_web_pro` ON `b.original_shopper_id = web.original_shopper_id`
   - LEFT JOIN `cte_shopper_clients` ON `b.original_shopper_id = cli.original_shopper_id`

9. **dim_bill_shopper_core** (shopper + portfolio at bill date):
   - `cte_dim_bill_shopper_id_xref` LEFT JOIN `cte_dim_shopper_core` ON `x.original_shopper_id = shop.original_shopper_id`
   - LEFT JOIN `cte_shopper_domain_portfolio` ON `x.merged_shopper_id = dom.shopper_id` AND `x.bill_modified_mst_date = dom.bill_modified_mst_date`
   - LEFT JOIN `cte_crm_portfolio` ON `x.original_shopper_id = crm.original_shopper_id` AND `x.bill_modified_mst_date = crm.bill_modified_mst_date`
   - LEFT JOIN `cte_current_crm_portfolio` ON `COALESCE(x.merged_shopper_id, x.original_shopper_id) = cur.original_shopper_id` (BROADCAST hint)
   - LEFT JOIN `cte_customer_type` ON `COALESCE(x.original_shopper_id, x.merged_shopper_id) = ct.merged_shopper_id`
   - LEFT JOIN `customers.customer_id_mapping_snapshot` ON `TRIM(x.original_shopper_id) = TRIM(org_cms.id)`
   - LEFT JOIN `customers.customer_id_mapping_snapshot` ON `TRIM(x.merged_shopper_id) = TRIM(merged_cms.id)`

10. **customer_type**: `analytic_feature.customer_type_history` LEFT JOIN `ecomm_core_conformed.dim_customer_registration_acquisition` ON `ct.shopper_id = nas.shopper_id`

11. **ads_bill_line_core (final merge)**:
    - `fact_bill_line_core.join(fact_bill_core.drop("bill_modified_mst_date"), how="left", on=["bill_id"])`
    - `.join(dim_bill_shopper_core.drop("bill_modified_mst_date"), how="left", on=["bill_id"])`
    - `.join(F.broadcast(customer_type_gcr_logic_lookup), how="left", on=["customer_type_name", "product_pnl_new_renewal_name", "product_pnl_category_name", "product_pnl_line_name", "product_pnl_version_name", "product_pnl_subline_name", "bill_report_region_2_name"])`

12. **dim_bill subquery**: `ecomm360.dim_bill_vw` LEFT JOIN `callcenterreporting.rpt_c3_orders_snap` ON `c3.order_id = dim.bill_id`

---

### 7. Aggregation Expressions

| Expression | Purpose |
|---|---|
| `ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY date_entered DESC, cpl_id DESC)` | Dedup payment processor; take latest CPL row per bill |
| `ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY tx_write_mst_ts desc, tx_source_id desc, create_mst_ts asc, fraud_review_id asc)` | Dedup fraud note/history; take most recent per order |
| `UPPER(MAX(bill_country_code) OVER (PARTITION BY bill_id))` | Fill bill_country_code across all rows of a bill |
| `SUM(CASE WHEN refund_flag=FALSE AND chargeback_flag=FALSE AND pnl_category='domain registration' THEN unit_qty ELSE 0 END) OVER (PARTITION BY bill_id) >= 50` | Compute `domain_bulk_flag` |
| `ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY effective_end_mst_ts DESC)` | Internal shopper dedup in dim_customer_history_vw |
| `min(sign_at_utc_ts) GROUP BY parent_shopper_id` | Earliest Web Pro sign date per pro shopper |
| `min(named_struct(...)) GROUP BY client_shopper_id` | Earliest client creation per client shopper |
| `min(product_free_trial_acquisition_date), min(product_free_trial_acquisition_ts) GROUP BY bill_id, bill_line_num, ...` | Free entitlement dedup |
| `ROUND(COALESCE(gcr_trxn_amt * exchange_rate, gcr_usd_amt), 2)` | Constant currency GCR |
| `ROUND(COALESCE(...), 2) AS receipt_price_constant_currency_amt` | Constant currency RPA |

---

### 8. Key Computed / Derived Columns

| Column | Logic |
|---|---|
| `partition_bill_mst_year_month` | `CONCAT(YEAR(bill_modified_mst_date), '-', LPAD(MONTH(...), 2, '0'))` |
| `bill_modified_mst_date_prior_year` | `DATE_SUB(bill_modified_mst_date, 364)` |
| `bill_domestic_international_name` | `'Domestic'` if `bill_country_code='US'` else `'International'` |
| `domain_bulk_flag` | `SUM(domain reg units) OVER (PARTITION BY bill_id) >= 50` |
| `c3_bill_flag` | `c3_bill_id IS NOT NULL` |
| `new_registered_user_flag` | `new_registered_user_bill_id = bill_id` |
| `new_acquisition_flag` | `new_acquisition_bill_id = bill_id` |
| `web_pro_participant_type_name` | `'Pro'` if web_pro_signed AND bill_date >= signed_at-7d; `'Client'` if client AND bill_date >= client_created-7d |
| `customer_type_name` | Temporal logic: use assigned type if `bill_date >= assignment_date`, else use `ind_desc` for pre-Partner/Investor dates, else `'Not Evaluated'` |
| `product_pnl_new_renewal_name` | Override to `'New Purchase'` if `product_free_trial_conversion_flag=TRUE`; else `COALESCE(TRIM(pnl_new_renewal), 'Unknown')` |
| `pnl_usi_flag` | From GCR logic lookup or `customer_type='US Independent'` |
| `pnl_gdii_flag` | From GCR logic lookup or `customer_type IN ('International Independent', '123 Reg')` |
| `pnl_partner_flag` | From GCR logic lookup or `customer_type='Partner'` |
| `pnl_dri_flag` | From GCR logic lookup or `customer_type='Investor'` |
| `pnl_commerce_flag` | From GCR logic lookup only |
| `bill_isc_channel_name` | COALESCE(ISC channel, derived from `point_of_purchase_name`) |
| `free_bill_line_flag` | `receipt_price_usd_amt=0 AND gcr_usd_amt=0 AND virtual_bill_flag=FALSE` |
| `free_bill_line_with_fair_market_value_flag` | `receipt_price_usd_amt=0 AND gcr_usd_amt>0 AND offer_collection_id IS NULL AND virtual_bill_flag=FALSE` |
| `etl_build_mst_ts` | `FROM_UTC_TIMESTAMP(FROM_UNIXTIME(UNIX_TIMESTAMP()), 'MST')` |
| `source_process_name` | Literal `'ads_bill_line.py (full)'` |

---

### 9. DDL / Policy / DQ Files Consulted

| File | Type | Key Findings |
|---|---|---|
| `src/pyspark/ddl/schema_ads_bill_line.py` | PySpark StructType schema | Authoritative column list with types and inline comments; 200+ columns defined |
| `src/pyspark/conf/config_ads_bill_line.py` | Source DB config | Maps table aliases → `database.table_name` |
| `src/policies/analytic_bill_line_dag.yml` | Pipeline policy (schemaUrn: `urn:dna:pipeline:metadata:/v1`) | Lists all inputs/outputs with platform, SLA (maxDurationMins: 150, TIER_2), DAG ID |
| `src/data_quality/constraints/ads_bill_line.json` | DQ constraints | `isPrimaryKey("bill_id", "bill_line_num")` — enabled, USER_DEFINED |
| `repos/lake/catalog/config/prod/us-west-2/analytic/ads-bill-line/table.ddl` | Lake DDL | 202-line Hive DDL with column comments; authoritative Lake schema |
| `repos/lake/catalog/config/prod/us-west-2/analytic/ads-bill-line/table.yaml` | Lake config | storage_format: Parquet; partition key: `partition_bill_mst_year_month` (string); data_tier: 2; SLA cron `0 14 * * ? *` (UTC=7AM MST); 80+ consumer permissions granted |

---

### 10. Confluence Pages

None provided in INPUT.md.

---

### 11. Alation

| Field | Value |
|---|---|
| Alation URL | `https://godaddy.alationcloud.com` |
| Table ID | 6242622 |
| Alation key | `AwsDataCatalog.analytic.ads_bill_line` |
| Display Title | "Analytic Data Set (ADS) Bill Line" |
| Data Source | GoDaddy Central Data Lake (Prod) (ds_id: 81, type: Athena OCF) |
| Created | 2021-04-20 |
| Last Updated | 2026-06-02 |
| Saved Queries | 0 (num_queries: 0 per Alation record) |

**Alation description (verbatim condensed):**
> Bill Line is the analytic (ads) layer which rests on top of the EDS (enterprise layer) for Fact_Bill and Fact_Bill_Line. It is conceptually order and row data, similar to what is found in pds/uds_order. The purpose was to replace the bulk of data currently available in uds_order (or pds_order), while incorporating new taxonomy and structures from new ecomm. Additional data sources are also referenced to create corollaries for existing pds order fields — primarily relating to original shopper and merged shopper attributes.
> - Refunds and Chargeback Bills are included. Filter using `refund_flag` and `chargeback_flag`.
> - **GCR metrics will be NULL for refunds and chargebacks.**
> - For web Pro-related orders, `ads_bill_line` reflects the shopper's **current** opt-in status — not status at time of order.
> - Primary Keys: `bill_id` and `bill_line_num`
> - Common Use Cases: UDS/PDS order replacement
> - Related: `dna_approved.bill_line` (Redshift view), `bill_line_ext` (extended with GA traffic attributes)
> - Design docs: Confluence at `/display/BI/ADS+Bill+Line+%28and+Extended%29+-+Table+Definition`

---

### 12. Lake Table Configuration (from table.yaml)

- **Storage format:** Parquet
- **Table type:** PARTITIONED
- **Partition key:** `partition_bill_mst_year_month` (string)
- **SLA:** `cron(0 14 * * ? *)` = delivery by 7:00 AM MST daily; `legacyLookBackEnabled: true`
- **Data tier:** 2
- **Upstream lineage (table.yaml):** 24 upstream table dependencies listed matching code (minor note: `callcenterreporting.rpt_c3_orders_snap` appears twice — harmless duplicate)
- **Consumer permissions:** 80+ consumers including: dri_data.prod, data_platform.prod, ckp_customer_insights.prod, martech_data.prod, websites_and_marketing.prod, gdml_ml.stage, mobile_ventures.prod, risk_services.prod, and many more

---

### 13. Conflicts / Discrepancies

| # | Description | Source A | Source B | Resolution |
|---|---|---|---|---|
| 1 | `callcenterreporting.rpt_c3_orders_snap` listed twice in `table.yaml` upstream lineage | `table.yaml` (duplicate entry) | PySpark code (single usage) | No functional conflict; duplicate in yaml only |
| 2 | `dim_customer_registration_acquisition` listed in policy as `ecomm_core_conformed` platform but read via direct Iceberg S3 in PySpark | `policies/analytic_bill_line_dag.yml` shows `platform: s3-ckpetlbatch` | PySpark reads via `read_iceberg_table()` from `gd-ckpetlbatch-prod-ecomm-core-conformed` bucket | Code is authoritative; S3 Iceberg read is correct |
| 3 | Policy yml lists `analytic_feature.customer_type_history` as input; code uses `customer_type_schema.customer_type_history` where `customer_type_schema` is `analytic_feature` (prod) or `analytic_feature_local` (test with `dim_product_hist_cln`) | Policy yml always shows `analytic_feature` | Code conditionally uses `analytic_feature_local` when `dim_product_hist_cln` selected | Code is authoritative; policy reflects prod-only |
| 4 | `table.yaml` description says "analytic data set for bill line" (terse); Alation and script docstring are richer | `table.yaml` | Alation / PySpark docstring | No conflict; yaml is brief by design |
| 5 | `pnl_usi_flag` / `pnl_gdii_flag` / `pnl_dri_flag` in lake DDL — `pnl_dri_flag` maps to `pnl_investor_flag` in PySpark (via alias `pnl_investor_flag AS pnl_dri_flag`) | DDL column name `pnl_dri_flag` | Code internal name `pnl_investor_flag` | Alias resolved correctly in final SELECT; no issue |
| 6 | Alation record shows `num_queries: 0` — no saved queries reference this table in Alation despite high consumer permissions | Alation API | — | Alation query tracking may not be exhaustive; no queries returned |

---

### 14. Column Schema (Lake DDL — authoritative)

Full 202-line DDL in `repos/lake/catalog/config/prod/us-west-2/analytic/ads-bill-line/table.ddl`.  
Schema also defined in `src/pyspark/ddl/schema_ads_bill_line.py` (PySpark StructType).

Selected key columns (abbreviated — full DDL is authoritative):

| Column | Type | Description |
|---|---|---|
| `bill_id` | string | PK. Order/receipt ID |
| `bill_line_num` | int | PK. Line item number on receipt (0 = header-level) |
| `bill_modified_mst_date` | date | MST date of order creation/last modification |
| `bill_modified_mst_ts` | timestamp | MST timestamp of order creation/last modification |
| `bill_country_code` | string | ISO country code from payment instrument |
| `bill_domestic_international_name` | string | 'Domestic' (US) or 'International' |
| `bill_report_region_1/2/3_name` | string | Geo reporting hierarchy from dim_geography |
| `merged_shopper_id` | string | Current post-merge shopper ID |
| `original_shopper_id` | string | Shopper ID at original bill creation |
| `customer_type_name` | string | Customer type at bill time (e.g. US Independent, Partner, Investor) |
| `pf_id` | int | Product family ID (SKU) |
| `product_pnl_group_name` | string | PnL level 1 |
| `product_pnl_category_name` | string | PnL level 2 |
| `product_pnl_line_name` | string | PnL level 3 |
| `product_pnl_subline_name` | string | PnL level 4 |
| `product_pnl_new_renewal_name` | string | New or Renewal designation (adjusted for free trial conversions) |
| `receipt_price_usd_amt` | decimal(18,2) | Amt paid (USD) after discounts |
| `gcr_usd_amt` | decimal(18,2) | Gross Cash Receipts in USD |
| `gcr_constant_currency_amt` | decimal(18,2) | GCR at constant FX rate |
| `fair_market_value_usd_amt` | decimal(18,2) | Fair market value for revenue recognition |
| `refund_flag` | boolean | True if refund transaction |
| `chargeback_flag` | boolean | True if chargeback transaction |
| `new_acquisition_flag` | boolean | True if first paid purchase by customer |
| `bill_fraud_flag` | boolean | True if flagged fraudulent |
| `pnl_usi_flag` | boolean | US Independent PnL segment |
| `pnl_gdii_flag` | boolean | International Independent PnL segment |
| `pnl_partner_flag` | boolean | Partner PnL segment |
| `pnl_dri_flag` | boolean | DRI/Investor PnL segment |
| `pnl_commerce_flag` | boolean | Commerce PnL segment |
| `private_label_id` | int | PLID for reseller/white-label partner |
| `bill_isc_source_code` | string | ISC marketing attribution code |
| `bill_isc_channel_name` | string | Marketing channel |
| `trxn_currency_code` | string | ISO 4217 transaction currency |
| `partition_bill_mst_year_month` | string | Partition key (YYYY-MM format) |
| `etl_build_mst_ts` | timestamp | ETL build time (MST) |
| `source_process_name` | string | `'ads_bill_line.py (full)'` |

*Full column list: 202 columns per DDL (bill-level: ~60, line-level: ~60, shopper: ~25, financial: ~50, flags: ~25, metadata: ~5)*

---

**Summary:** All facts above are sourced from: PySpark script (authoritative), DAG (authoritative for schedule/deps), sibling DDL/policy/DQ files (corroborating), lake repo DDL+yaml (corroborating), and Alation (corroborating). No Confluence pages were provided. The table is a full-refresh analytic layer over eComm billing data, partitioned by year-month, running daily at 3:30 AM UTC in prod with a 7 AM MST delivery SLA.


**The agent's final response to the user was:**
All research complete. Here is a summary of what was gathered and appended to `gather.md`:

---

## Research Summary: `analytic.ads_bill_line`

### Sources consulted
- **PySpark script** (`ads_bill_line.py`, `main` branch) — primary source of truth
- **DAG** (`analytic_bill_line_dag.py`) — authoritative for schedule/dependencies
- **Config** (`conf/config_ads_bill_line.py`) — source table→database mapping
- **Schema DDL** (`ddl/schema_ads_bill_line.py`) — PySpark StructType with column comments
- **Policy** (`policies/analytic_bill_line_dag.yml`) — pipeline lineage manifest
- **DQ constraints** (`data_quality/constraints/ads_bill_line.json`) — PK constraint
- **Lake DDL** (`repos/lake/.../analytic/ads-bill-line/table.ddl`, `table.yaml`) — 202-column Hive DDL + config
- **Alation** (table ID 6242622, `AwsDataCatalog.analytic.ads_bill_line`) — enriched description fetched

### Key facts established
- **Grain:** `(bill_id, bill_line_num)` — one row per line item per order/receipt
- **Schedule:** `30 3 * * *` UTC daily (prod only); SLA 7:00 AM MST; full overwrite
- **Primary output:** `analytic.ads_bill_line`, Parquet, partitioned by `partition_bill_mst_year_month`
- **28 source tables** identified with exact join keys documented
- **12 join chains** fully extracted with join keys and join types
- **10+ aggregation/window patterns** documented
- **5 discrepancies** noted between code and secondary sources (all minor)
- **Alation:** No saved queries found (num_queries: 0); rich description confirms business context