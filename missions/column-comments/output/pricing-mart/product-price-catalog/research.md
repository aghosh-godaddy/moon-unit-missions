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

## Stage: Data Governance Research — pricing_mart.product_price_catalog

### 1. Target Table Overview

- **Database:** pricing-mart  
- **Table:** product_price_catalog  
- **DDL path:** `catalog/config/prod/us-west-2/pricing-mart/product-price-catalog/table.ddl`  
- **YAML path:** `catalog/config/prod/us-west-2/pricing-mart/product-price-catalog/table.yaml`  
- **Alation ID (ds_id=81):** 7010676  
- **Data Tier:** 3  
- **Storage Format:** Parquet  
- **Table Type:** PARTITIONED  
- **SLA:** Daily delivery by 5:00am MST  

**Alation Table Description (cleaned):**  
"Product Price Catalog provides a daily snapshot of GoDaddy's & 123 Reg's product list price, sale price and cost (domain product only) for all products, markets, currencies and membership price types."

Primary Key: `(pf_id, price_type_id, price_group_id, trxn_currency_code, as_of_mst_date, private_label_id)`

**Partition Keys (from table.yaml):**
- `as_of_mst_date` (string) — snapshot date
- `private_label_id` (int) — reseller/private label identifier

---

### 2. Full Current DDL

```sql
CREATE TABLE product_price_catalog(
  pf_id int COMMENT '@PrimaryKey Product identifier, composite key with price_type_id, price_group_id, private_label_id, and trxn_currency_code',
  price_type_id int COMMENT '@PrimaryKey Identifier for the price type as 0, 1, 2, 4, 8, 16, 32, 64, 128 or 256',
  price_group_id int COMMENT '@PrimaryKey Identifier for the price group, integer range from 0 to 34',
  reseller_type_id int COMMENT 'Identifier for the reseller type, 1 - Go Daddy, 14 - Boutique Resellers',
  reseller_name string COMMENT 'Name of the reseller, GoDaddy.com vs 123 Reg',
  reseller_type_name string COMMENT 'Name of the reseller type, Go Daddy vs Boutique Resellers',
  department_id int COMMENT 'Identifier for the department associated with the product',
  product_name string COMMENT 'Name of the product',
  product_period_name string COMMENT '@Enumerated(month,quarter,6-month,year,onetime) Name of the product subscription period',
  product_period_qty int COMMENT 'Number of units in the product period (e.g., 12 for a 12-period term)',
  product_pnl_group_name string COMMENT 'Profit and Loss group name for financial reporting',
  product_pnl_category_name string COMMENT 'Profit and Loss category name for financial reporting',
  product_pnl_line_name string COMMENT 'Profit and Loss line name for financial reporting',
  product_pnl_subline_name string COMMENT 'Profit and Loss subline name for financial reporting',
  product_pnl_version_name string COMMENT 'Profit and Loss version name for financial reporting',
  product_pnl_new_renewal_name string COMMENT 'Profit and Loss new versus renewal classification name',
  department_name string COMMENT 'Name of the department associated with the product',
  price_group_name string COMMENT 'Descriptive name of the price group',
  country_site_code string COMMENT 'Country site code',
  country_site_name string COMMENT 'Country site name',
  default_market_code string COMMENT 'Default market locale code (e.g., en-US, en-GB)',
  price_type_name string COMMENT 'Descriptive name of the price type, such as Standard Price, Costco, Employee Discount, etc',
  trxn_currency_code string COMMENT '@PrimaryKey ISO 4217 currency code for the transaction currency',
  usd_conversion_rate double COMMENT 'Exchange rate used to convert transaction currency to US dollars',
  list_price_trxn_amt decimal(38,2) COMMENT 'List price of the product in transaction currency',
  list_price_usd_amt decimal(38,2) COMMENT 'List price of the product converted to US dollars',
  sale_price_trxn_amt decimal(38,2) COMMENT 'Promotional or discounted sale price in transaction currency',
  sale_price_usd_amt decimal(38,2) COMMENT 'Promotional or discounted sale price converted to US dollars',
  sale_start_mst_date date COMMENT 'Start date of the sale period (MST)',
  sale_end_mst_date date COMMENT 'End date of the sale period (MST)',
  cost_usd_amt decimal(38,2) COMMENT 'Cost of the product in US dollars',
  list_price_change_flag boolean COMMENT 'Indicates whether the list price changed compared to the prior period (true/false)',
  sale_price_change_flag boolean COMMENT 'Indicates whether the sale price changed compared to the prior period (true/false)',
  cost_change_flag boolean COMMENT 'Indicates whether the cost changed compared to the prior period (true/false)',
  etl_build_mst_ts timestamp COMMENT 'Timestamp when the ETL process created or last updated this record (MST)'
)
```

