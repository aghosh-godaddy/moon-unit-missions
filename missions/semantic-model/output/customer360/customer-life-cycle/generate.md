**Stage name:** generate
**The coding agent was given these instructions:** You are generating an **OSI-compliant semantic model** YAML file for a Data Lake table.
Your output must be 100% accurate. Never fabricate fields, relationships, or metrics.

Read `docs/osi-spec-reference.md` for the complete schema contract.

## Step 1: Read all prior artifacts
Read:
- `INPUT.md` — includes USER NOTES (HIGHEST PRIORITY after code) if provided
- `gather.md`
- `analyze.md`
- `RESOLVED_TARGET.json`
- `PROVENANCE.json` — machine-readable lineage and do-not-claim preservation contract

USER NOTES override Confluence/Alation — but NEVER override PySpark/DAG code.

## Step 2: Create SEMANTIC_MODEL.yaml
Create `SEMANTIC_MODEL.yaml` in the workspace root with this exact structure:

```yaml
version: "0.2.0.dev0"

semantic_model:
  - name: <from analyze.md or RESOLVED_TARGET.json>
    description: <business description>
    ai_context:
      instructions: <how AI should use this model>
      synonyms: [<terms>]
      examples: [<sample questions>]

    datasets:
      - name: <snake_case dataset name>
        source: <schema.table>
        primary_key: [<col(s)>]
        unique_keys:
          - [<col(s)>]
        description: <text>
        ai_context:
          synonyms: [<terms>]
        fields:
          - name: <field_name>
            expression:
              dialects:
                - dialect: ANSI_SQL
                  expression: <scalar_sql>
            dimension:
              is_time: true|false
            description: <text>
            ai_context:
              synonyms: [<terms>]

    relationships:
      - name: <rel_name>
        from: <many_side_dataset>
        to: <one_side_dataset>
        from_columns: [<fk_cols>]
        to_columns: [<pk_cols>]

    metrics:
      - name: <metric_name>
        expression:
          dialects:
            - dialect: ANSI_SQL
              expression: <aggregate_sql>
        description: <text>
        ai_context:
          synonyms: [<terms>]

    custom_extensions:
      - vendor_name: GODADDY
        data: '{"lake_table_path": "<path>", "pyspark_path": "<path>", "dag_name": "<name>", "refresh_cadence": "<cadence>", "pipeline_lineage": {"intermediate_tables": [], "transitive_sources": [], "materialized_direct_reads": [], "legacy_sources": []}, "query_guards": {"grain": "<grain>", "partition_filter": "<col>", "primary_key_notes": "<notes>"}}'
```

