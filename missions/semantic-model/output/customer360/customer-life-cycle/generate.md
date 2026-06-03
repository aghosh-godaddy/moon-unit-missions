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
        data: '{"lake_table_path": "<path>", "pyspark_path": "<path>", "dag_name": "<name>", "refresh_cadence": "<cadence>"}'
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

## Step 3: Append summary to generate.md
Append:
- Semantic model name
- Dataset count (fact + dimensions)
- Field count per dataset
- Relationship count
- Metric count
- Items omitted due to insufficient evidence
- Key sources used

**The agent summarized its work in this way:**

---

## Stage: generate — customer360_customer_life_cycle_analytics
**Generated:** 2026-06-03

---

### Output: SEMANTIC_MODEL.yaml

**Semantic model name:** `customer360_customer_life_cycle_analytics`

---

### Dataset count: 6 (1 fact + 5 dimensions)

| # | Dataset name | Role | Source | Field count |
|---|---|---|---|---|
| 1 | `customer_life_cycle_vw` | FACT | `customer360.customer_life_cycle_vw` | 35 |
| 2 | `shopper_acquisition` | DIMENSION | `analytic_feature.shopper_acquisition` | 17 |
| 3 | `dim_reseller` | DIMENSION | `dp_enterprise.dim_reseller` | 10 |
| 4 | `dim_country_vw` | DIMENSION | `finance360.dim_country_vw` | 20 |
| 5 | `dim_customer_history_vw` | DIMENSION | `customer360.dim_customer_history_vw` | 31 |
| 6 | `dim_subscription_history` | DIMENSION | `enterprise.dim_subscription_history` | 21 |

**Total fields across all datasets:** 134

---

### Relationship count: 5

| Name | From | To | from_columns | to_columns | Notes |
|---|---|---|---|---|---|
| `customer_life_cycle_to_shopper_acquisition` | `customer_life_cycle_vw` | `shopper_acquisition` | `[shopper_id]` | `[shopper_id]` | Standard scalar FK |
| `customer_life_cycle_to_dim_reseller` | `customer_life_cycle_vw` | `dim_reseller` | `[reseller_type_id]` | `[reseller_type_id]` | Non-PK join; dim PK is private_label_id |
| `customer_life_cycle_to_dim_country_vw` | `customer_life_cycle_vw` | `dim_country_vw` | `[customer_acquisition_country_code]` | `[country_code]` | Filter current_record_flag=true |
| `customer_life_cycle_to_dim_customer_history_vw` | `customer_life_cycle_vw` | `dim_customer_history_vw` | `[customer_id]` | `[customer_id]` | SCD2; filter current_record_flag=true |
| `customer_life_cycle_to_dim_subscription_history` | `customer_life_cycle_vw` | `dim_subscription_history` | `[active_paid_subscription_list]` | `[subscription_id]` | ARRAY FK; requires UNNEST/LATERAL |

---

### Metric count: 5

| Name | Expression | Evidence |
|---|---|---|
| `total_ttm_gcr_usd` | `SUM(customer_life_cycle_vw.ttm_gcr_usd_amt)` | PySpark SUM(ttm_total_gcr_usd_amt); Alation TTM GCR key feature |
| `active_customer_count` | `COUNT(DISTINCT CASE WHEN active_status_flag=TRUE THEN customer_id END)` | PySpark active_status_flag logic; Confluence lifecycle state |
| `churned_customer_count` | `COUNT(DISTINCT CASE WHEN customer_state_enum='churned' THEN customer_id END)` | PySpark customer_state_enum 'churned'; Confluence churn definition |
| `avg_customer_tenure_years` | `AVG(customer_life_cycle_vw.customer_tenure_year_count)` | PySpark CAST(DATEDIFF/365 AS INT); Confluence tenure_days/365 |
| `unique_customer_count` | `COUNT(DISTINCT customer_life_cycle_vw.customer_id)` | Grain: one row per customer per eval date; DQ PK constraint |

---

### Items omitted due to insufficient evidence or OSI rule violations

