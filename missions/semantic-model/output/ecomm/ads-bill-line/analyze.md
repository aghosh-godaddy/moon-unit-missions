**Stage name:** analyze
**The coding agent was given these instructions:** You are a Data Engineering analyst mapping a PySpark ETL job to an OSI semantic model.
Your job is to resolve lineage, classify tables, extract relationships and metrics,
and produce a structured analysis for OSI YAML generation.

Read `docs/osi-spec-reference.md` in the workspace for the OSI schema contract.

## Step 1: Read INPUT.md and gather.md
- Read `INPUT.md` and `gather.md`.
- If INPUT.md contains USER NOTES, factor them into your analysis (expert-provided,
  priority over Confluence/Alation text).

## Step 2: Identify the target table
Determine the final output lake table populated by this PySpark job.
- Prefer direct evidence in code: write targets, insertInto, saveAsTable, etc.
- If `lake_table_override` is provided, use it only if it does not contradict code.
- Record grain (what one row represents) with evidence.

## Step 3: Deep lineage resolution — MANDATORY for EVERY source table
For EACH table referenced in the PySpark:
1. Check if it exists as a lake table in `repos/lake/catalog/config/prod/`.
   Try both `us-west-2/<schema>/<table-hyphenated>/` and
   `dlms-api/us-west-2/<schema>/<table-hyphenated>/`.
2. If NOT a lake table, recursively trace upstream PySpark scripts until you reach
   a lake table or external system.
3. If traversal fails: record `UNRESOLVED: <table> — <reason>`

**CRITICAL:** OSI dataset `source` values must be lake tables only (schema.table form).
Never use intermediate/staging tables as dataset sources.

## Step 4: Classify datasets (fact vs dimension)
For each resolved lake table included in the semantic model:
- **Target table** = primary fact dataset (the table this PySpark populates)
- **Upstream tables joined TO** = dimension datasets
- Record classification with evidence (join direction in PySpark)

## Step 5: Extract relationships
From PySpark join conditions in gather.md:
- Map each join to an OSI relationship: `from` (many side) → `to` (one side)
- Record `from_columns` and `to_columns` with matching order
- Name relationships descriptively (e.g., `orders_to_customers`)

## Step 6: Map fields for each dataset
For each dataset, list fields from lake `table.ddl`:
- Column name → OSI field name (use snake_case)
- Scalar expression (column reference or computed scalar)
- `dimension.is_time: true` for date/timestamp/partition date columns
- Description from DDL comments, Alation, or Confluence (if available)
- Candidate synonyms for `ai_context` from business docs

## Step 7: Identify metrics
From PySpark aggregations, Alation queries, and Confluence docs:
- Name each metric (snake_case)
- ANSI_SQL aggregate expression (may reference `dataset.column`)
- Description and synonyms
- Only include metrics with evidence — do not invent

## Step 8: Determine semantic model metadata
- Model name: use `semantic_model_name` from INPUT.md if provided, else derive from
  schema + table (e.g., `customer360_customer_life_cycle_analytics`)
- Model description: from Confluence, Alation, or code comments
- ai_context: instructions, synonyms, example questions the model answers

## Step 9: Output (append to analyze.md)
Append:
- Target table resolution with evidence
- Lineage resolution table (intermediate → lake)
- **Dataset classification table**: | Lake Table | OSI Dataset Name | Role (fact/dim) | source | primary_key |
- **Materialized direct-reads table**: | Lake Table | materialized_in_fields | evidence | — lake tables read by the PySpark job whose values are fully denormalized onto the fact (no join key back to source)
- **Excluded dimensions table**: | Lake Table | reason | fields_on_fact | — direct-read lake tables NOT included as OSI datasets (e.g. no FK in fact)
- **Relationship table**: | name | from | to | from_columns | to_columns | evidence |
- **Field inventory per dataset**: columns, types, is_time, descriptions
- **Metrics table**: | name | expression | description | evidence |
- **Semantic model metadata**: name, description, ai_context draft
- **Do-not-claim table**: | item | reason | preserve_as | — items that must NOT become OSI datasets, relationships, or metrics; `preserve_as` is one or more of: `field_description`, `ai_context`, `custom_extensions`

## Step 10: Write RESOLVED_TARGET.json (required)
Create `RESOLVED_TARGET.json` in workspace root:
```json
{
  "schema": "customer360",
  "table_hyphen": "customer-life-cycle-vw",
  "table_underscore": "customer_life_cycle_vw",
  "lake_table_path": "customer360/customer-life-cycle-vw",
  "semantic_model_name": "customer360_customer_life_cycle_analytics",
  "confidence": "high",
  "evidence": ["file/line references"]
}
```

## Step 11: Write PROVENANCE.json (required)
Create `PROVENANCE.json` in workspace root. This is the machine-readable contract for
preserving do-not-claim lineage in the OSI YAML without adding non-joinable datasets.
See `docs/osi-spec-reference.md` for the GODADDY custom_extensions schema.

```json
{
  "grain": "one row per (shopper_id, partition_eval_mst_date)",
  "primary_key_notes": "Composite PK; customer_id is not unique and may be null",
  "partition_filter": "partition_eval_mst_date",
  "intermediate_tables": [
    {
      "table": "customer_core_conformed.active_customer_stg",
      "role": "staging",
      "upstream_pyspark": "customer360/active-customer/src/pyspark/active_customer_stg.py"
    }
  ],
  "transitive_sources": [
    {
      "table": "enterprise.dim_subscription_history",
      "via": "customer_core_conformed.customer_active_subscription_detail_driver",
      "materialized_in_fields": ["active_paid_subscription_list"]
    }
  ],
  "materialized_direct_reads": [
    {
      "table": "analytic_feature.customer_type_history",
      "materialized_in_fields": ["customer_type_name", "customer_type_reason_desc"]
    }
  ],
  "excluded_dimensions": [
    {
      "table": "analytic_feature.customer_fraud",
      "reason": "no_join_key_in_fact",
      "fields_on_fact": ["customer_fraud_flag", "customer_fraud_mst_date"]
    }
  ],
  "array_fields": [
    {
      "field": "active_paid_subscription_list",
      "scalar_proxy": "product_pnl_category_qty",
      "note": "not suitable for OSI aggregate metrics; use scalar proxy fields instead"
    }
  ],
  "legacy_sources": [
    {
      "path": "s3://gd-ckpetlbatch-prod-analytic/analytic/ads_bill_line_ext/",
      "equivalent": "ecomm_mart.bill_line_traffic_ext",
      "condition": "pre-2022-08 partitions only"
    }
  ],
  "do_not_claim": [
    {
      "item": "customer_core_conformed.active_customer_stg as OSI dataset",
      "reason": "intermediate staging table not in lake catalog",
      "preserve_as": "custom_extensions"
    }
  ]
}
```

Use empty arrays `[]` for sections with no entries. Every do-not-claim item from Step 9
must appear in `do_not_claim` with a `preserve_as` value.

**The agent summarized its work in this way:**

---

# Analyze Stage Output — `analytic.ads_bill_line`

**Generated:** 2026-06-05
**Analyst stage:** analyze
**OSI spec version:** 0.2.0.dev0

---

## Step 2: Target Table Resolution

| Field | Value | Evidence |
|---|---|---|
| Schema | `analytic` | PySpark `DATABASE_NAME = 'analytic_local'`; Lake catalog path `us-west-2/analytic/` |
| Table | `ads_bill_line` | PySpark `TABLE_NAME = 'ads_bill_line'`; DDL `CREATE TABLE ads_bill_line` |
| Lake path | `analytic/ads-bill-line` | `repos/lake/catalog/config/prod/us-west-2/analytic/ads-bill-line/` |
| Write format | Parquet | PySpark `.write.parquet(...)` |
| S3 path | `s3://gd-ckpetlbatch-{ENV}-analytic/analytic/ads_bill_line/` | PySpark output path |
| Grain | One row per (`bill_id`, `bill_line_num`) | PySpark docstring; DDL `@PrimaryKey` annotations; DQ constraint |
| Partition | `partition_bill_mst_year_month` (string YYYY-MM) | table.yaml `partition_keys`; DDL |
| Confidence | **HIGH** | Direct write evidence in code + lake DDL match |

