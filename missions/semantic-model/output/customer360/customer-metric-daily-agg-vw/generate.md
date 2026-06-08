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
      - vendor_name: GoDaddy
        data: |
          {
            "lake_table_path": "<path>",
            "pyspark_path": "<path>",
            "dag_name": "<name>",
            "refresh_cadence": "<cadence>",
            "pipeline_lineage": {
              "intermediate_tables": [],
              "transitive_sources": [],
              "materialized_direct_reads": [],
              "legacy_sources": []
            },
            "query_guards": {
              "grain": "<grain>",
              "partition_filter": "<col>",
              "primary_key_notes": "<notes>"
            }
          }
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
11. `custom_extensions.data` must be a JSON **string**, not nested YAML — use a
    YAML literal block scalar (`data: |`) with pretty-printed JSON at 2-space indent
    (not a single-line minified string)
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

## Stage: Generate — SEMANTIC_MODEL.yaml

**Date:** 2026-06-05
**OSI Spec:** v0.2.0.dev0
**Model name:** `customer360_customer_metric_daily_agg`

---

### Semantic Model Summary

| Field | Value |
|---|---|
| Model name | `customer360_customer_metric_daily_agg` |
| Dataset count | 1 (1 fact; 0 dimensions — upstream source excluded per PROVENANCE.json) |
| Fact dataset | `customer_metric_daily_agg` → source: `customer360.customer_metric_daily_agg_vw` |
| Field count (fact dataset) | 31 fields |
| Relationship count | 0 (omitted — no cross-table FK joins exist; only LEFT ANTI self-join in PySpark) |
| Metric count | 11 |

---

### Field Count Breakdown — `customer_metric_daily_agg`

| Category | Fields |
|---|---|
| Partition/time (is_time: true) | 3 (`partition_eval_mst_date`, `customer_acquisition_mst_month`, `etl_build_mst_ts`) |
| Composite PK dimension columns | 18 (all non-metric, non-timestamp fields) |
| Measure/metric columns | 11 (`product_category_qty`, `ttm_gcr_usd_amt`, `ending_customer_qty`, `churn_customer_qty`, `merge_customer_qty`, `new_customer_qty`, `reactivate_customer_qty`, `beginning_customer_qty`, `net_move_qty`, `net_add_qty`, `net_churn_qty`) |
| ETL metadata | 1 (`etl_build_mst_ts`) |
| **Total** | **31** |

---

### Metrics (11)

| # | Metric name | Aggregate expression | Additivity |
|---|---|---|---|
| 1 | `ending_customer_qty` | `SUM(customer_metric_daily_agg.ending_customer_qty)` | Point-in-time — do NOT sum across dates |
| 2 | `beginning_customer_qty` | `SUM(customer_metric_daily_agg.beginning_customer_qty)` | Point-in-time — do NOT sum across dates |
| 3 | `new_customer_qty` | `SUM(customer_metric_daily_agg.new_customer_qty)` | Period-additive |
| 4 | `churn_customer_qty` | `SUM(customer_metric_daily_agg.churn_customer_qty)` | Period-additive |
| 5 | `reactivate_customer_qty` | `SUM(customer_metric_daily_agg.reactivate_customer_qty)` | Period-additive |
| 6 | `merge_customer_qty` | `SUM(customer_metric_daily_agg.merge_customer_qty)` | Period-additive |
| 7 | `net_add_qty` | `SUM(customer_metric_daily_agg.net_add_qty)` | Period-additive |
| 8 | `net_churn_qty` | `SUM(customer_metric_daily_agg.net_churn_qty)` | Period-additive |
| 9 | `net_move_qty` | `SUM(customer_metric_daily_agg.net_move_qty)` | Period-additive |
| 10 | `ttm_gcr_usd_amt` | `SUM(customer_metric_daily_agg.ttm_gcr_usd_amt)` | NOT date-additive (overlapping TTM windows) |
| 11 | `product_category_qty` | `SUM(customer_metric_daily_agg.product_category_qty)` | Additive across dimension groups for single date |

---

### Provenance Fields Enriched

**Count:** 0 transitive_sources + 0 materialized_direct_reads = **0 provenance field enrichments required** (PROVENANCE.json has empty arrays for both sections).

No transitive upstream fields required upstream provenance appended to descriptions.

---

### Do-Not-Claim Items — All 10 Preserved

| # | Item | Preserved in |
|---|---|---|
| 1 | `customer_core_conformed.customer_metric_daily_agg` as OSI dataset | `custom_extensions.data` → `pipeline_lineage.intermediate_tables` |
| 2 | `customer_core_conformed.customer_life_cycle` as OSI dataset | `custom_extensions.data` → `pipeline_lineage.intermediate_tables` |
| 3 | `customer360.customer_life_cycle_vw` as OSI dataset | `custom_extensions.data` → `excluded_dimensions` + `ai_context.instructions` |
| 4 | `data_source_enum` as OSI field | Dataset `description` + `ai_context.instructions` |
| 5 | `active_paid_subscription_list` (life_cycle field) as OSI field/metric | `ai_context.instructions` (EXCLUDED JOIN TARGETS section) |
| 6 | `ttm_all_bill_list` (life_cycle field) as OSI field/metric | `ai_context.instructions` (EXCLUDED JOIN TARGETS section) |
| 7 | Redshift `customer360.customer_metric_daily_agg` as OSI dataset | `custom_extensions.data` → `redshift_delivery` |
| 8 | LEFT ANTI JOIN self-join pattern as OSI relationship | `ai_context.instructions` (INTERNAL ETL NOTE) + `beginning_customer_qty` field description |
| 9 | `customer_fraud_mst_date` (life_cycle field) as OSI field/metric | `ai_context.instructions` (EXCLUDED JOIN TARGETS section) |
| 10 | `customer_state_enum` (life_cycle field) as OSI field/metric | `ai_context.instructions` (EXCLUDED JOIN TARGETS section) |

