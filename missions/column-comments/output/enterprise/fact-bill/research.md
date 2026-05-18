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

## Research Summary: enterprise.fact_bill

**Date:** 2026-05-18  
**Researcher:** Data Governance Research Agent (Stage 1)  
**Alation Status:** ⚠️ UNAVAILABLE — Alation refresh token is expired (`401000: Refresh token provided is expired or revoked`). No Alation data could be fetched (target table columns, reference table columns, or Certified Data Dictionary from Document Folder 6).

---

## 1. Table Overview

**Table:** `enterprise.fact_bill`  
**Description (from table.yaml):** "Enterprise Dataset (EDS) that provides a comprehensive view of a receipt for the purchase of GoDaddy products rollup at bill level"  
**Storage Format:** Parquet  
**Table Type:** PARTITIONED  
**Partition Keys:** `bill_mst_year` (string), `bill_mst_month` (string)  
**Data Tier:** 1  
**SLA:** Delivered by 6 AM MST every day (`cron(0 13 * * ? *)`)  
**Relative Path:** `enterprise_eds_prime/fact_bill`

---

## 2. Full Current DDL

```sql
CREATE TABLE fact_bill(
bill_id                                   string
,original_bill_id                          string
,bill_friendly_id                          string
,source_system_name                        string
,bill_modified_mst_ts                      timestamp
,bill_modified_mst_date                    string
,refund_flag                               boolean
,chargeback_flag                           boolean
,private_label_id                          int
,rep_version_id                            int
,bill_country_code                         string
,bill_sub_geo_code                         string
,bill_postal_code                          string
,bill_source_name                          string
,entered_by_name                           string  comment 'PII'
,translation_language_name                 string
,order_site_language_code                  string
,virtual_order_flag                        boolean
,free_order_flag                           boolean
,primary_payment_type_name                 string
,primary_payment_subtype_name              string
,secondary_payment_type_name               string
,secondary_payment_subtype_name            string
,intent                                    string  comment 'Intent Enum for virtual bill with value such as FREEMIUM_PURCHASE, FREE_PURCHASE, FREE_TRIAL_MODIFY, etc'
,related_subscription                      string  comment 'Associate a receiptless or virtual order event to a specific subscription'
,bill_isc_source_code                      string
,receipt_price_usd_amt                     decimal(18,2)
,receipt_price_trxn_amt                    decimal(18,2)
,gcr_usd_amt                               decimal(18,2)
,gcr_trxn_amt                              decimal(18,2)
,margin_gcr_usd_amt                        decimal(18,2)
,margin_gcr_trxn_amt                       decimal(18,2)
,commission_usd_amt                        decimal(18,2)
,commission_trxn_amt                       decimal(18,2)
,aftermarket_seller_commission_usd_amt     decimal(18,2)
,aftermarket_seller_commission_trxn_amt    decimal(18,2)
,cost_usd_amt                              decimal(18,2)
,cost_trxn_amt                             decimal(18,2)
,fee_usd_amt                               decimal(18,2)
,fee_trxn_amt                              decimal(18,2)
,fair_market_value_usd_amt                 decimal(18,2)
,fair_market_value_trxn_amt                decimal(18,2)
,tax_usd_amt                               decimal(18,2)
,tax_trxn_amt                              decimal(18,2)
,injected_fair_market_value_usd_amt        decimal(18,2)
,injected_fair_market_value_trxn_amt       decimal(18,2)
,injected_icann_fee_usd_amt                decimal(18,2)
,injected_icann_fee_trxn_amt               decimal(18,2)
,injected_tax_usd_amt                      decimal(18,2)
,injected_tax_trxn_amt                     decimal(18,2)
,bundle_allocated_revenue_usd_amt          decimal(18,2)
,reseller_commission_usd_amt               decimal(18,2)
,parent_reseller_commission_usd_amt        decimal(18,2)
,trxn_currency_code                        string
,exclude_reason_desc                       string
,exclude_reason_month_end_desc             string
,etl_build_mst_ts                          string
);
```

---

## 3. Upstream Lineage (from table.yaml)

- `ecomm360.fact_bill_line_vw` — EDS Prime fact table, tracks every receipt line
- `ecomm360.dim_bill_vw` — EDS Prime bill-grain dimension
- `bigreporting.dim_product_snap` — product dimension
- `godaddy_txlog.gdshop_receipt_header` — legacy e-comm receipt header
- `godaddy_txlog.gdshop_receipt_virtualOrder` — virtual order events

---

## 4. Confluence Page Summaries

### 4.1. Fact_Bill Design Doc (Page ID 10358411)

**Purpose:** Enterprise Dataset (EDS) providing a comprehensive receipt view for purchase of GoDaddy products, with no metrics value stored for legacy orders. Rolled up at bill level.

**Primary Key:** `bill_id`, `source_system_name`  
**Foreign Keys:** `pf_id` → `dim_product`  
**Source Repo:** `GDLakeDataProcessors/uds`  
**Airflow DAG:** `EDT_Ingest_Unified_Bill` (runs 3x daily, refreshes prior day data by 6 AM MST)