**Secondary write targets (non-lake):**
- `analytic_local.rs_ads_bill_line` → Redshift delta staging (dropped to S3, then upserted to `ecomm_prod.ads_bill_line`)
- `analytic_local.tmp_ads_bill_line` → in-process intermediate (DROP TABLE at job end)

---

## Step 3: Lineage Resolution

| PySpark Table | Resolved Lake Table | Path | Status |
|---|---|---|---|
| `analytic_local.ads_bill_line` | `analytic.ads_bill_line` | `us-west-2/analytic/ads-bill-line/` | ✅ TARGET |
| `ecomm360.fact_bill_line_vw` | `ecomm360.fact_bill_line_vw` | `dlms-api/us-west-2/ecomm360/fact-bill-line-vw/` | ✅ RESOLVED |
| `ecomm360.dim_bill_vw` | `ecomm360.dim_bill_vw` | `dlms-api/us-west-2/ecomm360/dim-bill-vw/` | ✅ RESOLVED |
| `bigreporting.dim_product_snap` | `bigreporting.dim_product_snap` | `us-west-2/bigreporting/dim-product-snap/` | ✅ RESOLVED |
| `bigreporting.dim_product_hist_cln` | `bigreporting.dim_product_hist_cln` | `us-west-2/bigreporting/dim-product-hist-cln/` | ✅ RESOLVED (conditional alt to dim_product_snap) |
| `dp_enterprise.dim_isc_source_code` | `dp_enterprise.dim_isc_source_code` | `us-west-2/dp-enterprise/dim-isc-source-code/` | ✅ RESOLVED |
| `partner360.dim_reseller_vw` | `partner360.dim_reseller_vw` | `dlms-api/us-west-2/partner360/dim-reseller-vw/` | ✅ RESOLVED |
| `care_mart.employee_master_snap_v3` | `care_mart.employee_master_snap_v3` | `us-west-2/care-mart/employee-master-v3/` (folder name differs; `table_relative_path = employee_master_snap_v3`) | ✅ RESOLVED (folder/name discrepancy confirmed benign) |
| `care_mart.rev_attribution` | `care_mart.rev_attribution` | `us-west-2/care-mart/rev-attribution/` | ✅ RESOLVED |
| `dm_reference.dim_geography` | `dm_reference.dim_geography` | `us-west-2/dm-reference/dim-geography/` | ✅ RESOLVED |
| `analytic_feature.customer_type` | `analytic_feature.customer_type` | `us-west-2/analytic-feature/customer-type/` | ✅ RESOLVED (code name); lake lineage uses `customer_type_history` — see discrepancy §12 of gather.md |
| `analytic_feature.customer_type_history` | `analytic_feature.customer_type_history` | `us-west-2/analytic-feature/customer-type-history/` | ✅ RESOLVED (lake lineage name) |
| `analytic_feature.shopper_crm_portfolio` | `analytic_feature.shopper_crm_portfolio` | `us-west-2/analytic-feature/shopper-crm-portfolio/` | ✅ RESOLVED |
| `analytic_feature.shopper_domain_portfolio` | `analytic_feature.shopper_domain_portfolio` | `us-west-2/analytic-feature/shopper-domain-portfolio/` | ✅ RESOLVED |
| `enterprise.free_entitlement` | `enterprise.free_entitlement` | `us-west-2/enterprise/free-entitlement/` | ✅ RESOLVED |
| `ecomm_mart.dim_bill_line_purchase_attribution` | `ecomm_mart.dim_bill_line_purchase_attribution` | `us-west-2/ecomm-mart/dim-bill-line-purchase-attribution/` | ✅ RESOLVED |
| `customers.customer_id_mapping_snapshot` | `customers.customer_id_mapping_snapshot` | `us-west-2/customers/customer-id-mapping-snapshot/` | ✅ RESOLVED |
| `gd_pro_mart.web_pro_shopper_client` | `gd_pro_mart.web_pro_shopper_client` | `us-west-2/gd-pro-mart/web-pro-shopper-client/` | ✅ RESOLVED |
| `gmode.customer_type_gcr_logic_lookup` | `gmode.customer_type_gcr_logic_lookup` | `us-west-2/gmode/customer-type-gcr-logic-lookup/` | ✅ RESOLVED |
| `callcenterreporting.rpt_c3_orders_ordersource_snap` | `callcenterreporting.rpt_c3_orders_ordersource_snap` | `us-west-2/callcenterreporting/rpt-c3-orders-ordersource-snap/` | ✅ RESOLVED |
| `dp_stage.ref_order_constant_currency` | `dp_stage.ref_order_constant_currency` | `us-west-2/dp-stage/ref-order-constant-currency/` | ✅ RESOLVED |
| `dp_stage.ref_commission_products` | `dp_stage.ref_commission_products` | `us-west-2/dp-stage/ref-commission-products/` | ✅ RESOLVED |
| `fraud_cln.fraud_note_cln` | `fraud_cln.fraud_note_cln` | `us-west-2/fraud-cln/fraud-note-cln/` | ✅ RESOLVED |
| `fraud_cln.fraud_review_history_cln` | `fraud_cln.fraud_review_history_cln` | `us-west-2/fraud-cln/fraud-review-history-cln/` | ✅ RESOLVED |
| `godaddycpl.gdshop_common_purchase_log_snap` | `godaddycpl.gdshop_common_purchase_log_snap` | `us-west-2/godaddycpl/gdshop-common-purchase-log-snap/` | ✅ RESOLVED |
| `reference_cln.tld_registry_reference_cln` | `reference_cln.tld_registry_reference_cln` | `us-west-2/reference-cln/tld-registry-reference/` (folder differs; `table_relative_path = tld_registry_reference_cln`) | ✅ RESOLVED (folder/name discrepancy confirmed benign) |
| `customer360.dim_customer_vw` | `customer360.dim_customer_vw` | `dlms-api/us-west-2/customer360/dim-customer-vw/` | ✅ RESOLVED (joined via dim_reseller_vw only) |
| `customer360.dim_customer_history_vw` | `customer360.dim_customer_history_vw` | `dlms-api/us-west-2/customer360/dim-customer-history-vw/` (inferred) | ✅ RESOLVED (filter only) |
| `callcenterreporting.rpt_c3_orders_snap` | `callcenterreporting.rpt_c3_orders_snap` | `us-west-2/callcenterreporting/rpt-c3-orders-snap/` (unconfirmed) | ⚠️ NOT CONFIRMED in lake search; used as payment processor check |
| `finance360.dim_country_vw` | — | No `finance360` schema in lake catalog | ❌ UNRESOLVED — schema not in lake catalog; joined to `dim_reseller_vw` for reseller country |
| `ecomm_core_conformed.dim_customer_registration_acquisition` | — | No `ecomm_core_conformed` schema in lake catalog | ❌ UNRESOLVED — Iceberg S3 table (per gather.md); contributes to `new_acquisition_*` fields on fact |
| `analytic_local.tmp_ads_bill_line` | N/A | In-process intermediate | ❌ NOT A LAKE TABLE — intermediate staging |
| `analytic_local.rs_ads_bill_line` | N/A | Redshift delta staging | ❌ NOT A LAKE TABLE — Redshift staging |

---

## Step 4: Dataset Classification

