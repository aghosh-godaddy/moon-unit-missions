**Stage name:** research
**The coding agent was given these instructions:** You are a Data Governance analyst enriching column descriptions for a Data Lake table.

## Step 1: Read INPUT.md
Read `INPUT.md` in your workspace. It contains:
- The TARGET TABLE (database, table name, DDL path, YAML path)
- CONFLUENCE PAGES to fetch
- REFERENCE TABLES for Alation lookup
- ALATION configuration

Use these details for all subsequent steps.

## Step 2: Read the Table DDL and Metadata
From INPUT.md, determine the DDL and YAML paths. Read those EXACT files
from the cloned repository under `repos/lake/`.

## Step 3: Fetch Confluence Pages
For each URL listed in INPUT.md under CONFLUENCE PAGES, use the Atlassian
REST API to fetch page content. The page ID is the numeric part of the URL path.
For example, from URL `.../pages/10371978/Fact_Bill_Line`, the page ID is `10371978`.

**Credentials:** Confluence credentials are in the `MOONUNIT_JIRA` env var (JSON).
Extract them first:
```bash
ATLASSIAN_CREDS=$(node -e "const j=JSON.parse(process.env.MOONUNIT_JIRA); console.log(j.email + ':' + j.api_token)")
curl -s -u "$ATLASSIAN_CREDS" \
  "https://godaddy-corp.atlassian.net/wiki/rest/api/content/{PAGE_ID}?expand=body.storage"
```

Alternatively, if `MOONUNIT_ATLASSIAN` is set:
```bash
ATLASSIAN_CREDS=$(node -e "const j=JSON.parse(process.env.MOONUNIT_ATLASSIAN); console.log(j.email + ':' + j.api_token)")
curl -s -u "$ATLASSIAN_CREDS" \
  "https://godaddy-corp.atlassian.net/wiki/rest/api/content/{PAGE_ID}?expand=body.storage"
```

Fetch ALL pages listed in INPUT.md. Extract and summarize content relevant to
understanding what each column represents.

## Step 4: Alation Lookup (if enabled)
Check INPUT.md for ALATION configuration. If enabled:

First, extract Alation credentials and get an API access token:
```bash
ALATION_CREDS=$(node -e "const j=JSON.parse(process.env.MOONUNIT_ALATION); console.log(JSON.stringify({refresh_token:j.refresh_token, user_id:j.user_id}))")
curl -s -X POST "https://godaddy.alationcloud.com/integration/v1/createAPIAccessToken/" \
  -H "Content-Type: application/json" \
  -d "$ALATION_CREDS"
```
This returns a JSON with `api_access_token`. Use it as `TOKEN` header for subsequent calls.

Then search for the table (use the table name from INPUT.md, with underscores):
```
curl "https://godaddy.alationcloud.com/integration/v2/table/?name={table_name_underscored}&limit=5" \
  -H "TOKEN: $API_ACCESS_TOKEN"
```
Look for the entry with ds_id=81 (AwsDataCatalog) and matching schema. Note the table `id`.

Then fetch column metadata:
```
curl "https://godaddy.alationcloud.com/integration/v2/column/?table_id={table_id}&limit=200" \
  -H "TOKEN: $API_ACCESS_TOKEN"
```
Each column object contains these important fields:
- `name` — column name
- `description` — user-authored description in Alation (may be empty)
- `column_comment` — **Source Comment** propagated from the DDL COMMENT clause
  in the Data Lake Registry (GitHub). This is the existing inline comment from
  the table's DDL file. It may contain valuable annotations like 'Employee PII',
  business definitions, or enum descriptions that MUST be preserved or incorporated.
- `title` — display title in Alation

Extract BOTH `description` and `column_comment` for each column. When writing
enriched descriptions:
- If `column_comment` contains important annotations (e.g., 'Employee PII',
  enum values, business rules), these MUST be preserved in the enriched comment.
- If `column_comment` already has a meaningful description, use it as a strong
  starting point and enhance it to meet the Column Description Standard.
- If both `description` and `column_comment` exist, merge the information.

Also capture the table-level description from the search result, which contains
rich context about primary keys, use cases, and data quirks.

## Step 4a: Reference/Successor Tables
Check INPUT.md for REFERENCE TABLES. If any are listed, look up each table's
columns in Alation to extract existing column descriptions.

For each reference table, use the provided `alation_table_id`:
```
curl "https://godaddy.alationcloud.com/integration/v2/column/?table_id={alation_table_id}&limit=200" \
  -H "TOKEN: $API_ACCESS_TOKEN"
```
Extract both `description` and `column_comment` (Source Comment) for each column.
The `column_comment` field contains the DDL inline comment from the reference table's
Data Lake Registry — these are existing descriptions written by data engineers and
are a primary source of truth for what columns mean.
Also fetch the table-level metadata:
```
curl "https://godaddy.alationcloud.com/integration/v2/table/?id={alation_table_id}" \
  -H "TOKEN: $API_ACCESS_TOKEN"
```
Map columns from the reference table to the target table by name. Where column names
match, carry over the description as a strong candidate for the target column's comment.

