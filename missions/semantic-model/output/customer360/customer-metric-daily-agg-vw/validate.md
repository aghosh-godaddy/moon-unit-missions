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

## Stage: Validate — customer360 / customer-metric-daily-agg-vw

**Date:** 2026-06-05
**Semantic model name:** `customer360_customer_metric_daily_agg`
**OSI Spec:** v0.2.0.dev0

---

### Validation Results

| Check | Result |
|---|---|
| Structural validation | **PASS** |
| Reference validation | **PASS** |
| Accuracy validation | **PASS** |
| Provenance validation | **PASS** |

---

### Step 2: Structural Validation — Detail

| Rule | Result | Notes |
|---|---|---|
| Root `version: "0.2.0.dev0"` | PASS | Line 1 of YAML |
| Root `semantic_model` array | PASS | Line 3 of YAML |
| Model has `name` | PASS | `customer360_customer_metric_daily_agg` |
| Model has `datasets` (min 1) | PASS | 1 dataset present |
| Dataset has `name` | PASS | `customer_metric_daily_agg` |
| Dataset has `source` | PASS | `customer360.customer_metric_daily_agg_vw` |
| All 31 fields have `name` + `expression.dialects[ANSI_SQL]` | PASS | Verified all fields |
| All 11 metrics have `name` + `expression.dialects[ANSI_SQL]` | PASS | All use `SUM(...)` |
| Field expressions are scalar (no SUM/COUNT/AVG/MIN/MAX) | PASS | All expressions are bare column references |
| Metric expressions contain aggregates | PASS | All 11 metrics use `SUM(customer_metric_daily_agg.<col>)` |
| Field names unique within dataset | PASS | 31 unique names |
| Metric names unique within model | PASS | 11 unique names |
| Relationships present | N/A | No relationships defined; correct per analyze.md (no FK joins between distinct lake tables) |
| `custom_extensions.data` is valid JSON string | PASS | JSON parsed successfully |
| `vendor_name` value | **FIXED** | Was `GoDaddy`; corrected to `GODADDY` per OSI spec convention |

---

### Step 3: Reference Validation — Detail

| Rule | Result | Notes |
|---|---|---|
| Dataset source is a lake table | PASS | `customer360.customer_metric_daily_agg_vw` confirmed in lake catalog at `dlms-api/us-west-2/customer360/customer-metric-daily-agg-vw/` |
| No intermediate table used as `source` | PASS | `customer_core_conformed.customer_metric_daily_agg` and `customer_core_conformed.customer_life_cycle` are NOT dataset sources |
| All 19 composite PK columns exist as dataset fields | PASS | All 19 PK members verified present in fields list |
| Relationship columns exist in referenced datasets | N/A | No relationships |

---

### Step 4: Accuracy Validation — Detail

| Check | Result |
|---|---|
| All 31 fields traceable to lake DDL (`table.ddl`) or PySpark | PASS |
| All 11 metrics traceable to PySpark aggregations | PASS |
| No do_not_claim item appears as dataset source | PASS |
| No do_not_claim item appears in metric expressions | PASS |
| `data_source_enum` absent from fields (do_not_claim) | PASS |
| `active_paid_subscription_list` absent from fields/metrics (do_not_claim) | PASS |
| `ttm_all_bill_list` absent from fields/metrics (do_not_claim) | PASS |
| `customer_fraud_mst_date` absent from fields/metrics (do_not_claim) | PASS |
| `customer_state_enum` absent from fields/metrics (do_not_claim) | PASS |
| Redshift table not used as dataset source (do_not_claim) | PASS |
| LEFT ANTI JOIN self-join not modeled as relationship (do_not_claim) | PASS |
| Descriptions match source material (DDL comments, PySpark logic) | PASS |

---

### Step 5: Completeness Check — Detail

| Check | Result | Notes |
|---|---|---|
| Target table present as dataset | PASS | `customer360.customer_metric_daily_agg_vw` |
| `customer360.customer_life_cycle_vw` absent (excluded dimension) | PASS | Excluded per analyze.md: no FK from fact; 18-column composite key with array cast/sort_array required — not a standard FK join. Documented in `custom_extensions.data.excluded_dimensions`. |
| Time dimensions have `is_time: true` | PASS | `partition_eval_mst_date`, `customer_acquisition_mst_month`, `etl_build_mst_ts` |
| At least one metric | PASS | 11 metrics present |

---

### Step 5b: Provenance Validation — Detail