**Upstream TX Log Tables:**
- `godaddy_txlog.gdshop_CommissionJunction`
- `godaddy_txlog.gdshop_receipt_header`
- `godaddy_txlog.gdshop_receipt_header_payment`
- `godaddy_txlog.gdshop_receipt_virtualOrder`

**Data Flow:**
1. tx_log (near real-time) tables made available in HDFS by upstream teams
2. EDT_Ingest_Unified_Bills Airflow job runs hourly
3. Hive scripts join item & currency level purchase info with static ref tables → produces fact_bill_line (3x/day)
4. **Raw layer:** data replicated from MSSQLSERVER by upstream process
5. **Clean layer:** Hive scripts cleanse/process data in dp_stage schema with minimum business logic
6. **EDS layer:** additional Hive scripts apply business logic on cleansed data → enterprise schema for downstream consumers

**EDS Layer Column Notes (from Confluence schema table, section 10.3.1):**

| Column | Data Source | Notes |
|--------|-------------|-------|
| bill_id | gdshop_receipt_item.order_id | Include refunds, set a flag |
| original_bill_id | gdshop_recent_header.order_order_id | Added for ADS replacement (INSIGHT-22025) |
| source_system_name | Literal 'legacy e-comm' | |
| bill_modified_mst_ts | gdshop_receipt_item.date_entered | |
| bill_modified_mst_date | gdshop_receipt_item.date_entered | |
| refund_flag | Set true if order_id contains "R" | Refunds included in this table |
| chargeback_flag | Set true if order_id contains "C" | Chargebacks included in this table |
| private_label_id | gdshop_receipt_header.private_label_id | |
| rep_version_id | gdshop_receipt_header.rep_version_id | NES source TBD |
| bill_country_code | gdshop_receipt_header.bill_to_countryn | Enhanced geo logic in order geo ADS; EDS pulls directly from source; no special logic for virtual orders |
| bill_sub_geo_code | gdshop_receipt_header.bill_to_state | |
| bill_postal_code | gdshop_receipt_header.bill_to_zip | |
| bill_source_name | gdshop_receipt_header.order_source | EDS uses raw value from source; transformations in ADS |
| entered_by_name | gdshop_receipt_header.entered_by | For W+M free product conversions through app stores (Apple/Google), contains the app store name |
| order_site_language_code | gdshop_receipt_header.catalog_market_id | |
| virtual_order_flag | When order_id is in gdshop_receipt_virtualOrder | |
| primary_payment_type_name | gdshop_receipt_header_payment.type | From first payment row with max amount |
| primary_payment_subtype_name | gdshop_receipt_header_payment.subtype | From first payment row with max amount |
| secondary_payment_type_name | gdshop_receipt_header_payment.type | From second payment row with max amount |
| secondary_payment_subtype_name | gdshop_receipt_header_payment.subtype | From second payment row with max amount |
| bill_isc_source_code | source_code | EDS uses raw value from source; transformations in ADS |
| receipt_price_usd_amt | — | Sum of bill lines for new ecomm data; null for legacy |
| receipt_price_trxn_amt | — | Sum of bill lines for new ecomm data; null for legacy |
| gcr_usd_amt | — | Sum of bill lines for new ecomm data; null for legacy |
| gcr_trxn_amt | — | Sum of bill lines for new ecomm data; null for legacy |
| margin_gcr_usd_amt | — | Sum of bill lines for new ecomm data; null for legacy |
| margin_gcr_trxn_amt | — | Sum of bill lines for new ecomm data; null for legacy |
| commission_usd_amt | — | Sum of bill lines for new ecomm data; null for legacy |
| commission_trxn_amt | — | Sum of bill lines for new ecomm data; null for legacy |
| aftermarket_seller_commission_usd_amt | — | Sum of bill lines for new ecomm data; null for legacy |
| aftermarket_seller_commission_trxn_amt | — | Sum of bill lines for new ecomm data; null for legacy |
| cost_usd_amt | — | Sum of bill lines for new ecomm data; null for legacy |
| cost_trxn_amt | — | Sum of bill lines for new ecomm data; null for legacy |
| fee_usd_amt | — | Sum of bill lines for new ecomm data; null for legacy |
| fee_trxn_amt | — | Sum of bill lines for new ecomm data; null for legacy |
| fair_market_value_usd_amt | — | Sum of bill lines for new ecomm data; null for legacy |
| fair_market_value_trxn_amt | — | Sum of bill lines for new ecomm data; null for legacy |
| tax_usd_amt | — | Sum of bill lines for new ecomm data; null for legacy |
| tax_trxn_amt | — | Sum of bill lines for new ecomm data; null for legacy |
| injected_fair_market_value_usd_amt | — | Sum of bill lines for new ecomm data; null for legacy |
| injected_fair_market_value_trxn_amt | — | Sum of bill lines for new ecomm data; null for legacy |
| injected_icann_fee_usd_amt | — | Sum of bill lines for new ecomm data; null for legacy |
| injected_icann_fee_trxn_amt | — | Sum of bill lines for new ecomm data; null for legacy |
| injected_tax_usd_amt | — | Sum of bill lines for new ecomm data; null for legacy |
| injected_tax_trxn_amt | — | Sum of bill lines for new ecomm data; null for legacy |
| bundle_allocated_revenue_usd_amt | — | Sum of bill lines for new ecomm data; null for legacy |
| reseller_commission_usd_amt | — | Sum of bill lines for new ecomm data; null for legacy |
| parent_reseller_commission_usd_amt | — | Sum of bill lines for new ecomm data; null for legacy |
| trxn_currency_code | — | |
| exclude_reason_desc | — | |
| exclude_reason_month_end_desc | — | |
| bill_mst_year | — | Partition column e.g. 2020 |
| bill_mst_month | — | Partition column e.g. 01 |

