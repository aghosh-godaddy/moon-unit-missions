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
- **Relationship table**: | name | from | to | from_columns | to_columns | evidence |
- **Field inventory per dataset**: columns, types, is_time, descriptions
- **Metrics table**: | name | expression | description | evidence |
- **Semantic model metadata**: name, description, ai_context draft
- "Do not claim" list: items tempting but not proven

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

**The agent summarized its work in this way:**

---

## analyze stage — ads-bill-line (analytic.ads_bill_line)

**Analyzed:** 2026-06-04
**Sources:** gather.md, lake DDLs, OSI spec v0.2.0.dev0

---

## Step 2: Target Table Resolution

| Field | Value | Evidence |
|---|---|---|
| Lake schema | `analytic` | `table.yaml` → `database_name` resolves to `analytic` |
| Lake table | `ads_bill_line` | `TABLE_NAME = "ads_bill_line"` in `ads_bill_line.py` |
| Lake path (hyphen) | `analytic/ads-bill-line` | `repos/lake/catalog/config/prod/us-west-2/analytic/ads-bill-line/` |
| Qualified name | `analytic.ads_bill_line` | `table.yaml`, lake DDL |
| S3 location | `s3://gd-ckpetlbatch-prod-analytic/analytic/ads_bill_line/` | DAG EMR step config |
| Partition key | `partition_bill_mst_year_month` (string, YYYY-MM) | `table.yaml` partition_keys |
| Grain | One row per `(bill_id, bill_line_num)` | DQ constraint `isPrimaryKey("bill_id","bill_line_num")` |
| Write method | Parquet overwrite per partition | DAG `load_ads_bill_line` step |
| Lake override | None provided; code is unambiguous | INPUT.md `lake_table_override` is empty |
| Confidence | **HIGH** | DDL + yaml + DQ + code all consistent |

---

## Step 3: Lineage Resolution (all source tables)

| Source Table (as referenced in PySpark) | Lake Catalog Path Found | Status | Notes |
|---|---|---|---|
| `ecomm360.fact_bill_line_vw` | `dlms-api/us-west-2/ecomm360/fact-bill-line-vw/` | ✅ RESOLVED | Primary line-level source |
| `ecomm360.dim_bill_vw` | `dlms-api/us-west-2/ecomm360/dim-bill-vw/` | ✅ RESOLVED | Bill header dimension |
| `bigreporting.dim_product_snap` | `us-west-2/bigreporting/dim-product-snap/` | ✅ RESOLVED | Product dimension (default) |
| `bigreporting.dim_product_hist_cln` | `us-west-2/bigreporting/dim-product-hist-cln/` | ✅ RESOLVED | Alternate product dim via `--dim-product-table` flag |
| `callcenterreporting.rpt_c3_orders_ordersource_snap` | `us-west-2/callcenterreporting/rpt-c3-orders-ordersource-snap/` | ✅ RESOLVED | C3 order source |
| `callcenterreporting.rpt_c3_orders_snap` | `us-west-2/callcenterreporting/rpt-c3-orders-snap/` | ✅ RESOLVED | C3 rep version lookup |
| `godaddycpl.gdshop_common_purchase_log_snap` | `us-west-2/godaddycpl/gdshop-common-purchase-log-snap/` | ✅ RESOLVED | CPL / payment processor |
| `partner360.dim_reseller_vw` | `dlms-api/us-west-2/partner360/dim-reseller-vw/` | ✅ RESOLVED | Reseller / PLID dimension |
| `enterprise.free_entitlement` | `us-west-2/enterprise/free-entitlement/` | ✅ RESOLVED | Free trial entitlement |
| `care_mart.rev_attribution` | `us-west-2/care-mart/rev-attribution/` | ✅ RESOLVED | C3 revenue attribution type |
| `gmode.customer_type_gcr_logic_lookup` | `us-west-2/gmode/customer-type-gcr-logic-lookup/` | ✅ RESOLVED | GCR PnL segment logic (BROADCAST) |
| `customers.customer_id_mapping_snapshot` | `us-west-2/customers/customer-id-mapping-snapshot/` | ✅ RESOLVED | Shopper↔customer ID bridge |
| `customer360.dim_customer_vw` | `dlms-api/us-west-2/customer360/dim-customer-vw/` | ✅ RESOLVED | Customer/shopper attributes |
| `customer360.dim_customer_history_vw` | `dlms-api/us-west-2/customer360/dim-customer-history-vw/` | ✅ RESOLVED | Internal shopper detection |
| `finance360.dim_country_vw` | `dlms-api/us-west-2/finance360/dim-country-vw/` | ✅ RESOLVED | Country name for reseller |
| `fraud_cln.fraud_note_cln` | Schema `fraud_cln` absent from catalog | ⚠️ UNRESOLVED | Schema not in lake registry |
| `fraud_cln.fraud_review_history_cln` | Schema `fraud_cln` absent from catalog | ⚠️ UNRESOLVED | Schema not in lake registry |
| `reference_cln.tld_registry_reference_cln` | Schema `reference_cln` absent from catalog | ⚠️ UNRESOLVED | Schema not in lake registry |
| `dm_reference.dim_geography` | Schema `dm_reference` absent from catalog | ⚠️ UNRESOLVED | Schema not in lake registry |
| `gd_pro_mart.web_pro_shopper_client` | Schema `gd_pro_mart` absent from catalog | ⚠️ UNRESOLVED | Schema not in lake registry |
| `dp_stage.ref_order_constant_currency` | Schema `dp_stage` absent from catalog | ⚠️ UNRESOLVED | Schema not in lake registry |
| `dp_stage.ref_commission_products` | Schema `dp_stage` absent from catalog | ⚠️ UNRESOLVED | Schema not in lake registry |
| `dp_enterprise.dim_isc_source_code` | Schema `dp_enterprise` absent from catalog | ⚠️ UNRESOLVED | Schema not in lake registry |
| `ecomm_core_conformed.dim_customer_registration_acquisition` | Schema `ecomm_core_conformed` absent from catalog | ⚠️ UNRESOLVED | Read via Iceberg S3 directly in code; not in lake registry |
| `ecomm_mart.dim_bill_line_purchase_attribution` | Schema `ecomm_mart` dir found (dlms-api) but table absent | ⚠️ UNRESOLVED | Table not registered under dlms-api/us-west-2/ecomm_mart/ |
| `analytic_feature.customer_type_history` | Schema `analytic_feature` dir found (dlms-api) but table absent | ⚠️ UNRESOLVED | Table not found in catalog |
| `analytic_feature.shopper_crm_portfolio` | Schema `analytic_feature` dir found (dlms-api) but table absent | ⚠️ UNRESOLVED | Table not found in catalog |
| `analytic_feature.shopper_domain_portfolio` | Schema `analytic_feature` dir found (dlms-api) but table absent | ⚠️ UNRESOLVED | Table not found in catalog |
| `care_mart.employee_master_snap_v3` | Variant `care-mart/employee-master-v3` found; exact name `employee-master-snap-v3` not found | ⚠️ UNRESOLVED | Name mismatch; possible stale reference |

**Resolved lake tables (15):** ecomm360.fact_bill_line_vw, ecomm360.dim_bill_vw, bigreporting.dim_product_snap, bigreporting.dim_product_hist_cln, callcenterreporting.rpt_c3_orders_ordersource_snap, callcenterreporting.rpt_c3_orders_snap, godaddycpl.gdshop_common_purchase_log_snap, partner360.dim_reseller_vw, enterprise.free_entitlement, care_mart.rev_attribution, gmode.customer_type_gcr_logic_lookup, customers.customer_id_mapping_snapshot, customer360.dim_customer_vw, customer360.dim_customer_history_vw, finance360.dim_country_vw

