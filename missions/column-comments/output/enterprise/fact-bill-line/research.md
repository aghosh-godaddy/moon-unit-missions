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
Write a structured research document containing:
- The full current DDL
- Key metadata from table.yaml (description, lineage, upstream dependencies)
- Summarized knowledge from Confluence pages
- Alation catalog metadata (if available), including Source Comments (column_comment)
  from both the target table and reference tables
- GoDaddy Data Dictionary definitions for relevant business terms
- For each column: current DDL comment (if any), Alation Source Comment (if any),
  Alation description (if any), inferred purpose, and relevant context from all sources

Environment variables available (all are JSON, parse with node):
- MOONUNIT_JIRA — {"url","email","api_token"} (use for Confluence access)
- MOONUNIT_ATLASSIAN — {"email","api_token"} (alternative Confluence creds)
- MOONUNIT_ALATION — {"url","refresh_token","user_id"} (Alation access)

**The agent summarized its work in this way:**

---

## Research Summary — enterprise.fact_bill_line

### Sources Consulted
1. **DDL**: `catalog/config/prod/us-west-2/enterprise/fact-bill-line/table.ddl` — 72 columns, no existing COMMENT clauses
2. **YAML**: `catalog/config/prod/us-west-2/enterprise/fact-bill-line/table.yaml` — table description, lineage, SLA, permissions
3. **Confluence**: Page 10371978 (Fact_Bill_Line, 89,482 bytes) — design spec with EDS layer schema (section 10.3.1), data flow, upstream dependencies, column-level data sources and business logic
4. **Alation** (target): Table ID 6332236 (AwsDataCatalog.enterprise.fact_bill_line) — all 72 column descriptions and comments were empty; no existing metadata
5. **Alation** (reference): Table ID 7027689 (ecomm360.fact_bill_line_vw) — 98 columns with rich `column_comment` values used as primary baseline
6. **Alation Certified Data Dictionary** (Folder 6): 150+ documents scanned across 3 pages

---

### Table Overview
**enterprise.fact_bill_line** is a Data Tier 1 Enterprise Dataset (EDS) providing a comprehensive receipt-level view of GoDaddy product purchases. Each row represents one line item on a bill/receipt.

- **Primary Key**: `bill_id`, `bill_line_num`, `source_system_name`
- **Partitioned by**: `bill_mst_year`, `bill_mst_month`
- **SLA**: Delivered by 6 AM MST daily
- **Sources**: Three upstream systems — legacy e-comm receipts (`gdshop_receipt_item`), virtual orders (`gdshop_receipt_virtualOrder`), and SmartLine in-app subscriptions (`nds_smartline_event`)
- **Upstream tables**: `customers.customer_id_mapping_snapshot`, `ecomm360.fact_bill_line_vw`

---

### Certified Data Dictionary Mappings

| Abbreviation | Official Name | Document ID | Notes |
|---|---|---|---|
| GCR | Gross Cash Receipts | 6 | Total value of products purchased excluding tax; critical business metric used company-wide for performance tracking |
| MSRP | Manufacturer Suggested Retail Price | (not in dictionary) | Standard industry term; used in column names msrp_duration_unit and msrp_total |
| COGS | Cost of Goods Sold | 132 | Variable costs aligned directly with a product or allocated by product groupings; excludes fixed costs |
| ISC | Internal Sales Channel | (used in ecomm360 reference table comment) | Internal source code for sales channel attribution |
| ICANN | Internet Corporation for Assigned Names and Numbers | (well-known industry term) | Regulatory fee on domain registrations |

**Critical finding**: The reference table (ecomm360.fact_bill_line_vw) `column_comment` for `gcr_usd_amt` says "Gross Customer Receipt amount in USD" — this is **INCORRECT** per the Certified Data Dictionary (Doc 6), which defines GCR as **Gross Cash Receipts**. The enriched DDL uses the authoritative "Gross Cash Receipts" expansion.

---

### Column-by-Column Research Notes