### 4.2. DQ Fact_Bill (Page ID 10357308)

**Purpose:** Data-quality validation comparing `dp_enterprise.fact_bill` against aggregated order-grain dataset `dp_enterprise.uds_order`.

**Key DQ Notes:**
- Total records for 2020-01 matched 100% between fact_bill and uds_order after excluding chargeback and refund orders (5,430,099 rows)
- No duplicates in fact_bill
- **exclude_reason_desc** is at order-level; metrics columns are zeroed out for rows where exclude_reason_desc is set either at bill or line level
- `bill_friendly_id` — n/a at time of testing, only applicable for NES
- `rep_version_id` — '-1' for AppStore/GooglePlay orders in fact_bill vs NULL in uds_order
- `translation_language_name` — 'EN' for AppStore/GooglePlay orders in fact_bill vs NULL in uds_order
- `commission_usd_amt` — differs for AppStore/GooglePlay orders; fact_bill is correct
- `bill_isc_source_code` — directly from source, no business logic applied
- Various *_amt columns have minor rounding differences (up to ~1000 records)

---

## 5. Reference Table DDL Analysis

### 5.1. enterprise.fact_bill_line (Alation table_id: 6332236)

The enterprise.fact_bill_line DDL (read from repos/lake) has NO inline column comments. However, it contains many columns that directly overlap with fact_bill, providing structural confirmation:

**Overlapping columns with fact_bill:**
- bill_id, original_bill_id, source_system_name, bill_modified_mst_ts, bill_modified_mst_date
- refund_flag, chargeback_flag
- receipt_price_usd_amt, receipt_price_trxn_amt
- gcr_usd_amt, gcr_trxn_amt, margin_gcr_usd_amt, margin_gcr_trxn_amt
- commission_usd_amt, commission_trxn_amt
- aftermarket_seller_commission_usd_amt, aftermarket_seller_commission_trxn_amt
- cost_usd_amt, cost_trxn_amt, fee_usd_amt, fee_trxn_amt
- fair_market_value_usd_amt, fair_market_value_trxn_amt
- tax_usd_amt, tax_trxn_amt
- injected_fair_market_value_usd_amt, injected_fair_market_value_trxn_amt
- injected_icann_fee_usd_amt, injected_icann_fee_trxn_amt
- injected_tax_usd_amt, injected_tax_trxn_amt
- bundle_allocated_revenue_usd_amt
- reseller_commission_usd_amt, parent_reseller_commission_usd_amt
- trxn_currency_code
- exclude_reason_desc, exclude_reason_month_end_desc
- etl_build_mst_ts

### 5.2. ecomm360.fact_bill_line_vw (Alation table_id: 7027689)

EDS Prime successor table with rich DDL column comments. This is the primary source for column description candidates:

| Column | ecomm360.fact_bill_line_vw DDL Comment |
|--------|----------------------------------------|
| bill_id | 'Primary Key - Unique identifier for the bill' |
| original_bill_id | 'Reference to the original bill ID in case of modifications or refunds' |
| bill_friendly_id | 'Human-readable friendly identifier for the bill' |
| source_system_name | 'Name of the source system that originated this billing data' |
| bill_modified_mst_ts | 'Timestamp when the bill was last modified in Mountain Standard Time' |
| bill_modified_mst_date | 'Date when the bill was last modified in Mountain Standard Time' |
| refund_flag | 'Flag indicating if this bill line represents a refund transaction' |
| chargeback_flag | 'Flag indicating if this bill line represents a chargeback transaction' |
| bill_country_code | 'ISO country code where the billing address is located' |
| bill_sub_geo_code | 'Sub-geographic code for more specific location within the country' |
| bill_postal_code | 'Postal or ZIP code of the billing address' |
| bill_source_name | 'Name of the billing source or channel that generated this line' |
| primary_payment_type_name | 'Primary payment method type used for this transaction' |
| primary_payment_subtype_name | 'Subtype or specific variant of the primary payment method' |
| secondary_payment_type_name | 'Secondary payment method if multiple payment types were used' |
| secondary_payment_subtype_name | 'Subtype of the secondary payment method' |
| order_site_language_code | 'Language code of the website where the order was placed' |
| translation_language_name | 'Language name for any translation services applied' |
| free_order_flag | 'Flag indicating if this was a free order with no charge' |
| bill_isc_source_code | 'Internal source code for ISC (Internal Sales Channel) tracking' |
| virtual_order_flag | 'Flag indicating if this was a virtual or digital-only order' |
| entered_by_name | 'Name or identifier of the person who entered this bill line' |
| receipt_price_usd_amt | 'Receipt price amount in USD as shown to customer' |
| receipt_price_trxn_amt | 'Receipt price amount in the transaction currency' |
| gcr_usd_amt | 'Gross Customer Receipt amount in USD' |
| gcr_trxn_amt | 'Gross Customer Receipt amount in transaction currency' |
| margin_gcr_usd_amt | 'Margin calculation on Gross Customer Receipt in USD' |
| margin_gcr_trxn_amt | 'Margin calculation on Gross Customer Receipt in transaction currency' |
| commission_usd_amt | 'Commission amount paid in USD' |
| commission_trxn_amt | 'Commission amount paid in transaction currency' |
| aftermarket_seller_commission_usd_amt | 'Commission paid to aftermarket sellers in USD' |
| aftermarket_seller_commission_trxn_amt | 'Commission paid to aftermarket sellers in transaction currency' |
| cost_usd_amt | 'Cost of goods sold amount in USD' |
| cost_trxn_amt | 'Cost of goods sold amount in transaction currency' |
| fee_usd_amt | 'Additional fees charged in USD' |
| fee_trxn_amt | 'Additional fees charged in transaction currency' |
| fair_market_value_usd_amt | 'Fair market value assessment in USD' |
| fair_market_value_trxn_amt | 'Fair market value assessment in transaction currency' |
| tax_usd_amt | 'Tax amount charged in USD' |
| tax_trxn_amt | 'Tax amount charged in transaction currency' |
| injected_fair_market_value_usd_amt | 'System-injected fair market value adjustment in USD' |
| injected_fair_market_value_trxn_amt | 'System-injected fair market value adjustment in transaction currency' |
| injected_icann_fee_usd_amt | 'ICANN regulatory fee amount injected by system in USD' |
| injected_icann_fee_trxn_amt | 'ICANN regulatory fee amount injected by system in transaction currency' |
| injected_tax_usd_amt | 'Tax amount injected by system in USD' |
| injected_tax_trxn_amt | 'Tax amount injected by system in transaction currency' |
| bundle_allocated_revenue_usd_amt | 'Revenue allocated to this item from bundle pricing in USD' |
| reseller_commission_usd_amt | 'Commission paid to reseller partners in USD' |
| parent_reseller_commission_usd_amt | 'Commission paid to parent reseller in USD' |
| trxn_currency_code | 'ISO currency code for the transaction' |
| exclude_reason_desc | 'Description of reason why this line item might be excluded from reports' |
| exclude_reason_month_end_desc | 'Month-end specific exclusion reason description' |
| intent | 'Intent Enum for virtual bill with value such as FREEMIUM_PURCHASE, FREE_PURCHASE, FREE_TRIAL_MODIFY, etc' |
| related_subscription | 'Associate a receiptless or virtual order event to a specific subscription' |

### 5.3. ecomm360.dim_bill_vw (Alation table_id: 7028947)

Bill-grain dimension in EDS Prime. Limited column overlap with fact_bill, but confirms:

| Column | dim_bill_vw DDL Comment |
|--------|------------------------|
| bill_id | 'Primary Key - Unique identifier for the bill' |
| rep_version_id | 'current rep version id on the bill' |
| bill_modified_mst_date | 'Timestamp when the bill was last modified in Mountain Standard Time' |

---

## 6. Certified Data Dictionary Mappings

⚠️ **CRITICAL NOTE:** Alation was unavailable (expired refresh token). The Certified Data Dictionary (Document Folder ID 6) could NOT be fetched. The following table is based on available evidence only.

| Abbreviation | Evidence / Candidate Official Name | Source | Confidence |
|---|---|---|---|
| GCR | Gross Cash Receipts | Instructions example explicitly states "If the dictionary says 'GCR = Gross Cash Receipts'" as the authoritative form | HIGH — instructions strongly imply this is the official expansion |
| GCR | ~~Gross Customer Receipt~~ | ecomm360.fact_bill_line_vw DDL comment | REJECT if GCR = Gross Cash Receipts is confirmed |
| ISC | Internal Sales Channel | ecomm360.fact_bill_line_vw DDL comment (bill_isc_source_code: 'Internal source code for ISC (Internal Sales Channel) tracking') | MEDIUM — from reference DDL, not verified in dictionary |
| ICANN | Internet Corporation for Assigned Names and Numbers | Industry standard | HIGH — standard industry term, unlikely to differ |
| EDS | Enterprise Dataset | table.yaml description, Confluence | HIGH — used consistently across GoDaddy data docs |
| NES | Not verified — new e-commerce system (inferred) | Confluence context | LOW — not confirmed |
| ADS | Aggregated/Analytics Dataset (inferred) | Confluence context (references "ADS replacement for uds_refund") | LOW — not confirmed |
| MST | Mountain Standard Time | Common usage | HIGH — standard time zone abbreviation |
| ETL | Extract, Transform, Load | Common usage | HIGH — standard industry term |
| PII | Personally Identifiable Information | DDL comment on entered_by_name | HIGH — standard term |
| USD | US Dollar | Common usage | HIGH — standard currency abbreviation |
| trxn | Transaction | Common usage throughout DDL | HIGH — self-evident in context |