**Unresolved (14):** fraud_cln.fraud_note_cln, fraud_cln.fraud_review_history_cln, reference_cln.tld_registry_reference_cln, dm_reference.dim_geography, gd_pro_mart.web_pro_shopper_client, dp_stage.ref_order_constant_currency, dp_stage.ref_commission_products, dp_enterprise.dim_isc_source_code, ecomm_core_conformed.dim_customer_registration_acquisition, ecomm_mart.dim_bill_line_purchase_attribution, analytic_feature.customer_type_history, analytic_feature.shopper_crm_portfolio, analytic_feature.shopper_domain_portfolio, care_mart.employee_master_snap_v3

> **OSI note:** Unresolved tables cannot be used as `source` in OSI datasets. Columns contributed by these tables appear denormalized in `analytic.ads_bill_line` and are covered via the fact dataset fields only.

---

## Step 4: Dataset Classification

| Lake Table | OSI Dataset Name | Role | source | primary_key | Evidence |
|---|---|---|---|---|---|
| `analytic.ads_bill_line` | `ads_bill_line` | **FACT** (primary) | `analytic.ads_bill_line` | `[bill_id, bill_line_num]` | Output of PySpark; DQ `isPrimaryKey` |
| `ecomm360.dim_bill_vw` | `dim_bill` | DIMENSION | `ecomm360.dim_bill_vw` | `[bill_id]` | One row per bill_id; joined on `bill_id` (one side) |
| `bigreporting.dim_product_snap` | `dim_product` | DIMENSION | `bigreporting.dim_product_snap` | `[pf_id]` | One row per pf_id; joined on `pf_id` (one side) |
| `customer360.dim_customer_vw` | `dim_customer` | DIMENSION | `customer360.dim_customer_vw` | `[customer_id]` | One row per customer; joined on `customer_id` (one side) |
| `partner360.dim_reseller_vw` | `dim_reseller` | DIMENSION | `partner360.dim_reseller_vw` | `[private_label_id]` | One row per PLID; joined on `private_label_id` (one side) |
| `gmode.customer_type_gcr_logic_lookup` | `customer_type_gcr_logic` | DIMENSION (BROADCAST lookup) | `gmode.customer_type_gcr_logic_lookup` | `[customer_type_name, product_pnl_new_renewal_name, product_pnl_category_name, product_pnl_line_name, product_pnl_version_name, product_pnl_subline_name, order_region_2_name]` | BROADCAST join; composite key; PnL segment logic |
| `enterprise.free_entitlement` | `free_entitlement` | DIMENSION | `enterprise.free_entitlement` | `[free_bill_id, free_bill_line_num]` | Joined on `(bill_id, bill_line_num)` = `(paid_bill_id, paid_bill_line_num)` |
| `care_mart.rev_attribution` | `c3_rev_attribution` | DIMENSION | `care_mart.rev_attribution` | `[order_id]` | Joined on `bill_id = order_id`; provides `c3_attribution_type_name` |

**Excluded from OSI datasets (lake tables found but not included):**
- `ecomm360.fact_bill_line_vw` — same grain as fact; its data is fully absorbed into `ads_bill_line`; including would create an identity-like relationship with no analytical value
- `bigreporting.dim_product_hist_cln` — alternate product table (conditional flag `--dim-product-table`); not active in prod default path; prod always uses `dim_product_snap`
- `callcenterreporting.rpt_c3_orders_ordersource_snap` — contributes `c3_bill_source_code`/`c3_bill_process_name` to fact; thin reference table, fully denormalized into fact
- `callcenterreporting.rpt_c3_orders_snap` — contributes `rep_version_id` join; narrow; absorbed into fact
- `godaddycpl.gdshop_common_purchase_log_snap` — payment processor details; fully denormalized into fact payment columns
- `customers.customer_id_mapping_snapshot` — ID bridge/mapping utility; no standalone semantic value
- `customer360.dim_customer_history_vw` — used only for internal shopper flag detection; narrow analytical use
- `finance360.dim_country_vw` — used only for `reseller_country_name`; absorbed into fact

---

## Step 5: Relationships

| name | from | to | from_columns | to_columns | evidence |
|---|---|---|---|---|---|
| `bill_line_to_bill` | `ads_bill_line` | `dim_bill` | `[bill_id]` | `[bill_id]` | `fact_bill_denorm` CTE: `cte_fb_distinct` LEFT JOIN `cte_dim_bill` ON `bill_id`; many lines per bill |
| `bill_line_to_product` | `ads_bill_line` | `dim_product` | `[pf_id]` | `[pf_id]` | `fact_bill_line_core` CTE: `fbl` LEFT JOIN `cte_dim_product_snap` ON `fbl.pf_id = dp.pf_id` (BROADCAST) |
| `bill_line_to_customer` | `ads_bill_line` | `dim_customer` | `[original_customer_id]` | `[customer_id]` | `dim_bill_shopper_core` uses `customer360.dim_customer_vw` ON `customer_id`; resolved via bill's `original_customer_id` |
| `bill_line_to_reseller` | `ads_bill_line` | `dim_reseller` | `[private_label_id]` | `[private_label_id]` | `dim_reseller` CTE: `partner360.dim_reseller_vw` joined on `private_label_id`; bill has PLID, reseller has one row per PLID |
| `bill_line_to_gcr_logic` | `ads_bill_line` | `customer_type_gcr_logic` | `[customer_type_name, product_pnl_new_renewal_name, product_pnl_category_name, product_pnl_line_name, product_pnl_version_name, product_pnl_subline_name, bill_report_region_2_name]` | `[customer_type_name, product_pnl_new_renewal_name, product_pnl_category_name, product_pnl_line_name, product_pnl_version_name, product_pnl_subline_name, order_region_2_name]` | `ads_bill_line_core` final join: `F.broadcast(customer_type_gcr_logic_lookup)` ON these 7 columns |
| `bill_line_to_free_entitlement` | `ads_bill_line` | `free_entitlement` | `[bill_id, bill_line_num]` | `[paid_bill_id, paid_bill_line_num]` | `cte_free_entitlements`: `enterprise.free_entitlement` ON `fbl.bill_id = free.bill_id AND fbl.bill_line_num = free.bill_line_num` |
| `bill_line_to_c3_attribution` | `ads_bill_line` | `c3_rev_attribution` | `[bill_id]` | `[order_id]` | `fact_bill_denorm` CTE: LEFT JOIN `care_mart.rev_attribution` ON `fb.bill_id = rev.order_id` |

---

## Step 6: Field Inventory

### Dataset: `ads_bill_line` (analytic.ads_bill_line) — FACT

Source: `repos/lake/catalog/config/prod/us-west-2/analytic/ads-bill-line/table.ddl`