---

### Items Omitted Due to Insufficient Evidence

| Item | Reason |
|---|---|
| Relationships | No cross-table FK joins in PySpark; the only join is a LEFT ANTI self-join on intermediate CTEs (ETL-internal backfill pattern). Documented in do-not-claim and ai_context. |
| `customer360.customer_life_cycle_vw` as OSI dataset | No FK join key (no customer_id/shopper_id) in fact table; requires 18-column composite key with complex array cast/sort_array operations. Preserved in custom_extensions.excluded_dimensions. |
| `data_source_enum` as OSI field | Absent from lake-registered table.ddl; hardcoded value 'customer360'; no analytic value. Preserved in dataset description and ai_context. |
| Array source fields (`active_paid_subscription_list`, `ttm_all_bill_list`) | Not present in fact table; fully aggregated away in GROUP BY. Preserved in ai_context. |
| `customer_fraud_mst_date`, `customer_state_enum` | Not present in fact table; aggregated away in GROUP BY. Preserved in ai_context. |

---

### Array Fields Documented (3)

| Field | Scalar Proxy | Documented in |
|---|---|---|
| `product_ownership_category_list` | `product_category_qty` | Field description + `ai_context.instructions` |
| `product_ownership_line_list` | None | Field description + `ai_context.instructions` |
| `brand_name_list` | None | Field description + `ai_context.instructions` |

---

### Key Sources Used

| Source | Role |
|---|---|
| `repos/dof-dpaas-customer-feature/customer360/customer-metrics/src/pyspark/customer_metric_daily_agg.py` | Primary source of truth — aggregations, GROUP BY columns, derived metrics, array encoding |
| `repos/dof-dpaas-customer-feature/customer360/customer-metrics/src/dag/customer_metric_daily_agg_dag.py` | DAG schedule, SLA, dependencies, Redshift delivery tasks |
| `repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/customer-metric-daily-agg-vw/table.ddl` | Lake-registered schema (authoritative column list) |
| `repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/customer-metric-daily-agg-vw/table.yaml` | Lake metadata: tier, SLA, partition key, lineage |
| `repos/dof-dpaas-customer-feature/customer360/customer-metrics/src/data_quality/constraints/customer_metric_daily_agg_vw.json` | Authoritative 19-column composite PK (isPrimaryKey constraint) |
| `gather.md` | Aggregation expressions, join conditions, null-handling defaults, conflict documentation |
| `analyze.md` | Field inventory, metrics table, do-not-claim table, model metadata |
| `PROVENANCE.json` | Machine-readable do-not-claim contract, array fields, pipeline lineage |
| `RESOLVED_TARGET.json` | Confirmed lake table: `customer360.customer_metric_daily_agg_vw`, high confidence |
| Confluence (ID 3779199819 + child 4387965088) | Business Metrics Layer description, domain classification |

---

*Generated by: Generate agent — 2026-06-05*

**The agent's final response to the user was:**
`SEMANTIC_MODEL.yaml` has been created and `generate.md` has been updated. Here is a summary of what was produced:

---

## Output: `SEMANTIC_MODEL.yaml`

**Model name:** `customer360_customer_metric_daily_agg`
**OSI spec version:** `0.2.0.dev0`

### Structure

| Element | Count | Notes |
|---|---|---|
| Datasets | **1** | Fact only: `customer_metric_daily_agg` → `customer360.customer_metric_daily_agg_vw` |
| Fields | **31** | 18 PK dimensions + 11 measures/metrics columns + 1 ETL timestamp + 1 partition date |
| Relationships | **0** | Omitted — no cross-table FK joins; only a LEFT ANTI self-join in PySpark (ETL-internal) |
| Metrics | **11** | All with `SUM(...)` ANSI_SQL aggregates; additivity caveats documented |
| Custom extensions | **1** | GoDaddy vendor block with pipeline_lineage, excluded_dimensions, redshift_delivery, query_guards |

### Key decisions

- **`customer360.customer_life_cycle_vw` excluded as dataset** — no `customer_id`/`shopper_id` FK in the fact; join would require 18-column composite key with `cast(sort_array(...) as string)` operations. Preserved in `custom_extensions.data.excluded_dimensions` and `ai_context.instructions`.
- **19-column composite PK** — overrides the 16-column `@PrimaryKey` in lake DDL; DQ `isPrimaryKey` constraints and PySpark `GROUP BY` are authoritative.
- **3 array fields documented** — `product_ownership_category_list` (scalar proxy: `product_category_qty`), `product_ownership_line_list`, and `brand_name_list` — all flagged in field descriptions and `ai_context.instructions` as string-encoded, not query-filterable.
- **All 10 do-not-claim items preserved** — none appear as datasets, relationships, or metrics. Each is traceable to `field description`, `ai_context.instructions`, or `custom_extensions.data`.
- **TTM and point-in-time warnings** — `ttm_gcr_usd_amt`, `ending_customer_qty`, and `beginning_customer_qty` carry explicit cross-date summation warnings in both field descriptions and metric descriptions.