**⚠️ NEXT STAGE MUST VERIFY:** The writing stage should note that GCR's official expansion must come from the Certified Data Dictionary. The instructions example ("GCR = Gross Cash Receipts") is treated as authoritative; DO NOT use "Gross Customer Receipt" from the ecomm360 DDL without Data Dictionary confirmation.

---

## 7. Per-Column Research Notes

| Column | Type | Existing DDL Comment | ecomm360.fact_bill_line_vw Comment | Confluence Notes | Inferred Description |
|--------|------|---------------------|-------------------------------------|-----------------|---------------------|
| bill_id | string | — | 'Primary Key - Unique identifier for the bill' | Source: gdshop_receipt_item.order_id; includes refunds | **PK (composite with source_system_name)**. Unique identifier for the bill/receipt. Source: gdshop_receipt_item.order_id. Refunds included (set refund_flag). |
| original_bill_id | string | — | 'Reference to the original bill ID in case of modifications or refunds' | Added per INSIGHT-22025 for ADS uds_refund replacement. Source: gdshop_recent_header.order_order_id | Identifier of the original bill before modification; used to link refunds back to the originating bill. |
| bill_friendly_id | string | — | 'Human-readable friendly identifier for the bill' | DQ: n/a for now, only applicable for NES | Human-readable display identifier for the bill; applicable for NES (New E-Commerce System) orders. |
| source_system_name | string | — | 'Name of the source system that originated this billing data' | PK (composite with bill_id). Values include 'legacy e-comm'. | **PK (composite with bill_id)**. Name of the source system that originated the billing data (e.g., 'legacy e-comm'). |
| bill_modified_mst_ts | timestamp | — | 'Timestamp when the bill was last modified in Mountain Standard Time' | Source: gdshop_receipt_item.date_entered | Timestamp when the bill was last modified, in Mountain Standard Time (MST). |
| bill_modified_mst_date | string | — | 'Date when the bill was last modified in Mountain Standard Time' | Source: gdshop_receipt_item.date_entered | Date when the bill was last modified, in Mountain Standard Time (MST). |
| refund_flag | boolean | — | 'Flag indicating if this bill line represents a refund transaction' | Set to true if order_id contains "R"; refunds included in this table | True if this bill represents a refund transaction (order_id contains "R"). Refunds are included in this table alongside non-refund bills. |
| chargeback_flag | boolean | — | 'Flag indicating if this bill line represents a chargeback transaction' | Set to true if order_id contains "C"; chargebacks included | True if this bill represents a chargeback transaction (order_id contains "C"). Chargebacks are included in this table. |
| private_label_id | int | — | 'Identifier for private label partner if applicable' (from fact_bill_line_vw) | Source: gdshop_receipt_header.private_label_id | Identifier for the private label partner through which the purchase was made, if applicable. |
| rep_version_id | int | — | dim_bill_vw: 'current rep version id on the bill' | '-1' for AppStore/GooglePlay orders (vs NULL in uds_order); source: gdshop_receipt_header.repversion | Rep (reseller/representative) version identifier on the bill. Set to -1 for Apple App Store and Google Play orders. |
| bill_country_code | string | — | 'ISO country code where the billing address is located' | Source: gdshop_receipt_header.bill_to_countryn; EDS pulls directly from source, no special geo logic for virtual orders | ISO country code of the billing address. Sourced directly from gdshop_receipt_header; no special geo logic applied for virtual orders. |
| bill_sub_geo_code | string | — | 'Sub-geographic code for more specific location within the country' | Source: gdshop_receipt_header.bill_to_state | Sub-geographic code (e.g., state or region) within the billing country, sourced from gdshop_receipt_header.bill_to_state. |
| bill_postal_code | string | — | 'Postal or ZIP code of the billing address' | Source: gdshop_receipt_header.bill_to_zip | Postal or ZIP code of the billing address. |
| bill_source_name | string | — | 'Name of the billing source or channel that generated this line' | Source: gdshop_receipt_header.order_source; EDS uses raw value from source, transformations in ADS | Order source channel name as recorded at time of purchase (e.g., 'online', agent sales channel). Raw value from source; transformations applied in ADS layer. |
| entered_by_name | string | 'PII' | 'Name or identifier of the person who entered this bill line' | For W+M free product conversions through app stores (Apple/Google), contains app store name. Source: gdshop_receipt_header.entered_by | **PII.** Name or identifier of the agent who entered the bill. For Website+Marketing free product conversions through Apple App Store or Google Play, contains the app store name. |
| translation_language_name | string | — | 'Language name for any translation services applied' | 'EN' for AppStore/GooglePlay orders (vs NULL in uds_order) | Language name used for translation services at time of purchase. Set to 'EN' for Apple App Store and Google Play orders. |
| order_site_language_code | string | — | 'Language code of the website where the order was placed' | Source: gdshop_receipt_header.catalog_market_id | Language code of the GoDaddy website where the order was placed. Sourced from gdshop_receipt_header.catalog_market_id. |
| virtual_order_flag | boolean | — | 'Flag indicating if this was a virtual or digital-only order' | Set to TRUE when order_id is in gdshop_receipt_virtualOrder | True if this is a virtual order (no physical component; sourced from gdshop_receipt_virtualOrder). |
| free_order_flag | boolean | — | 'Flag indicating if this was a free order with no charge' | DQ: 19 orders had different flag; new one looks correct | True if this order was placed at no charge to the customer. |
| primary_payment_type_name | string | — | 'Primary payment method type used for this transaction' | From first payment row with max amount. Source: gdshop_receipt_header_payment.type | Payment method type of the primary (largest-amount) payment used for this bill (e.g., 'creditcard', 'paypal'). |
| primary_payment_subtype_name | string | — | 'Subtype or specific variant of the primary payment method' | From first payment row with max amount. Source: gdshop_receipt_header_payment.subtype | Subtype or card network of the primary payment method (e.g., 'visa', 'mastercard'). |
| secondary_payment_type_name | string | — | 'Secondary payment method if multiple payment types were used' | From second payment row with max amount | Payment method type of a secondary payment used for this bill, if multiple payment methods were applied. |
| secondary_payment_subtype_name | string | — | 'Subtype of the secondary payment method' | From second payment row with max amount | Subtype of the secondary payment method, if applicable. |
| intent | string | 'Intent Enum for virtual bill with value such as FREEMIUM_PURCHASE, FREE_PURCHASE, FREE_TRIAL_MODIFY, etc' | 'Intent Enum for virtual bill with value such as FREEMIUM_PURCHASE, FREE_PURCHASE, FREE_TRIAL_MODIFY, etc' | Same comment in ecomm360 DDL | **PRESERVE EXISTING COMMENT.** Intent classification for virtual orders. Values include FREEMIUM_PURCHASE, FREE_PURCHASE, FREE_TRIAL_MODIFY. |
| related_subscription | string | 'Associate a receiptless or virtual order event to a specific subscription' | 'Associate a receiptless or virtual order event to a specific subscription' | Same comment in ecomm360 DDL | **PRESERVE EXISTING COMMENT.** Subscription identifier linking a receiptless or virtual order event to its associated subscription. |
| bill_isc_source_code | string | — | 'Internal source code for ISC (Internal Sales Channel) tracking' | DQ: directly from source, no business logic applied | Internal Sales Channel (ISC) source code as recorded at time of purchase. Raw value from source; no business logic applied. |
| receipt_price_usd_amt | decimal(18,2) | — | 'Receipt price amount in USD as shown to customer' | Sum of bill lines for new ecomm data; null for legacy | Total receipt price in USD as charged to the customer. Aggregated from bill lines (new e-commerce); null for legacy orders. |
| receipt_price_trxn_amt | decimal(18,2) | — | 'Receipt price amount in the transaction currency' | Sum of bill lines for new ecomm data; null for legacy | Total receipt price in the transaction currency (see trxn_currency_code). Aggregated from bill lines (new e-commerce); null for legacy orders. |
| gcr_usd_amt | decimal(18,2) | — | 'Gross Customer Receipt amount in USD' [NOTE: see GCR warning below] | Sum of bill lines for new ecomm data; null for legacy | **GCR** amount in USD, aggregated from bill lines (new e-commerce); null for legacy. ⚠️ Use official GCR expansion from Certified Data Dictionary. |
| gcr_trxn_amt | decimal(18,2) | — | 'Gross Customer Receipt amount in transaction currency' | Sum of bill lines for new ecomm data; null for legacy | **GCR** amount in transaction currency (see trxn_currency_code), aggregated from bill lines; null for legacy. |
| margin_gcr_usd_amt | decimal(18,2) | — | 'Margin calculation on Gross Customer Receipt in USD' | Sum of bill lines for new ecomm data; null for legacy | Margin on **GCR** in USD, aggregated from bill lines; null for legacy. |
| margin_gcr_trxn_amt | decimal(18,2) | — | 'Margin calculation on Gross Customer Receipt in transaction currency' | Sum of bill lines for new ecomm data; null for legacy | Margin on **GCR** in transaction currency, aggregated from bill lines; null for legacy. |
| commission_usd_amt | decimal(18,2) | — | 'Commission amount paid in USD' | Differs for AppStore/GooglePlay; fact_bill is correct. Sum of bill lines. | Commission amount in USD. Aggregated from bill lines (new e-commerce); null for legacy. Note: differs from uds_order for Apple App Store and Google Play orders; fact_bill values are authoritative. |
| commission_trxn_amt | decimal(18,2) | — | 'Commission amount paid in transaction currency' | Differs for AppStore/GooglePlay; fact_bill is correct | Commission amount in transaction currency. Aggregated from bill lines (new e-commerce); null for legacy. |
| aftermarket_seller_commission_usd_amt | decimal(18,2) | — | 'Commission paid to aftermarket sellers in USD' | Sum of bill lines; 2 records with rounding diff | Commission paid to aftermarket domain/product sellers, in USD. Aggregated from bill lines; null for legacy. |
| aftermarket_seller_commission_trxn_amt | decimal(18,2) | — | 'Commission paid to aftermarket sellers in transaction currency' | Sum of bill lines; 2 records with rounding diff | Commission paid to aftermarket sellers in transaction currency. Aggregated from bill lines; null for legacy. |
| cost_usd_amt | decimal(18,2) | — | 'Cost of goods sold amount in USD' | Sum of bill lines | Cost of goods sold in USD, aggregated from bill lines; null for legacy. |
| cost_trxn_amt | decimal(18,2) | — | 'Cost of goods sold amount in transaction currency' | Sum of bill lines | Cost of goods sold in transaction currency, aggregated from bill lines; null for legacy. |
| fee_usd_amt | decimal(18,2) | — | 'Additional fees charged in USD' | Sum of bill lines | Additional fees charged on the bill in USD, aggregated from bill lines; null for legacy. |
| fee_trxn_amt | decimal(18,2) | — | 'Additional fees charged in transaction currency' | Sum of bill lines | Additional fees charged in transaction currency, aggregated from bill lines; null for legacy. |
| fair_market_value_usd_amt | decimal(18,2) | — | 'Fair market value assessment in USD' | Sum of bill lines | Fair market value of the billed products in USD, aggregated from bill lines; null for legacy. |
| fair_market_value_trxn_amt | decimal(18,2) | — | 'Fair market value assessment in transaction currency' | Sum of bill lines | Fair market value in transaction currency, aggregated from bill lines; null for legacy. |
| tax_usd_amt | decimal(18,2) | — | 'Tax amount charged in USD' | Sum of bill lines | Tax amount charged on the bill in USD, aggregated from bill lines; null for legacy. |
| tax_trxn_amt | decimal(18,2) | — | 'Tax amount charged in transaction currency' | Sum of bill lines | Tax amount in transaction currency, aggregated from bill lines; null for legacy. |
| injected_fair_market_value_usd_amt | decimal(18,2) | — | 'System-injected fair market value adjustment in USD' | Sum of bill lines | System-calculated fair market value adjustment injected into the bill in USD (overrides source FMV), aggregated from bill lines; null for legacy. |
| injected_fair_market_value_trxn_amt | decimal(18,2) | — | 'System-injected fair market value adjustment in transaction currency' | Sum of bill lines | System-injected fair market value adjustment in transaction currency, aggregated from bill lines; null for legacy. |
| injected_icann_fee_usd_amt | decimal(18,2) | — | 'ICANN regulatory fee amount injected by system in USD' | Sum of bill lines | ICANN (Internet Corporation for Assigned Names and Numbers) regulatory fee injected by the system in USD, aggregated from bill lines; null for legacy. |
| injected_icann_fee_trxn_amt | decimal(18,2) | — | 'ICANN regulatory fee amount injected by system in transaction currency' | Sum of bill lines | ICANN regulatory fee in transaction currency, injected by system, aggregated from bill lines; null for legacy. |
| injected_tax_usd_amt | decimal(18,2) | — | 'Tax amount injected by system in USD' | Sum of bill lines | Tax amount injected by the system (separate from transaction-reported tax) in USD, aggregated from bill lines; null for legacy. |
| injected_tax_trxn_amt | decimal(18,2) | — | 'Tax amount injected by system in transaction currency' | Sum of bill lines | System-injected tax amount in transaction currency, aggregated from bill lines; null for legacy. |
| bundle_allocated_revenue_usd_amt | decimal(18,2) | — | 'Revenue allocated to this item from bundle pricing in USD' | Sum of bill lines | Revenue allocated to this bill from bundle pricing arrangements in USD, aggregated from bill lines; null for legacy. |
| reseller_commission_usd_amt | decimal(18,2) | — | 'Commission paid to reseller partners in USD' | Sum of bill lines | Commission paid to reseller partners for this bill in USD, aggregated from bill lines; null for legacy. |
| parent_reseller_commission_usd_amt | decimal(18,2) | — | 'Commission paid to parent reseller in USD' | Sum of bill lines | Commission paid to the parent-level reseller for this bill in USD, aggregated from bill lines; null for legacy. |
| trxn_currency_code | string | — | 'ISO currency code for the transaction' | — | ISO 4217 currency code for the transaction currency used for all *_trxn_amt columns (e.g., 'USD', 'EUR', 'GBP'). |
| exclude_reason_desc | string | — | 'Description of reason why this line item might be excluded from reports' | Set at order/bill level; metrics zeroed out for bills with exclude_reason_desc set at either bill or line level | Reason this bill is excluded from revenue metrics reporting. When set (at bill or line level), all metric amount columns are zeroed out for the affected bill/line combination. |
| exclude_reason_month_end_desc | string | — | 'Month-end specific exclusion reason description' | — | Month-end close-specific reason for excluding this bill from period-end revenue calculations. |
| etl_build_mst_ts | string | — | N/A (fact_bill_line_vw has etl_insert_utc_ts/etl_update_utc_ts instead) | — | Timestamp when the ETL process built this record, in Mountain Standard Time (MST). |