| Check | Result | Notes |
|---|---|---|
| `PROVENANCE.json` exists and parses | PASS | 2 intermediate_tables, 0 transitive_sources, 0 materialized_direct_reads, 3 array_fields, 10 do_not_claim items |
| `custom_extensions.data` is valid JSON | PASS | |
| `pipeline_lineage` object present (required because PROVENANCE has intermediate_tables) | PASS | |
| `pipeline_lineage.intermediate_tables` count matches PROVENANCE (2) | PASS | `customer_core_conformed.customer_metric_daily_agg` (hive_write_target) and `customer_core_conformed.customer_life_cycle` (hive_read_source) |
| `pipeline_lineage.transitive_sources` present and empty | PASS | No transitive sources |
| `pipeline_lineage.materialized_direct_reads` present and empty | PASS | No materialized direct reads |
| `transitive_sources[].materialized_in_fields` fully matched | PASS | Empty — nothing to validate |
| `materialized_direct_reads[].materialized_in_fields` fully matched | PASS | Empty — nothing to validate |
| No do_not_claim item as dataset `source` | PASS | |
| No do_not_claim item as relationship endpoint | PASS | No relationships |
| No do_not_claim item in metric expressions | PASS | |
| Array fields (`product_ownership_category_list`, `product_ownership_line_list`, `brand_name_list`) NOT in metric expressions | PASS | Metrics use `product_category_qty` (scalar proxy) not `product_ownership_category_list` |
| `ai_context.instructions` contains grain (GRAIN: section) | PASS | |
| `ai_context.instructions` contains partition filter (REQUIRED PARTITION FILTER) | PASS | |
| `ai_context.instructions` contains PK caveats (PRIMARY KEY CAVEATS) | PASS | |
| `query_guards.grain` present | PASS | |
| `query_guards.partition_filter` present | PASS | |
| `query_guards.primary_key_notes` present | PASS | |

**Provenance fields enriched:** None required. `transitive_sources` and `materialized_direct_reads` are both empty in PROVENANCE.json, so no fact field descriptions needed enrichment with upstream table references.

---

### Issues Found and Fixes Applied

| # | Issue | Severity | Fix Applied |
|---|---|---|---|
| 1 | `vendor_name: GoDaddy` — incorrect casing; OSI spec convention requires uppercase `GODADDY` | WARN | Fixed in-place: `GoDaddy` → `GODADDY` |

### Items Removed Due to Lack of Evidence

None. All fields, metrics, and model metadata have documented evidence from lake DDL, PySpark source code, or analyze.md. No content was fabricated.

---

### Final Counts

| Item | Count |
|---|---|
| Semantic models | 1 |
| Datasets | 1 |
| Fields (in `customer_metric_daily_agg`) | 31 |
| Relationships | 0 |
| Metrics | 11 |
| custom_extensions vendors | 1 (GODADDY) |

---

*Validation completed by: Validate agent — 2026-06-05*

**The agent's final response to the user was:**
All validation steps are complete. Here is a summary of what was done:

---

## Validation Summary — `customer360_customer_metric_daily_agg`

**Overall result: PASS** (one minor fix applied)

### Validation results

| Check | Result |
|---|---|
| Structural (OSI spec v0.2.0.dev0) | **PASS** |
| Reference (sources, PKs, relationships) | **PASS** |
| Accuracy (evidence-backed content) | **PASS** |
| Provenance (PROVENANCE.json compliance) | **PASS** |

### Fix applied

- `vendor_name: GoDaddy` → `GODADDY` — corrected to uppercase per OSI spec convention.

### Key findings

- **31 fields** and **11 metrics** all have valid `expression.dialects[ANSI_SQL]` entries; no aggregates in field expressions; all metrics use `SUM(...)`.
- All 10 `do_not_claim` items (intermediate tables, excluded upstream tables, `data_source_enum`, array fields from source, Redshift copy, ETL self-join) are absent from dataset sources, relationship endpoints, and metric expressions.
- `custom_extensions.data` is valid JSON with `pipeline_lineage` (2 intermediate tables), `query_guards` (grain, partition filter, PK caveats), and `excluded_dimensions` all correctly populated.
- `ai_context.instructions` contains all three required provenance guards: grain, partition filter requirement, and PK caveats.
- No content was removed — every field, metric, and description has traceable evidence in lake DDL or PySpark source.
- No items added — provenance enrichment not needed (transitive_sources and materialized_direct_reads are both empty).

**Final counts:** 1 dataset · 31 fields · 0 relationships · 11 metrics