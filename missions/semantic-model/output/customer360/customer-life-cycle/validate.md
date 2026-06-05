**Stage name:** validate
**The coding agent was given these instructions:** You are a strict validation agent for an OSI semantic model. Your job is to ensure
`SEMANTIC_MODEL.yaml` is:
1) structurally valid per OSI spec v0.2.0.dev0
2) accurate (no fabricated content)
3) internally consistent (relationships, names, column references)

Read `docs/osi-spec-reference.md` for the validation checklist.

## Step 1: Read all artifacts
Read:
- `INPUT.md`
- `gather.md`
- `analyze.md`
- `RESOLVED_TARGET.json`
- `PROVENANCE.json`
- `SEMANTIC_MODEL.yaml`

## Step 2: Structural validation
Verify against OSI spec:
- Root has `version: "0.2.0.dev0"` and `semantic_model` array
- Each model has `name` and `datasets` (min 1)
- Each dataset has `name` and `source`
- Each field has `name` and `expression.dialects` (min 1, dialect ANSI_SQL)
- Each metric has `name` and `expression.dialects` (min 1)
- Each relationship has `name`, `from`, `to`, `from_columns`, `to_columns`
- `len(from_columns) == len(to_columns)` for each relationship
- Field expressions contain no aggregates (SUM/COUNT/AVG/MIN/MAX)
- Metric expressions contain aggregates
- All names unique within scope
- `custom_extensions.data` values are valid JSON strings

Fix any structural issues in-place in `SEMANTIC_MODEL.yaml`.

## Step 3: Reference validation
- Relationship `from`/`to` must reference existing dataset names
- Relationship columns should exist as fields in the respective datasets
- Dataset sources must be lake tables (not intermediate/staging tables)
- Primary keys should exist as fields in the dataset

## Step 4: Accuracy validation
For each dataset, field, relationship, and metric:
- Identify evidence source (PySpark line, DDL, analyze.md)
- Remove or fix any entry without evidence
- Ensure descriptions match source material (not invented)

## Step 5: Completeness check
- Target table must be present as a dataset
- Key dimension tables from analyze.md should be included (or noted as omitted)
- Time dimensions should have `is_time: true`
- At least one metric if analyze.md identified any

## Step 5b: Provenance validation
Using `PROVENANCE.json` and `docs/osi-spec-reference.md`:
- `PROVENANCE.json` exists; `custom_extensions.data` parses as valid JSON
- When `PROVENANCE.json` lists intermediate or transitive tables,
  `custom_extensions.data` must contain a `pipeline_lineage` object
- Every field in `transitive_sources[].materialized_in_fields` and
  `materialized_direct_reads[].materialized_in_fields` has a matching fact field
  whose `description` mentions the upstream table or pipeline (fix in-place if missing)
- No item from `do_not_claim` appears as a dataset `source`, relationship endpoint,
  or metric expression
- Fields listed in `array_fields` are not referenced in metric expressions
- `ai_context.instructions` includes grain, partition filter, and PK caveats from
  `query_guards`
Fix any missing provenance in-place in `SEMANTIC_MODEL.yaml`.

## Step 6: Append report to validate.md
Append:
- Semantic model name
- PASS/FAIL for structural, reference, accuracy, and **provenance** validation
- Provenance fields enriched (list)
- Issues found and how they were fixed
- Items removed due to lack of evidence
- Final counts: datasets, fields, relationships, metrics

**The agent summarized its work in this way:**

---

# Validation Report — customer360_customer_life_cycle_analytics

**Stage:** validate
**Date:** 2026-06-05
**Validator:** OSI strict validation agent (v0.2.0.dev0)
**Artifacts read:** INPUT.md, gather.md, analyze.md, RESOLVED_TARGET.json, PROVENANCE.json, SEMANTIC_MODEL.yaml, docs/osi-spec-reference.md

---

## Validation Results

| Check | Result |
|---|---|
| Structural | **PASS** |
| Reference | **PASS** |
| Accuracy | **PASS** |
| Provenance | **PASS** |

---

## Step 2: Structural Validation Detail