| OSI Field Name | SQL Expression | Type | is_time | Description |
|---|---|---|---|---|
| `bill_id` | `bill_id` | string | | PK. Unique ID for bill (order/receipt) |
| `bill_line_num` | `bill_line_num` | int | | PK. Line item number within bill (0 = header level) |
| `bill_country_code` | `bill_country_code` | string | | ISO country code from payment instrument |
| `rep_version_id` | `rep_version_id` | int | | Care rep version ID on bill |
| `private_label_id` | `private_label_id` | int | | ID for private label (reseller/white-label) partner |
| `bill_isc_source_code` | `bill_isc_source_code` | string | | ISC code attributing bill to marketing campaign/email/affiliate/channel |
| `bill_sub_geo_code` | `bill_sub_geo_code` | string | | Sub-geography code for payment address |
| `bill_postal_code` | `bill_postal_code` | string | | Postal code for payment address |
| `bill_source_name` | `bill_source_name` | string | | Point-of-sale channel or purchase origin |
| `entered_by_name` | `entered_by_name` | string | | Entity/role that submitted bill |
| `translation_language_name` | `translation_language_name` | string | | Language of browser/session at purchase time |
| `primary_payment_type_name` | `primary_payment_type_name` | string | | Payment method type for highest-value payment |
| `primary_payment_subtype_name` | `primary_payment_subtype_name` | string | | Subtype of primary payment method |
| `secondary_payment_type_name` | `secondary_payment_type_name` | string | | Payment method type for second payment if multiple methods used |
| `secondary_payment_subtype_name` | `secondary_payment_subtype_name` | string | | Subtype of secondary payment method |
| `bill_payment_processor_name` | `bill_payment_processor_name` | string | | Name of payment processor used for bill |
| `bill_payment_processor_common_name` | `bill_payment_processor_common_name` | string | | Common display name of payment processor |
| `bill_payment_cpl_trxn_currency_code` | `bill_payment_cpl_trxn_currency_code` | string | | Currency code from Common Purchase Log (CPL) |
| `bill_payment_cpl_trxn_amt` | `bill_payment_cpl_trxn_amt` | decimal(18,2) | | Transaction amount from CPL |
| `bill_modified_mst_date_prior_year` | `bill_modified_mst_date_prior_year` | date | true | Bill modification date MST shifted back 364 days for YoY comparison |
| `bill_isc_source_code_desc` | `bill_isc_source_code_desc` | string | | Description of ISC code |
| `bill_isc_company_id` | `bill_isc_company_id` | int | | Company ID for ISC on bill |
| `bill_isc_campaign_id` | `bill_isc_campaign_id` | int | | Campaign ID for ISC on bill |
| `bill_isc_channel_id` | `bill_isc_channel_id` | int | | Channel ID for ISC on bill |
| `bill_isc_product_id` | `bill_isc_product_id` | int | | Product ID for ISC on bill |
| `bill_isc_vendor_id` | `bill_isc_vendor_id` | int | | Vendor ID for ISC on bill |
| `bill_isc_media_specialist_id` | `bill_isc_media_specialist_id` | int | | Media specialist ID for ISC on bill |
| `bill_isc_sub_channel_id` | `bill_isc_sub_channel_id` | int | | Sub-channel ID for ISC on bill |
| `bill_isc_channel_name` | `bill_isc_channel_name` | string | | Marketing channel for ISC (e.g. Billing Agent, Branding, Legacy) |
| `bill_isc_sub_channel_name` | `bill_isc_sub_channel_name` | string | | Marketing sub-channel for ISC |
| `bill_isc_vendor_name` | `bill_isc_vendor_name` | string | | Vendor name for ISC (e.g. Google UK, Internal Affiliate Program) |
| `bill_isc_product_name` | `bill_isc_product_name` | string | | Product name for ISC |
| `bill_isc_media_specialist_name` | `bill_isc_media_specialist_name` | string | | Employee PII (encrypted). GD media specialist name for ISC |
| `reseller_type_name` | `reseller_type_name` | string | | Reseller type of PLID (e.g. Go Daddy, Pro Reseller, API Reseller) |
| `reseller_name` | `reseller_name` | string | | Name of private label reseller for bill |
| `reseller_shopper_id` | `reseller_shopper_id` | string | | Reseller shopper ID; may change with merges |
| `reseller_country_code` | `reseller_country_code` | string | | Country code of first paid bill for reseller shopper ID |
| `reseller_country_name` | `reseller_country_name` | string | | Country name of first paid bill for reseller shopper ID |
| `c3_rep_name` | `c3_rep_name` | string | | Employee PII (encrypted). Care rep name for bill |
| `c3_rep_supervisor_name` | `c3_rep_supervisor_name` | string | | Employee PII (encrypted). Supervisor name of Care rep |
| `c3_rep_department_name` | `c3_rep_department_name` | string | | Care rep department name |
| `c3_call_center_location_name` | `c3_call_center_location_name` | string | | Care rep call center location |
| `bill_country_name` | `bill_country_name` | string | | Country name for bill (from dim_geography) |
| `bill_report_region_1_name` | `bill_report_region_1_name` | string | | 1st-level geo reporting region (from dim_geography) |
| `bill_report_region_2_name` | `bill_report_region_2_name` | string | | 2nd-level geo reporting region (from dim_geography) |
| `bill_report_region_3_name` | `bill_report_region_3_name` | string | | 3rd-level geo reporting region (from dim_geography) |
| `bill_report_focal_country_name` | `bill_report_focal_country_name` | string | | Focal country name for geo reporting |
| `bill_report_sub_region_name` | `bill_report_sub_region_name` | string | | Sub-region name for geo reporting |
| `bill_domestic_international_name` | `bill_domestic_international_name` | string | | 'Domestic' if US, 'International' otherwise |
| `merged_shopper_id` | `merged_shopper_id` | string | | Current post-merge shopper ID on bill |
| `original_shopper_id` | `original_shopper_id` | string | | Shopper ID at original bill creation |
| `new_registered_user_bill_id` | `new_registered_user_bill_id` | string | | Bill ID created when customer first registered before paid purchase |
| `new_acquisition_bill_country_code` | `new_acquisition_bill_country_code` | string | | Country code for first paid purchase by customer |
| `new_acquisition_bill_id` | `new_acquisition_bill_id` | string | | Bill ID for first paid purchase by customer |
| `new_acquisition_bill_mst_date` | `new_acquisition_bill_mst_date` | date | true | MST date for first paid purchase by customer |
| `new_registered_user_bill_mst_date` | `new_registered_user_bill_mst_date` | date | true | MST date for new registered user (NRU) bill |
| `federation_partner_id` | `federation_partner_id` | string | | ID for federation partner for bill |
| `federation_friendly_name` | `federation_friendly_name` | string | | Name of federation partner (e.g. Media Temple, 123 Reg, TSOHost) |
| `web_pro_participant_type_name` | `web_pro_participant_type_name` | string | | 'Pro' or 'Client' for Web Pro bills; reflects current opt-in status |
| `web_pro_shopper_id` | `web_pro_shopper_id` | string | | Web Pro shopper ID for bill |
| `original_shopper_exclude_reason_desc` | `original_shopper_exclude_reason_desc` | string | | Reason bill line is excluded based on original shopper ID |
| `original_shopper_exclude_reason_month_end_desc` | `original_shopper_exclude_reason_month_end_desc` | string | | Month-end exclusion reason based on original shopper ID |
| `shopper_domain_portfolio_qty` | `shopper_domain_portfolio_qty` | int | | Number of domains in customer's portfolio at bill time |
| `shopper_domain_portfolio_segment_name` | `shopper_domain_portfolio_segment_name` | string | | Domain portfolio segment name at bill time |
| `crm_portfolio_type_name` | `crm_portfolio_type_name` | string | | CRM portfolio type assigned at bill time |
| `crm_portfolio_rep_id` | `crm_portfolio_rep_id` | int | | CRM portfolio care rep ID assigned at bill time |
| `crm_portfolio_rep_name` | `crm_portfolio_rep_name` | string | | Employee PII (encrypted). CRM portfolio rep at bill time |
| `current_crm_portfolio_type_name` | `current_crm_portfolio_type_name` | string | | Current CRM portfolio type for customer |
| `current_crm_portfolio_rep_id` | `current_crm_portfolio_rep_id` | int | | Current CRM portfolio rep ID for customer |
| `current_crm_portfolio_rep_name` | `current_crm_portfolio_rep_name` | string | | Employee PII (encrypted). Current CRM portfolio rep |
| `product_term_num` | `product_term_num` | int | | Number of billing periods for product purchased |
| `product_term_unit_desc` | `product_term_unit_desc` | string | | Billing period unit (e.g. month, quarter, year) |
| `product_pnl_category_name` | `product_pnl_category_name` | string | | 2nd level of Finance PnL product hierarchy |
| `product_pnl_group_name` | `product_pnl_group_name` | string | | 1st level of Finance PnL product hierarchy |
| `product_pnl_line_name` | `product_pnl_line_name` | string | | 3rd level of Finance PnL product hierarchy |
| `product_pnl_subline_name` | `product_pnl_subline_name` | string | | 4th level of Finance PnL product hierarchy |
| `product_pnl_version_name` | `product_pnl_version_name` | string | | Flexible pseudo-level of Finance PnL hierarchy |
| `original_product_pnl_new_renewal_name` | `original_product_pnl_new_renewal_name` | string | | Identifies product (pf_id) as new purchase or renewal (pre-override) |
| `product_type_desc` | `product_type_desc` | string | | Product type description |
| `product_type_id` | `product_type_id` | double | | Product type ID |
| `product_name` | `product_name` | string | | Product name for purchased product (pf_id) |
| `pnl_new_renewal` | `pnl_new_renewal` | string | | New or renewal designation for product (pf_id) |
| `bill_fraud_flag_ts` | `bill_fraud_flag_ts` | timestamp | true | Timestamp when bill was flagged fraudulent |
| `bill_fraud_flag_date` | `bill_fraud_flag_date` | date | true | Date when bill was flagged fraudulent |
| `bill_fraud_review_id` | `bill_fraud_review_id` | int | | Fraud review ID under which bill was flagged |
| `free_trial_type_desc` | `free_trial_type_desc` | string | | Description of free trial type for bill line |
| `free_trial_target_expiration_date` | `free_trial_target_expiration_date` | date | true | Target expiration date of free trial |
| `product_free_trial_acquisition_ts` | `product_free_trial_acquisition_ts` | timestamp | true | Timestamp of original free trial bill |
| `original_bill_id` | `original_bill_id` | string | | For refunds/chargebacks: original bill ID |
| `original_bill_line_num` | `original_bill_line_num` | int | | For refunds/chargebacks: original bill line number |
| `source_system_name` | `source_system_name` | string | | Originating system name (e.g. legacy e-comm) |
| `bill_modified_mst_ts` | `bill_modified_mst_ts` | timestamp | true | Timestamp (MST) of bill creation or last modification |
| `bill_modified_mst_date` | `bill_modified_mst_date` | date | true | Date (MST) of bill creation or last modification |
| `subaccount_shopper_id` | `subaccount_shopper_id` | string | | Shopper ID for subaccount; used for API reseller bills |
| `item_tracking_code` | `item_tracking_code` | string | | Item tracking code (ITC) for bill line |
| `item_tracking_code_desc` | `item_tracking_code_desc` | string | | ITC description identifying website location or process |
| `purchase_path_name` | `purchase_path_name` | string | | GD website location where product was added to cart |
| `purchase_path_attributed_name` | `purchase_path_attributed_name` | string | | Attributed purchase path (first non-Cart path for Cart New Purchase) |
| `department_id` | `department_id` | int | | Business department ID responsible for bill line |
| `accounting_company_id` | `accounting_company_id` | int | | Accounting company ID associating bill to GD legal entity |
| `pf_id` | `pf_id` | int | | Product family ID for product purchased |
| `upgraded_pf_id` | `upgraded_pf_id` | int | | Product family ID being upgraded from (legacy) |
| `unit_qty` | `unit_qty` | int | | Number of units purchased for bill line |
| `duration_qty` | `duration_qty` | decimal(18,3) | | Number of subscription period units |
| `product_unit_qty` | `product_unit_qty` | int | | Unit qty adjusted for units-as-orders products |
| `product_month_qty` | `product_month_qty` | decimal(18,2) | | Number of calendar months in subscription period |
| `receipt_price_usd_amt` | `receipt_price_usd_amt` | decimal(18,2) | | Amount paid for bill line in USD after discounts |
| `receipt_price_trxn_amt` | `receipt_price_trxn_amt` | decimal(18,2) | | Amount paid for bill line in transaction currency |
| `receipt_price_constant_currency_amt` | `receipt_price_constant_currency_amt` | decimal(18,2) | | Amount paid using constant FX rate for YoY comparison |
| `gcr_usd_amt` | `gcr_usd_amt` | decimal(18,2) | | Gross Cash Receipts (GCR) for bill line in USD |
| `gcr_trxn_amt` | `gcr_trxn_amt` | decimal(18,2) | | GCR for bill line in transaction currency |
| `gcr_constant_currency_amt` | `gcr_constant_currency_amt` | decimal(18,2) | | GCR using constant FX rate for YoY comparison |
| `margin_gcr_usd_amt` | `margin_gcr_usd_amt` | decimal(18,2) | | GCR margin in USD after subtracting COGS |
| `margin_gcr_trxn_amt` | `margin_gcr_trxn_amt` | decimal(18,2) | | GCR margin in transaction currency |
| `commission_usd_amt` | `commission_usd_amt` | decimal(18,2) | | Commission owed to 3rd-party sales channel in USD |
| `commission_trxn_amt` | `commission_trxn_amt` | decimal(18,2) | | Commission owed to 3rd-party sales channel in transaction currency |
| `aftermarket_seller_commission_usd_amt` | `aftermarket_seller_commission_usd_amt` | decimal(18,2) | | Commission paid to domain aftermarket seller in USD |
| `aftermarket_seller_commission_trxn_amt` | `aftermarket_seller_commission_trxn_amt` | decimal(18,2) | | Commission paid to domain aftermarket seller in transaction currency |
| `cost_usd_amt` | `cost_usd_amt` | decimal(18,2) | | Cost of goods sold in USD (approximation for domains) |
| `cost_trxn_amt` | `cost_trxn_amt` | decimal(18,2) | | Cost of goods sold in transaction currency |
| `msrp_duration_unit_usd_amt` | `msrp_duration_unit_usd_amt` | decimal(18,2) | | List price per single billing-period unit in USD |
| `msrp_duration_unit_trxn_amt` | `msrp_duration_unit_trxn_amt` | decimal(18,2) | | List price per single billing-period unit in transaction currency |
| `msrp_total_usd_amt` | `msrp_total_usd_amt` | decimal(18,2) | | Full list price for bill line in USD |
| `msrp_total_trxn_amt` | `msrp_total_trxn_amt` | decimal(18,2) | | Full list price for bill line in transaction currency |
| `fee_usd_amt` | `fee_usd_amt` | decimal(18,2) | | Fee in USD (typically ICANN fee for domain purchase) |
| `fee_trxn_amt` | `fee_trxn_amt` | decimal(18,2) | | Fee in transaction currency |
| `fair_market_value_usd_amt` | `fair_market_value_usd_amt` | decimal(18,2) | | Fair market value (FMV) in USD for revenue recognition |
| `fair_market_value_trxn_amt` | `fair_market_value_trxn_amt` | decimal(18,2) | | FMV in transaction currency |
| `tax_usd_amt` | `tax_usd_amt` | decimal(18,2) | | Tax charged for bill line in USD |
| `tax_trxn_amt` | `tax_trxn_amt` | decimal(18,2) | | Tax charged for bill line in transaction currency |
| `receipt_regular_price_usd_amt` | `receipt_regular_price_usd_amt` | decimal(18,2) | | Current selling price in USD for bill line |
| `receipt_regular_price_trxn_amt` | `receipt_regular_price_trxn_amt` | decimal(18,2) | | Current selling price in transaction currency |
| `injected_fair_market_value_usd_amt` | `injected_fair_market_value_usd_amt` | decimal(18,2) | | System-injected FMV adjustment in USD |
| `injected_fair_market_value_trxn_amt` | `injected_fair_market_value_trxn_amt` | decimal(18,2) | | System-injected FMV adjustment in transaction currency |
| `injected_icann_fee_usd_amt` | `injected_icann_fee_usd_amt` | decimal(18,2) | | System-injected ICANN fee in USD |
| `injected_icann_fee_trxn_amt` | `injected_icann_fee_trxn_amt` | decimal(18,2) | | System-injected ICANN fee in transaction currency |
| `injected_tax_usd_amt` | `injected_tax_usd_amt` | decimal(18,2) | | System-injected tax in USD |
| `injected_tax_trxn_amt` | `injected_tax_trxn_amt` | decimal(18,2) | | System-injected tax in transaction currency |
| `bundle_allocated_revenue_usd_amt` | `bundle_allocated_revenue_usd_amt` | decimal(18,2) | | Revenue allocated to bill line within a bundle in USD |
| `reseller_commission_usd_amt` | `reseller_commission_usd_amt` | decimal(18,2) | | Commission earned by reseller in USD |
| `parent_reseller_commission_usd_amt` | `parent_reseller_commission_usd_amt` | decimal(18,2) | | Commission earned by parent reseller in USD |
| `trxn_currency_code` | `trxn_currency_code` | string | | ISO 4217 currency code for transaction |
| `offer_id` | `offer_id` | int | | ID for bundle product was included in |
| `offer_collection_id` | `offer_collection_id` | int | | ID for parent offer collection |
| `free_product_package_id` | `free_product_package_id` | int | | ID for free product package for bill line |
| `variant_price_type_id` | `variant_price_type_id` | int | | ID for variant price type (Standard Price, GD Pro Member Price, etc.) |
| `variant_price_type_name` | `variant_price_type_name` | string | | Name of variant price type |
| `exclude_reason_desc` | `exclude_reason_desc` | string | | Reason bill line is excluded from reporting (e.g. Acquisition Elimination) |
| `exclude_reason_month_end_desc` | `exclude_reason_month_end_desc` | string | | Month-end exclusion reason for bill line |
| `item_discount_code` | `item_discount_code` | string | | Discount code applied to bill line at purchase |
| `item_redemption_code` | `item_redemption_code` | string | | Code used after purchase to claim/activate item |
| `intent` | `intent` | string | | Intent for virtual bill line (e.g. FREEMIUM_PURCHASE, FREE_TRIAL_MODIFY) |
| `related_subscription` | `related_subscription` | string | | Subscription ID linking virtual bill to customer subscription |
| `bill_site_language_code` | `bill_site_language_code` | string | | Language locale of website where bill submitted |
| `c3_bill_source_code` | `c3_bill_source_code` | string | | Code showing how Care attributed bill |
| `c3_bill_process_name` | `c3_bill_process_name` | string | | How Care attributed bill (e.g. Call Center, Web, DelayedPayment) |
| `free_trial_bill_type` | `free_trial_bill_type` | string | | Bill type for free trial bill (e.g. virtual, standard) |
| `free_trial_bill_date` | `free_trial_bill_date` | date | true | Date of free trial bill for bill line |
| `virtual_bill_flag` | `virtual_bill_flag` | boolean | | True if virtual bill with no associated payment |
| `free_bill_flag` | `free_bill_flag` | boolean | | True if no GCR on entire bill (excluding ICANN fees) |
| `bill_isc_viral_flag` | `bill_isc_viral_flag` | boolean | | True if ISC classified as viral marketing |
| `new_acquisition_flag` | `new_acquisition_flag` | boolean | | True if first paid customer purchase |
| `new_registered_user_flag` | `new_registered_user_flag` | boolean | | True when customer registered before first paid purchase |
| `product_free_term_flag` | `product_free_term_flag` | boolean | | True for products free for first billing period then paid (e.g. O365 1 Month Free) |
| `units_as_bills_flag` | `units_as_bills_flag` | boolean | | True if purchase is for 1 resource regardless of qty |
| `primary_product_flag` | `primary_product_flag` | boolean | | True for primary products; False for add-ons |
| `c3_receipt_move_flag` | `c3_receipt_move_flag` | boolean | | True if bill was retroactively attributed to Care |
| `product_free_trial_flag` | `product_free_trial_flag` | boolean | | True for bills initiating free trial subscription |
| `product_free_trial_conversion_flag` | `product_free_trial_conversion_flag` | boolean | | True if product converted from free trial to paid |
| `refund_flag` | `refund_flag` | boolean | | True if bill line is a refund transaction |
| `chargeback_flag` | `chargeback_flag` | boolean | | True if bill line is a chargeback transaction |
| `accounting_deferred_flag` | `accounting_deferred_flag` | boolean | | True when revenue is deferred to subsequent accounting period |
| `renewal_price_locked_flag` | `renewal_price_locked_flag` | boolean | | True if renewal price is locked for future periods |
| `bill_fraud_flag` | `bill_fraud_flag` | boolean | | True if bill was flagged fraudulent by fraud team |
| `c3_bill_flag` | `c3_bill_flag` | boolean | | True if bill is attributed to a Care rep |
| `c3_attribution_type_name` | `c3_attribution_type_name` | string | | Care revenue attribution type (e.g. Direct, Contact History) |
| `product_pnl_new_renewal_name` | `product_pnl_new_renewal_name` | string | | Identifies product as new purchase or renewal (override-adjusted) |
| `customer_type_name` | `customer_type_name` | string | | Customer type assigned at bill time |
| `customer_type_reason_desc` | `customer_type_reason_desc` | string | | Reason for customer type assigned at bill time |
| `original_customer_id` | `original_customer_id` | string | | Customer ID at original bill creation |
| `merged_customer_id` | `merged_customer_id` | string | | Current post-merge customer ID on bill |
| `domain_bulk_flag` | `domain_bulk_flag` | boolean | | True if total non-refund domain reg units for bill >= 50 |
| `domain_bulk_pricing_flag` | `domain_bulk_pricing_flag` | boolean | | True if product type ID is 4 or 5 (domain bulk pricing) |
| `domain_back_end_registry_name` | `domain_back_end_registry_name` | string | | Back-end registry name for TLD (e.g. VERISIGN, Identity Digital) |
| `domain_front_end_registry_name` | `domain_front_end_registry_name` | string | | Front-end registry name for TLD |
| `domain_registry_family_name` | `domain_registry_family_name` | string | | Registry family name for TLD |
| `domain_parent_tld_name` | `domain_parent_tld_name` | string | | Parent TLD for domain (e.g. COM, NET, ORG) |
| `pnl_priority_num` | `pnl_priority_num` | int | | Priority number from customer type GCR logic lookup |
| `pnl_usi_flag` | `pnl_usi_flag` | boolean | | True if bill is for USI (US Independent) PnL segment |
| `pnl_gdii_flag` | `pnl_gdii_flag` | boolean | | True if bill is for GDII (GD International Independent) PnL segment |
| `pnl_partner_flag` | `pnl_partner_flag` | boolean | | True if bill is for Partner PnL segment |
| `pnl_dri_flag` | `pnl_dri_flag` | boolean | | True if bill is for DRI (Domain Registrar and Investor) PnL segment |
| `pnl_commerce_flag` | `pnl_commerce_flag` | boolean | | True if bill is for Commerce PnL segment |
| `point_of_purchase_name` | `point_of_purchase_name` | string | | Point of purchase derived from source/entered_by/bill_source (e.g. Web, C3) |
| `sub_point_of_purchase_name` | `sub_point_of_purchase_name` | string | | Sub-category of point of purchase |
| `shopper_product_purchase_type_name` | `shopper_product_purchase_type_name` | string | | Customer purchase type (e.g. Existing - Buying More, New - New) |
| `etl_build_mst_ts` | `etl_build_mst_ts` | timestamp | true | Timestamp (MST) when record was last updated by ETL |
| `source_process_name` | `source_process_name` | string | | ETL process name ('ads_bill_line.py (full)') |
| `free_bill_line_flag` | `free_bill_line_flag` | boolean | | True for non-virtual bill line where receipt price and GCR are both zero |
| `free_bill_line_with_fair_market_value_flag` | `free_bill_line_with_fair_market_value_flag` | boolean | | True for non-virtual, non-bundle-child bill line where receipt price is zero but GCR > 0 |
| `partition_bill_mst_year_month` | `partition_bill_mst_year_month` | string | true | Partition key: YYYY-MM format derived from bill_modified_mst_date |

