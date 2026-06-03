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

## Step 6: Append report to validate.md
Append:
- Semantic model name
- PASS/FAIL for structural, reference, and accuracy validation
- Issues found and how they were fixed
- Items removed due to lack of evidence
- Final counts: datasets, fields, relationships, metrics

**The agent summarized its work in this way:**

---

## Validation Report — customer360_customer_life_cycle_analytics
**Validated:** 2026-06-03
**Validator:** OSI strict validation agent (v0.2.0.dev0)

---

### Semantic Model Name
`customer360_customer_life_cycle_analytics`

---

### Step 2: Structural Validation — PASS

All OSI spec v0.2.0.dev0 structural rules satisfied:

| Check | Result | Notes |
|---|---|---|
| Root `version: "0.2.0.dev0"` | ✅ PASS | Line 1 |
| Root `semantic_model` array | ✅ PASS | Line 3 |
| Model has `name` | ✅ PASS | `customer360_customer_life_cycle_analytics` |
| Model has `datasets` (min 1) | ✅ PASS | 6 datasets |
| Each dataset has `name` and `source` | ✅ PASS | All 6 datasets |
| Each field has `name` and `expression.dialects` | ✅ PASS | All 134 fields; all have ANSI_SQL dialect |
| Each metric has `name` and `expression.dialects` | ✅ PASS | All 5 metrics |
| Each relationship has `name`, `from`, `to`, `from_columns`, `to_columns` | ✅ PASS | All 5 relationships |
| `len(from_columns) == len(to_columns)` | ✅ PASS | All relationships are 1:1 column mappings |
| Field expressions are scalar (no aggregates) | ✅ PASS | All field expressions are bare column references |
| Metric expressions contain aggregates | ✅ PASS | SUM, COUNT(DISTINCT), AVG present in all 5 metrics |
| All names unique within scope | ✅ PASS | Datasets, per-dataset fields, metrics, relationships all unique |
| `custom_extensions.data` is valid JSON string | ✅ PASS | Single JSON string with 4 keys |

---

### Step 3: Reference Validation — PASS

| Check | Result | Notes |
|---|---|---|
| Relationship `from` references existing dataset | ✅ PASS | All 5 use `customer_life_cycle_vw` (exists) |
| Relationship `to` references existing dataset | ✅ PASS | `shopper_acquisition`, `dim_reseller`, `dim_country_vw`, `dim_customer_history_vw`, `dim_subscription_history` all exist |
| `from_columns` exist as fields in `from` dataset | ✅ PASS | `shopper_id`, `reseller_type_id`, `customer_acquisition_country_code`, `customer_id`, `active_paid_subscription_list` all in `customer_life_cycle_vw` |
| `to_columns` exist as fields in `to` dataset | ✅ PASS | `shopper_id` (shopper_acquisition), `reseller_type_id` (dim_reseller), `country_code` (dim_country_vw), `customer_id` (dim_customer_history_vw), `subscription_id` (dim_subscription_history) all exist |
| Dataset sources are lake tables only | ✅ PASS | All 6 confirmed in `repos/lake/catalog/config/prod/` |
| Primary keys exist as fields in datasets | ✅ PASS | All composite and scalar PKs verified |

**Source lake table paths verified:**
| Dataset | Source | Lake Registry Path |
|---|---|---|
| `customer_life_cycle_vw` | `customer360.customer_life_cycle_vw` | `dlms-api/us-west-2/customer360/customer-life-cycle-vw/` |
| `shopper_acquisition` | `analytic_feature.shopper_acquisition` | `us-west-2/analytic-feature/shopper-acquisition/` |
| `dim_reseller` | `dp_enterprise.dim_reseller` | `us-west-2/dp-enterprise/dim-reseller/` |
| `dim_country_vw` | `finance360.dim_country_vw` | `dlms-api/us-west-2/finance360/dim-country-vw/` |
| `dim_customer_history_vw` | `customer360.dim_customer_history_vw` | `dlms-api/us-west-2/customer360/dim-customer-history-vw/` |
| `dim_subscription_history` | `enterprise.dim_subscription_history` | `us-west-2/enterprise/dim-subscription-history/` |

---

### Step 4: Accuracy Validation — PASS (1 issue found and fixed)

**Issue found and fixed:**

| # | Location | Issue | Fix | Evidence |
|---|---|---|---|---|
| 1 | `ai_context.instructions` (model level) | Said "customer_state_enum enumerates **five** states: active, churned, reactivated, merged, intraday" — missing state `new` | Changed to "six states: active, new, churned, reactivated, merged, intraday" | gather.md DDL: "Enum: intraday → merged → churned → reactivated → **new** → active"; field description at YAML line 357 also includes 'new' |

**Accuracy checks passed:**
- All 35 `customer_life_cycle_vw` fields match `repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/customer-life-cycle-vw/table.ddl` ✅
- All 17 `shopper_acquisition` fields match `repos/lake/catalog/config/prod/us-west-2/analytic-feature/shopper-acquisition/table.ddl` ✅
- All 10 `dim_reseller` fields match `repos/lake/catalog/config/prod/us-west-2/dp-enterprise/dim-reseller/table.ddl` ✅
- All 20 `dim_country_vw` fields match `repos/lake/catalog/config/prod/dlms-api/us-west-2/finance360/dim-country-vw/table.ddl` ✅
- All 31 `dim_customer_history_vw` fields match `repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/dim-customer-history-vw/table.ddl` ✅
- All 21 `dim_subscription_history` fields match `repos/lake/catalog/config/prod/us-west-2/enterprise/dim-subscription-history/table.ddl` ✅
- 5 metrics: expressions and descriptions backed by PySpark aggregations in gather.md ✅
- All 5 relationships: column mappings consistent with PySpark join conditions and lake DDL FK annotations ✅
- Descriptions sourced from: lake DDL column comments, Alation description, Confluence Customer Lifecycle design doc ✅
- No invented columns, metrics, or relationships detected ✅