| Lake Table | OSI Dataset Name | Role | source | primary_key |
|---|---|---|---|---|
| `analytic.ads_bill_line` | `ads_bill_line` | **fact** (primary output) | `analytic.ads_bill_line` | [`bill_id`, `bill_line_num`] |
| `ecomm360.fact_bill_line_vw` | `fact_bill_line_vw` | **dimension** (source EDS fact, provides bill line grain) | `ecomm360.fact_bill_line_vw` | [`bill_id`, `bill_line_num`] |
| `ecomm360.dim_bill_vw` | `dim_bill_vw` | **dimension** (bill header attributes) | `ecomm360.dim_bill_vw` | [`bill_id`] |
| `bigreporting.dim_product_snap` | `dim_product_snap` | **dimension** (product catalog) | `bigreporting.dim_product_snap` | [`pf_id`] |
| `dp_enterprise.dim_isc_source_code` | `dim_isc_source_code` | **dimension** (marketing channel) | `dp_enterprise.dim_isc_source_code` | [`isc_source_code`] |
| `partner360.dim_reseller_vw` | `dim_reseller_vw` | **dimension** (reseller/private label) | `partner360.dim_reseller_vw` | [`private_label_id`] |
| `care_mart.employee_master_snap_v3` | `employee_master_snap_v3` | **dimension** (Care rep lookup) | `care_mart.employee_master_snap_v3` | [`rep_version_id`] |

**Evidence for fact classification:** PySpark writes to `analytic_local.ads_bill_line`; all upstream tables are joined to this output.

**Evidence for dimension classification:** All 6 dimension tables are LEFT JOINed into the fact — they are on the "one" side of the join; the fact has FK columns pointing to each.

---

## Materialized Direct-Reads

Lake tables read directly by the PySpark job whose attribute values are fully denormalized onto the fact with no FK preserved in the fact schema pointing back to the source table.

| Lake Table | materialized_in_fields | Evidence |
|---|---|---|
| `dm_reference.dim_geography` | `bill_country_name`, `bill_report_region_1_name`, `bill_report_region_2_name`, `bill_report_region_3_name`, `bill_report_focal_country_name`, `bill_report_sub_region_name`, `bill_domestic_international_name` | BROADCAST LEFT JOIN on `bill_country_code → country_code`; all geo attributes copied to fact |
| `analytic_feature.customer_type_history` | `customer_type_name`, `customer_type_reason_desc` | LEFT JOIN on `shopper_id`; join key not preserved in fact schema; attributes fully materialized |
| `analytic_feature.shopper_crm_portfolio` | `crm_portfolio_type_name`, `crm_portfolio_rep_id`, `crm_portfolio_rep_name`, `current_crm_portfolio_type_name`, `current_crm_portfolio_rep_id`, `current_crm_portfolio_rep_name` | LEFT JOIN on `original_shopper_id` + partition date range filter; complex time-bounded join |
| `analytic_feature.shopper_domain_portfolio` | `shopper_domain_portfolio_qty`, `shopper_domain_portfolio_segment_name` | LEFT JOIN on `original_shopper_id` + partition date range filter |
| `gd_pro_mart.web_pro_shopper_client` | `web_pro_participant_type_name`, `web_pro_shopper_id` | LEFT JOIN on `shopper_id`; date-bounded: within 7 days of bill |
| `gmode.customer_type_gcr_logic_lookup` | `pnl_usi_flag`, `pnl_gdii_flag`, `pnl_partner_flag`, `pnl_dri_flag`, `pnl_commerce_flag`, `pnl_priority_num` | BROADCAST LEFT JOIN on 7-column composite key (not a simple FK); all flags denormalized |
| `ecomm_mart.dim_bill_line_purchase_attribution` | `purchase_path_name`, `purchase_path_attributed_name`, `item_tracking_code`, `item_tracking_code_desc`, `shopper_product_purchase_type_name` | LEFT JOIN on `bill_id + bill_line_num + partition date range`; time-bounded join makes it not a simple FK |
| `enterprise.free_entitlement` | `free_trial_type_desc`, `free_trial_target_expiration_date`, `product_free_trial_acquisition_ts`, `product_free_trial_flag`, `product_free_trial_conversion_flag` | LEFT JOIN on `bill_id + bill_line_num`; CTE-aggregated before join |
| `customers.customer_id_mapping_snapshot` | `original_shopper_id`, `merged_shopper_id`, `subaccount_shopper_id`, `original_customer_id`, `merged_customer_id` | Multiple joins for shopper/customer ID resolution; intermediate `customerid` key not in fact |
| `callcenterreporting.rpt_c3_orders_ordersource_snap` | `c3_rep_name`, `c3_rep_supervisor_name`, `c3_rep_department_name`, `c3_call_center_location_name`, `c3_bill_flag`, `c3_attribution_type_name`, `c3_bill_source_code`, `c3_bill_process_name`, `c3_receipt_move_flag` | LEFT JOIN on `bill_id → order_id` with date range; `order_id` not in fact schema |
| `care_mart.rev_attribution` | `c3_bill_flag`, `c3_attribution_type_name` (C3 attribution path) | LEFT JOIN on `bill_id → order_id` with prior-day date filter; `order_id` not in fact schema |
| `dp_stage.ref_order_constant_currency` | `receipt_price_constant_currency_amt`, `gcr_constant_currency_amt` | LEFT JOIN on `trxn_currency_code → transaction_currency_code`; exchange rate lookup, computed derived fields |
| `dp_stage.ref_commission_products` | `aftermarket_seller_commission_usd_amt`, `aftermarket_seller_commission_trxn_amt` | LEFT JOIN on `pf_id`; commission flag lookup |
| `fraud_cln.fraud_note_cln` | `bill_fraud_flag`, `bill_fraud_flag_ts`, `bill_fraud_flag_date`, `bill_fraud_review_id` | LEFT JOIN on `bill_id → order_id` (different column name); fraud attributes copied to fact |
| `fraud_cln.fraud_review_history_cln` | `bill_fraud_review_id` (confirmation) | LEFT JOIN on `fraud_review_id`; dedup via ROW_NUMBER() |
| `godaddycpl.gdshop_common_purchase_log_snap` | `primary_payment_type_name`, `primary_payment_subtype_name`, `secondary_payment_type_name`, `secondary_payment_subtype_name`, `bill_payment_processor_name`, `bill_payment_processor_common_name`, `bill_payment_cpl_trxn_currency_code`, `bill_payment_cpl_trxn_amt` | LEFT JOIN on `bill_id`; payment processor details copied to fact |

---

## Excluded Dimensions

Lake tables that are direct reads but NOT included as OSI datasets because they have no FK preserved in the fact schema or because the join is transitive (through another table).

| Lake Table | Reason | fields_on_fact |
|---|---|---|
| `customer360.dim_customer_vw` | Joined only to `partner360.dim_reseller_vw` (not directly to fact); transitive via reseller_customer_id; no direct FK in fact | `reseller_shopper_id` (indirectly) |
| `customer360.dim_customer_history_vw` | Used only as a deduplication filter (`internal_shopper_flag`, `current_record_flag`); no FK in fact schema | `original_shopper_id`, `merged_shopper_id` |
| `finance360.dim_country_vw` | NOT FOUND in lake catalog (no `finance360` schema); joined only via `dim_reseller_vw`, not directly to fact | `reseller_country_code`, `reseller_country_name` |
| `ecomm_core_conformed.dim_customer_registration_acquisition` | NOT FOUND in lake catalog (no `ecomm_core_conformed` schema); Iceberg S3 table; contributes new acquisition fields to fact | `new_acquisition_flag`, `new_registered_user_flag`, `new_acquisition_bill_id`, `new_acquisition_bill_mst_date`, `new_registered_user_bill_id`, `new_registered_user_bill_mst_date`, `new_acquisition_bill_country_code`, `federation_partner_id`, `federation_friendly_name` |
| `callcenterreporting.rpt_c3_orders_snap` | Not confirmed in lake catalog; used as alternative C3 orders check (payment processor path); results fully materialized | `bill_payment_processor_common_name` (partial) |
| `reference_cln.tld_registry_reference_cln` | Joined via `bigreporting.dim_product_snap` (not directly to fact); transitive; domain registry attributes on fact | `domain_back_end_registry_name`, `domain_front_end_registry_name`, `domain_registry_family_name`, `domain_parent_tld_name` |