---

### Dataset: `dim_bill` (ecomm360.dim_bill_vw) — DIMENSION

Source: `repos/lake/catalog/config/prod/dlms-api/us-west-2/ecomm360/dim-bill-vw/table.ddl`

| OSI Field Name | SQL Expression | Type | is_time | Description |
|---|---|---|---|---|
| `bill_id` | `bill_id` | string | | PK. Unique bill/order ID |
| `event_id` | `event_id` | string | | Event identifier for the bill |
| `original_shopper_id` | `original_shopper_id` | string | | Shopper ID at original bill creation |
| `original_customer_id` | `original_customer_id` | string | | Customer ID at original bill creation |
| `merged_shopper_id` | `merged_shopper_id` | string | | Current post-merge shopper ID |
| `merged_customer_id` | `merged_customer_id` | string | | Current post-merge customer ID |
| `rep_version_id` | `rep_version_id` | int | | Care rep version ID on bill |
| `bill_modified_mst_date` | `bill_modified_mst_date` | date | true | MST date of bill creation/last modification |
| `current_record_flag` | `current_record_flag` | boolean | | True for the current/latest record |
| `etl_insert_utc_ts` | `etl_insert_utc_ts` | timestamp | true | ETL insert timestamp (UTC) |
| `etl_update_utc_ts` | `etl_update_utc_ts` | timestamp | true | ETL update timestamp (UTC) |