## Step 4b: Certified Data Dictionary (Alation Document Folder 6) — MANDATORY
**CRITICAL:** You MUST fetch and use the official GoDaddy Certified Data Dictionary
definitions from Alation (Document Folder ID 6, URL: https://godaddy.alationcloud.com/doc-folder/6/).
These are GoDaddy's AUTHORITATIVE definitions. NEVER invent, guess, or fabricate
what an abbreviation stands for. If the dictionary says "GCR = Gross Cash Receipts",
you MUST use "Gross Cash Receipts" — not "Gross Customer Receipt" or any other variation.

**Procedure:**
1. Fetch ALL documents from the folder (paginate with skip):
```
curl "https://godaddy.alationcloud.com/integration/v2/document/?folder_id=6&limit=50&skip=0" \
  -H "TOKEN: $API_ACCESS_TOKEN"
curl "https://godaddy.alationcloud.com/integration/v2/document/?folder_id=6&limit=50&skip=50" \
  -H "TOKEN: $API_ACCESS_TOKEN"
curl "https://godaddy.alationcloud.com/integration/v2/document/?folder_id=6&limit=50&skip=100" \
  -H "TOKEN: $API_ACCESS_TOKEN"
```

2. Build a lookup table mapping abbreviations/terms to their official names:
Each document has `id`, `title`, `description` (HTML body).
The `title` contains the official term, e.g.:
- "Gross Cash Receipts (GCR)" — GCR = Gross Cash Receipts
- "New Registered User (NRU) Count" — NRU = New Registered User
- "Monthly Recurring Revenue (MRR)" — MRR = Monthly Recurring Revenue

3. For EVERY abbreviation found in column names (e.g., gcr, mrr, nru, mau, aos),
look up its official expansion in the dictionary titles. If found, you MUST use
the exact official name — DO NOT paraphrase or invent alternative expansions.

4. For each matching document, fetch its full definition:
```
curl "https://godaddy.alationcloud.com/integration/v2/document/?id={doc_id}" \
  -H "TOKEN: $API_ACCESS_TOKEN"
```
Extract the official definition from the `description` field (HTML).

5. In your research output, create a section called "## Certified Data Dictionary Mappings"
that explicitly lists EVERY abbreviation → official name mapping you found.
Example:
```
| Abbreviation | Official Name | Document ID |
|---|---|---|
| GCR | Gross Cash Receipts | 6 |
| MSRP | Manufacturer's Suggested Retail Price | (not in dictionary) |
```

**RULE: If an abbreviation is in the Certified Data Dictionary, its official expansion
is the ONLY acceptable expansion. Never fabricate alternatives.**

## Step 5: Produce Research Output
The framework pre-created `research.md` in your workspace with a header.
Append — do not overwrite — a structured research document containing:
- The full current DDL
- Key metadata from table.yaml (description, lineage, upstream dependencies)
- Summarized knowledge from Confluence pages
- Alation catalog metadata (if available), including Source Comments (column_comment)
  from both the target table and reference tables
- Certified Data Dictionary Mappings (the mandatory table from Step 4b)
- For each column: current DDL comment (if any), Alation Source Comment (if any),
  Alation description (if any), inferred purpose, and relevant context from all sources

Environment variables available (all are JSON, parse with node):
- MOONUNIT_JIRA — {"url","email","api_token"} (use for Confluence access)
- MOONUNIT_ATLASSIAN — {"email","api_token"} (alternative Confluence creds)
- MOONUNIT_ALATION — {"url","refresh_token","user_id"} (Alation access)

**The agent summarized its work in this way:**

---

## Research Summary: ecomm360.fact_bill_line_vw

**Date:** 2026-05-13
**Analyst:** Data Governance Research Stage

---

## 1. Table DDL (Current)

```sql
CREATE TABLE fact_bill_line_vw (
    bill_id string COMMENT 'Primary Key - Unique identifier for the bill',
    bill_line_num int COMMENT 'Line number within the bill to identify specific items',
    original_bill_id string COMMENT 'Reference to the original bill ID in case of modifications or refunds',
    original_bill_line_num int COMMENT 'Original line number from the source bill before any modifications',
    event_id string COMMENT 'Unique identifier for the event that generated this bill line',
    source_system_name string COMMENT 'Name of the source system that originated this billing data',
    bill_modified_mst_ts timestamp COMMENT 'Timestamp when the bill was last modified in Mountain Standard Time',
    bill_modified_mst_date date COMMENT 'Date when the bill was last modified in Mountain Standard Time',
    subaccount_customer_id string COMMENT 'Customer identifier for subaccount associated with this bill line',
    refund_flag boolean COMMENT 'Flag indicating if this bill line represents a refund transaction',
    chargeback_flag boolean COMMENT 'Flag indicating if this bill line represents a chargeback transaction',
    item_tracking_code string COMMENT 'Internal tracking code for the specific item being billed',
    department_id int COMMENT 'Department identifier responsible for this billing line',
    accounting_company_id int COMMENT 'Company identifier for accounting purposes',
    accounting_deferred_flag boolean COMMENT 'Flag indicating if revenue recognition is deferred for accounting',
    pf_id int COMMENT 'Product Family identifier for categorizing the billed product',
    product_uri string COMMENT 'Uniform Resource Identifier for the specific product',
    upgraded_pf_id int COMMENT 'Product Family ID after upgrade if applicable',
    private_label_id int COMMENT 'Identifier for private label partner if applicable',
    bill_country_code string COMMENT 'ISO country code where the billing address is located',
    bill_sub_geo_code string COMMENT 'Sub-geographic code for more specific location within the country',
    bill_postal_code string COMMENT 'Postal or ZIP code of the billing address',
    bill_source_name string COMMENT 'Name of the billing source or channel that generated this line',
    primary_payment_type_name string COMMENT 'Primary payment method type used for this transaction',
    primary_payment_subtype_name string COMMENT 'Subtype or specific variant of the primary payment method',
    secondary_payment_type_name string COMMENT 'Secondary payment method if multiple payment types were used',
    secondary_payment_subtype_name string COMMENT 'Subtype of the secondary payment method',
    order_site_language_code string COMMENT 'Language code of the website where the order was placed',
    translation_language_name string COMMENT 'Language name for any translation services applied',
    free_order_flag boolean COMMENT 'Flag indicating if this was a free order with no charge',
    bill_isc_source_code string COMMENT 'Internal source code for ISC (Internal Sales Channel) tracking',
    virtual_order_flag boolean COMMENT 'Flag indicating if this was a virtual or digital-only order',
    unit_qty int COMMENT 'Quantity of units purchased for this line item',
    duration_qty int COMMENT 'Duration quantity (e.g., number of months for subscription)',
    product_unit_qty int COMMENT 'Quantity of product units independent of duration',
    product_month_qty int COMMENT 'Number of months the product is valid for',
    entered_by_name string COMMENT 'Name or identifier of the person who entered this bill line',
    bill_friendly_id string COMMENT 'Human-readable friendly identifier for the bill',
    receipt_price_usd_amt double COMMENT 'Receipt price amount in USD as shown to customer',
    receipt_price_trxn_amt double COMMENT 'Receipt price amount in the transaction currency',
    gcr_usd_amt double COMMENT 'Gross Customer Receipt amount in USD',
    gcr_trxn_amt double COMMENT 'Gross Customer Receipt amount in transaction currency',
    margin_gcr_usd_amt double COMMENT 'Margin calculation on Gross Customer Receipt in USD',
    margin_gcr_trxn_amt double COMMENT 'Margin calculation on Gross Customer Receipt in transaction currency',
    commission_usd_amt double COMMENT 'Commission amount paid in USD',
    commission_trxn_amt double COMMENT 'Commission amount paid in transaction currency',
    aftermarket_seller_commission_usd_amt double COMMENT 'Commission paid to aftermarket sellers in USD',
    aftermarket_seller_commission_trxn_amt double COMMENT 'Commission paid to aftermarket sellers in transaction currency',
    cost_usd_amt double COMMENT 'Cost of goods sold amount in USD',
    cost_trxn_amt double COMMENT 'Cost of goods sold amount in transaction currency',
    msrp_duration_unit_usd_amt double COMMENT 'Manufacturer Suggested Retail Price per duration unit in USD',
    msrp_duration_unit_trxn_amt double COMMENT 'Manufacturer Suggested Retail Price per duration unit in transaction currency',
    msrp_total_usd_amt double COMMENT 'Total Manufacturer Suggested Retail Price in USD',
    msrp_total_trxn_amt double COMMENT 'Total Manufacturer Suggested Retail Price in transaction currency',
    fee_usd_amt double COMMENT 'Additional fees charged in USD',
    fee_trxn_amt double COMMENT 'Additional fees charged in transaction currency',
    fair_market_value_usd_amt double COMMENT 'Fair market value assessment in USD',
    fair_market_value_trxn_amt double COMMENT 'Fair market value assessment in transaction currency',
    tax_usd_amt double COMMENT 'Tax amount charged in USD',
    tax_trxn_amt double COMMENT 'Tax amount charged in transaction currency',
    receipt_regular_price_usd_amt double COMMENT 'Regular price before discounts in USD',
    receipt_regular_price_trxn_amt double COMMENT 'Regular price before discounts in transaction currency',
    injected_fair_market_value_usd_amt double COMMENT 'System-injected fair market value adjustment in USD',
    injected_fair_market_value_trxn_amt double COMMENT 'System-injected fair market value adjustment in transaction currency',
    injected_icann_fee_usd_amt double COMMENT 'ICANN regulatory fee amount injected by system in USD',
    injected_icann_fee_trxn_amt double COMMENT 'ICANN regulatory fee amount injected by system in transaction currency',
    injected_tax_usd_amt double COMMENT 'Tax amount injected by system in USD',
    injected_tax_trxn_amt double COMMENT 'Tax amount injected by system in transaction currency',
    bundle_allocated_revenue_usd_amt double COMMENT 'Revenue allocated to this item from bundle pricing in USD',
    reseller_commission_usd_amt double COMMENT 'Commission paid to reseller partners in USD',
    parent_reseller_commission_usd_amt double COMMENT 'Commission paid to parent reseller in USD',
    trxn_currency_code string COMMENT 'ISO currency code for the transaction',
    renewal_price_locked_flag boolean COMMENT 'Flag indicating if renewal price is locked for future periods',
    offer_id int COMMENT 'Identifier for the specific offer or promotion applied',
    offer_collection_id int COMMENT 'Identifier for the collection of offers this item belongs to',
    free_product_package_id int COMMENT 'Identifier for free product package if applicable',
    variant_price_type_id int COMMENT 'Identifier for the pricing variant type applied',
    exclude_reason_desc string COMMENT 'Description of reason why this line item might be excluded from reports',
    exclude_reason_month_end_desc string COMMENT 'Month-end specific exclusion reason description',
    list_price_usd_amt double COMMENT 'Published list price in USD',
    list_price_trxn_amt double COMMENT 'Published list price in transaction currency',
    sale_price_usd_amt double COMMENT 'Final sale price after discounts in USD',
    sale_price_trxn_amt double COMMENT 'Final sale price after discounts in transaction currency',
    item_subtotal_usd_amt double COMMENT 'Subtotal for this line item in USD',
    item_subtotal_trxn_amt double COMMENT 'Subtotal for this line item in transaction currency',
    product_list_price_usd_amt double COMMENT 'Product-specific list price in USD',
    product_list_price_trxn_amt double COMMENT 'Product-specific list price in transaction currency',
    variant_price_type_name string COMMENT 'Name of the pricing variant type applied',
    item_tracking_code_desc string COMMENT 'Description of the item tracking code',
    purchase_path_name string COMMENT 'Name of the purchase path or customer journey',
    parent_bill_id string COMMENT 'Bill ID of the parent transaction if this is a child transaction',
    child_bill_id string COMMENT 'Bill ID of child transactions spawned from this bill',
    item_discount_code string COMMENT 'The discount code applied to this item, if any',
    free_trial_flag boolean COMMENT 'Indicates whether or not the order row is part of a free trial',
    intent string COMMENT 'Intent Enum for virtual bill with value such as FREEMIUM_PURCHASE, FREE_PURCHASE, FREE_TRIAL_MODIFY, etc',
    related_subscription string COMMENT 'Associate a receiptless or virtual order event to a specific subscription',
    etl_insert_utc_ts timestamp COMMENT 'ETL process timestamp when record was first inserted in UTC',
    etl_update_utc_ts timestamp COMMENT 'ETL process timestamp when record was last updated in UTC'
);
```

---

## 2. Table YAML Metadata (table.yaml)

- **Description:** "tracks every receipt of the purchase of a godaddy customer."
- **Table type:** ICEBERG (Parquet storage)
- **Data tier:** 3
- **Partition key:** `bill_modified_mst_date_month` (string)
- **SLA:** Delivered by 3 AM MST daily (`cron(0 10 * * ? *)`)
- **SLO Identifier:** `ecomm360.fact_bill_line_vw`
- **Upstream lineage:**
  - `signals_platform_cln.ecomm_unified_order_event_cln`
  - `signals_platform_cln.ecomm_order_item_event_cln`
  - `signals_platform_cln.ecomm_order_finance_item_cln`
  - `signals_platform_cln.ecomm_order_payment_event_cln`

---

## 3. Confluence Page Summary (Page ID: 3688240210 — Fact_Bill_Line_Vw)

**URL:** https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3688240210/Fact_Bill_Line_Vw

### Purpose
Enterprise Dataset (EDS) that provides a **comprehensive view of a receipt for the purchase of GoDaddy products**.

- Table: `ecomm360.fact_bill_line_vw`
- **Primary Key:** `bill_id`, `bill_line_num`
- **Foreign Key:** `pf_id` → `dim_product`

### Architecture
- Data from the **Event Bus Platform (EBP)** → Clean Layer → PySpark ETL → Iceberg EDS
- `fact_bill_line`: Immutable transactional data (receipts)
- `dim_bill`: SCD2 dimension tracking mutable attribute history
- ETL scheduled via Airflow (~2× daily, higher frequency for special events)

### Key Column Derivation Details (from Confluence physical data model table)

| fact_bill_line_vw Column | Source Column | Source Table | Notes |
|---|---|---|---|
| bill_id | order_id | ecomm_order_item_event_cln | PK |
| bill_line_num | row_id | ecomm_order_item_event_cln | PK |
| original_bill_id | original_order_id | ecomm_order_finance_item_cln | |
| original_bill_line_num | original_row_id | ecomm_order_finance_item_cln | |
| event_id | event_id | ecomm_order_item_event_cln | |
| source_system_name | CASE WHEN lower(source_system)='ces' THEN 'legacy e-comm' ELSE source_system END | ecomm_unified_order_event_cln | |
| bill_modified_mst_ts | from_utc_timestamp(order_date_utc_ts, 'MST') | ecomm_unified_order_event_cln | |
| bill_modified_mst_date | TO_DATE(FROM_UTC_TIMESTAMP(order_date_utc_ts, 'MST')) | ecomm_unified_order_event_cln | |
| subaccount_customer_id | subaccount_customer_id | ecomm_unified_order_event_cln | |
| refund_flag | CASE WHEN INSTR(order_id,'R') > 0 THEN TRUE ELSE FALSE END | ecomm_order_item_event_cln | Derived from 'R' in order_id |
| chargeback_flag | CASE WHEN INSTR(order_id,'C') > 0 THEN TRUE ELSE FALSE END | ecomm_order_item_event_cln | Derived from 'C' in order_id |
| item_tracking_code | LOWER(TRIM(regexp_replace(gdshop_item_trackingcode,"\n",""))) | ecomm_order_item_event_cln | Normalized |
| department_id | department_id | ecomm_order_item_event_cln | |
| accounting_company_id | CASE (7→1, 9→2, 13→1, 14→2, else as-is) | ecomm_order_item_event_cln | Company remapping: CA/India subsidiaries → parent entity |
| accounting_deferred_flag | CASE WHEN finance_deferrment_configuration_type_id IS NULL THEN FALSE ELSE TRUE END | ecomm_order_finance_item_cln | |
| pf_id | pf_id | ecomm_order_item_event_cln | FK to dim_product |
| product_uri | NULL (reserved for future) | — | Not yet populated |
| upgraded_pf_id | upgraded_pf_id | ecomm_order_finance_item_cln | |
| private_label_id | private_label_id | ecomm_unified_order_event_cln | |
| bill_country_code | billing_country_code | ecomm_unified_order_event_cln | |
| bill_sub_geo_code | billing_state_code | ecomm_unified_order_event_cln | |
| bill_postal_code | billing_zip_code | ecomm_unified_order_event_cln | |
| bill_source_name | order_point_of_purchase | ecomm_unified_order_event_cln | |
| primary_payment_type_name | payment_type (rank 1 by payment_usd_amt DESC) | ecomm_order_payment_event_cln | |
| primary_payment_subtype_name | payment_sub_type (rank 1) | ecomm_order_payment_event_cln | |
| secondary_payment_type_name | payment_type (rank 2 by payment_usd_amt DESC) | ecomm_order_payment_event_cln | |
| secondary_payment_subtype_name | payment_sub_type (rank 2) | ecomm_order_payment_event_cln | |
| order_site_language_code | COALESCE(LOWER(market_id),'Missing') | ecomm_unified_order_event_cln | |
| translation_language_name | NULL (reserved for future) | — | Not yet populated |
| free_order_flag | Derived: SUM(gcr_usd_amt - fee - injected_icann_fee) per bill_id > 0 OR refund/chargeback = FALSE | Multiple | |
| bill_isc_source_code | CASE: order_discount_Code if non-blank, else '???' (online) or '?SR' (non-online) | ecomm_unified_order_event_cln | ISC = Internal Sales Channel |
| virtual_order_flag | FALSE (reserved for future) | — | Not yet populated |
| unit_qty | product_qty | ecomm_order_item_event_cln | |
| duration_qty | item_period_value | ecomm_order_item_event_cln | |
| product_unit_qty | CASE WHEN unitsasorders=TRUE THEN 1 ELSE product_qty END | bigreporting.dim_product_snap | |
| product_month_qty | Lookup on period type (month=1, year=12, quarter=3, etc.) | bigreporting.dim_product_snap | |
| entered_by_name | order_entered_by_type | ecomm_unified_order_event_cln | |
| bill_friendly_id | N/A (reserved for future) | — | Not yet populated |
| receipt_price_usd_amt | item_subtotal_usd_amt | ecomm_order_item_event_cln | |
| receipt_price_trxn_amt | item_subtotal_trxn_amt | ecomm_order_item_event_cln | |
| gcr_usd_amt | Derived: fair_market_value + item_subtotal - icann_fee - injected_fair_market_value - injected_icann_fee | Multiple | GCR formula |
| gcr_trxn_amt | Derived (transaction currency) | Multiple | |
| margin_gcr_usd_amt | Derived: injected_icann_fee - cost_item_actual_cost | ecomm_order_finance_item_cln | |
| margin_gcr_trxn_amt | Derived (transaction currency) | ecomm_order_finance_item_cln | |
| commission_usd_amt | c3_commission_usd_amt | ecomm_order_item_event_cln | C3 = channel 3 |
| commission_trxn_amt | c3_commission_trxn_amt | ecomm_order_item_event_cln | |
| aftermarket_seller_commission_usd_amt | CASE WHEN commission_product_flag=1 THEN fair_market_value - domain_auction_commission ELSE 0 END | ecomm_order_item_event_cln | Domain aftermarket seller |
| aftermarket_seller_commission_trxn_amt | Same in trxn currency | ecomm_order_item_event_cln | |
| cost_usd_amt | cost_item_actual_cost_usd_amt | ecomm_order_finance_item_cln | |
| cost_trxn_amt | cost_item_actual_cost_trxn_amt | ecomm_order_finance_item_cln | |
| msrp_duration_unit_usd_amt | ROUND((product_list_price_usd_amt * qty * period) + icann_fee) | Multiple | Current list price × period |
| msrp_duration_unit_trxn_amt | ROUND((product_list_price_trxn_amt * qty * period) + icann_fee_trxn) | Multiple | |
| msrp_total_usd_amt | ROUND((product_original_list_price_usd_amt * qty * period) + icann_fee) | Multiple | Original (undiscounted) list price |
| msrp_total_trxn_amt | ROUND((product_original_list_price_trxn_amt * qty * period) + icann_fee_trxn) | Multiple | |
| fee_usd_amt | tax_item_icann_fee_usd_amt | ecomm_order_finance_item_cln | **ICANN fee specifically** |
| fee_trxn_amt | tax_item_icann_fee_trxn_amt | ecomm_order_finance_item_cln | |
| fair_market_value_usd_amt | finance_fair_market_value_usd_amt | ecomm_order_finance_item_cln | |
| fair_market_value_trxn_amt | finance_fair_market_value_trxn_amt | ecomm_order_finance_item_cln | |
| tax_usd_amt | item_tax_usd_amt | ecomm_order_item_event_cln | |
| tax_trxn_amt | item_tax_trxn_amt | ecomm_order_item_event_cln | |
| receipt_regular_price_usd_amt | ROUND((adjusted_current_price * qty * period) + icann_fee) | Multiple | Current period price (with discounts) |
| receipt_regular_price_trxn_amt | Same in trxn currency | Multiple | |
| injected_fair_market_value_usd_amt | finance_injected_fair_market_value_usd_amt | ecomm_order_finance_item_cln | |
| injected_fair_market_value_trxn_amt | finance_injected_fair_market_value_trxn_amt | ecomm_order_finance_item_cln | |
| injected_icann_fee_usd_amt | tax_item_injected_icann_fee_adjusted_usd_amt | ecomm_order_finance_item_cln | |
| injected_icann_fee_trxn_amt | tax_item_injected_icann_fee_adjusted_trxn_amt | ecomm_order_finance_item_cln | |
| injected_tax_usd_amt | tax_item_injected_tax_amt | ecomm_order_finance_item_cln | |
| injected_tax_trxn_amt | tax_item_injected_tax_trxn_amt | ecomm_order_finance_item_cln | |
| bundle_allocated_revenue_usd_amt | finance_bundle_allocated_revenue_usd_amt | ecomm_order_finance_item_cln | |
| reseller_commission_usd_amt | SUM(commission) * 0.01 | godaddyaccounting.resellercommission_mart_snap | |
| parent_reseller_commission_usd_amt | SUM(parent_commission) * 0.01 | godaddyaccounting.resellercommission_mart_snap | |
| trxn_currency_code | trxn_currency_code | ecomm_unified_order_event_cln | |
| bill_country_code | billing_country_code | ecomm_unified_order_event_cln | |
| bill_sub_geo_code | billing_state_code | ecomm_unified_order_event_cln | |
| bill_postal_code | billing_zip_code | ecomm_unified_order_event_cln | |
| bill_source_name | order_point_of_purchase | ecomm_unified_order_event_cln | |
| renewal_price_locked_flag | renewal_price_locked_flag | ecomm_order_item_event_cln | |
| offer_id | bundle_id | ecomm_order_item_event_cln | Renamed from bundle_id |
| offer_collection_id | parent_bundle_id | ecomm_order_item_event_cln | Renamed from parent_bundle_id |
| free_product_package_id | free_product_package_id | ecomm_order_item_event_cln | |
| variant_price_type_id | variant_price_type_id | ecomm_order_item_event_cln | |
| exclude_reason_desc | CASE: COALESCE(order_exclude_reason, row_exclude_reason_desc) | ecomm_cln_local.ref_excluded_products | |
| exclude_reason_month_end_desc | CASE: COALESCE(order_exclude_reason_monthend, row_exclude_reason_monthend_desc) | ecomm_cln_local.ref_excluded_products | |
| list_price_usd_amt | product_original_list_price_usd_amt | ecomm_order_item_event_cln | Original (undiscounted) list price |
| list_price_trxn_amt | product_original_list_price_trxn_amt | ecomm_order_item_event_cln | |
| sale_price_usd_amt | adjusted_current_price_usd_amt | ecomm_order_item_event_cln | Current discounted price |
| sale_price_trxn_amt | adjusted_current_price_trxn_amt | ecomm_order_item_event_cln | |
| item_subtotal_usd_amt | item_subtotal_usd_amt | ecomm_order_item_event_cln | |
| item_subtotal_trxn_amt | item_subtotal_trxn_amt | ecomm_order_item_event_cln | |
| product_list_price_usd_amt | product_list_price_usd_amt | ecomm_order_item_event_cln | Current period list price |
| product_list_price_trxn_amt | product_list_price_trxn_amt | ecomm_order_item_event_cln | |
| etl_insert_utc_ts | ETL process timestamp | — | |
| etl_update_utc_ts | ETL process timestamp | — | |

---

## 4. Alation Lookup

**Status: UNAVAILABLE — Refresh token expired (HTTP 401)**

The Alation API refresh token stored in `MOONUNIT_ALATION` is expired or revoked. Consequently, the following data could not be retrieved:
- Target table column metadata (`description`, `column_comment`) from Alation
- Reference table column metadata for the four upstream tables
- Certified Data Dictionary (Document Folder 6)

All column analysis below is based on:
1. Existing DDL comments
2. Confluence page derivation tables
3. YAML metadata

---

## 5. Certified Data Dictionary Mappings

**Status: UNAVAILABLE — Alation API token expired**

The following abbreviations appear in column names and require dictionary lookup. Known expansions from Confluence context and existing DDL are noted, but **cannot be confirmed as authoritative** without Alation access:

| Abbreviation | Likely Official Name | Source | Document ID |
|---|---|---|---|
| GCR | Gross Cash Receipts (NOT "Gross Customer Receipt") | Confluence formula context; DDL current says "Gross Customer Receipt" — needs dict confirmation | Unknown |
| MSRP | Manufacturer's Suggested Retail Price | DDL existing comment | Unknown |
| ISC | Internal Sales Channel | Confluence: bill_isc_source_code description | Unknown |
| ICANN | Internet Corporation for Assigned Names and Numbers | Industry standard | N/A |
| ETL | Extract, Transform, Load | Standard | N/A |
| MST | Mountain Standard Time | Standard | N/A |
| UTC | Coordinated Universal Time | Standard | N/A |
| EDS | Enterprise Dataset | Confluence: "Enterprise Dataset (EDS')" | N/A |
| PF | Product Family | DDL: pf_id = Product Family | N/A |
| SCD2 | Slowly Changing Dimension Type 2 | Confluence | N/A |

> **NOTE:** The `gcr_usd_amt` column currently has COMMENT 'Gross **Customer** Receipt amount in USD' but Confluence context (GCR = sum of fair market value components) strongly suggests it should be "Gross **Cash** Receipts". This MUST be confirmed against Alation Document Folder 6 when the token is renewed.

---

## 6. Per-Column Research Notes

### Identity & Keys
- **bill_id** — PK (Confluence confirmed). Maps from `order_id` in ecomm_order_item_event_cln. Current comment good.
- **bill_line_num** — PK (composite with bill_id). Maps from `row_id`. Current comment good.
- **original_bill_id** — Maps from `original_order_id` in ecomm_order_finance_item_cln. Used for refund/modification tracing. Current comment acceptable.
- **original_bill_line_num** — Maps from `original_row_id`. Current comment acceptable.
- **event_id** — From ecomm_order_item_event_cln.event_id (Event Bus event). Current comment good.

### System/Source Metadata
- **source_system_name** — CASE logic: 'ces' → 'legacy e-comm', others as-is. Values indicate origin system (e.g., "legacy e-comm", "new-ecomm"). Current comment could be improved to mention normalization logic.
- **bill_modified_mst_ts** — Derived: `from_utc_timestamp(order_date_utc_ts, 'MST')`. Note: this is the **order date** converted to MST, not a modification timestamp. The term "modified" in the name reflects legacy naming. Current comment acceptable.
- **bill_modified_mst_date** — Same as above, date-only. Current comment acceptable.
- **etl_insert_utc_ts** — ETL metadata. Current comment good.
- **etl_update_utc_ts** — ETL metadata. Current comment good.

### Customer/Account
- **subaccount_customer_id** — Customer ID for subaccounts (not the primary account holder). From ecomm_unified_order_event_cln. Current comment good.
- **private_label_id** — Identifier for private label (reseller/white-label partner). From ecomm_unified_order_event_cln. Current comment good.

### Transaction Classification
- **refund_flag** — Derived from presence of 'R' in order_id string (INSTR check). Current comment good.
- **chargeback_flag** — Derived from presence of 'C' in order_id string. Current comment good.
- **free_order_flag** — Derived formula: order is free if sum of (gcr - fee - injected_icann_fee) over the bill ≤ 0 AND not a refund/chargeback. Current comment could mention the GCR-based derivation.
- **virtual_order_flag** — Currently always FALSE (reserved for future use). Current comment acceptable.
- **free_trial_flag** — Indicates free trial order row. Current comment good.
- **intent** — Virtual bill intent enum. Current comment already lists example values (FREEMIUM_PURCHASE, FREE_PURCHASE, FREE_TRIAL_MODIFY). Good existing comment.
- **related_subscription** — Associates receiptless/virtual orders to subscriptions. Current comment good.

### Product & Pricing Identifiers
- **item_tracking_code** — Normalized (LOWER/TRIM/regex) from gdshop_item_trackingcode. Current comment acceptable; could note normalization.
- **item_tracking_code_desc** — Description of item tracking code. No Confluence source noted; likely a lookup-enriched field.
- **pf_id** — FK to dim_product. Current comment mentions "Product Family" — consistent with Confluence.
- **upgraded_pf_id** — Product Family ID after upgrade. From ecomm_order_finance_item_cln. Current comment good.
- **product_uri** — NULL (reserved for future). Current comment acceptable; could note "currently NULL, reserved for future use".
- **department_id** — From ecomm_order_item_event_cln.department_id. Current comment acceptable.
- **accounting_company_id** — Remapped: company 7→1, 9→2, 13→1, 14→2 to consolidate Canadian/Indian subsidiaries into parent entities. Current comment "Company identifier for accounting purposes" is too generic — should mention the remapping context.
- **accounting_deferred_flag** — TRUE when finance_deferrment_configuration_type_id is not NULL. Current comment good.
- **variant_price_type_id** — Pricing variant type. From ecomm_order_item_event_cln. Current comment good.
- **variant_price_type_name** — Human-readable name for pricing variant. Current comment good.

### Geographic/Localization
- **bill_country_code** — ISO country code from billing_country_code. Current comment good.
- **bill_sub_geo_code** — Maps from billing_state_code. This is state/province code, not generic sub-geo. Current comment could be more specific.
- **bill_postal_code** — Maps from billing_zip_code. Current comment good.
- **order_site_language_code** — COALESCE(LOWER(market_id),'Missing'). Market ID = language locale of purchase site. Defaults to 'Missing' when null. Current comment good.
- **translation_language_name** — NULL (reserved for future). Current comment acceptable.

### Payment
- **primary_payment_type_name** — Highest `payment_usd_amt` payment record's payment_type. Current comment good.
- **primary_payment_subtype_name** — Subtype of highest-value payment. Current comment good.
- **secondary_payment_type_name** — Second-ranked payment record's payment_type. Current comment good.
- **secondary_payment_subtype_name** — Subtype of second payment. Current comment good.
- **trxn_currency_code** — ISO currency code from ecomm_unified_order_event_cln. Current comment good.

### Sales Channel
- **bill_source_name** — Maps from order_point_of_purchase. Represents the point-of-sale channel. Current comment ("billing source or channel") is accurate.
- **bill_isc_source_code** — ISC = Internal Sales Channel. Derived: use order_discount_Code if present, else derive from point_of_purchase ('???' for online, '?SR' for non-online). Current comment good.
- **bill_friendly_id** — Currently 'N/A' (reserved for future). Current comment acceptable; could note "currently not populated".

### Quantities
- **unit_qty** — Maps from product_qty. Number of units ordered. Current comment good.
- **duration_qty** — Maps from item_period_value. Number of period units (e.g., months, years) for the subscription term. Current comment good.
- **product_unit_qty** — Adjusted quantity: if `unitsasorders`=TRUE for product then 1, else product_qty. Useful for products sold as single units regardless of quantity field. Current comment could better explain the unitsasorders logic.
- **product_month_qty** — Number of calendar months for the subscription period. Lookup table: month=1, year=12, quarter=3, 4-month=4, 6-month=6, onetime=1. Current comment good.

### Financial Metrics (USD & Transaction Currency Pairs)
- **receipt_price_usd_amt / receipt_price_trxn_amt** — Direct item_subtotal (what customer paid). Current comments good.
- **gcr_usd_amt / gcr_trxn_amt** — GCR = Gross Cash Receipts (to be confirmed). Complex formula: fair_market_value + item_subtotal - icann_fee - injected_fair_market_value - injected_icann_fee. **Current DDL comment says "Gross Customer Receipt" — this likely should be "Gross Cash Receipts" per GoDaddy standard.**
- **margin_gcr_usd_amt / margin_gcr_trxn_amt** — GCR margin = injected_icann_fee - cost. Current comment mentions "Gross Customer Receipt" — same correction needed as gcr_usd_amt.
- **commission_usd_amt / commission_trxn_amt** — C3 (Channel 3) commission. Current comments good.
- **aftermarket_seller_commission_usd_amt / trxn_amt** — For domain aftermarket sales: fair_market_value minus domain_auction_commission when commission_product_flag=1, else 0. Current comments good.
- **cost_usd_amt / cost_trxn_amt** — Actual cost of goods (cost_item_actual_cost). Current comments good.
- **msrp_duration_unit_usd_amt / trxn_amt** — MSRP based on **current** product_list_price × qty × period + ICANN fee. Current comments mention "per duration unit" — accurate.
- **msrp_total_usd_amt / trxn_amt** — MSRP based on **original** (undiscounted) product_original_list_price × qty × period + ICANN fee. **Key distinction from msrp_duration_unit: uses original list price.** Current comments say "Total Manufacturer Suggested Retail Price" — could note "based on original undiscounted list price".
- **fee_usd_amt / fee_trxn_amt** — **SPECIFICALLY the ICANN fee** (tax_item_icann_fee). Current comment "Additional fees charged" is too generic — should specify ICANN regulatory fee.
- **fair_market_value_usd_amt / trxn_amt** — FMV from ecomm_order_finance_item_cln. Current comments good.
- **tax_usd_amt / tax_trxn_amt** — Item-level tax from ecomm_order_item_event_cln. Current comments good.
- **receipt_regular_price_usd_amt / trxn_amt** — ROUND((adjusted_current_price × qty × period) + icann_fee). This is the price at current rates including any active discounts. **Distinct from list_price (original) and receipt_price (actual paid).** Current comment "Regular price before discounts" is potentially misleading — this includes current discounts (adjusted_current_price), it's the **current-period price**.
- **injected_fair_market_value_usd_amt / trxn_amt** — System-injected FMV adjustment. Current comments good.
- **injected_icann_fee_usd_amt / trxn_amt** — System-injected adjusted ICANN fee. Current comments good.
- **injected_tax_usd_amt / trxn_amt** — System-injected tax. Current comments good.
- **bundle_allocated_revenue_usd_amt** — Revenue allocated from bundle pricing. Current comment good.
- **reseller_commission_usd_amt** — SUM(commission) * 0.01 from resellercommission_mart_snap. Current comment good.
- **parent_reseller_commission_usd_amt** — SUM(parent_commission) * 0.01. Current comment good.
- **list_price_usd_amt / trxn_amt** — Original (undiscounted) list price: product_original_list_price. Current comments say "Published list price" — acceptable, but "original undiscounted list price" more precise.
- **sale_price_usd_amt / trxn_amt** — Adjusted current price (with discounts applied). Current comments say "Final sale price after discounts" — accurate.
- **item_subtotal_usd_amt / trxn_amt** — Raw item subtotal before any finance adjustments. Current comments good.
- **product_list_price_usd_amt / trxn_amt** — Per-unit current list price (not multiplied by qty/period). Current comments say "Product-specific list price" — acceptable.

### Offer/Bundle
- **offer_id** — Maps from `bundle_id` in ecomm_order_item_event_cln. Renamed for EDS clarity. Current comment "specific offer or promotion" is reasonable, but noting the bundle_id source adds context.
- **offer_collection_id** — Maps from `parent_bundle_id`. Current comment "collection of offers" aligns with parent bundle concept.
- **free_product_package_id** — From ecomm_order_item_event_cln. Current comment good.
- **renewal_price_locked_flag** — Price lock for renewals. Current comment good.

### Exclusions
- **exclude_reason_desc** — Derived from ref_excluded_products: COALESCE(order_exclude_reason, row_exclude_reason_desc) when not refund/chargeback; for refunds/chargebacks only order_exclude_reason. Current comment good.
- **exclude_reason_month_end_desc** — Month-end specific exclusion from ref_excluded_products. NULL for refund/chargeback records. Current comment good.

### Additional
- **entered_by_name** — Maps from order_entered_by_type (type of entity that entered the order). Current comment good.
- **purchase_path_name** — Not found in Confluence mapping table; likely the purchase path/funnel name. Current comment good.
- **parent_bill_id** — Not found in Confluence mapping table. Current comment good.
- **child_bill_id** — Not found in Confluence mapping table. Current comment good.
- **item_discount_code** — Discount code applied to item. Current comment good.

---

## 7. Columns Needing Enrichment/Correction

Based on research, the following columns have comments that need improvement:

| Column | Issue | Recommended Change |
|---|---|---|
| gcr_usd_amt | "Gross Customer Receipt" likely incorrect; should be "Gross Cash Receipts" | Confirm with Alation dictionary, then update |
| gcr_trxn_amt | Same as above | Same |
| margin_gcr_usd_amt | References "Gross Customer Receipt" | Update to "Gross Cash Receipts" when confirmed |
| margin_gcr_trxn_amt | Same | Same |
| fee_usd_amt | Too generic; actually maps specifically to ICANN fee | Should mention ICANN regulatory fee |
| fee_trxn_amt | Same | Same |
| receipt_regular_price_usd_amt | "Regular price before discounts" is misleading; it IS the discounted price (adjusted_current_price) | Should say "current period sale price" or "price at current rates" |
| receipt_regular_price_trxn_amt | Same | Same |
| accounting_company_id | "Company identifier for accounting purposes" too generic | Should mention consolidation of subsidiaries |
| product_uri | Should note currently NULL/not populated | Add "currently not populated, reserved for future use" |
| translation_language_name | Should note currently NULL/not populated | Same |
| virtual_order_flag | Should note currently always FALSE/not populated | Same |
| bill_friendly_id | Should note currently not populated | Same |
| msrp_total_usd_amt | Should clarify "based on original undiscounted list price" | Distinguish from msrp_duration_unit which uses current list price |
| source_system_name | Could note 'legacy e-comm' normalization | Optional enhancement |

---

## 8. Alation API Limitation Note

The Alation API refresh token in `MOONUNIT_ALATION` is expired. The following steps were skipped:
- Step 4: Target table column/description lookup in Alation
- Step 4a: Reference table column lookups (tables 6968214, 6968215, 7010016, 6968216)
- Step 4b: Certified Data Dictionary (Document Folder 6) — **CRITICAL** for GCR abbreviation confirmation

**Recommended action before writing DDL:** Renew the Alation API token and fetch:
1. `GET /integration/v2/document/?folder_id=6&limit=50` to confirm GCR = "Gross Cash Receipts" or alternative
2. Column metadata for reference tables to validate source column descriptions


**The agent's final response to the user was:**
Research complete. Here's a summary of what was done:

## Research Summary

**Target:** `ecomm360.fact_bill_line_vw` (99 columns, Iceberg/Parquet, Data Tier 3)

### Sources Consulted
1. **DDL** (`table.ddl`) — All 99 columns with existing comments read and analyzed
2. **YAML** (`table.yaml`) — Table metadata: description, lineage, SLA, partition key
3. **Confluence** (Page 3688240210) — Full design page fetched; extracted detailed column-to-source mappings for all columns, derivation logic, and business context

### Alation Status
The Alation API refresh token is **expired (HTTP 401)**. The following could not be retrieved:
- Target table Alation metadata
- Reference table column comments (4 upstream tables)
- **Certified Data Dictionary** (Document Folder 6) — critical for confirming `GCR` expansion

### Key Findings for Column Enrichment

| Priority | Column(s) | Issue |
|---|---|---|
| HIGH | `gcr_usd_amt`, `gcr_trxn_amt`, `margin_gcr_*` | Current comments say "Gross **Customer** Receipt" — likely should be "Gross **Cash** Receipts"; needs dictionary confirmation |
| HIGH | `fee_usd_amt`, `fee_trxn_amt` | Too generic — Confluence shows these map specifically to **ICANN fees** |
| MEDIUM | `receipt_regular_price_*` | Comment "Regular price before discounts" is misleading — it IS the discounted adjusted_current_price |
| MEDIUM | `product_uri`, `translation_language_name`, `virtual_order_flag`, `bill_friendly_id` | Should note "currently not populated" |
| MEDIUM | `msrp_total_*` vs `msrp_duration_unit_*` | Need to clarify distinction: total uses original list price, duration_unit uses current list price |
| LOW | `accounting_company_id` | Should mention subsidiary consolidation remapping logic |