---

## Step 5: Relationships

| name | from | to | from_columns | to_columns | evidence |
|---|---|---|---|---|---|
| `ads_bill_line_to_fact_bill_line_vw` | `ads_bill_line` | `fact_bill_line_vw` | [`bill_id`, `bill_line_num`] | [`bill_id`, `bill_line_num`] | PySpark: fact grain `bill_id + bill_line_num`; EDS source of ADS fact |
| `ads_bill_line_to_dim_bill_vw` | `ads_bill_line` | `dim_bill_vw` | [`bill_id`] | [`bill_id`] | PySpark: `fact_bill_line_vw JOIN dim_bill_vw ON bill_id` (LEFT JOIN) |
| `ads_bill_line_to_dim_product_snap` | `ads_bill_line` | `dim_product_snap` | [`pf_id`] | [`pf_id`] | PySpark: BROADCAST LEFT JOIN `dim_product_snap ON pf_id`; `@ForeignKey(dim_product)` in fact_bill_line_vw DDL |
| `ads_bill_line_to_dim_isc_source_code` | `ads_bill_line` | `dim_isc_source_code` | [`bill_isc_source_code`] | [`isc_source_code`] | PySpark: LEFT JOIN `dim_isc_source_code ON bill_isc_source_code = isc_source_code` |
| `ads_bill_line_to_dim_reseller_vw` | `ads_bill_line` | `dim_reseller_vw` | [`private_label_id`] | [`private_label_id`] | PySpark: LEFT JOIN `dim_reseller_vw ON private_label_id`; `@PrimaryKey private_label_id` in dim DDL |
| `ads_bill_line_to_employee_master_snap_v3` | `ads_bill_line` | `employee_master_snap_v3` | [`rep_version_id`] | [`rep_version_id`] | PySpark: LEFT JOIN `employee_master_snap_v3 ON rep_version_id` via dim_bill_vw |

---

## Step 6: Field Inventory

### Dataset: `ads_bill_line` (fact — `analytic.ads_bill_line`)

Primary key: `bill_id`, `bill_line_num` | Partition: `partition_bill_mst_year_month`

Full column list from `repos/lake/catalog/config/prod/us-west-2/analytic/ads-bill-line/table.ddl`:

**Identity / Keys**
| Field name | Type | is_time | Description |
|---|---|---|---|
| `bill_id` | string | | Unique ID for bill (order). Composite PK with bill_line_num |
| `bill_line_num` | int | | Line number within bill. Composite PK with bill_id |
| `pf_id` | int | | Product family ID for product purchased |
| `private_label_id` | int | | ID for private label (reseller or white-label) partner for bill line |
| `original_shopper_id` | string | | Shopper ID at original bill creation |
| `merged_shopper_id` | string | | Current post-merge shopper ID on bill |
| `original_customer_id` | string | | Customer ID at original bill creation |
| `merged_customer_id` | string | | Current post-merge customer ID on bill |
| `subaccount_shopper_id` | string | | Shopper ID for subaccount for bill |
| `rep_version_id` | int | | Care rep version ID on bill |
| `bill_isc_source_code` | string | | Internal or internet source code (ISC) for bill |

**Bill Attributes**
| Field name | Type | is_time | Description |
|---|---|---|---|
| `bill_modified_mst_date` | date | ✓ | MST date of bill creation or last modification |
| `bill_modified_mst_ts` | timestamp | ✓ | MST timestamp of bill creation or last modification |
| `bill_modified_mst_date_prior_year` | date | ✓ | Bill modification date shifted back one year for YoY comparison |
| `bill_country_code` | string | | ISO country code of payment instrument address |
| `bill_source_name` | string | | Point-of-sale channel or purchase origin |
| `entered_by_name` | string | | Entity or role that submitted bill |
| `source_system_name` | string | | Originating system name |
| `trxn_currency_code` | string | | ISO 4217 currency code |
| `translation_language_name` | string | | Language of customer browser at purchase |
| `bill_sub_geo_code` | string | | Sub-geography code for payment instrument address |
| `bill_postal_code` | string | | Postal code for payment instrument address |
| `bill_site_language_code` | string | | Language locale code of website where bill was submitted |
| `item_tracking_code` | string | | Item tracking code for bill line |
| `item_tracking_code_desc` | string | | ITC description |
| `purchase_path_name` | string | | GoDaddy website location where product was added to cart |
| `purchase_path_attributed_name` | string | | Attributed purchase path (first non-Cart for Cart New Purchase) |
| `point_of_purchase_name` | string | | Point of purchase derived from source/entered_by/bill_source |
| `sub_point_of_purchase_name` | string | | Sub-category of point of purchase |
| `department_id` | int | | Business dept ID responsible for bill line |
| `accounting_company_id` | int | | Accounting company ID for GD legal entity |
| `original_bill_id` | string | | For refunds/chargebacks, original bill ID |
| `original_bill_line_num` | int | | For refunds/chargebacks, original bill line num |
| `intent` | string | | Intent for virtual bill line |
| `related_subscription` | string | | Subscription ID linking virtual bill to customer subscription |

**Financial Amounts**
| Field name | Type | is_time | Description |
|---|---|---|---|
| `receipt_price_usd_amt` | decimal(18,2) | | Amount paid in USD after discounts |
| `receipt_price_trxn_amt` | decimal(18,2) | | Amount paid in transaction currency after discounts |
| `receipt_price_constant_currency_amt` | decimal(18,2) | | Amount paid using constant FX rate (YoY) |
| `receipt_regular_price_usd_amt` | decimal(18,2) | | Current selling price in USD |
| `receipt_regular_price_trxn_amt` | decimal(18,2) | | Current selling price in trxn currency |
| `gcr_usd_amt` | decimal(18,2) | | Gross Cash Receipts in USD |
| `gcr_trxn_amt` | decimal(18,2) | | GCR in transaction currency |
| `gcr_constant_currency_amt` | decimal(18,2) | | GCR using constant FX rate |
| `margin_gcr_usd_amt` | decimal(18,2) | | GCR margin in USD (after COGS) |
| `margin_gcr_trxn_amt` | decimal(18,2) | | GCR margin in transaction currency |
| `msrp_total_usd_amt` | decimal(18,2) | | Full list price in USD |
| `msrp_total_trxn_amt` | decimal(18,2) | | Full list price in transaction currency |
| `msrp_duration_unit_usd_amt` | decimal(18,2) | | List price for single billing-period unit in USD |
| `msrp_duration_unit_trxn_amt` | decimal(18,2) | | List price for single billing-period unit in trxn currency |
| `fair_market_value_usd_amt` | decimal(18,2) | | Fair market value in USD |
| `fair_market_value_trxn_amt` | decimal(18,2) | | Fair market value in transaction currency |
| `tax_usd_amt` | decimal(18,2) | | Tax charged in USD |
| `tax_trxn_amt` | decimal(18,2) | | Tax charged in transaction currency |
| `commission_usd_amt` | decimal(18,2) | | Commission owed to 3rd party in USD |
| `commission_trxn_amt` | decimal(18,2) | | Commission owed to 3rd party in trxn currency |
| `aftermarket_seller_commission_usd_amt` | decimal(18,2) | | Commission paid to domain aftermarket seller in USD |
| `aftermarket_seller_commission_trxn_amt` | decimal(18,2) | | Commission paid to domain aftermarket seller in trxn currency |
| `cost_usd_amt` | decimal(18,2) | | Cost of goods sold in USD |
| `cost_trxn_amt` | decimal(18,2) | | Cost of goods sold in transaction currency |
| `fee_usd_amt` | decimal(18,2) | | Fee in USD (typically ICANN fee) |
| `fee_trxn_amt` | decimal(18,2) | | Fee in transaction currency |
| `injected_fair_market_value_usd_amt` | decimal(18,2) | | System-injected FMV adjustment in USD |
| `injected_fair_market_value_trxn_amt` | decimal(18,2) | | System-injected FMV adjustment in trxn currency |
| `injected_icann_fee_usd_amt` | decimal(18,2) | | System-injected ICANN fee in USD |
| `injected_icann_fee_trxn_amt` | decimal(18,2) | | System-injected ICANN fee in trxn currency |
| `injected_tax_usd_amt` | decimal(18,2) | | System-injected tax in USD |
| `injected_tax_trxn_amt` | decimal(18,2) | | System-injected tax in trxn currency |
| `bundle_allocated_revenue_usd_amt` | decimal(18,2) | | Revenue allocated within bundle in USD |
| `reseller_commission_usd_amt` | decimal(18,2) | | Commission earned by reseller in USD |
| `parent_reseller_commission_usd_amt` | decimal(18,2) | | Commission earned by parent reseller in USD |