---

### Dataset: `dim_product` (bigreporting.dim_product_snap) — DIMENSION

Source: `repos/lake/catalog/config/prod/us-west-2/bigreporting/dim-product-snap/table.ddl`

| OSI Field Name | SQL Expression | Type | is_time | Description |
|---|---|---|---|---|
| `pf_id` | `pf_id` | int | | PK. Product family ID |
| `product_key` | `product_key` | bigint | | Surrogate product key |
| `productclass` | `productclass` | string | | Product class |
| `productfamily` | `productfamily` | string | | Product family name |
| `productcategory` | `productcategory` | string | | Product category |
| `productsubcategory` | `productsubcategory` | string | | Product sub-category |
| `productgroup` | `productgroup` | string | | Product group |
| `productline` | `productline` | string | | Product line |
| `productname` | `productname` | string | | Product name |
| `period` | `period` | string | | Billing period descriptor |
| `numberofperiods` | `numberofperiods` | int | | Number of billing periods |
| `new_renewal` | `new_renewal` | string | | New or renewal designation |
| `bulk_notbulk` | `bulk_notbulk` | string | | Bulk vs non-bulk designation |
| `unitsasorders` | `unitsasorders` | boolean | | True if units are treated as orders |
| `gdshop_product_typeid` | `gdshop_product_typeid` | double | | GDShop product type ID |
| `gdshop_product_type_description` | `gdshop_product_type_description` | string | | GDShop product type description |
| `ki_productgroupid` | `ki_productgroupid` | int | | KI product group ID |
| `ki_productgroupname` | `ki_productgroupname` | string | | KI product group name |
| `dept_id` | `dept_id` | int | | Department ID |
| `dept_name` | `dept_name` | string | | Department name |
| `createdate` | `createdate` | timestamp | true | Product record creation date |
| `updatedate` | `updatedate` | timestamp | true | Product record update date |
| `deletedate` | `deletedate` | timestamp | true | Product record delete date |
| `isdomestic` | `isdomestic` | smallint | | Domestic flag |
| `bundlegroup` | `bundlegroup` | string | | Bundle group |
| `isprimaryproduct` | `isprimaryproduct` | smallint | | True if primary product |
| `pnl_group` | `pnl_group` | string | | PnL group (level 1) |
| `pnl_category` | `pnl_category` | string | | PnL category (level 2) |
| `pnl_line` | `pnl_line` | string | | PnL line (level 3) |
| `pnl_subline` | `pnl_subline` | string | | PnL subline (level 4; joined to TLD registry on tld_name) |
| `pnl_new_renewal` | `pnl_new_renewal` | string | | PnL new/renewal designation |
| `pnl_version` | `pnl_version` | string | | PnL version (pseudo-level) |
| `businessunit` | `businessunit` | string | | Business unit |
| `businessline` | `businessline` | string | | Business line |
| `businesslinetier` | `businesslinetier` | string | | Business line tier |