Partition columns with NO current DDL comment:
- `as_of_mst_date` (string)
- `private_label_id` (int)

---

### 3. Table YAML Metadata

- **Description:** "This table captures product price information"
- **Upstream dependencies (lineage):** bigreporting.dim_product_snap, godaddy.gdshop_currencytype_snap, godaddy.gdshop_currencytypeconversionrate_snap, godaddy.gdshop_dept_snap, godaddy.gdshop_product_snap, godaddy.gdshop_product_type_snap, godaddy.gdshop_variant_price_type_snap, gdmastercatalog.catalog_countrysite_snap, gdmastercatalog.catalog_pricegroup_snap, gdmastercatalog.catalog_productprivatelabelprice_snap, gdmastercatalog.catalog_productprivatelabelpricesale_snap, gdmastercatalog.catalog_productresellertypeprice_snap, gdmastercatalog.catalog_productresellertype_snap, godaddy.pl_resellertype_snap, godaddy.pl_signupinfo_snap

---

### 4. Confluence Page Summaries

#### 4a. Product Price Catalog (page 3740008527)

**Purpose:** Successor to `product_price_list`, extends it with boutique reseller support (123 Reg). A daily snapshot of product list price, sale price, and domain cost for all products, markets, currencies, and membership price types — for both GoDaddy (private_label_id=1) and 123 Reg (private_label_id=587240, reseller_type_id=14).

**Primary Key (6/6):** `(pf_id, price_group_id, price_type_id, trxn_currency_code, private_label_id, as_of_mst_date)`

**Key business rules from Confluence:**
- `pf_id`: Product Family ID. Filters applied: catalog_productprivatelabelprice.privatelabelid IN (1,587240); catalog_productresellertypeprice.privatelabelresellertypeid IN (1,14); catalog_productresellertype.canbesold = 1
- `price_group_id`: Also known as "Server Group ID". Range 0–34.
- `price_group_name`: Most of the time, price_group_name = country_site_code + country_site_desc
- `country_site_code`: Filters: catalog_countrysite.isactive=1; defaultmarketid NOT IN ('zh-CN','en-AE','he-IL')
- `price_type_id`: Values 0,1,2,4,8,16,32,64,128,256 (per gdshop_variant_price_type). Example: 8 = Domain Discount Club
- `trxn_currency_code`: For boutique resellers (reseller_type_id=14), only GBP and USD are included
- `usd_conversion_rate`: Conversion rate from transaction currency to USD. Note: The Pricing Tool's "Exchange Rate" is the INVERSE (USD to transaction currency)
- `reseller_name`: Identifier is private_label_id (e.g., GoDaddy, 123 Reg). 123 Reg is currently the only active boutique reseller (reseller_type_id=14; PLID=587240); TSO was absorbed into 123 Reg as of 2025-01-27
- `department_id`: Include department_id=0 (not in lookup table); exclude department_id=1690 (Marketplace 3rd Party Products)
- `list_price_change_flag`: True if list_price_trxn_amt changed compared to PREVIOUS as_of_mst_date
- `sale_price_change_flag`: True if sale_price_trxn_amt changed compared to PREVIOUS as_of_mst_date
- `cost_change_flag`: True if cost_usd_amt changed compared to PREVIOUS as_of_mst_date
- `cost_usd_amt`: Domain products only; NULL for non-domain products
- `sale_start_mst_date` / `sale_end_mst_date`: Time part is always 00:00:00.000 in source table
- `as_of_mst_date`: As of date in YYYY-MM-DD format (Primary key 6/6), partition key
- `private_label_id`: Private label ID (5/6), partition key. Currently either 1 (GoDaddy) or 587240 (123 Reg). In the future, may include additional boutique reseller PLIDs