| Rule | Result | Notes |
|---|---|---|
| Root has `version: "0.2.0.dev0"` | ✅ PASS | Line 1 |
| Root has `semantic_model` array | ✅ PASS | Line 3 |
| Each model has `name` and `datasets` (min 1) | ✅ PASS | name=`customer360_customer_life_cycle_analytics`; 5 datasets |
| Each dataset has `name` and `source` | ✅ PASS | All 5 datasets valid |
| Each field has `name` and `expression.dialects` (ANSI_SQL) | ✅ PASS | All 100 fields verified; all use `dialect: ANSI_SQL` |
| Each metric has `name` and `expression.dialects` | ✅ PASS | 3 metrics, all have ANSI_SQL dialect |
| Each relationship has `name`, `from`, `to`, `from_columns`, `to_columns` | ✅ PASS | 4 relationships, all have required fields |
| `len(from_columns) == len(to_columns)` | ✅ PASS | All 4 relationships: 1 from_column = 1 to_column |
| Field expressions are scalar (no SUM/COUNT/AVG/MIN/MAX) | ✅ PASS | All 100 field expressions are simple column references |
| Metric expressions contain aggregates | ✅ PASS | SUM, COUNT(DISTINCT …), AVG all present |
| All names unique within scope | ✅ PASS | No duplicate dataset, field, metric, or relationship names found |
| `custom_extensions.data` is a valid JSON string | ✅ PASS | Single GODADDY entry; data is a quoted JSON string containing all required keys |

---

## Step 3: Reference Validation Detail

| Rule | Result | Notes |
|---|---|---|
| Relationship `from`/`to` reference existing dataset names | ✅ PASS | All 4 relationships: from=`customer_life_cycle` exists; to= `shopper_acquisition`, `dim_country`, `dim_bill_line_purchase_attribution`, `dim_bill_fraud_history` all exist |
| Relationship columns exist in respective datasets | ✅ PASS | `shopper_id` in both, `customer_acquisition_country_code`/`country_code`, `customer_acquisition_bill_id`/`bill_id` all confirmed as named fields |
| Dataset sources are lake tables only | ✅ PASS | All 5 sources confirmed in analyze.md lineage table as lake catalog entries (`us-west-2/` or `dlms-api/us-west-2/`): `customer360.customer_life_cycle_vw`, `analytic_feature.shopper_acquisition`, `finance360.dim_country_vw`, `ecomm_mart.dim_bill_line_purchase_attribution`, `finance360.dim_bill_fraud_history_vw` |
| Primary keys exist as fields in datasets | ✅ PASS | `customer_life_cycle`: [shopper_id ✅, partition_eval_mst_date ✅]; `shopper_acquisition`: [shopper_id ✅]; `dim_country`: [country_code ✅]; `dim_bill_line_purchase_attribution`: [bill_id ✅, bill_line_num ✅]; `dim_bill_fraud_history`: [bill_id ✅, effective_start_mst_ts ✅] |
| No `do_not_claim` item appears as dataset source | ✅ PASS | All 14 do_not_claim items checked; none appear as source, relationship endpoint, or metric expression |

**Fan-out warning (flagged and fixed):** Relationships `life_cycle_to_dim_bill_line_purchase_attribution` and `life_cycle_to_dim_bill_fraud_history` join on `bill_id` which is not a unique key in the respective dimension tables (composite PKs: [bill_id, bill_line_num] and [bill_id, effective_start_mst_ts]). These relationships are OSI-valid per spec (required fields all present, column references correct), but required join guards documented. **Fixed in-place:** added `ai_context` to each relationship with explicit fan-out guard instructions.

---

## Step 4: Accuracy Validation Detail

All datasets, fields, relationships, and metrics traced to verifiable evidence:

| Dataset | Evidence |
|---|---|
| `customer_life_cycle` (customer360.customer_life_cycle_vw) | DAG SuccessNotificationOperator, DQ constraint isPrimaryKey, lake catalog `dlms-api/us-west-2/customer360/customer-life-cycle-vw/`, Alation ID 7038345, RESOLVED_TARGET.json |
| `shopper_acquisition` (analytic_feature.shopper_acquisition) | PySpark join #1; lake catalog `us-west-2/analytic-feature/shopper-acquisition/` confirmed in analyze.md Step 3 |
| `dim_country` (finance360.dim_country_vw) | PySpark join #12; lake catalog `dlms-api/us-west-2/finance360/dim-country-vw/` confirmed |
| `dim_bill_line_purchase_attribution` (ecomm_mart.dim_bill_line_purchase_attribution) | PySpark join #9; lake catalog `us-west-2/ecomm-mart/dim-bill-line-purchase-attribution/` confirmed |
| `dim_bill_fraud_history` (finance360.dim_bill_fraud_history_vw) | PySpark join #10; lake catalog `dlms-api/us-west-2/finance360/dim-bill-fraud-history-vw/` confirmed |

**Metrics evidence:**
- `total_ttm_gcr_usd_amt`: SUM(ttm_gcr_usd_amt) — scalar field pre-computed from customer_ttm_payment_driver; confirmed in analyze.md Step 7 and PySpark ETL
- `active_customer_count`: COUNT(DISTINCT CASE WHEN active_status_flag = true THEN shopper_id END) — derived from active_status_flag field confirmed in DDL and gather.md
- `avg_product_pnl_category_qty`: AVG(product_pnl_category_qty) — scalar proxy confirmed in analyze.md and PROVENANCE.json array_fields