---

## 8. Partition Columns (informational — not in main DDL body)

| Column | Notes |
|--------|-------|
| bill_mst_year | Partition key. Year the bill was created (MST). Example: '2020' |
| bill_mst_month | Partition key. Month the bill was created (MST). Example: '01' |

---

## 9. Key Observations for Writing Stage

1. **GCR expansion:** Instructions example says GCR = "Gross Cash Receipts". The ecomm360.fact_bill_line_vw DDL says "Gross Customer Receipt". The writing stage must use the authoritative Certified Data Dictionary expansion. Since instructions explicitly use "Gross Cash Receipts" as the example, use "Gross Cash Receipts" unless new information contradicts this.

2. **`_usd_amt` vs `_trxn_amt` naming pattern:** All financial columns come in pairs. `_usd_amt` = amount in US dollars; `_trxn_amt` = amount in the transaction currency (ISO code in `trxn_currency_code`). All are aggregated (summed) from fact_bill_line for new ecomm data; NULL for legacy orders.

3. **`entered_by_name`:** Already has comment 'PII' — this MUST be preserved. Enhance by adding business context while keeping PII annotation.

4. **`intent` and `related_subscription`:** Already have substantive DDL comments that match ecomm360 DDL — preserve and expand only minimally.

5. **`exclude_reason_desc`:** Bill-level exclusion reason; not line-level. Metrics are zeroed for affected bills. Distinguish from `exclude_reason_month_end_desc` (month-end close specific).