---

### Dataset: `dim_customer` (customer360.dim_customer_vw) — DIMENSION

Source: `repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/dim-customer-vw/table.ddl`

| OSI Field Name | SQL Expression | Type | is_time | Description |
|---|---|---|---|---|
| `customer_id` | `customer_id` | string | | PK. Customer identifier |
| `shopper_id` | `shopper_id` | string | | Shopper ID linked to customer |
| `external_reseller_customer_id` | `external_reseller_customer_id` | int | | External reseller customer ID |
| `federation_partner_id` | `federation_partner_id` | string | | Federation partner ID |
| `federation_partner_name` | `federation_partner_name` | string | | Federation partner name |
| `parent_customer_id` | `parent_customer_id` | string | | Parent customer ID |
| `parent_shopper_id` | `parent_shopper_id` | string | | Parent shopper ID |
| `private_label_id` | `private_label_id` | int | | Private label ID |
| `company_flag` | `company_flag` | boolean | | True if customer is a company |
| `internal_shopper_flag` | `internal_shopper_flag` | boolean | | True if internal/employee shopper |
| `temporary_shopper_flag` | `temporary_shopper_flag` | boolean | | True if temporary shopper |
| `closed_shopper_flag` | `closed_shopper_flag` | boolean | | True if shopper account is closed |
| `city_name` | `city_name` | string | | City name for customer |
| `state_code` | `state_code` | string | | State code for customer |
| `zip_code` | `zip_code` | string | | ZIP code for customer |
| `country_code` | `country_code` | string | | Country code for customer |
| `email_domain_name` | `email_domain_name` | string | | Email domain name for customer |
| `email_hash` | `email_hash` | string | | Hashed email for customer (PII-safe) |
| `primary_phone_flag` | `primary_phone_flag` | boolean | | True if customer has primary phone |
| `mobile_phone_flag` | `mobile_phone_flag` | boolean | | True if customer has mobile phone |
| `secondary_phone_flag` | `secondary_phone_flag` | boolean | | True if customer has secondary phone |
| `default_currency_code` | `default_currency_code` | string | | Default currency for customer |
| `market_code` | `market_code` | string | | Market code for customer |
| `created_mst_ts` | `created_mst_ts` | timestamp | true | Customer account creation timestamp (MST) |
| `updated_mst_ts` | `updated_mst_ts` | timestamp | true | Customer account update timestamp (MST) |
| `closed_mst_ts` | `closed_mst_ts` | timestamp | true | Customer account close timestamp (MST) |
| `deleted_mst_ts` | `deleted_mst_ts` | timestamp | true | Customer account delete timestamp (MST) |
| `current_record_flag` | `current_record_flag` | boolean | | True for current/latest record (used in join filter) |
| `etl_build_mst_ts` | `etl_build_mst_ts` | timestamp | true | ETL build timestamp (MST) |