| Item | Reason |
|---|---|
| `analytic_feature.customer_type_history` as OSI dataset | `customer_type_name` and `customer_type_reason_desc` already denormalized into fact; redundant |
| `analytic_feature.customer_fraud` as OSI dataset | `customer_fraud_flag` and `customer_fraud_mst_date` already in fact |
| `analytic_feature.shopper_merge` as OSI dataset | Identity resolution detail; `customer_merge_mst_date` already in fact |
| `enterprise.dim_new_acquisition_shopper` as OSI dataset | Acquisition computation input; acquisition attributes already denormalized |
| `ecomm_mart.bill_line_traffic_ext` as OSI dataset | `customer_acquisition_channel_name` already in fact |
| `ecomm_mart.dim_bill_line_purchase_attribution` as OSI dataset | `point_of_purchase_name` already in fact |
| `finance360.dim_bill_fraud_history_vw` as OSI dataset | `customer_acquisition_bill_fraud_flag` already in fact |
| `customer_core_conformed.customer_ttm_payment_driver` | Not a lake table; internal ETL driver |
| `customer_core_conformed.customer_active_subscription_detail_driver` | Not a lake table; internal ETL driver |
| `customer_core_conformed.active_customer_stg` | Not a lake table; internal ETL driver |
| Legacy S3 `ads_bill_line_ext` | Hardcoded prod S3 path; not a lake table; pre-2022-08 legacy data only |
| Redshift `customer360.customer_life_cycle` | Downstream copy; not a lake table |

---

### Key sources used

| Source | Used for |
|---|---|
| `repos/dof-dpaas-customer-feature/customer360/customer-metrics/src/pyspark/customer_life_cycle.py` | Authoritative write target, join conditions, aggregation patterns, field derivation logic |
| `repos/dof-dpaas-customer-feature/customer360/customer-metrics/src/dag/customer_life_cycle_dag.py` | DAG ID, schedule, lake view promotion (SuccessNotificationOperator), refresh cadence |
| `repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/customer-life-cycle-vw/table.ddl` | Canonical 34-column DDL for fact dataset; FK annotations; PK annotations |
| `repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/customer-life-cycle-vw/table.yaml` | Lake path, data_tier, SLA cron |
| `repos/lake/catalog/config/prod/us-west-2/analytic-feature/shopper-acquisition/table.ddl` | shopper_acquisition dimension schema |
| `repos/lake/catalog/config/prod/us-west-2/dp-enterprise/dim-reseller/table.ddl` | dim_reseller dimension schema |
| `repos/lake/catalog/config/prod/dlms-api/us-west-2/finance360/dim-country-vw/table.ddl` | dim_country_vw dimension schema |
| `repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/dim-customer-history-vw/table.ddl` | dim_customer_history_vw SCD2 dimension schema |
| `repos/lake/catalog/config/prod/us-west-2/enterprise/dim-subscription-history/table.ddl` | dim_subscription_history dimension schema |
| `repos/dof-dpaas-customer-feature/customer360/customer-metrics/src/data_quality/constraints/customer_life_cycle.json` | DQ PK constraint confirming (partition_eval_mst_date, shopper_id) |
| Confluence Customer Lifecycle page (ID 3970861345) | Business grain, churn definition, tenure formula |
| Confluence Business Context page (ID 4387965088) | OSI/OWL target confirmation, domain weight, stakeholders |
| Alation (table ID 7038345) | Table description, key feature list (TTM GCR), type discrepancy (customer_tenure_year_count) |


**The agent's final response to the user was:**
The `SEMANTIC_MODEL.yaml` has been created and `generate.md` has been updated. Here is a summary of what was produced:

---

## SEMANTIC_MODEL.yaml — Summary

**Model:** `customer360_customer_life_cycle_analytics`  
**Version:** `0.2.0.dev0`

### Datasets: 6 (1 fact + 5 dimensions)

| Dataset | Role | Source | Fields |
|---|---|---|---|
| `customer_life_cycle_vw` | FACT | `customer360.customer_life_cycle_vw` | 35 |
| `shopper_acquisition` | DIM | `analytic_feature.shopper_acquisition` | 17 |
| `dim_reseller` | DIM | `dp_enterprise.dim_reseller` | 10 |
| `dim_country_vw` | DIM | `finance360.dim_country_vw` | 20 |
| `dim_customer_history_vw` | DIM | `customer360.dim_customer_history_vw` | 31 |
| `dim_subscription_history` | DIM | `enterprise.dim_subscription_history` | 21 |

**Total fields: 134**

### Relationships: 5
All sourced from PySpark join conditions and lake DDL `@ForeignKey` annotations. The `active_paid_subscription_list → subscription_id` relationship is flagged as an array FK requiring `UNNEST/LATERAL` with an `ai_context` note.

### Metrics: 5
`total_ttm_gcr_usd`, `active_customer_count`, `churned_customer_count`, `avg_customer_tenure_years`, `unique_customer_count` — all backed by PySpark aggregation evidence and/or Confluence/Alation documentation.

### Items omitted: 12
Seven source tables whose attributes are already denormalized into the fact, three internal `customer_core_conformed.*` driver tables (not lake tables), one legacy hardcoded S3 path, and one Redshift downstream copy.