**Source tables in eComm / Data Lake:**
| # | eComm | Data Lake |
|---|---|---|
| 1 | gdMasterCatalog.dbo.catalog_productPrivateLabelPrice | gdmastercatalog.catalog_productprivatelabelprice_snap |
| 2 | gdMasterCatalog.dbo.catalog_productPrivateLabelPriceSales | gdmastercatalog.catalog_productprivatelabelpricesale_snap |
| 3 | gdMasterCatalog.dbo.catalog_productResellerTypePrice | gdmastercatalog.catalog_productresellertypeprice_snap |
| 4 | gdMasterCatalog.dbo.catalog_productResellerType | gdmastercatalog.catalog_productresellertype_snap |
| 5 | gdMasterCatalog.dbo.catalog_countrySite | gdmastercatalog.catalog_countrysite_snap |
| 6 | gdMasterCatalog.dbo.catalog_priceGroup | gdmastercatalog.catalog_pricegroup_snap |
| 7 | GoDaddy.dbo.gdshop_currencyTypeConversionRate | godaddy.gdshop_currencytypeconversionrate_snap |
| 8 | GoDaddy.dbo.gdshop_currencyType | godaddy.gdshop_currencytype_snap |
| 9 | GoDaddy.dbo.gdshop_product | godaddy.gdshop_product_snap |
| 10 | GoDaddy.dbo.gdshop_product_type | godaddy.gdshop_product_type_snap |
| 11 | GoDaddy.dbo.gdshop_dept | godaddy.gdshop_dept_snap |
| 12 | GoDaddy.dbo.gdshop_variant_price_type | godaddy.gdshop_variant_price_type_snap |
| 13 | DMStaging.dbo.dim_product | bigreporting.dim_product_snap |
| 14 | GoDaddy.dbo.pl_signupInfo | godaddy.pl_signupinfo_snap |
| 15 | GoDaddy.dbo.pl_resellerType | godaddy.pl_resellertype_snap |

#### 4b. Product Price List (page 3354394625) — Predecessor Table

**Purpose:** Predecessor table (GoDaddy-only, private_label_id=1). A daily snapshot of product list price, sale price, and domain cost for all products, markets, currencies, and membership price types. Primary key (5/5): (pf_id, price_group_id, price_type_id, trxn_currency_code, as_of_mst_date).

**Key additional details from predecessor table:**
- `product_period_qty`: Source field: dim_product_snap.numberofperiods
- `product_period_name`: Source field: dim_product_snap.period
- `price_group_name`: Also known as "Server Group ID"
- `cost_usd_amt`: Domain products only (Product Namespace = 'domains' filter); NULL for non-domain products
- `usd_conversion_rate`: Calculated as: Conversion Rate * 10 (Decimal Precision) / 1,000,000 from gdshop_currencyTypeConversionRate
- `sale_start_mst_date` / `sale_end_mst_date`: Time part always 00:00:00.000 in source

---

### 5. Alation Catalog Data

#### 5a. Target Table (product_price_catalog, id=7010676)

- All column descriptions (`description`) are empty in Alation
- `column_comment` fields match current DDL COMMENT clauses exactly (propagated from DDL)
- Two columns have empty `column_comment`:
  - `as_of_mst_date` (partition key)
  - `private_label_id` (partition key)

#### 5b. Reference Table (pricing_mart.product_price_list, id=6636972)

- All Alation `description` and `column_comment` fields are empty
- Alation `title` fields provide concise labels (e.g., "PF ID (Primary key 1/5)", "Price type ID (Primary key 3/5)", "Sale start date in MST timezone")
- No distinct enrichment beyond what is in the Confluence schema table

---

### 6. Certified Data Dictionary Mappings (Folder ID 6)

Reviewed all 200 dictionary entries. Terms relevant to this table's column names:

| Abbreviation/Term | Official Name (Dictionary) | Document ID | Notes |
|---|---|---|---|
| PnL | Profit and Loss | 84 ("PnL Pillar Name") | Column names use full "Profit and Loss" already; `pnl` in column names is the abbreviated form |
| Product Hierarchy | Product Hierarchy (aka PnL Hierarchy) | 93 | 5-level hierarchy: group → category → line → subline → version; source: bigreporting.dim_product_snap |
| Reseller / Private Label | Reseller and Reseller Clients | 21 | Private label ID uniquely identifies a reseller; reseller_type_id groups them |
| GCR | Gross Cash Receipts | 6 | **Not in this table's columns** — included for completeness |
| COGS | Cost of Goods Sold | 132 | Aligns with cost_usd_amt (domain products only) |
| pf_id | Product Family Identifier (PF_ID) | 93 | Official term from Product Hierarchy entry |

**Key dictionary definitions used:**
- **Product Hierarchy (id 93):** "Product Hierarchy (aka PnL Hierarchy) is the classification of products and services at the Product Family Identifier (PF_ID) level by their essential components into a logical structure across five key attributes." Source: `bigreporting.dim_product_snap`. The 5 attributes map directly to `product_pnl_group_name`, `product_pnl_category_name`, `product_pnl_line_name`, `product_pnl_subline_name`, `product_pnl_version_name`.
- **Reseller and Reseller Clients (id 21):** "GoDaddy allows some of its products and services to be sold by other entities, called Resellers, under their own brands... products manufactured by one company for sale under another company's brand are called 'private label'... Resellers are customers who purchase a Reseller plan, which provides them with a private label ID — a unique identifier"