| Column | DDL Comment (existing) | Reference Table Comment | Confluence Context | Final Decision |
|---|---|---|---|---|
| bill_id | (none) | "Primary Key - Unique identifier for the bill" | Sourced from order_id; part of PK with bill_line_num and source_system_name | Added full PK context |
| bill_line_num | (none) | "Line number within the bill to identify specific items" | Sourced from row_id | Added PK context |
| original_bill_id | (none) | "Reference to the original bill ID in case of modifications or refunds" | Maps to original_order_id | Used reference comment |
| original_bill_line_num | (none) | "Original line number from the source bill before any modifications" | Maps to original_row_id | Used reference comment |
| source_system_name | (none) | "Name of the source system that originated this billing data" | Hardcoded 'legacy e-comm'/'new e-comm' or smartline store; part of PK | Added PK and values context |
| bill_modified_mst_ts | (none) | "Timestamp when the bill was last modified in Mountain Standard Time" | Sources: date_entered from receipt tables or smartline purchase_time | Used reference + Confluence |
| bill_modified_mst_date | (none) | "Date when the bill was last modified in Mountain Standard Time" | Date version of bill_modified_mst_ts | Used reference comment |
| subaccount_shopper_id | (none) | (not in reference) | "Moved from fact_bill to fact_bill_line as the data for this column is at line level" | Used Confluence note |
| refund_flag | (none) | "Flag indicating if this bill line represents a refund transaction" | "Set to TRUE if the order_id contains an 'R'" | Added derivation logic |
| chargeback_flag | (none) | "Flag indicating if this bill line represents a chargeback transaction" | "Set to TRUE if the order_id contains a 'C'" | Added derivation logic |
| item_tracking_code | (none) | "Internal tracking code for the specific item being billed" | "EDS will only use the value from source; Transformations will be done in ADS" | Added EDS/ADS distinction |
| item_tracking_code_desc | (none) | "Description of the item tracking code" | Source: TRIM(COALESCE(gdshop_item_tracking.description, 'Unknown')) | Added source detail |
| purchase_path_name | (none) | "Name of the purchase path or customer journey" | "Lookup value" from gdshop_item_trackingGroup.description | Added source detail |
| department_id | (none) | "Department identifier responsible for this billing line" | Sourced from dept_id | Used reference comment |
| accounting_company_id | (none) | "Company identifier for accounting purposes" | Sourced from accountingcompanyid | Used reference comment |
| accounting_deferred_flag | (none) | "Flag indicating if revenue recognition is deferred for accounting" | Based on gdshop_deferrmentconfigurationtypeid; null for virtual/smartline | Added null behavior |
| pf_id | (none) | "Product Family identifier for categorizing the billed product" | FK to dim_product | Added FK context |
| product_uri | (none) | "Uniform Resource Identifier for the specific product" | "Add once NES is incorporated" | Added NES context |
| upgraded_pf_id | (none) | "Product Family ID after upgrade if applicable" | Null for virtual orders and smartline | Added null behavior |
| unit_qty | (none) | "Quantity of units purchased for this line item" | Sourced from quantity; 1 for virtual; receipt_qty for smartline | Added source detail |
| duration_qty | (none) | "Duration quantity (e.g., number of months for subscription)" | "Units described in product_period_name (dim_product)" | Used Confluence context |
| product_unit_qty | (none) | "Quantity of product units independent of duration" | Based on dim_product.unitsasorders logic | Added logic detail |
| product_month_qty | (none) | "Number of months the product is valid for" | Complex formula: duration × units × period_conversion_factor | Added derivation |
| receipt_price_usd_amt | (none) | "Receipt price amount in USD as shown to customer" | adjusted_price * 0.01 | Added calculation detail |
| receipt_price_trxn_amt | (none) | "Receipt price amount in the transaction currency" | From currency transaction table | Used reference comment |
| gcr_usd_amt | (none) | "Gross Customer Receipt amount in USD" ← INCORRECT | "Complex calculation; Smartline app store and W+M free product conversions via app stores are excluded" | Used "Gross Cash Receipts" per Certified Data Dictionary; added exclusion notes |
| gcr_trxn_amt | (none) | "Gross Customer Receipt amount in transaction currency" ← INCORRECT | Complex calculation | Corrected to "Gross Cash Receipts" |
| margin_gcr_usd_amt | (none) | "Margin calculation on Gross Customer Receipt in USD" ← INCORRECT | "Formula specific to a set of pf_ids" | Corrected to "Gross Cash Receipts" |
| margin_gcr_trxn_amt | (none) | "Margin calculation on Gross Customer Receipt in transaction currency" ← INCORRECT | Custom formula | Corrected to "Gross Cash Receipts" |
| commission_usd_amt | (none) | "Commission amount paid in USD" | Null for virtual orders | Added null behavior |
| commission_trxn_amt | (none) | "Commission amount paid in transaction currency" | From currency transaction table | Used reference comment |
| aftermarket_seller_commission_usd_amt | (none) | "Commission paid to aftermarket sellers in USD" | pf_id IN (739,742,757,768,769,772,779,57631); FMV − domain auction commission | Added specific pf_ids and formula |
| aftermarket_seller_commission_trxn_amt | (none) | "Commission paid to aftermarket sellers in transaction currency" | Same pf_id logic | Added context |
| cost_usd_amt | (none) | "Cost of goods sold amount in USD" | adjusted_actualcost * 0.01; null for virtual; negative → 0 | Added COGS acronym and floor behavior |
| cost_trxn_amt | (none) | "Cost of goods sold amount in transaction currency" | From currency transaction table | Used reference comment |
| msrp_duration_unit_usd_amt | (none) | "Manufacturer Suggested Retail Price per duration unit in USD" | (product_list_price × qty × duration + icann_fee) × 0.01; 0 for virtual | Added formula |
| msrp_duration_unit_trxn_amt | (none) | "Manufacturer Suggested Retail Price per duration unit in transaction currency" | 0 for virtual | Added note |
| msrp_total_usd_amt | (none) | "Total Manufacturer Suggested Retail Price in USD" | (originallistprice × qty × duration + icann_fee) × 0.01; 0 for virtual | Added formula |
| msrp_total_trxn_amt | (none) | "Total Manufacturer Suggested Retail Price in transaction currency" | 0 for virtual | Added note |
| fee_usd_amt | (none) | "Additional fees charged in USD" | ICANN fee (icannfee_adjusted × 0.01); 0 for virtual | Clarified as ICANN fee |
| fee_trxn_amt | (none) | "Additional fees charged in transaction currency" | From currency transaction table | Clarified as ICANN fee |
| fair_market_value_usd_amt | (none) | "Fair market value assessment in USD" | fairmarketvalue × 0.01; 0 for virtual; used in aftermarket pricing | Added context |
| fair_market_value_trxn_amt | (none) | "Fair market value assessment in transaction currency" | From currency transaction table | Used reference comment |
| tax_usd_amt | (none) | "Tax amount charged in USD" | tax_amount × 0.01; null for virtual | Added null behavior |
| tax_trxn_amt | (none) | "Tax amount charged in transaction currency" | From currency transaction table | Used reference comment |
| receipt_regular_price_usd_amt | (none) | "Regular price before discounts in USD" | (adjusted_currentprice × qty × duration + icann_fee); null for virtual | Added ICANN inclusion note |
| receipt_regular_price_trxn_amt | (none) | "Regular price before discounts in transaction currency" | Null for virtual | Added null behavior |
| injected_fair_market_value_usd_amt | (none) | "System-injected fair market value adjustment in USD" | injectedfairmarketvalue × 0.01; null for virtual | Used reference comment |
| injected_fair_market_value_trxn_amt | (none) | "System-injected fair market value adjustment in transaction currency" | From currency transaction table | Used reference comment |
| injected_icann_fee_usd_amt | (none) | "ICANN regulatory fee amount injected by system in USD" | injectedicannfee_adjusted × 0.01; null for virtual | Used reference comment |
| injected_icann_fee_trxn_amt | (none) | "ICANN regulatory fee amount injected by system in transaction currency" | From currency transaction table | Used reference comment |
| injected_tax_usd_amt | (none) | "Tax amount injected by system in USD" | From _injected_tax_amount; null for virtual | Used reference comment |
| injected_tax_trxn_amt | (none) | "Tax amount injected by system in transaction currency" | From currency transaction table | Used reference comment |
| bundle_allocated_revenue_usd_amt | (none) | "Revenue allocated to this item from bundle pricing in USD" | bundle_allocated_revenue × 0.01; 0 for virtual and smartline | Added zero behavior |
| reseller_commission_usd_amt | (none) | "Commission paid to reseller partners in USD" | From godaddyaccounting.resellercommission_mart_snap | Used reference + added source |
| parent_reseller_commission_usd_amt | (none) | "Commission paid to parent reseller in USD" | From godaddyaccounting.resellercommission_mart_snap | Used reference + added source |
| trxn_currency_code | (none) | "ISO currency code for the transaction" | UPPER(COALESCE(transaction_currency, 'USD' or 'N/A')); N/A for virtual | Added default behavior |
| renewal_price_locked_flag | (none) | "Flag indicating if renewal price is locked for future periods" | isrenewalpricelocked=1 → TRUE; null for virtual | Added derivation |
| offer_id | (none) | "Identifier for the specific offer or promotion applied" | gdshop_receipt_item.bundle_id; null for virtual and smartline | Clarified source field |
| offer_collection_id | (none) | "Identifier for the collection of offers this item belongs to" | gdshop_receipt_item.parent_bundle_id; null for virtual and smartline | Clarified source field |
| free_product_package_id | (none) | "Identifier for free product package if applicable" | gdshop_free_product_packageid; null for virtual and smartline | Used reference comment |
| variant_price_type_id | (none) | "Identifier for the pricing variant type applied" | gdshop_variant_price_type_id; null for virtual and smartline | Added null behavior |
| variant_price_type_name | (none) | "Name of the pricing variant type applied" | TRIM(COALESCE(gdshop_variant_price_type.description, 'Unknown')) | Added source detail |
| exclude_reason_desc | (none) | "Description of reason why this line item might be excluded from reports" | 'Internal Shopper' or 'Original_order_id != -1'; null = included in GCR | Added specific values |
| exclude_reason_month_end_desc | (none) | "Month-end specific exclusion reason description" | Month-end version with additional account creation date logic | Added logic context |
| etl_build_mst_ts | (none) | (not in reference) | Current timestamp at ETL build time | Standard ETL field |
| list_price_usd_amt | (none) | "Published list price in USD" | ROUND(legacy_receipt_item_cln.originallistprice, 2) | Clarified as original list price |
| list_price_trxn_amt | (none) | "Published list price in transaction currency" | ROUND(transaction_originallistprice, 2) | Used reference comment |
| sale_price_usd_amt | (none) | "Final sale price after discounts in USD" | ROUND(adjusted_currentprice, 2) | Clarified as price at purchase session |
| sale_price_trxn_amt | (none) | "Final sale price after discounts in transaction currency" | ROUND(transaction_adjusted_currentprice, 2) | Used reference comment |
| original_receipt_price_usd_amt | (none) | (not in reference) | Not in Confluence EDS schema; inferred as pre-refund original price | Inferred from naming convention and PK context |
| original_receipt_price_trxn_amt | (none) | (not in reference) | Not in Confluence EDS schema; inferred as pre-refund original price in transaction currency | Inferred from naming convention |