**Items removed due to lack of evidence:** None. All 100 fields, 4 relationships, and 3 metrics are backed by PySpark code, DDL, or lake catalog evidence.

---

## Step 5: Completeness Check

| Check | Result |
|---|---|
| Target table `customer360.customer_life_cycle_vw` present as dataset | ✅ YES — `customer_life_cycle` |
| Key dimension tables from analyze.md included | ✅ YES — all 4 classified OSI dimensions included |
| Omitted dimensions noted with justification | ✅ YES — all 10 do_not_claim omissions explained in descriptions and ai_context |
| Time dimensions have `is_time: true` | ✅ YES — 17 time fields marked across all datasets: partition_eval_mst_date, customer_acquisition_mst_date, customer_churn_mst_date, customer_reactivate_mst_date, customer_merge_mst_date, customer_fraud_mst_date, etl_build_mst_ts (fact); evaluation_mst_date, acq_bill_mst_date, acq_bill_mst_ts, load_date (shopper_acquisition); etl_insert_utc_ts, etl_update_utc_ts (dim_country, dim_bill_fraud_history); bill_modified_mst_ts, bill_modified_mst_date, etl_build_mst_ts (dim_bill_line_purchase_attribution); fraud_flag_mst_ts, fraud_flag_mst_date, effective_start_mst_ts, effective_end_mst_ts (dim_bill_fraud_history) |
| At least one metric | ✅ YES — 3 metrics |

---

## Step 5b: Provenance Validation Detail

| Check | Result | Notes |
|---|---|---|
| PROVENANCE.json exists | ✅ PASS | Present at workspace root |
| `custom_extensions.data` parses as valid JSON | ✅ PASS | GODADDY vendor JSON string validated |
| `pipeline_lineage` object present (intermediate/transitive tables listed) | ✅ PASS | `pipeline_lineage` key contains `intermediate_tables`, `transitive_sources`, `materialized_direct_reads`, `legacy_sources` |
| `transitive_sources[].materialized_in_fields` all have matching fact fields with upstream table in description | ✅ PASS | `enterprise.dim_subscription_history` → `active_paid_subscription_list`, `product_pnl_category_list`, `product_pnl_line_list`, `product_pnl_category_qty` — all 4 fields present; all descriptions reference `enterprise.dim_subscription_history` |
| `materialized_direct_reads[].materialized_in_fields` all have matching fact fields with upstream table in description | ✅ PASS | All 8 fields across 5 direct-read tables verified (see table below) |
| No `do_not_claim` item as dataset source | ✅ PASS | Verified across all 14 do_not_claim entries |
| No `do_not_claim` item as relationship endpoint | ✅ PASS | No excluded table appears as `from` or `to` in any relationship |
| No `do_not_claim` item in metric expressions | ✅ PASS | No array field appears in SUM/COUNT/AVG expressions |
| `array_fields` not in metric expressions | ✅ PASS | active_paid_subscription_list, product_pnl_category_list, product_pnl_line_list, ttm_all_bill_list, brand_name_list all absent from metric expressions |
| `ai_context.instructions` includes grain | ✅ PASS | "This model tracks daily customer lifecycle states" + "one row per shopper per evaluation date" |
| `ai_context.instructions` includes partition filter | ✅ PASS | "ALWAYS filter by partition_eval_mst_date for point-in-time queries" |
| `ai_context.instructions` includes PK caveats | ✅ PASS | "The composite primary key is (shopper_id, partition_eval_mst_date); customer_id may be null for some historical records and is NOT unique alone." |

**Materialized direct-reads field verification:**

| Upstream Table | Fields | Description Mentions Upstream? |
|---|---|---|
| analytic_feature.customer_type_history | customer_type_name, customer_type_reason_desc | ✅ Both mention "analytic_feature.customer_type_history via SCD2 time-filtered join" |
| dp_enterprise.dim_reseller | reseller_type_id, reseller_type_name | ✅ Both mention "dp_enterprise.dim_reseller via customer360.dim_customer_history_vw.private_label_id join chain" |
| analytic_feature.shopper_merge | customer_merge_mst_date | ✅ Mentions "analytic_feature.shopper_merge via SCD2 date-range join" |
| ecomm_mart.bill_line_traffic_ext | customer_acquisition_channel_name | ✅ Mentions "ecomm_mart.bill_line_traffic_ext via customer360/customer-metrics PySpark join #6" |
| enterprise.dim_new_acquisition_shopper | customer_acquisition_mst_date, customer_acquisition_bill_id | ✅ Both mention "enterprise.dim_new_acquisition_shopper via acquisition derivation chain" |