**Product / PnL**
| Field name | Type | is_time | Description |
|---|---|---|---|
| `product_pnl_group_name` | string | | 1st level Finance PnL hierarchy |
| `product_pnl_category_name` | string | | 2nd level Finance PnL hierarchy |
| `product_pnl_line_name` | string | | 3rd level Finance PnL hierarchy |
| `product_pnl_subline_name` | string | | 4th level Finance PnL hierarchy |
| `product_pnl_version_name` | string | | Flexible pseudo-level of PnL hierarchy |
| `product_pnl_new_renewal_name` | string | | New or renewal designation for product |
| `original_product_pnl_new_renewal_name` | string | | Identifies product as new or renewal (original) |
| `pnl_new_renewal` | string | | New or renewal designation (legacy) |
| `product_name` | string | | Product name for purchased product |
| `product_type_desc` | string | | Product type description |
| `product_type_id` | double | | Product type ID |
| `product_term_num` | int | | Number of billing periods |
| `product_term_unit_desc` | string | | Billing period unit (month/quarter/year) |
| `unit_qty` | int | | Units purchased |
| `product_unit_qty` | int | | Unit qty adjusted for units-as-orders products |
| `duration_qty` | decimal(18,3) | | Subscription period units |
| `product_month_qty` | decimal(18,2) | | Calendar months in subscription period |
| `upgraded_pf_id` | int | | pf_id of product upgrading from (legacy) |
| `offer_id` | int | | ID for bundle product was included in |
| `offer_collection_id` | int | | ID for parent offer collection |
| `free_product_package_id` | int | | ID for free product package |
| `variant_price_type_id` | int | | Variant price type ID |
| `variant_price_type_name` | string | | Variant price type name |

**Geography**
| Field name | Type | is_time | Description |
|---|---|---|---|
| `bill_country_name` | string | | Country name from geo dim |
| `bill_report_region_1_name` | string | | 1st-level geo reporting region |
| `bill_report_region_2_name` | string | | 2nd-level geo reporting region |
| `bill_report_region_3_name` | string | | 3rd-level geo reporting region |
| `bill_report_focal_country_name` | string | | Focal country name for geo reporting |
| `bill_report_sub_region_name` | string | | Sub-region name for geo reporting |
| `bill_domestic_international_name` | string | | Domestic or International classification |

**Customer Type / PnL Segments**
| Field name | Type | is_time | Description |
|---|---|---|---|
| `customer_type_name` | string | | Customer type assigned at bill time |
| `customer_type_reason_desc` | string | | Reason for type assignment |
| `pnl_usi_flag` | boolean | | True if USI (US Independent) PnL segment |
| `pnl_gdii_flag` | boolean | | True if GDII (GD International Independent) PnL segment |
| `pnl_partner_flag` | boolean | | True if Partner PnL segment |
| `pnl_dri_flag` | boolean | | True if DRI PnL segment |
| `pnl_commerce_flag` | boolean | | True if Commerce PnL segment |
| `pnl_priority_num` | int | | Priority number for PnL segment assignment |

**ISC / Marketing**
| Field name | Type | is_time | Description |
|---|---|---|---|
| `bill_isc_source_code_desc` | string | | Description of ISC |
| `bill_isc_company_id` | int | | Company ID for ISC on bill |
| `bill_isc_campaign_id` | int | | Campaign ID for ISC on bill |
| `bill_isc_channel_id` | int | | Channel ID for ISC on bill |
| `bill_isc_product_id` | int | | Product ID for ISC on bill |
| `bill_isc_vendor_id` | int | | Vendor ID for ISC on bill |
| `bill_isc_media_specialist_id` | int | | Media specialist ID for ISC on bill |
| `bill_isc_sub_channel_id` | int | | Sub-channel ID for ISC on bill |
| `bill_isc_channel_name` | string | | Marketing channel for ISC on bill |
| `bill_isc_sub_channel_name` | string | | Marketing sub-channel for ISC on bill |
| `bill_isc_vendor_name` | string | | Vendor name for ISC on bill |
| `bill_isc_product_name` | string | | Product name for ISC on bill |
| `bill_isc_media_specialist_name` | string | | Media specialist name for ISC (PII encrypted) |
| `bill_isc_viral_flag` | boolean | | True if ISC classified as viral marketing |

**Reseller**
| Field name | Type | is_time | Description |
|---|---|---|---|
| `reseller_type_name` | string | | Reseller type |
| `reseller_name` | string | | Reseller name |
| `reseller_shopper_id` | string | | Reseller shopper ID for bill |
| `reseller_country_code` | string | | Country code of first paid reseller bill |
| `reseller_country_name` | string | | Country name of first paid reseller bill |

**Care / C3**
| Field name | Type | is_time | Description |
|---|---|---|---|
| `c3_rep_name` | string | | Care rep name (PII encrypted) |
| `c3_rep_supervisor_name` | string | | Supervisor name (PII encrypted) |
| `c3_rep_department_name` | string | | Care rep department |
| `c3_call_center_location_name` | string | | Call center location |
| `c3_bill_flag` | boolean | | True if attributed to Care rep |
| `c3_attribution_type_name` | string | | Care revenue attribution type |
| `c3_bill_source_code` | string | | Code showing how Care attributed bill |
| `c3_bill_process_name` | string | | Describes how Care attributed bill |
| `c3_receipt_move_flag` | boolean | | True if bill attributed to Care retroactively |

**New Acquisition / Registration**
| Field name | Type | is_time | Description |
|---|---|---|---|
| `new_acquisition_bill_id` | string | | Bill ID for first paid purchase by customer |
| `new_acquisition_bill_country_code` | string | | Bill country code for first paid purchase |
| `new_acquisition_bill_mst_date` | date | ✓ | MST date for first paid purchase |
| `new_registered_user_bill_id` | string | | Bill ID created when customer initially registered |
| `new_registered_user_bill_mst_date` | date | ✓ | MST date for new registered user bill |
| `federation_partner_id` | string | | ID for federation partner for bill |
| `federation_friendly_name` | string | | Name of federation partner |

**Web Pro / Portfolio**
| Field name | Type | is_time | Description |
|---|---|---|---|
| `web_pro_participant_type_name` | string | | For Web Pro bills: Pro or Client initiated purchase |
| `web_pro_shopper_id` | string | | Web Pro shopper ID for bill |
| `shopper_domain_portfolio_qty` | int | | Number of domains in customer portfolio at bill time |
| `shopper_domain_portfolio_segment_name` | string | | Domain portfolio segment at bill time |
| `crm_portfolio_type_name` | string | | CRM portfolio type at bill time |
| `crm_portfolio_rep_id` | int | | CRM portfolio care rep ID at bill time |
| `crm_portfolio_rep_name` | string | | CRM portfolio care rep name (PII encrypted) |
| `current_crm_portfolio_type_name` | string | | Current CRM portfolio type |
| `current_crm_portfolio_rep_id` | int | | Current CRM portfolio care rep ID |
| `current_crm_portfolio_rep_name` | string | | Current CRM portfolio care rep name (PII encrypted) |