---

### 7. Per-Column Analysis & Enrichment Candidates

| Column | Current DDL Comment | Enrichment Source | Proposed Enhancement |
|---|---|---|---|
| `pf_id` | `@PrimaryKey Product identifier, composite key with price_type_id, price_group_id, private_label_id, and trxn_currency_code` | Confluence schema table | Already good; expand "Product identifier" → "Product Family Identifier (PF_ID)" per data dictionary |
| `price_type_id` | `@PrimaryKey Identifier for the price type as 0, 1, 2, 4, 8, 16, 32, 64, 128 or 256` | Confluence, Alation | Add source reference: gdshop_variant_price_type |
| `price_group_id` | `@PrimaryKey Identifier for the price group, integer range from 0 to 34` | Confluence | Add alias: also known as "Server Group ID" |
| `reseller_type_id` | `Identifier for the reseller type, 1 - Go Daddy, 14 - Boutique Resellers` | Confluence | Already complete |
| `reseller_name` | `Name of the reseller, GoDaddy.com vs 123 Reg` | Confluence | Add: identified by private_label_id |
| `reseller_type_name` | `Name of the reseller type, Go Daddy vs Boutique Resellers` | Confluence | Already complete |
| `department_id` | `Identifier for the department associated with the product` | Confluence | Add: includes 0; excludes 1690 (Marketplace 3rd Party Products) |
| `product_name` | `Name of the product` | Confluence | Add example |
| `product_period_name` | `@Enumerated(month,quarter,6-month,year,onetime) Name of the product subscription period` | Confluence | Add source: dim_product_snap.period |
| `product_period_qty` | `Number of units in the product period (e.g., 12 for a 12-period term)` | Confluence | Add source: dim_product_snap.numberofperiods |
| `product_pnl_group_name` | `Profit and Loss group name for financial reporting` | Dict ID 93 | Add: top-level tier of product hierarchy per bigreporting.dim_product_snap; example: "Domains" |
| `product_pnl_category_name` | `Profit and Loss category name for financial reporting` | Dict ID 93 | Add: second tier of product hierarchy; example: "Domain Registration" |
| `product_pnl_line_name` | `Profit and Loss line name for financial reporting` | Dict ID 93 | Add: third tier of product hierarchy; example: "Domain Name Registration" |
| `product_pnl_subline_name` | `Profit and Loss subline name for financial reporting` | Dict ID 93 | Add: fourth tier of product hierarchy; example: "COM" |
| `product_pnl_version_name` | `Profit and Loss version name for financial reporting` | Dict ID 93 | Add: fifth (most granular) tier of product hierarchy; example: "COM" |
| `product_pnl_new_renewal_name` | `Profit and Loss new versus renewal classification name` | Confluence | Add example: "New Purchase" |
| `department_name` | `Name of the department associated with the product` | Confluence | Add example |
| `price_group_name` | `Descriptive name of the price group` | Confluence | Add: also known as Server Group ID; typically country_site_code + country_site_desc; example: "Default" |
| `country_site_code` | `Country site code` | Confluence | Add: active country sites only; excludes zh-CN, en-AE, he-IL markets; example: "www", "br", "fr" |
| `country_site_name` | `Country site name` | Confluence | Add example: "Global", "US" |
| `default_market_code` | `Default market locale code (e.g., en-US, en-GB)` | Confluence | Already good |
| `price_type_name` | `Descriptive name of the price type, such as Standard Price, Costco, Employee Discount, etc` | Confluence | Already good |
| `trxn_currency_code` | `@PrimaryKey ISO 4217 currency code for the transaction currency` | Confluence | Add: boutique resellers (reseller_type_id=14) only include USD and GBP |
| `usd_conversion_rate` | `Exchange rate used to convert transaction currency to US dollars` | Confluence | Add important note: the Pricing Tool "Exchange Rate" is the inverse (USD to transaction currency); sourced from gdshop_currencytypeconversionrate_snap |
| `list_price_trxn_amt` | `List price of the product in transaction currency` | Confluence | Add: source is catalog_productprivatelabelprice_snap / catalog_productresellertypeprice_snap |
| `list_price_usd_amt` | `List price of the product converted to US dollars` | Confluence | Already good |
| `sale_price_trxn_amt` | `Promotional or discounted sale price in transaction currency` | Confluence | Add: applies to all customers without a coupon |
| `sale_price_usd_amt` | `Promotional or discounted sale price converted to US dollars` | Confluence | Already good |
| `sale_start_mst_date` | `Start date of the sale period (MST)` | Confluence | Add: time component is always 00:00:00; source: catalog_productprivatelabelpricesale_snap |
| `sale_end_mst_date` | `End date of the sale period (MST)` | Confluence | Add: time component is always 00:00:00; source: catalog_productprivatelabelpricesale_snap |
| `cost_usd_amt` | `Cost of the product in US dollars` | Confluence | Add: domain products only (Product Namespace = 'domains'); NULL for non-domain products |
| `list_price_change_flag` | `Indicates whether the list price changed compared to the prior period (true/false)` | Confluence | Refine: "prior period" → "previous as_of_mst_date"; "list_price_trxn_amt" compared |
| `sale_price_change_flag` | `Indicates whether the sale price changed compared to the prior period (true/false)` | Confluence | Refine: "prior period" → "previous as_of_mst_date"; "sale_price_trxn_amt" compared |
| `cost_change_flag` | `Indicates whether the cost changed compared to the prior period (true/false)` | Confluence | Refine: "prior period" → "previous as_of_mst_date"; "cost_usd_amt" compared |
| `etl_build_mst_ts` | `Timestamp when the ETL process created or last updated this record (MST)` | — | Already good |
| `as_of_mst_date` | **(MISSING — partition key)** | Confluence | Add: @PrimaryKey snapshot date in YYYY-MM-DD format; primary key 6/6; partition column |
| `private_label_id` | **(MISSING — partition key)** | Confluence, Dict ID 21 | Add: @PrimaryKey private label identifier (primary key 5/6); 1=GoDaddy, 587240=123 Reg; partition column |