6. **`bill_friendly_id`:** Only applicable for NES (New E-Commerce System) orders; legacy orders may be null.

7. **`source_system_name`:** Part of composite primary key with bill_id. Values include 'legacy e-comm'.

8. **Commission for AppStore/GooglePlay:** `commission_usd_amt` and `commission_trxn_amt` differ from `uds_order` for AppStore/GooglePlay; `fact_bill` values are correct.

9. **`rep_version_id`:** Set to -1 for AppStore/GooglePlay orders (vs NULL in uds_order).

10. **`translation_language_name`:** Set to 'EN' for AppStore/GooglePlay orders.

11. **`bill_isc_source_code`:** Raw value from source; no business logic applied. ISC = Internal Sales Channel.

12. **`etl_build_mst_ts`:** Note that this column is typed as `string` (not `timestamp`), unlike `bill_modified_mst_ts` which is `timestamp`.


**The agent's final response to the user was:**
The research is complete. Here's a summary of what was accomplished:

## Research Summary

**Target Table:** `enterprise.fact_bill` — EDS comprehensive receipt view rolled up at bill grain (PK: `bill_id` + `source_system_name`)

**Sources Consulted:**
1. **DDL/YAML** from `repos/lake` — 59 columns analyzed, existing inline comments on `entered_by_name` (PII), `intent`, and `related_subscription` identified for preservation
2. **Confluence Page 10358411** (Fact_Bill design doc) — full data flow, source column mappings, and EDS schema notes extracted
3. **Confluence Page 10357308** (DQ Fact_Bill) — DQ validation notes on column semantics, AppStore/GooglePlay edge cases, exclude_reason behavior
4. **`ecomm360.fact_bill_line_vw` DDL** (from repos/lake) — rich inline comments for ~48 overlapping columns used as primary description candidates
5. **`enterprise.fact_bill_line` DDL** (from repos/lake) — structural overlap confirmed; no inline comments
6. **`ecomm360.dim_bill_vw` DDL** — bill-grain dimension comments for a few columns

**⚠️ Limitation:** Alation was unavailable (refresh token expired `401000`). Could not fetch: target table column metadata, reference table Alation descriptions, or Certified Data Dictionary (Folder 6).

**Key Finding on GCR:** The instructions explicitly use "Gross Cash Receipts" as the authoritative GCR expansion. The ecomm360 DDL uses "Gross Customer Receipt" — the writing stage should use "Gross Cash Receipts" per the instructions' guidance.

**`research.md`** now contains 591 lines with full DDL, per-column research notes table, Confluence summaries, reference DDL mappings, and key observations for the writing stage.