**Provenance fields enriched (all pre-existing in generated model — no in-place fixes required for provenance):**
- active_paid_subscription_list → enterprise.dim_subscription_history ✅
- product_pnl_category_list → enterprise.dim_subscription_history ✅
- product_pnl_line_list → enterprise.dim_subscription_history ✅
- product_pnl_category_qty → enterprise.dim_subscription_history ✅
- customer_type_name → analytic_feature.customer_type_history ✅
- customer_type_reason_desc → analytic_feature.customer_type_history ✅
- reseller_type_id → dp_enterprise.dim_reseller ✅
- reseller_type_name → dp_enterprise.dim_reseller ✅
- customer_merge_mst_date → analytic_feature.shopper_merge ✅
- customer_acquisition_channel_name → ecomm_mart.bill_line_traffic_ext ✅
- customer_acquisition_mst_date → enterprise.dim_new_acquisition_shopper ✅
- customer_acquisition_bill_id → enterprise.dim_new_acquisition_shopper ✅

---

## Issues Found and Fixes Applied

| # | Issue | Severity | Fix Applied |
|---|---|---|---|
| 1 | `life_cycle_to_dim_bill_line_purchase_attribution`: `to_columns: [bill_id]` is not unique in `dim_bill_line_purchase_attribution` (composite PK = [bill_id, bill_line_num]); joining without dedup guard causes fan-out | WARNING | Added `ai_context` to relationship: "FAN-OUT GUARD REQUIRED: … Always apply ROW_NUMBER() OVER (PARTITION BY bill_id ORDER BY bill_line_num DESC) = 1 before joining to avoid multiplying fact rows." |
| 2 | `life_cycle_to_dim_bill_fraud_history`: `to_columns: [bill_id]` is not unique in `dim_bill_fraud_history` (SCD2; composite PK = [bill_id, effective_start_mst_ts]); joining without guard causes fan-out | WARNING | Added `ai_context` to relationship: "FAN-OUT GUARD REQUIRED: … Filter current_record_flag = true, or use SELECT DISTINCT bill_id, before joining to avoid multiplying fact rows." |

**Note:** Both issues were previously documented only at the model-level `ai_context.instructions`. The fix brings the warning directly to the relationship level. No structural defects required removal of entities.

---

## Items Removed Due to Lack of Evidence

None. All datasets, fields, relationships, and metrics are traceable to PySpark source code, DDL, DQ constraints, lake catalog entries, or analyze.md lineage tables.

---

## Final Counts

| Entity | Count |
|---|---|
| Semantic models | 1 |
| Datasets | 5 |
| Fields (customer_life_cycle) | 35 |
| Fields (shopper_acquisition) | 17 |
| Fields (dim_country) | 28 |
| Fields (dim_bill_line_purchase_attribution) | 9 |
| Fields (dim_bill_fraud_history) | 11 |
| **Total fields** | **100** |
| Relationships | 4 |
| Metrics | 3 |
| custom_extensions | 1 (GODADDY vendor) |


**The agent's final response to the user was:**
Validation complete. Here is a summary of what was done:

## Validation Summary — `customer360_customer_life_cycle_analytics`

**All four validation categories PASS:**

| Check | Result |
|---|---|
| Structural | **PASS** |
| Reference | **PASS** |
| Accuracy | **PASS** |
| Provenance | **PASS** |

### Two fixes applied to `SEMANTIC_MODEL.yaml`

Both were `WARNING`-level issues (not structural failures), both pre-documented at the model-level `ai_context.instructions` but missing from the relationship definitions themselves:

1. **`life_cycle_to_dim_bill_line_purchase_attribution`** — `to_columns: [bill_id]` is not unique in the dimension (composite PK `[bill_id, bill_line_num]`). Added `ai_context` requiring `ROW_NUMBER() OVER (PARTITION BY bill_id ORDER BY bill_line_num DESC) = 1` before joining.

2. **`life_cycle_to_dim_bill_fraud_history`** — `to_columns: [bill_id]` is not unique in the SCD2 dimension (composite PK `[bill_id, effective_start_mst_ts]`). Added `ai_context` requiring `current_record_flag = true` or `SELECT DISTINCT bill_id` before joining.

### No entities removed
All 100 fields, 5 datasets, 4 relationships, and 3 metrics are fully backed by PySpark source code, DDL, DQ constraints, or lake catalog evidence.

### Final counts
- Datasets: 5 | Fields: 100 | Relationships: 4 | Metrics: 3