---

### Dataset: `dim_reseller` (partner360.dim_reseller_vw) — DIMENSION

Source: `repos/lake/catalog/config/prod/dlms-api/us-west-2/partner360/dim-reseller-vw/table.ddl`

| OSI Field Name | SQL Expression | Type | is_time | Description |
|---|---|---|---|---|
| `private_label_id` | `private_label_id` | int | | PK. Private label ID for reseller/white-label partner |
| `reseller_type_id` | `reseller_type_id` | int | | Reseller type ID |
| `reseller_type_name` | `reseller_type_name` | string | | Reseller type name |
| `reseller_name` | `reseller_name` | string | | Reseller name |
| `reseller_customer_id` | `reseller_customer_id` | string | | Reseller's customer ID |
| `status_id` | `status_id` | smallint | | Reseller status ID |
| `program_id` | `program_id` | string | | Reseller program ID |
| `display_name` | `display_name` | string | | Reseller display name |
| `company_name` | `company_name` | string | | Reseller company name |
| `market_site_code` | `market_site_code` | string | | Market site code for reseller |
| `customer_support_opt_out_flag` | `customer_support_opt_out_flag` | boolean | | True if reseller opted out of customer support |
| `cross_sell_flag` | `cross_sell_flag` | boolean | | True if cross-selling enabled |
| `email_opt_in_flag` | `email_opt_in_flag` | boolean | | True if email opt-in |
| `current_record_flag` | `current_record_flag` | boolean | | True for current/latest record |
| `etl_build_mst_ts` | `etl_build_mst_ts` | timestamp | true | ETL build timestamp (MST) |

---

### Dataset: `customer_type_gcr_logic` (gmode.customer_type_gcr_logic_lookup) — DIMENSION (BROADCAST)

Source: `repos/lake/catalog/config/prod/us-west-2/gmode/customer-type-gcr-logic-lookup/table.ddl`

| OSI Field Name | SQL Expression | Type | is_time | Description |
|---|---|---|---|---|
| `customer_type_name` | `customer_type_name` | string | | Customer type name (part of composite PK) |
| `priority_num` | `priority_num` | int | | Priority number for PnL segment assignment |
| `product_pnl_new_renewal_name` | `product_pnl_new_renewal_name` | string | | PnL new/renewal designation (part of composite PK) |
| `product_pnl_category_name` | `product_pnl_category_name` | string | | PnL category (part of composite PK) |
| `product_pnl_line_name` | `product_pnl_line_name` | string | | PnL line (part of composite PK) |
| `product_pnl_version_name` | `product_pnl_version_name` | string | | PnL version (part of composite PK) |
| `product_pnl_subline_name` | `product_pnl_subline_name` | string | | PnL subline (part of composite PK) |
| `order_region_2_name` | `order_region_2_name` | string | | 2nd-level geo reporting region (part of composite PK; maps to bill_report_region_2_name) |
| `us_independent_flag` | `us_independent_flag` | boolean | | True for USI PnL segment |
| `international_independent_flag` | `international_independent_flag` | boolean | | True for GDII PnL segment |
| `partner_flag` | `partner_flag` | boolean | | True for Partner PnL segment |
| `investor_flag` | `investor_flag` | boolean | | True for DRI/Investor PnL segment |
| `commerce_flag` | `commerce_flag` | boolean | | True for Commerce PnL segment |

---

### Dataset: `free_entitlement` (enterprise.free_entitlement) — DIMENSION

Source: `repos/lake/catalog/config/prod/us-west-2/enterprise/free-entitlement/table.ddl`

| OSI Field Name | SQL Expression | Type | is_time | Description |
|---|---|---|---|---|
| `entitlement_id` | `entitlement_id` | string | | Entitlement identifier |
| `resource_id` | `resource_id` | int | | Resource ID |
| `product_type_id` | `product_type_id` | int | | Product type ID |
| `product_family_name` | `product_family_name` | string | | Product family name |
| `free_pf_id` | `free_pf_id` | int | | Product family ID for free product |
| `free_type_name` | `free_type_name` | string | | Free type name |
| `free_bill_id` | `free_bill_id` | string | | PK (partial). Bill ID of free bill |
| `free_bill_line_num` | `free_bill_line_num` | int | | PK (partial). Line number on free bill |
| `free_bill_mst_ts` | `free_bill_mst_ts` | timestamp | true | Timestamp (MST) of free bill |
| `free_bill_mst_date` | `free_bill_mst_date` | date | true | Date (MST) of free bill |
| `free_bill_type_name` | `free_bill_type_name` | string | | Bill type for free bill (e.g. virtual, standard) |
| `free_target_expiration_mst_ts` | `free_target_expiration_mst_ts` | timestamp | true | Target expiration timestamp for free trial |
| `free_target_expiration_mst_date` | `free_target_expiration_mst_date` | date | true | Target expiration date for free trial |
| `free_acquisition_mst_ts` | `free_acquisition_mst_ts` | timestamp | true | Free trial acquisition timestamp |
| `free_acquisition_mst_date` | `free_acquisition_mst_date` | date | true | Free trial acquisition date |
| `paid_pf_id` | `paid_pf_id` | int | | Product family ID for paid product |
| `paid_bill_id` | `paid_bill_id` | string | | PK (partial). Bill ID of paid conversion bill |
| `paid_bill_line_num` | `paid_bill_line_num` | int | | PK (partial). Line number on paid conversion bill |
| `paid_bill_mst_ts` | `paid_bill_mst_ts` | timestamp | true | Timestamp (MST) of paid conversion bill |
| `paid_bill_mst_date` | `paid_bill_mst_date` | date | true | Date (MST) of paid conversion bill |
| `etl_build_mst_ts` | `etl_build_mst_ts` | timestamp | true | ETL build timestamp (MST) |

---

### Dataset: `c3_rev_attribution` (care_mart.rev_attribution) — DIMENSION

Source: `repos/lake/catalog/config/prod/us-west-2/care-mart/rev-attribution/table.ddl`

| OSI Field Name | SQL Expression | Type | is_time | Description |
|---|---|---|---|---|
| `order_id` | `order_id` | string | | PK. Order ID (corresponds to bill_id in ads_bill_line) |
| `order_source` | `order_source` | string | | Order source identifier |
| `shopper_id` | `shopper_id` | string | | Shopper ID |
| `agent_manager_user_id` | `agent_manager_user_id` | int | | Care agent/manager user ID |
| `c3_order_process_name` | `c3_order_process_name` | string | | C3 order process name |
| `c3_receipt_move_flag` | `c3_receipt_move_flag` | boolean | | True if bill retroactively attributed to Care |
| `order_ts` | `order_ts` | timestamp | true | Order timestamp |
| `attribution_type` | `attribution_type` | string | | C3 attribution type (e.g. Direct, Contact History) |
| `related_interaction_id` | `related_interaction_id` | string | | Related interaction ID |
| `related_interaction_platform` | `related_interaction_platform` | string | | Platform of related interaction |
| `related_interaction_source` | `related_interaction_source` | string | | Source of related interaction |
| `related_interaction_start_mst_ts` | `related_interaction_start_mst_ts` | timestamp | true | Related interaction start timestamp (MST) |
| `related_interaction_end_mst_ts` | `related_interaction_end_mst_ts` | timestamp | true | Related interaction end timestamp (MST) |
| `etl_build_mst_ts` | `etl_build_mst_ts` | timestamp | true | ETL build timestamp (MST) |

---