**No items removed** — all elements in the model have verified evidence.

**Internal staging tables correctly excluded:**
- `customer_core_conformed.customer_life_cycle` — internal ETL target, not a lake table ✅
- `customer_core_conformed.customer_ttm_payment_driver` — internal driver ✅
- `customer_core_conformed.customer_active_subscription_detail_driver` — internal driver ✅
- `customer_core_conformed.active_customer_stg` — internal driver ✅

**Relationship note (reseller):** `customer_life_cycle_to_dim_reseller` joins on `reseller_type_id → reseller_type_id`. The ETL internally joins on `private_label_id`, but `private_label_id` is not an output column in `customer_life_cycle_vw`. The lake DDL FK annotation on `reseller_type_id` is authoritative for consumer-facing joins; `reseller_type_id` exists as a field in both datasets. The ai_context note correctly flags this as a non-unique lookup key (dim_reseller PK is `private_label_id`).

---

### Step 5: Completeness Check — PASS

| Check | Result | Notes |
|---|---|---|
| Target table present as dataset | ✅ PASS | `customer_life_cycle_vw` is the primary fact dataset |
| Key dimension tables included | ✅ PASS | 5 dimensions: shopper_acquisition, dim_reseller, dim_country_vw, dim_customer_history_vw, dim_subscription_history |
| Omitted dimensions justified | ✅ PASS | 8 tables omitted per analyze.md "Do Not Claim" list — all have attributes already denormalized into fact |
| Time dimensions have `is_time: true` | ✅ PASS | All date/timestamp/partition columns flagged; see breakdown below |
| At least one metric | ✅ PASS | 5 metrics present |
| Partition column present and flagged | ✅ PASS | `partition_eval_mst_date` has `is_time: true` |
| custom_extensions include operational metadata | ✅ PASS | `lake_table_path`, `pyspark_path`, `dag_name`, `refresh_cadence` |

**Time dimension coverage by dataset:**
| Dataset | `is_time: true` fields |
|---|---|
| customer_life_cycle_vw | customer_acquisition_mst_date, customer_acquisition_mst_month, customer_churn_mst_date, customer_reactivate_mst_date, customer_merge_mst_date, customer_fraud_mst_date, etl_build_mst_ts, partition_eval_mst_date (8) |
| shopper_acquisition | evaluation_mst_date, acq_bill_mst_date, acq_bill_mst_ts, load_date (4) |
| dim_country_vw | etl_insert_utc_ts, etl_update_utc_ts (2) |
| dim_customer_history_vw | created_mst_ts, updated_mst_ts, closed_mst_ts, effective_start_mst_ts, effective_end_mst_ts, etl_build_mst_ts, etl_insert_mst_ts, etl_update_mst_ts (8) |
| dim_subscription_history | subscription_bill_due_mst_ts, subscription_bill_due_mst_date, subscription_paid_through_mst_date, subscription_cancel_mst_date, subscription_create_mst_ts, subscription_create_mst_date (6) |

---

### Final Counts

| Category | Count |
|---|---|
| Datasets | 6 (1 fact + 5 dimensions) |
| Fields total | 134 (35 + 17 + 10 + 20 + 31 + 21) |
| Relationships | 5 |
| Metrics | 5 |
| custom_extensions | 1 |
| Structural issues fixed | 0 |
| Accuracy issues fixed | 1 (customer_state_enum state count: five → six, added 'new') |
| Items removed (no evidence) | 0 |

---

### Overall Result: PASS

`SEMANTIC_MODEL.yaml` is structurally valid per OSI spec v0.2.0.dev0, internally consistent, and accurate against the authoritative PySpark source, lake DDLs, and supporting documentation. One accuracy issue (missing 'new' state in model-level ai_context instructions) was fixed in-place.

**The agent's final response to the user was:**
Validation complete. Here is a summary of what was done:

---

## Validation Summary — `customer360_customer_life_cycle_analytics`

### Results: **PASS** (all three validation categories)

**Structural — PASS**
All 12 OSI spec v0.2.0.dev0 structural rules satisfied: correct root shape, 6 datasets with `name`/`source`, 134 fields with `name`/`expression.dialects`, 5 metrics with aggregates, 5 relationships with matching `from_columns`/`to_columns` lengths, scalar-only field expressions, unique names throughout, and valid JSON in `custom_extensions.data`.

**Reference — PASS**
All relationship `from`/`to` names resolve to existing dataset names. All join columns exist as fields in their respective datasets. All 6 dataset `source` values are confirmed lake tables (paths verified in `repos/lake/`). All `primary_key` columns exist as fields.

**Accuracy — PASS (1 issue fixed in-place)**
- **Fixed:** `ai_context.instructions` said `customer_state_enum` has "five states" but gather.md DDL and the field's own description document six states: `active`, `new`, `churned`, `reactivated`, `merged`, `intraday`. Changed to "six states" and added `new`.
- No items removed — all 6 datasets, 134 fields, 5 relationships, and 5 metrics have verified evidence in PySpark source, lake DDLs, Confluence, or Alation.

**Completeness — PASS**
Target table present; 5 key dimensions included; 8 omitted tables justified; all date/timestamp fields carry `is_time: true`; 5 metrics present; partition column flagged.

**Final counts:** 6 datasets · 134 fields · 5 relationships · 5 metrics