**Domain**
| Field name | Type | is_time | Description |
|---|---|---|---|
| `domain_back_end_registry_name` | string | | Back-end registry name for TLD |
| `domain_front_end_registry_name` | string | | Front-end registry name for TLD |
| `domain_registry_family_name` | string | | Registry family name for TLD |
| `domain_parent_tld_name` | string | | Parent TLD for domain on bill |
| `domain_bulk_pricing_flag` | boolean | | True if product type ID is 4 or 5 |

**Payment**
| Field name | Type | is_time | Description |
|---|---|---|---|
| `primary_payment_type_name` | string | | Payment method type for highest value payment |
| `primary_payment_subtype_name` | string | | Subtype of primary payment method |
| `secondary_payment_type_name` | string | | Payment method type for second highest payment |
| `secondary_payment_subtype_name` | string | | Subtype of secondary payment method |
| `bill_payment_processor_name` | string | | Name of payment processor used |
| `bill_payment_processor_common_name` | string | | Common display name of payment processor |
| `bill_payment_cpl_trxn_currency_code` | string | | Currency code from CPL transaction |
| `bill_payment_cpl_trxn_amt` | decimal(18,2) | | Transaction amount from CPL |

**Free Trial**
| Field name | Type | is_time | Description |
|---|---|---|---|
| `free_trial_type_desc` | string | | Description of free trial type |
| `free_trial_target_expiration_date` | date | ✓ | Target expiration date of free trial |
| `product_free_trial_acquisition_ts` | timestamp | ✓ | Timestamp of original free trial bill |
| `free_trial_bill_type` | string | | Bill type for free trial bill |
| `free_trial_bill_date` | date | ✓ | Date of free trial bill |

**Flags**
| Field name | Type | is_time | Description |
|---|---|---|---|
| `refund_flag` | boolean | | Is a refund transaction |
| `chargeback_flag` | boolean | | Is a chargeback transaction |
| `virtual_bill_flag` | boolean | | Is a virtual bill (no payment) |
| `new_acquisition_flag` | boolean | | True if bill was first paid customer purchase |
| `new_registered_user_flag` | boolean | | True when customer initially registered |
| `bill_fraud_flag` | boolean | | Flagged as fraudulent |
| `bill_fraud_flag_ts` | timestamp | ✓ | Timestamp when bill was flagged fraudulent |
| `bill_fraud_flag_date` | date | ✓ | Date when bill was flagged fraudulent |
| `bill_fraud_review_id` | int | | Fraud review ID |
| `domain_bulk_flag` | boolean | | True if total non-refund domain reg units >= 50 |
| `free_bill_flag` | boolean | | True if no GCR on entire bill |
| `free_bill_line_flag` | boolean | | True for non-virtual bill line with receipt price = 0 and GCR = 0 |
| `free_bill_line_with_fair_market_value_flag` | boolean | | True for non-virtual bill line with receipt price = 0 but GCR > 0 |
| `product_free_trial_flag` | boolean | | True for bills that initiated free trial |
| `product_free_trial_conversion_flag` | boolean | | True if converted from free trial to paid |
| `product_free_term_flag` | boolean | | True for products free for first billing period |
| `accounting_deferred_flag` | boolean | | Revenue is deferred |
| `primary_product_flag` | boolean | | True for primary products (not add-ons) |
| `renewal_price_locked_flag` | boolean | | Renewal price is locked |
| `units_as_bills_flag` | boolean | | True if purchase is for 1 resource regardless of qty |
| `c3_bill_flag` | boolean | | True if bill is attributed to Care rep |

**Exclusion**
| Field name | Type | is_time | Description |
|---|---|---|---|
| `exclude_reason_desc` | string | | Reason bill line is excluded from reporting |
| `exclude_reason_month_end_desc` | string | | Month-end exclusion reason |
| `original_shopper_exclude_reason_desc` | string | | Reason bill line excluded based on original shopper ID |
| `original_shopper_exclude_reason_month_end_desc` | string | | Month-end exclusion reason for original shopper |
| `item_discount_code` | string | | Discount code applied to bill line |
| `item_redemption_code` | string | | Code used after purchase to claim or activate item |
| `shopper_product_purchase_type_name` | string | | Customer purchase type for bill line |

**ETL Metadata**
| Field name | Type | is_time | Description |
|---|---|---|---|
| `etl_build_mst_ts` | timestamp | ✓ | Timestamp when record was last updated by ETL process |
| `source_process_name` | string | | Name of the ETL process |

**Partition**
| Field name | Type | is_time | Description |
|---|---|---|---|
| `partition_bill_mst_year_month` | string | ✓ | Year-month partition key (YYYY-MM) |

---

### Dataset: `fact_bill_line_vw` (dimension — `ecomm360.fact_bill_line_vw`)

Primary key: `bill_id`, `bill_line_num` | Source: `dlms-api/us-west-2/ecomm360/fact-bill-line-vw/table.ddl`

Key fields (abbreviated — see DDL for full list):

| Field name | Type | is_time | Description |
|---|---|---|---|
| `bill_id` | string | | Unique identifier for a bill. Composite PK with bill_line_num |
| `bill_line_num` | int | | Line number within bill. Composite PK with bill_id |
| `pf_id` | int | | Product Family ID. FK to dim_product |
| `private_label_id` | int | | Private label (reseller) partner ID |
| `bill_country_code` | string | | ISO country code of payment instrument |
| `bill_isc_source_code` | string | | Internal/internet source code |
| `bill_modified_mst_ts` | timestamp | ✓ | Bill timestamp in MST |
| `bill_modified_mst_date` | date | ✓ | Bill date in MST |
| `subaccount_customer_id` | string | | Customer ID for subaccount |
| `trxn_currency_code` | string | | ISO 4217 currency code |
| `receipt_price_usd_amt` | double | | Amount paid in USD after discounts |
| `gcr_usd_amt` | double | | Gross Cash Receipts in USD |
| `refund_flag` | boolean | | Is a refund transaction |
| `chargeback_flag` | boolean | | Is a chargeback transaction |
| `virtual_order_flag` | boolean | | Is a virtual or receiptless bill |
| `etl_insert_utc_ts` | timestamp | ✓ | ETL insert timestamp (UTC) |
| `etl_update_utc_ts` | timestamp | ✓ | ETL update timestamp (UTC) |

*Full DDL has ~58 columns. Complete list at `dlms-api/us-west-2/ecomm360/fact-bill-line-vw/table.ddl`.*

---

### Dataset: `dim_bill_vw` (dimension — `ecomm360.dim_bill_vw`)

Primary key: `bill_id` | Source: `dlms-api/us-west-2/ecomm360/dim-bill-vw/table.ddl`

| Field name | Type | is_time | Description |
|---|---|---|---|
| `bill_id` | string | | PK — Unique identifier for a customer bill |
| `event_id` | string | | Unique identifier for event that created/modified bill |
| `original_shopper_id` | string | | Shopper ID at original bill creation |
| `original_customer_id` | string | | Customer ID at original bill creation |
| `merged_shopper_id` | string | | Current post-merge shopper ID |
| `merged_customer_id` | string | | Current post-merge customer ID |
| `rep_version_id` | int | | Care representative version ID on bill |
| `bill_modified_mst_date` | date | ✓ | Date bill was last modified in MST |
| `current_record_flag` | boolean | | SCD2 flag: TRUE = current active record |
| `etl_insert_utc_ts` | timestamp | ✓ | ETL insert timestamp (UTC) |
| `etl_update_utc_ts` | timestamp | ✓ | ETL update timestamp (UTC) |

---

### Dataset: `dim_product_snap` (dimension — `bigreporting.dim_product_snap`)

Primary key: `pf_id` (product family ID, join key) | Source: `us-west-2/bigreporting/dim-product-snap/table.ddl`

