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

## generate stage — analytic_ads_bill_line

**Generated:** 2026-06-04
**Output:** `SEMANTIC_MODEL.yaml`

---

### Semantic Model Summary

| Property | Value |
|---|---|
| Model name | `analytic_ads_bill_line` |
| OSI version | `0.2.0.dev0` |
| Dataset count | 8 (1 fact + 7 dimensions) |
| Relationship count | 7 |
| Metric count | 10 |

### Dataset Field Counts

| Dataset | Source | Role | Fields |
|---|---|---|---|
| `ads_bill_line` | `analytic.ads_bill_line` | FACT | 201 |
| `dim_bill` | `ecomm360.dim_bill_vw` | DIMENSION | 11 |
| `dim_product` | `bigreporting.dim_product_snap` | DIMENSION | 35 |
| `dim_customer` | `customer360.dim_customer_vw` | DIMENSION | 29 |
| `dim_reseller` | `partner360.dim_reseller_vw` | DIMENSION | 15 |
| `customer_type_gcr_logic` | `gmode.customer_type_gcr_logic_lookup` | DIMENSION (BROADCAST) | 13 |
| `free_entitlement` | `enterprise.free_entitlement` | DIMENSION | 21 |
| `c3_rev_attribution` | `care_mart.rev_attribution` | DIMENSION | 14 |
| **Total** | | | **339** |

### Relationships

| Name | From | To | Join Columns |
|---|---|---|---|
| `bill_line_to_bill` | `ads_bill_line` | `dim_bill` | `[bill_id]` → `[bill_id]` |
| `bill_line_to_product` | `ads_bill_line` | `dim_product` | `[pf_id]` → `[pf_id]` |
| `bill_line_to_customer` | `ads_bill_line` | `dim_customer` | `[original_customer_id]` → `[customer_id]` |
| `bill_line_to_reseller` | `ads_bill_line` | `dim_reseller` | `[private_label_id]` → `[private_label_id]` |
| `bill_line_to_gcr_logic` | `ads_bill_line` | `customer_type_gcr_logic` | 7-column composite (bill_report_region_2_name → order_region_2_name) |
| `bill_line_to_free_entitlement` | `ads_bill_line` | `free_entitlement` | `[bill_id, bill_line_num]` → `[paid_bill_id, paid_bill_line_num]` |
| `bill_line_to_c3_attribution` | `ads_bill_line` | `c3_rev_attribution` | `[bill_id]` → `[order_id]` |

### Metrics

| Name | Expression | Description |
|---|---|---|
| `total_gcr_usd` | `SUM(ads_bill_line.gcr_usd_amt)` | Total GCR in USD |
| `total_gcr_constant_currency` | `SUM(ads_bill_line.gcr_constant_currency_amt)` | Total GCR constant FX |
| `total_receipt_price_usd` | `SUM(ads_bill_line.receipt_price_usd_amt)` | Total amount paid USD |
| `total_fair_market_value_usd` | `SUM(ads_bill_line.fair_market_value_usd_amt)` | Total FMV USD |
| `total_unit_qty` | `SUM(ads_bill_line.unit_qty)` | Total units purchased |
| `total_product_month_qty` | `SUM(ads_bill_line.product_month_qty)` | Total subscription months |
| `distinct_order_count` | `COUNT(DISTINCT ads_bill_line.bill_id)` | Unique orders |
| `new_acquisition_count` | `COUNT(DISTINCT CASE WHEN new_acquisition_flag=TRUE THEN bill_id END)` | New customer acquisitions |
| `total_margin_gcr_usd` | `SUM(ads_bill_line.margin_gcr_usd_amt)` | GCR margin USD |
| `total_commission_usd` | `SUM(ads_bill_line.commission_usd_amt)` | Total 3rd-party commission |

### Items Omitted (Insufficient Evidence)