## Generation rules (non-negotiable)
1. Root must have `version: "0.2.0.dev0"` and `semantic_model` array
2. Use **ANSI_SQL** dialect only for all expressions
3. Field expressions are **scalar** (no SUM/COUNT/AVG)
4. Metric expressions use **aggregates** and may reference `dataset.column`
5. Dataset `source` values must be **lake tables only** (schema.table)
6. Include the target table AND all resolved upstream dimension tables
7. Every field needs `name`, `expression.dialects`, and `description` (if known)
8. Set `dimension.is_time: true` on date/timestamp/partition columns
9. Relationships must have matching column counts in from/to
10. Only include metrics with evidence from analyze.md
11. `custom_extensions.data` must be a JSON **string**, not nested YAML
12. Omit fields/relationships/metrics you cannot support with evidence
13. For every field listed in `PROVENANCE.json` → `transitive_sources` or
    `materialized_direct_reads`, append upstream provenance to the fact field
    `description` (e.g. "Derived from enterprise.dim_subscription_history via
    customer_active_subscription_detail_driver; not directly joinable")
14. For every entry in `PROVENANCE.json` → `array_fields`, document in the field
    `description` and mention the field (and any `scalar_proxy`) in
    `ai_context.instructions` — do not define metrics that unnest or aggregate arrays
15. Expand `custom_extensions.data` to include `pipeline_lineage` (intermediate_tables,
    transitive_sources, materialized_direct_reads, legacy_sources) and `query_guards`
    (grain, partition_filter, primary_key_notes) sourced from `PROVENANCE.json`
16. `ai_context.instructions` must include: grain, required partition filter,
    primary-key caveats, array-field warnings, and excluded join targets with guidance
    to use denormalized fact columns instead
17. Every item in `PROVENANCE.json` → `do_not_claim` must appear in at least one of:
    field `description`, `ai_context`, or `custom_extensions` — never as a dataset,
    relationship, or metric

## Step 3: Append summary to generate.md
Append:
- Semantic model name
- Dataset count (fact + dimensions)
- Field count per dataset
- Relationship count
- Metric count
- Provenance fields enriched (count and list)
- Do-not-claim items preserved (and where: description / ai_context / custom_extensions)
- Items omitted due to insufficient evidence
- Key sources used

**The agent summarized its work in this way:**

---

## Generate Stage Summary — customer360_customer_life_cycle_analytics

**Stage:** generate
**Date:** 2026-06-05
**Output:** `SEMANTIC_MODEL.yaml` created in workspace root

---

### Semantic Model

| Field | Value |
|---|---|
| Model name | `customer360_customer_life_cycle_analytics` |
| OSI version | `0.2.0.dev0` |
| Lake table (canonical) | `customer360.customer_life_cycle_vw` |
| Grain | One row per (shopper_id, partition_eval_mst_date) |

---

### Dataset Count: 5 (1 fact + 4 dimensions)

| Dataset name | Role | source | Field count |
|---|---|---|---|
| customer_life_cycle | fact | customer360.customer_life_cycle_vw | 35 |
| shopper_acquisition | dimension | analytic_feature.shopper_acquisition | 17 |
| dim_country | dimension | finance360.dim_country_vw | 28 |
| dim_bill_line_purchase_attribution | dimension | ecomm_mart.dim_bill_line_purchase_attribution | 9 |
| dim_bill_fraud_history | dimension | finance360.dim_bill_fraud_history_vw | 11 |

**Total fields across all datasets: 100**

---

### Relationship Count: 4

| Relationship | from | to | from_columns | to_columns |
|---|---|---|---|---|
| life_cycle_to_shopper_acquisition | customer_life_cycle | shopper_acquisition | [shopper_id] | [shopper_id] |
| life_cycle_to_dim_country | customer_life_cycle | dim_country | [customer_acquisition_country_code] | [country_code] |
| life_cycle_to_dim_bill_line_purchase_attribution | customer_life_cycle | dim_bill_line_purchase_attribution | [customer_acquisition_bill_id] | [bill_id] |
| life_cycle_to_dim_bill_fraud_history | customer_life_cycle | dim_bill_fraud_history | [customer_acquisition_bill_id] | [bill_id] |

---

### Metric Count: 3

| Metric | Expression | Evidence |
|---|---|---|
| total_ttm_gcr_usd_amt | `SUM(customer_life_cycle.ttm_gcr_usd_amt)` | PySpark SUM(ttm_total_gcr_usd_amt); Alation "TTM GCR" |
| active_customer_count | `COUNT(DISTINCT CASE WHEN customer_life_cycle.active_status_flag = true THEN customer_life_cycle.shopper_id END)` | active_status_flag direct fact column; Alation/Confluence |
| avg_product_pnl_category_qty | `AVG(customer_life_cycle.product_pnl_category_qty)` | PySpark COUNT(DISTINCT product_pnl_category) producing scalar field |

---

### Provenance Fields Enriched: 12

Fields with upstream provenance appended to description per Rule 13:

| Field | Provenance source | Type |
|---|---|---|
| active_paid_subscription_list | enterprise.dim_subscription_history via customer_active_subscription_detail_driver | transitive_source |
| product_pnl_category_list | enterprise.dim_subscription_history via customer_active_subscription_detail_driver | transitive_source |
| product_pnl_line_list | enterprise.dim_subscription_history via customer_active_subscription_detail_driver | transitive_source |
| product_pnl_category_qty | enterprise.dim_subscription_history via customer_active_subscription_detail_driver | transitive_source |
| customer_type_name | analytic_feature.customer_type_history (SCD2 time-filtered) | materialized_direct_read |
| customer_type_reason_desc | analytic_feature.customer_type_history (SCD2 time-filtered) | materialized_direct_read |
| reseller_type_id | dp_enterprise.dim_reseller via customer360.dim_customer_history_vw.private_label_id | materialized_direct_read |
| reseller_type_name | dp_enterprise.dim_reseller via customer360.dim_customer_history_vw.private_label_id | materialized_direct_read |
| customer_merge_mst_date | analytic_feature.shopper_merge (SCD2 date-range join) | materialized_direct_read |
| customer_acquisition_channel_name | ecomm_mart.bill_line_traffic_ext + legacy S3 path (pre-2022-08) | materialized_direct_read |
| customer_acquisition_mst_date | enterprise.dim_new_acquisition_shopper (acquisition derivation chain) | materialized_direct_read |
| customer_acquisition_bill_id | enterprise.dim_new_acquisition_shopper (acquisition derivation chain) | materialized_direct_read |

---

### Do-Not-Claim Items Preserved: 17

All 17 items from PROVENANCE.json → do_not_claim are preserved per Rule 17:

| Item | Preserved where |
|---|---|
| customer_core_conformed.active_customer_stg as OSI dataset | custom_extensions (pipeline_lineage.intermediate_tables) |
| customer_core_conformed.customer_ttm_payment_driver as OSI dataset | custom_extensions (pipeline_lineage.intermediate_tables) |
| customer_core_conformed.customer_active_subscription_detail_driver as OSI dataset | custom_extensions (pipeline_lineage.intermediate_tables) |
| analytic_feature.customer_fraud as OSI dataset | field_description (customer_fraud_flag, customer_fraud_mst_date) |
| analytic_feature.customer_type_history as OSI dataset | field_description (customer_type_name, customer_type_reason_desc) |
| dp_enterprise.dim_reseller as OSI dataset | field_description (reseller_type_id, reseller_type_name) |
| customer360.dim_customer_history_vw as OSI dataset | ai_context (model instructions + custom_extensions materialized_direct_reads) |
| enterprise.dim_subscription_history as OSI dataset | custom_extensions (pipeline_lineage.transitive_sources) |
| enterprise.dim_new_acquisition_shopper as OSI dataset | field_description (customer_acquisition_mst_date, customer_acquisition_bill_id) |
| analytic_feature.shopper_merge as OSI dataset | field_description (customer_merge_mst_date) |
| ecomm_mart.bill_line_traffic_ext as OSI dataset | custom_extensions (pipeline_lineage.materialized_direct_reads) |
| s3://gd-ckpetlbatch-prod-analytic/analytic/ads_bill_line_ext/ as OSI source | custom_extensions (pipeline_lineage.legacy_sources) |
| active_paid_subscription_list as OSI metric | field_description + ai_context.instructions |
| product_pnl_category_list as OSI metric | field_description + ai_context.instructions |
| product_pnl_line_list as OSI metric | field_description + ai_context.instructions |
| ttm_all_bill_list as OSI metric | field_description + ai_context.instructions |
| brand_name_list as OSI metric | field_description + ai_context.instructions |

---

### Items Omitted Due to Insufficient Evidence

| Item | Reason |
|---|---|
| Metrics based on Alation saved queries | All 5 Alation queries had empty SQL content via API; no SQL was recoverable |
| Metrics unnesting array fields | array<string> fields incompatible with ANSI SQL aggregates; per Rule 14 and do-not-claim |
| Additional dimensions beyond 4 included | All other source tables are materialized reads, intermediate drivers, or excluded (M:M cardinality) per analyze.md classification |

---

### Key Sources Used

| Source | Role |
|---|---|
| `customer360/customer-metrics/src/pyspark/customer_life_cycle.py` | Authoritative: field values, join logic, aggregations |
| `customer360/customer-metrics/src/dag/customer_life_cycle_dag.py` | Authoritative: schedule, cadence, dependencies |
| `repos/lake/.../customer-life-cycle-vw/table.ddl` | Lake field definitions (34 body columns + partition) |
| `repos/lake/.../customer-life-cycle-vw/table.yaml` | Data tier, SLA, partition metadata |
| `src/data_quality/constraints/customer_life_cycle_vw.json` | PK confirmation: isPrimaryKey(partition_eval_mst_date, shopper_id) |
| `RESOLVED_TARGET.json` | Target table: customer360.customer_life_cycle_vw (high confidence) |
| `PROVENANCE.json` | 17 do-not-claim entries, 3 intermediate tables, 1 transitive source, 6 materialized reads, 5 array field guards, 1 legacy source |
| `analyze.md` | Dataset classification, relationships, metrics, field inventory, do-not-claim table |
| Confluence 3779199819, 4387965088 | Business context, grain confirmation |
| Alation ID 7038345 | Table description; query SQL not recoverable |

**The agent's final response to the user was:**
`SEMANTIC_MODEL.yaml` has been created and `generate.md` has been updated. Here is a summary of the work done:

---

## Generate Stage — `customer360_customer_life_cycle_analytics`

**Output:** `/tmp/moonunit-workspace/SEMANTIC_MODEL.yaml`

### Structure

| Element | Count |
|---|---|
| OSI version | `0.2.0.dev0` |
| Datasets | 5 (1 fact + 4 dimensions) |
| Fields | 100 total (35 + 17 + 28 + 9 + 11) |
| Relationships | 4 |
| Metrics | 3 (evidence-only) |
| custom_extensions | 1 GODADDY vendor block with full pipeline_lineage + query_guards |

### Datasets
- **`customer_life_cycle`** (fact) — `customer360.customer_life_cycle_vw` — 35 fields, PK: `(shopper_id, partition_eval_mst_date)`
- **`shopper_acquisition`** (dim) — `analytic_feature.shopper_acquisition` — 17 fields
- **`dim_country`** (dim) — `finance360.dim_country_vw` — 28 fields
- **`dim_bill_line_purchase_attribution`** (dim) — `ecomm_mart.dim_bill_line_purchase_attribution` — 9 fields
- **`dim_bill_fraud_history`** (dim) — `finance360.dim_bill_fraud_history_vw` — 11 fields

### Key compliance points
- **Rule 13:** 12 fact fields enriched with upstream provenance notes (4 from transitive sources, 8 from materialized direct reads)
- **Rule 14:** All 5 array fields documented with ARRAY FIELD warnings and scalar proxies; all 5 array fields mentioned in `ai_context.instructions`
- **Rule 16:** `ai_context.instructions` covers grain, required partition filter, PK caveats, array field warnings, and 5 excluded join targets with denormalized column guidance
- **Rule 17:** All 17 `do_not_claim` items preserved — none appear as datasets, relationships, or metrics