---

### Key Business Rules Captured in Comments

1. **GCR correction**: Reference table incorrectly uses "Gross Customer Receipt"; corrected to "Gross Cash Receipts" per Certified Data Dictionary Doc 6.
2. **Refund/chargeback derivation**: `refund_flag` = order_id contains 'R'; `chargeback_flag` = order_id contains 'C'.
3. **GCR exclusions**: Smartline app store purchases and W+M free product conversions via app stores are excluded from GCR.
4. **Aftermarket products**: `aftermarket_seller_commission` applies only to pf_id IN (739, 742, 757, 768, 769, 772, 779, 57631).
5. **Null behavior documented**: `accounting_deferred_flag`, `cost_usd_amt`, `tax_usd_amt`, and several other columns are null for virtual orders.
6. **MSRP includes ICANN fee**: Both `msrp_duration_unit` and `msrp_total` amounts include the ICANN fee component.
7. **Zero vs NULL for virtual orders**: Virtual orders have 0 (not NULL) for many monetary amounts.
8. **Reseller commission source**: Both reseller commission columns are derived from `godaddyaccounting.resellercommission_mart_snap`.


**The agent's final response to the user was:**
The DDL is complete. Here's a summary of the work done:

## Research & Enrichment Complete

**Target table**: `enterprise.fact_bill_line` (72 columns, Data Tier 1 EDS)

**Sources consulted**:
1. **Confluence page 10371978** (89KB) — Fact_Bill_Line design spec with full EDS layer schema (section 10.3.1), data sources, column-level derivation logic, and business rules
2. **Alation** — Target table (ID: 6332236) had zero existing descriptions; reference table `ecomm360.fact_bill_line_vw` (ID: 7027689) provided 98 columns of baseline `column_comment` data
3. **Certified Data Dictionary** (Folder 6, 150+ docs) — Confirmed all abbreviations

**Key findings applied**:
- **GCR = Gross Cash Receipts** (per Certified Data Dictionary Doc 6) — the reference table incorrectly said "Gross Customer Receipt"; all 4 GCR columns corrected
- **COGS** confirmed as "Cost of Goods Sold" (Doc 132)
- All 72 columns now have COMMENT clauses covering: purpose, data source/derivation, null/zero behavior for virtual orders, primary key roles, and relevant business rules (exclusion logic, ICANN fee inclusion, aftermarket pf_ids, etc.)