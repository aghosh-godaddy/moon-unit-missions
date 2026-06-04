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

## Validation Report — analytic_ads_bill_line

**Validated:** 2026-06-04
**Model name:** `analytic_ads_bill_line`
**File:** `SEMANTIC_MODEL.yaml` (2,755 lines)

---

### Step 2: Structural Validation — PASS

| Check | Result | Notes |
|---|---|---|
| Root `version: "0.2.0.dev0"` | PASS | Exact string confirmed at line 1 |
| Root `semantic_model` array | PASS | One model entry |
| Model has `name` and `datasets` | PASS | name=`analytic_ads_bill_line`; 8 datasets |
| All datasets have `name` + `source` | PASS | All 8 datasets verified |
| All fields have `name` + `expression.dialects` (ANSI_SQL) | PASS | 339 fields total, each with `dialect: ANSI_SQL` |
| All metrics have `name` + `expression.dialects` | PASS | 10 metrics, each with `dialect: ANSI_SQL` |
| All relationships have required 5 keys | PASS | 7 relationships, all have `name/from/to/from_columns/to_columns` |
| `len(from_columns) == len(to_columns)` | PASS | All 7 verified; `bill_line_to_gcr_logic` has 7 columns on each side |
| No aggregates (SUM/COUNT/etc.) in field expressions | PASS | Searched lines 58-2592; no aggregates found |
| Metric expressions contain aggregates | PASS | All 10 use SUM() or COUNT() |
| All names unique within scope | PASS | No duplicate field, metric, or relationship names detected |
| `custom_extensions.data` is valid JSON string | PASS | Validated with node JSON.parse |
| File encoding: Unix line endings, no tabs | PASS | od -c confirms `\n` only |

---

### Step 3: Reference Validation — PASS

| Check | Result | Notes |
|---|---|---|
| Relationship `from`/`to` reference existing dataset names | PASS | All 7 relationships reference valid dataset names |
| `bill_line_to_bill` columns exist in both datasets | PASS | `bill_id` in `ads_bill_line` (line 59) and `dim_bill` (line 1519) |
| `bill_line_to_product` columns exist | PASS | `pf_id` in `ads_bill_line` (line 792) and `dim_product` (line 1611) |
| `bill_line_to_customer` columns exist | PASS | `original_customer_id` in `ads_bill_line` (line 1350); `customer_id` in `dim_customer` |
| `bill_line_to_reseller` columns exist | PASS | `private_label_id` in both datasets |
| `bill_line_to_gcr_logic` 7-column composite exists | PASS | All 7 `from_columns` verified in `ads_bill_line`; all 7 `to_columns` verified in `customer_type_gcr_logic` |
| `bill_line_to_free_entitlement` columns exist | PASS | `bill_id`+`bill_line_num` in fact; `paid_bill_id`+`paid_bill_line_num` in `free_entitlement` |
| `bill_line_to_c3_attribution` columns exist | PASS | `bill_id` in fact; `order_id` in `c3_rev_attribution` |
| All dataset sources are lake tables | PASS | All 8 confirmed in `repos/lake/catalog/config/prod/` (see below) |
| Primary keys exist as fields in their datasets | PASS | All PK fields verified present in respective datasets |

**Lake table source confirmation:**
| Dataset | Source | Lake Path |
|---|---|---|
| `ads_bill_line` | `analytic.ads_bill_line` | `us-west-2/analytic/ads-bill-line/` |
| `dim_bill` | `ecomm360.dim_bill_vw` | `dlms-api/us-west-2/ecomm360/dim-bill-vw/` |
| `dim_product` | `bigreporting.dim_product_snap` | `us-west-2/bigreporting/dim-product-snap/` |
| `dim_customer` | `customer360.dim_customer_vw` | `dlms-api/us-west-2/customer360/dim-customer-vw/` |
| `dim_reseller` | `partner360.dim_reseller_vw` | `dlms-api/us-west-2/partner360/dim-reseller-vw/` |
| `customer_type_gcr_logic` | `gmode.customer_type_gcr_logic_lookup` | `us-west-2/gmode/customer-type-gcr-logic-lookup/` |
| `free_entitlement` | `enterprise.free_entitlement` | `us-west-2/enterprise/free-entitlement/` |
| `c3_rev_attribution` | `care_mart.rev_attribution` | `us-west-2/care-mart/rev-attribution/` |

---

### Step 4: Accuracy Validation — PASS

**Evidence basis for each dataset:**