| Field name | Type | is_time | Description |
|---|---|---|---|
| `pf_id` | int | | Product family ID (join key) |
| `product_key` | bigint | | Surrogate key |
| `productname` | string | | Product name |
| `productfamily` | string | | Product family name |
| `productcategory` | string | | Product category |
| `productsubcategory` | string | | Product subcategory |
| `productgroup` | string | | Product group |
| `productline` | string | | Product line |
| `period` | string | | Billing period unit |
| `numberofperiods` | int | | Number of billing periods |
| `new_renewal` | string | | New or renewal designation |
| `pnl_group` | string | | PnL group |
| `pnl_category` | string | | PnL category |
| `pnl_line` | string | | PnL line |
| `pnl_subline` | string | | PnL subline (used for TLD lookup) |
| `pnl_version` | string | | PnL version |
| `pnl_new_renewal` | string | | PnL new/renewal designation |
| `gdshop_product_typeid` | double | | GDShop product type ID |
| `gdshop_product_type_description` | string | | GDShop product type description |
| `dept_id` | int | | Department ID |
| `dept_name` | string | | Department name |
| `unitsasorders` | boolean | | True if units-as-orders product |
| `isprimaryproduct` | smallint | | Is primary product flag |
| `createdate` | timestamp | ✓ | Product creation date |
| `updatedate` | timestamp | ✓ | Product update date |
| `deletedate` | timestamp | ✓ | Product delete date |

---

### Dataset: `dim_isc_source_code` (dimension — `dp_enterprise.dim_isc_source_code`)

Primary key: `isc_source_code` | Source: `us-west-2/dp-enterprise/dim-isc-source-code/table.ddl`

| Field name | Type | is_time | Description |
|---|---|---|---|
| `isc_source_code` | string | | ISC code (join key from bill_isc_source_code) |
| `isc_description` | string | | ISC description |
| `isc_channel_id` | int | | Channel ID |
| `isc_channel_name` | string | | Marketing channel name |
| `isc_sub_channel_id` | int | | Sub-channel ID |
| `isc_sub_channel_name` | string | | Marketing sub-channel name |
| `isc_vendor_id` | int | | Vendor ID |
| `isc_vendor_name` | string | | Vendor name |
| `isc_product_id` | int | | Product ID |
| `isc_product_name` | string | | Product name |
| `isc_company_id` | int | | Company ID |
| `isc_campaign_id` | int | | Campaign ID |
| `isc_campaign_name` | string | | Campaign name |
| `isc_media_specialist_id` | int | | Media specialist ID |
| `isc_media_specialist_name` | string | | Media specialist name |
| `isc_media_specialist_name_encrypt` | string | | Media specialist name (encrypted) |
| `isc_viral_flag` | boolean | | True if classified as viral marketing |
| `isc_acquisition_tier_name` | string | | Acquisition tier name |
| `isc_country_code` | string | | Country code |
| `isc_country_name` | string | | Country name |
| `isc_domestic_international_name` | string | | Domestic or International classification |
| `isc_region_1_name` | string | | 1st-level region |
| `isc_region_2_name` | string | | 2nd-level region |

---

### Dataset: `dim_reseller_vw` (dimension — `partner360.dim_reseller_vw`)

Primary key: `private_label_id` | Source: `dlms-api/us-west-2/partner360/dim-reseller-vw/table.ddl`

| Field name | Type | is_time | Description |
|---|---|---|---|
| `private_label_id` | int | | PK — Used to distinguish brands and resellers |
| `reseller_type_id` | int | | Reseller type identifier |
| `reseller_type_name` | string | | Reseller type name |
| `reseller_name` | string | | Reseller name |
| `reseller_customer_id` | string | | Customer UUID for reseller account |
| `status_id` | smallint | | Current state of reseller (50=active, 51=cancelled) |
| `program_id` | string | | Program identifier for storefront proxy |
| `display_name` | string | | Configured display name |
| `company_name` | string | | Company name |
| `market_site_code` | string | | Site market/locale |
| `customer_support_opt_out_flag` | boolean | | Customer opted out of support |
| `cross_sell_flag` | boolean | | Opted into cross-selling GD products |
| `email_opt_in_flag` | boolean | | Email marketing preference flag |
| `current_record_flag` | boolean | | True if current active customer record |
| `etl_build_mst_ts` | timestamp | ✓ | ETL build timestamp in MST |

*(Other URL/branding columns omitted for brevity — 39 columns total in DDL)*

---

### Dataset: `employee_master_snap_v3` (dimension — `care_mart.employee_master_snap_v3`)

Primary key: `rep_version_id` (join key) | Source: `us-west-2/care-mart/employee-master-v3/table.ddl`

| Field name | Type | is_time | Description |
|---|---|---|---|
| `worker_id` | string | | PK UUID identifying the employee |
| `employee_id` | int | | Employee ID |
| `rep_version_id` | int | | Rep version ID (join key from fact) |
| `rep_version_order_id` | int | | Rep version order ID |
| `active_flag` | boolean | | Is employee currently active |
| `employee_full_name_encrypt` | string | | Employee full name (encrypted PII) |
| `employee_last_name_encrypt` | string | | Employee last name (encrypted PII) |
| `employee_first_name_encrypt` | string | | Employee first name (encrypted PII) |
| `supervisor_manager_user_id` | int | | Supervisor manager user ID |
| `supervisor_employee_id` | int | | Supervisor employee ID |
| `supervisor_full_name_encrypt` | string | | Supervisor full name (encrypted PII) |
| `department_id` | string | | Department ID |
| `rollup_department_name` | string | | Rollup department name |
| `management_unit_id` | string | | Management unit ID |
| `management_unit_name` | string | | Management unit name |
| `location_id` | string | | Location ID |
| `location_name` | string | | Location name |
| `region_name` | string | | Employee region name |
| `rep_type_id` | int | | Agent rep type ID |
| `rep_type_name` | string | | Agent rep type name |
| `job_code` | string | | Job code |
| `job_title_name` | string | | Job title |
| `job_effective_mst_date` | date | ✓ | Job effective date in MST |
| `start_mst_ts` | timestamp | ✓ | Employee start timestamp in MST |
| `end_mst_ts` | timestamp | ✓ | Employee end timestamp in MST |
| `snapshot_mst_ts` | timestamp | ✓ | Snapshot timestamp in MST |
| `etl_build_utc_ts` | timestamp | ✓ | ETL build timestamp (UTC) |

---

## Step 7: Metrics

| name | expression | description | evidence |
|---|---|---|---|
| `total_gcr_usd_amt` | `SUM(ads_bill_line.gcr_usd_amt)` | Total Gross Cash Receipts in USD for all bill lines in the selection. GCR is NULL for refund and chargeback transactions | DDL: `gcr_usd_amt` column; Alation description: "GCR metrics are NULL for refunds and chargebacks" |
| `total_receipt_price_usd_amt` | `SUM(ads_bill_line.receipt_price_usd_amt)` | Total amount paid in USD after discounts | DDL: `receipt_price_usd_amt` column; primary revenue metric |
| `total_gcr_constant_currency_amt` | `SUM(ads_bill_line.gcr_constant_currency_amt)` | Total GCR using constant foreign exchange rate for year-over-year comparison | DDL: `gcr_constant_currency_amt`; derived in PySpark via `ref_order_constant_currency` join |
| `total_margin_gcr_usd_amt` | `SUM(ads_bill_line.margin_gcr_usd_amt)` | Total GCR margin in USD after subtracting cost of goods sold. Note: cost approximation for domains | DDL: `margin_gcr_usd_amt` column |
| `bill_line_count` | `COUNT(*)` | Total number of bill lines (grain is one row per bill line) | PySpark grain: `bill_id + bill_line_num`; DQ constraint confirms uniqueness |
| `new_acquisition_count` | `COUNT(DISTINCT CASE WHEN ads_bill_line.new_acquisition_flag = TRUE THEN ads_bill_line.bill_id END)` | Count of distinct new customer acquisition bills (first paid purchase). Note: shopper merges may create two bills with new_acquisition_flag=true per customer | DDL: `new_acquisition_flag` column comment: "cust counts should count(distinct bill_id) where new_acquisition_flag=true" |
| `total_unit_qty` | `SUM(ads_bill_line.unit_qty)` | Total units purchased across all bill lines | DDL: `unit_qty` column; standard product volume metric |
| `total_tax_usd_amt` | `SUM(ads_bill_line.tax_usd_amt)` | Total tax charged in USD | DDL: `tax_usd_amt` column |