## Step 7: Metrics

Evidence sources: PySpark aggregation patterns (gather.md §7), Alation description (gather.md §11), and DDL column comments.

| name | expression | description | evidence |
|---|---|---|---|
| `total_gcr_usd` | `SUM(ads_bill_line.gcr_usd_amt)` | Total Gross Cash Receipts in USD. NULL for refunds and chargebacks. | DDL comment on `gcr_usd_amt`; Alation: "GCR metrics will be NULL for refunds and chargebacks" |
| `total_gcr_constant_currency` | `SUM(ads_bill_line.gcr_constant_currency_amt)` | Total GCR using constant FX rate to enable YoY trending without currency fluctuations. | DDL comment on `gcr_constant_currency_amt`; PySpark constant currency calculation |
| `total_receipt_price_usd` | `SUM(ads_bill_line.receipt_price_usd_amt)` | Total amount paid (USD) after discounts across bill lines. | DDL comment on `receipt_price_usd_amt` |
| `total_fair_market_value_usd` | `SUM(ads_bill_line.fair_market_value_usd_amt)` | Total fair market value in USD for revenue recognition. | DDL comment on `fair_market_value_usd_amt` |
| `total_unit_qty` | `SUM(ads_bill_line.unit_qty)` | Total number of units purchased. | DDL comment on `unit_qty` |
| `total_product_month_qty` | `SUM(ads_bill_line.product_month_qty)` | Total calendar months of subscription purchased. | DDL comment on `product_month_qty` |
| `distinct_order_count` | `COUNT(DISTINCT ads_bill_line.bill_id)` | Number of unique orders/bills (bills). | Grain definition; Alation: "bill_id is order_id on receipt" |
| `new_acquisition_count` | `COUNT(DISTINCT CASE WHEN ads_bill_line.new_acquisition_flag = TRUE THEN ads_bill_line.bill_id END)` | Count of new customer acquisition bills. | DDL comment on `new_acquisition_flag`; Alation: "count(distinct bill_id) where new_acquisition_flag=true" |
| `total_margin_gcr_usd` | `SUM(ads_bill_line.margin_gcr_usd_amt)` | Total GCR margin in USD after subtracting cost of goods sold. Note: cost is an approximation for domains. | DDL comment on `margin_gcr_usd_amt` |
| `total_commission_usd` | `SUM(ads_bill_line.commission_usd_amt)` | Total commission owed to 3rd-party sales channels in USD. | DDL comment on `commission_usd_amt` |

---

## Step 8: Semantic Model Metadata

### Model Name
`analytic_ads_bill_line`
- Derived from `schema=analytic` + `table=ads_bill_line`
- No override provided in INPUT.md

### Model Description
"Analytic Data Set (ADS) Bill Line — the analytic layer over GoDaddy eCommerce billing data providing one row per bill line item (product) per order/receipt. Replaces legacy `uds_order`/`pds_order` with updated taxonomy, incorporating core Enterprise Fact Bill/Fact Bill Line entities enriched with product, customer, geography, fraud, CRM, and marketing attribution dimensions. Includes refunds and chargebacks; GCR metrics are NULL for these. Partitioned by `partition_bill_mst_year_month` (YYYY-MM); daily refresh by 7:00 AM MST."

Source: Alation description (gather.md §11); PySpark script docstring.

### ai_context Draft

```yaml
ai_context:
  instructions: >
    Use this model for analyzing GoDaddy eCommerce billing and revenue data at the
    order line-item level. Each row represents one product (bill_line_num) on one
    order/receipt (bill_id). Refunds and chargebacks are included — filter using
    refund_flag and chargeback_flag. GCR metrics (gcr_usd_amt, gcr_constant_currency_amt)
    are NULL for refunds and chargebacks. When counting new customer acquisitions, use
    COUNT(DISTINCT bill_id) WHERE new_acquisition_flag = TRUE. For Web Pro orders,
    web_pro_participant_type_name reflects the shopper's current opt-in status, not
    status at time of order.
  synonyms:
    - "bill line"
    - "order line"
    - "receipt line"
    - "uds_order"
    - "pds_order"
    - "bill_line"
    - "ADS bill line"
    - "analytic bill line"
    - "ecomm transactions"
    - "order transactions"
  examples:
    - "What is the total GCR by product PnL category last month?"
    - "How many new customer acquisitions in Q4?"
    - "Show revenue by geographic region and reseller type."
    - "What is the renewal rate by product line?"
    - "Which customers have Web Pro orders?"
    - "What is the total receipt price for domain registrations by country?"
    - "Show GCR constant currency trend by year-month."
    - "How many orders came through Care (C3) vs. Web?"
```

---

## Step 9: "Do Not Claim" List

Items that are tempting but not proven — excluded from the OSI model:

| Item | Why excluded |
|---|---|
| `bill_line_ext` table (extended with GA traffic attributes) | Referenced in Alation description as a related table; not produced by this PySpark job; different table |
| Specific Confluence page content | No Confluence pages were provided; Alation reference to `/display/BI/ADS+Bill+Line` was not fetched |
| `dm_reference.dim_geography` as OSI dataset | Not found in lake catalog under any path; cannot use as OSI source |
| `dp_enterprise.dim_isc_source_code` as OSI dataset | Not found in lake catalog; ISC columns are fully denormalized into `ads_bill_line` |
| `analytic_feature.*` tables as OSI datasets | Schema found in dlms-api but no tables registered; cannot verify lake table existence |
| `ecomm_core_conformed.dim_customer_registration_acquisition` as OSI dataset | Not in lake catalog; accessed via direct Iceberg S3 read in PySpark |
| `fraud_cln.*` tables as OSI datasets | Schema entirely absent from lake catalog |
| Care rep PII fields as meaningful metrics | `c3_rep_name`, `crm_portfolio_rep_name` are encrypted PII; cannot build useful aggregates |
| Shopper-level counts | `merged_shopper_id` can change over time due to merges; counting distinct shoppers requires care |
| Web Pro status as "at time of order" | Alation explicitly notes this is **current** opt-in status, not historical |

---


**The agent's final response to the user was:**
The analysis is complete. Here's a summary of what was done:

## Work Summary

### Files Produced
- **`analyze.md`** — Full structured analysis appended (Steps 2–9)
- **`RESOLVED_TARGET.json`** — Target resolution with high confidence

---

### Key Findings

**Target Table:** `analytic.ads_bill_line`
- Path: `repos/lake/catalog/config/prod/us-west-2/analytic/ads-bill-line/`
- Grain: one row per `(bill_id, bill_line_num)` — confirmed by DQ constraint
- Confidence: **HIGH** (6 independent evidence sources)

**Lineage Resolution (29 source tables checked):**
- ✅ **15 RESOLVED** as lake tables (paths confirmed with DDLs)
- ⚠️ **14 UNRESOLVED** — schemas absent from lake catalog (`fraud_cln`, `dm_reference`, `dp_stage`, `dp_enterprise`, `gd_pro_mart`, `ecomm_core_conformed`) or table not found under known schema

**OSI Datasets (8 included):**
- 1 FACT: `analytic.ads_bill_line` (200 columns, all mapped)
- 7 DIMENSIONS: `ecomm360.dim_bill_vw`, `bigreporting.dim_product_snap`, `customer360.dim_customer_vw`, `partner360.dim_reseller_vw`, `gmode.customer_type_gcr_logic_lookup`, `enterprise.free_entitlement`, `care_mart.rev_attribution`

**Relationships (7 defined):** Including the complex 7-column BROADCAST join to `customer_type_gcr_logic_lookup`

**Metrics (10 defined):** All evidence-backed: GCR totals, receipt price, FMV, unit qty, product months, order counts, margin, commission