| Item | Reason |
|---|---|
| `fraud_cln.fraud_note_cln` as dataset | Schema absent from lake catalog |
| `fraud_cln.fraud_review_history_cln` as dataset | Schema absent from lake catalog |
| `reference_cln.tld_registry_reference_cln` as dataset | Schema absent from lake catalog |
| `dm_reference.dim_geography` as dataset | Schema absent from lake catalog |
| `gd_pro_mart.web_pro_shopper_client` as dataset | Schema absent from lake catalog |
| `dp_stage.ref_order_constant_currency` as dataset | Schema absent from lake catalog |
| `dp_stage.ref_commission_products` as dataset | Schema absent from lake catalog |
| `dp_enterprise.dim_isc_source_code` as dataset | Schema absent from lake catalog |
| `ecomm_core_conformed.dim_customer_registration_acquisition` as dataset | Not in lake catalog; accessed via direct Iceberg S3 read |
| `ecomm_mart.dim_bill_line_purchase_attribution` as dataset | Table not registered under known catalog paths |
| `analytic_feature.customer_type_history` as dataset | Table not found in catalog |
| `analytic_feature.shopper_crm_portfolio` as dataset | Table not found in catalog |
| `analytic_feature.shopper_domain_portfolio` as dataset | Table not found in catalog |
| `care_mart.employee_master_snap_v3` as dataset | Name mismatch; exact table not confirmed in catalog |
| `bigreporting.dim_product_hist_cln` as dataset | Alternate product table (non-default DAG flag); excluded per prod default path |
| Shopper-level distinct count metric | merged_shopper_id changes over time; not safe to define as metric without care |
| C3 rep PII metrics | `c3_rep_name`, `crm_portfolio_rep_name` are encrypted; not useful as aggregates |

### Key Sources Used

- `ecomm/analytic-bill-line/src/pyspark/ads_bill_line.py` — primary source of truth
- `ecomm/analytic-bill-line/src/dag/analytic_bill_line_dag.py` — DAG identity and schedule
- `repos/lake/catalog/config/prod/us-west-2/analytic/ads-bill-line/table.ddl` — 201-column fact DDL
- `repos/lake/catalog/config/prod/us-west-2/analytic/ads-bill-line/table.yaml` — lake config
- `repos/lake/catalog/config/prod/dlms-api/us-west-2/ecomm360/dim-bill-vw/table.ddl`
- `repos/lake/catalog/config/prod/us-west-2/bigreporting/dim-product-snap/table.ddl`
- `repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/dim-customer-vw/table.ddl`
- `repos/lake/catalog/config/prod/dlms-api/us-west-2/partner360/dim-reseller-vw/table.ddl`
- `repos/lake/catalog/config/prod/us-west-2/gmode/customer-type-gcr-logic-lookup/table.ddl`
- `repos/lake/catalog/config/prod/us-west-2/enterprise/free-entitlement/table.ddl`
- `repos/lake/catalog/config/prod/us-west-2/care-mart/rev-attribution/table.ddl`
- Alation record ID 6242622 (`AwsDataCatalog.analytic.ads_bill_line`) — business description

**The agent's final response to the user was:**
`SEMANTIC_MODEL.yaml` has been created and `generate.md` has been updated. Here's a summary of what was produced:

---

### SEMANTIC_MODEL.yaml — Summary

**Model:** `analytic_ads_bill_line` | **Version:** `0.2.0.dev0`

**8 datasets** (1 fact + 7 dimensions), **339 total fields**, **7 relationships**, **10 metrics**

| Dataset | Source | Fields |
|---|---|---|
| `ads_bill_line` | `analytic.ads_bill_line` | 201 |
| `dim_bill` | `ecomm360.dim_bill_vw` | 11 |
| `dim_product` | `bigreporting.dim_product_snap` | 35 |
| `dim_customer` | `customer360.dim_customer_vw` | 29 |
| `dim_reseller` | `partner360.dim_reseller_vw` | 15 |
| `customer_type_gcr_logic` | `gmode.customer_type_gcr_logic_lookup` | 13 |
| `free_entitlement` | `enterprise.free_entitlement` | 21 |
| `c3_rev_attribution` | `care_mart.rev_attribution` | 14 |

**7 relationships** — including the complex 7-column BROADCAST join to `customer_type_gcr_logic` and the cross-key join (`bill_id → order_id`, `original_customer_id → customer_id`, `bill_id/bill_line_num → paid_bill_id/paid_bill_line_num`).

**10 evidence-backed metrics** — GCR totals, receipt price, FMV, unit qty, subscription months, order counts, new acquisitions, margin, and commission.

**18 sources omitted** — all 14 unresolved lake tables plus 4 additional exclusions (alternate product table, shopper count, and encrypted PII fields) per the "do not claim" list from `analyze.md`.