---

## Step 8: Semantic Model Metadata

**Model name:** `analytic_ads_bill_line`
- Derived from: schema `analytic` + table `ads_bill_line` (no override in INPUT.md)

**Model description:**
> Analytic Data Set (ADS) for eCommerce bill lines. Augments core Enterprise Fact Bill / Fact Bill Line entities (ecomm360 EDS layer) with pre-joined dimensions including Customer Type, Finance PnL hierarchy, Geography, Reseller/Partner info, ISC/Marketing attribution, Care (C3) attribution, fraud flags, and Web Pro indicators. One row per bill line (bill_id + bill_line_num). Replaces the legacy UDS Order. Refreshed daily by 7:00 AM MST. Tier 2 data product owned by the Emerald Data Team (eComm domain).

**ai_context draft:**
```yaml
ai_context:
  instructions: >
    Use this model to analyze eCommerce transactions at the bill line level.
    Filter by partition_bill_mst_year_month for performance on large queries.
    Exclude refunds and chargebacks using refund_flag=false AND chargeback_flag=false
    for revenue analysis. GCR metrics are NULL for refunds/chargebacks.
    Use gcr_usd_amt for primary revenue; gcr_constant_currency_amt for YoY comparisons.
    new_acquisition_flag counts may double for shoppers with account merges;
    use COUNT(DISTINCT bill_id) WHERE new_acquisition_flag=true for new customer counts.
    Web Pro orders reflect current opt-in status, not status at order time.
  synonyms:
    - "ADS bill line"
    - "ads_bill_line"
    - "analytic bill line"
    - "ecommerce orders"
    - "ecomm transactions"
    - "UDS order replacement"
    - "bill line analytics"
    - "order revenue"
  examples:
    - "What is total GCR by product PnL category last month?"
    - "Show new customer acquisition count by region this year"
    - "What is the revenue breakdown by reseller type?"
    - "How many domain purchases had bulk pricing last quarter?"
    - "What is the Care rep attribution rate for US customers?"
    - "Show YoY constant currency revenue by market region"
    - "What is the average receipt price for renewal vs new products?"
```

---

## Step 9: Do-Not-Claim Table

| item | reason | preserve_as |
|---|---|---|
| `analytic_local.tmp_ads_bill_line` as OSI dataset | Intermediate table created and dropped within the same PySpark job; never persisted to lake catalog | `custom_extensions` |
| `analytic_local.rs_ads_bill_line` as OSI dataset | Redshift delta staging artifact; written to S3 then upserted to Redshift `ecomm_prod.ads_bill_line`; not a lake catalog table | `custom_extensions` |
| `ecomm_prod.ads_bill_line` as OSI dataset | Redshift destination copy of lake table; downstream Redshift target, not a lake table | `ai_context` |
| `dna_approved.bill_line` as OSI dataset | Redshift materialized view recreated post-upsert; not a lake table | `ai_context` |
| `dna_approved.uds_order` as OSI dataset | Redshift materialized view recreated post-upsert; not a lake table | `ai_context` |
| `ecomm_core_conformed.dim_customer_registration_acquisition` as OSI dataset | Not found in lake catalog (no schema in registry); Iceberg S3 table used for new_acquisition derivation; attributes fully materialized onto fact | `custom_extensions` |
| `finance360.dim_country_vw` as OSI dataset | Not found in lake catalog (no finance360 schema); joined only via dim_reseller_vw (transitive), not directly to fact | `custom_extensions` |
| `customer360.dim_customer_vw` as OSI relationship | Joined only to `dim_reseller_vw` (to get `reseller_shopper_id`); not directly joined from fact; no direct FK in `ads_bill_line` to customer360 | `field_description` |
| `customer360.dim_customer_history_vw` as OSI dataset | Used for shopper deduplication filter only (`internal_shopper_flag`, `current_record_flag`); no FK preserved in fact schema | `field_description` |
| `analytic_feature.customer_type` as separate OSI dataset | Code–vs–lake-lineage discrepancy (code: `customer_type`, lake lineage: `customer_type_history`); attributes fully materialized onto fact; no FK preserved in fact schema pointing back to either table | `custom_extensions` |
| `callcenterreporting.rpt_c3_orders_snap` as OSI dataset | Not confirmed in lake search; used as alternative C3/payment processor check; all attributes materialized onto fact | `custom_extensions` |
| `reference_cln.tld_registry_reference_cln` as OSI dataset | Joined only via `bigreporting.dim_product_snap` (transitive); no direct join from fact; domain registry attributes fully materialized | `field_description` |
| `bigreporting.dim_product_hist_cln` as OSI dataset | Conditional alternate read (when `--dim-product-table dim_product_hist_cln` flag passed); exact same semantic role as `dim_product_snap`; not needed as separate dataset | `custom_extensions` |

---

**The agent's final response to the user was:**
All three outputs have been written. Here is a summary of the analysis work performed:

---

## Analysis Summary — `analytic.ads_bill_line`

### Target Table (Step 2)
- **Lake table:** `analytic.ads_bill_line` at `us-west-2/analytic/ads-bill-line/`
- **Grain:** one row per (`bill_id`, `bill_line_num`) — confirmed by DDL `@PrimaryKey` annotations, DQ constraint, and PySpark docstring
- **Partition:** `partition_bill_mst_year_month` (YYYY-MM)
- **Confidence:** HIGH

### Lineage Resolution (Step 3)
- **28 PySpark source tables** examined; **25 resolved** to lake catalog entries
- **2 UNRESOLVED:** `finance360.dim_country_vw` (no finance360 schema in lake) and `ecomm_core_conformed.dim_customer_registration_acquisition` (no schema in lake; Iceberg S3)
- **1 near-miss confirmed:** `care-mart/employee-master-v3` → table name `employee_master_snap_v3` (confirmed via `table.yaml`)
- **1 name-fold confirmed:** `reference-cln/tld-registry-reference` → table name `tld_registry_reference_cln`

### OSI Dataset Classification (Step 4)
- **1 fact dataset:** `analytic.ads_bill_line`
- **6 dimension datasets** with direct FK in fact: `ecomm360.fact_bill_line_vw`, `ecomm360.dim_bill_vw`, `bigreporting.dim_product_snap`, `dp_enterprise.dim_isc_source_code`, `partner360.dim_reseller_vw`, `care_mart.employee_master_snap_v3`
- **16 materialized direct-reads** (all attributes denormalized onto fact)
- **6 excluded dimensions** (transitive, unresolved, or filter-only)

### Relationships (Step 5)
6 OSI relationships defined, all from `ads_bill_line` → respective dimension on direct FK columns.

### Metrics (Step 7)
8 metrics identified with evidence: `total_gcr_usd_amt`, `total_receipt_price_usd_amt`, `total_gcr_constant_currency_amt`, `total_margin_gcr_usd_amt`, `bill_line_count`, `new_acquisition_count`, `total_unit_qty`, `total_tax_usd_amt`.

### Outputs Written
- `analyze.md` — full structured analysis appended
- `RESOLVED_TARGET.json` — target table contract (high confidence)
- `PROVENANCE.json` — full pipeline lineage with 2 intermediate tables, 5 transitive sources, 16 materialized direct-reads, 6 excluded dimensions, 13 do-not-claim entries