| Dataset | Field Count | DDL Columns | Notes |
|---|---|---|---|
| `ads_bill_line` | 201 | 200 in DDL + 1 partition key in table.yaml | All 201 fields verified against lake DDL and table.yaml |
| `dim_bill` | 11 | 11 in DDL | Exact match with `ecomm360/dim-bill-vw/table.ddl` |
| `dim_product` | 35 | 35 of 42 in DDL | 7 `tx_source_*` CDC tracking columns + `datacenterregionid` correctly excluded |
| `dim_customer` | 29 | 29 in DDL | Exact match with `customer360/dim-customer-vw/table.ddl` (analyze.md had undercounted as 27) |
| `dim_reseller` | 15 | 15 of 37 in DDL | 22 branding/UI columns correctly excluded; 15 analytically relevant columns kept |
| `customer_type_gcr_logic` | 13 | 13 in DDL | Exact match with `gmode/customer-type-gcr-logic-lookup/table.ddl` |
| `free_entitlement` | 21 | 21 in DDL | Exact match with `enterprise/free-entitlement/table.ddl` |
| `c3_rev_attribution` | 14 | 14 in DDL | Exact match with `care-mart/rev-attribution/table.ddl` |

**Metric column evidence:** All 10 metric expressions reference columns that exist in the `ads_bill_line` lake DDL:
- `gcr_usd_amt`, `gcr_constant_currency_amt`, `receipt_price_usd_amt`, `fair_market_value_usd_amt`, `unit_qty`, `product_month_qty`, `margin_gcr_usd_amt`, `commission_usd_amt` — all confirmed in DDL
- `bill_id` (for COUNT DISTINCT) — confirmed as PK in DDL
- `new_acquisition_flag` (for conditional count) — confirmed in DDL

**No fabricated content found.** All fields, descriptions, and relationship join keys are backed by lake DDL, table.yaml, or the DQ constraints file.

---

### Step 5: Completeness Check — PASS

| Check | Result |
|---|---|
| Target table `analytic.ads_bill_line` present as dataset | PASS |
| All 8 datasets from analyze.md classification included | PASS |
| Time dimension fields have `is_time: true` | PASS (all date/timestamp fields flagged) |
| At least one metric defined | PASS (10 metrics) |

---

### Issues Found and Fixed

**None.** The `SEMANTIC_MODEL.yaml` required no corrections. All structural, reference, and accuracy checks passed on first inspection.

---

### Items Removed Due to Lack of Evidence

**None.** No fields or relationships were removed. The 14 unresolved source tables identified in analyze.md (fraud_cln, dm_reference, dp_stage, dp_enterprise, etc.) were correctly omitted by the generate stage as they have no lake catalog entries.

---

### Final Counts

| Item | Count |
|---|---|
| Semantic models | 1 |
| Datasets | 8 |
| Fields (total) | 339 |
| — ads_bill_line | 201 |
| — dim_bill | 11 |
| — dim_product | 35 |
| — dim_customer | 29 |
| — dim_reseller | 15 |
| — customer_type_gcr_logic | 13 |
| — free_entitlement | 21 |
| — c3_rev_attribution | 14 |
| Relationships | 7 |
| Metrics | 10 |
| Custom extensions | 1 (GODADDY) |

**Overall verdict: PASS — no changes made to SEMANTIC_MODEL.yaml**

**The agent's final response to the user was:**
The validation is complete. Here is a summary of what was done and found:

---

## Validation Summary — `analytic_ads_bill_line`

**All checks passed. No changes were required to `SEMANTIC_MODEL.yaml`.**

### What was validated:

**Step 2 — Structural (PASS)**
- Root `version: "0.2.0.dev0"` and `semantic_model` array confirmed
- All 339 field definitions have `name` + `expression.dialects` with `ANSI_SQL`
- All 10 metrics use aggregate expressions (SUM/COUNT); no aggregates found in field sections
- All 7 relationships have the required 5 keys; `len(from_columns) == len(to_columns)` for all
- No duplicate names within any scope
- `custom_extensions.data` is a valid JSON string; file uses Unix line endings

**Step 3 — Reference (PASS)**
- All 7 relationship `from`/`to` point to existing dataset names
- All relationship join columns verified present in their respective datasets (including the 7-column composite on `bill_line_to_gcr_logic`)
- All 8 dataset sources confirmed as lake tables in `repos/lake/catalog/config/prod/` (mix of `us-west-2/` and `dlms-api/us-west-2/` paths)

**Step 4 — Accuracy (PASS)**
- `ads_bill_line`: 201 YAML fields = 200 DDL columns + 1 partition key from `table.yaml` — exact match, no extras
- All 7 dimension datasets field-checked against their lake DDLs — all fields are real DDL columns; no fabricated content
- All 10 metric column references exist in the `ads_bill_line` DDL

**Step 5 — Completeness (PASS)**
- Target table present; 8 datasets; time fields flagged; 10 metrics defined

**Final counts:** 8 datasets, 339 fields, 7 relationships, 10 metrics