---

### 8. Summary of Findings

The DDL already has well-formed comments for 35 of 37 columns. The two partition key columns (`as_of_mst_date` and `private_label_id`) have no COMMENT clauses and must be added.

Enrichment opportunities across all columns:
1. **Missing comments** (critical): `as_of_mst_date`, `private_label_id`
2. **Minor precision improvements**: `list_price_change_flag`, `sale_price_change_flag`, `cost_change_flag` — change "prior period" to "previous as_of_mst_date" to be unambiguous
3. **Cost column**: Add domain-only restriction and NULL semantics
4. **Sale dates**: Add note that time part is always 00:00:00
5. **usd_conversion_rate**: Add clarification about direction vs Pricing Tool convention
6. **pf_id**: Expand "Product identifier" to "Product Family Identifier (PF_ID)" per official data dictionary
7. **price_group_id**: Add "also known as Server Group ID" per Confluence
8. **country_site_code/name**: Add examples from Confluence
9. **product_pnl_* columns**: Add source (bigreporting.dim_product_snap) and examples from Confluence
10. **department_id**: Add exclusion note for department_id=1690


**The agent's final response to the user was:**
The research document has been written. Here is a summary of what I found:

---

## Research Summary — `pricing_mart.product_price_catalog`

**Sources consulted:**
- DDL and YAML from `repos/lake/` (35/37 columns have existing comments)
- Confluence page 3740008527 (Product Price Catalog design spec)
- Confluence page 3354394625 (Product Price List predecessor design doc)
- Alation table 7010676 (target table metadata + column_comments)
- Alation table 6636972 (reference table `product_price_list`)
- Alation Certified Data Dictionary (200 entries, folder ID 6)

**Key findings:**

1. **Two partition-key columns are entirely missing COMMENT clauses**: `as_of_mst_date` and `private_label_id` — both are primary key components (6/6 and 5/6 respectively).

2. **Alation has no user-authored descriptions** for any column in either the target or reference table; the `column_comment` fields simply mirror the existing DDL comments.

3. **Certified Data Dictionary mappings** relevant to this table:
   - `pf_id` = Product Family Identifier (PF_ID), per document ID 93
   - Product Hierarchy (PnL hierarchy) = the 5 `product_pnl_*` columns; source: `bigreporting.dim_product_snap`
   - Private label / Reseller = document ID 21 (explains `private_label_id`, `reseller_name`, `reseller_type_id`)

4. **Enrichments from Confluence** available for: cost_usd_amt (domain-only/NULL semantics), usd_conversion_rate (direction clarification vs Pricing Tool), sale dates (time component is always 00:00:00), change flags (reference specific column names instead of "prior period"), price_group_id (alias "Server Group ID"), country_site_code (active filter + excluded markets), and department_id (exclusion of id=1690).