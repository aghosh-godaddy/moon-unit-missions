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

# Research: enterprise.fact_entitlement_bill

**Research Date:** 2026-05-13
**Researcher:** Data Governance Analyst (automated)

---

## 1. Full Current DDL

```sql
CREATE TABLE fact_entitlement_bill(
    entitlement_id string
    ,subscription_id string
    ,resource_id bigint
    ,product_family_name string
    ,product_type_id int
    ,pf_id  int
    ,entitlement_addon_id bigint 
    ,source_system_name string
    ,source_table_name string
    ,subscription_paid_through_mst_ts timestamp
    ,subscription_paid_through_mst_date date
    ,subscription_bill_due_mst_ts timestamp 
    ,subscription_bill_due_mst_date date 
    ,billing_subscription_status_name string COMMENT 'subscription status at bill_modified_mst_ts'
    ,bill_id string
    ,bill_line_num int
    ,prorated_bill_line_num int
    ,bill_sequence_number int
    ,bill_modified_mst_ts timestamp
    ,bill_modified_mst_date date
    ,refund_flag boolean
    ,chargeback_flag boolean
    ,payable_bill_line_flag boolean
    ,originating_payable_subscription_flag boolean
    ,current_payable_subscription_flag boolean
    ,bill_auto_renewal_flag boolean
    ,product_month_qty decimal(18,6)
    ,unit_qty decimal(18,6) COMMENT 'Prorated unit quantity from receipts'
    ,duration_qty decimal(18,6) COMMENT 'Prorated quantity of duration units which are described in product_period_name (dim_product)'
    ,msrp_duration_unit_usd_amt decimal(18,6)
    ,msrp_duration_unit_trxn_amt decimal(18,6)
    ,gcr_usd_amt decimal(18,6)
    ,gcr_trxn_amt decimal(18,6)
    ,trxn_currency_code string
    ,margin_gcr_usd_amt decimal(18,6)
    ,receipt_price_usd_amt decimal(18,6)
    ,receipt_price_trxn_amt decimal(18,6)
    ,list_price_usd_amt decimal(18,6)
    ,list_price_trxn_amt decimal(18,6)
    ,sale_price_usd_amt decimal(18,6)
    ,sale_price_trxn_amt decimal(18,6)
    ,injected_icann_fee_usd_amt decimal(18,6)
    ,fee_usd_amt decimal(18,6)
    ,etl_build_mst_ts timestamp          	                    
); 
```

**Partition key:** `partition_bill_modified_mst_year_month` (string)

---

## 2. Table YAML Metadata

- **Description:** "Enterprise Dataset (EDS) that provides a comprehensive view of a renewals of purchase Godaddy orders."
- **Storage format:** Parquet
- **Table type:** PARTITIONED
- **Data tier:** 1 (highest quality)
- **SLA:** Delivered by 7 AM MST every day (`cron(0 14 * * ? *)`)
- **SLO identifier:** `enterprise.fact_entitlement_bill`

### Upstream Lineage Dependencies
- `bigreporting.dim_product_snap`
- `dp_stage.nds_domain_change_of_ownership`
- `dp_stage.nds_product_type`
- `ecomm_mart.nds_resource_auto_renew_delta` — Conversion of nds_resource_auto_renew to Delta Lake
- `enterprise.dim_entitlement` — Entitlement information of customers products
- `enterprise.dim_subscription` — A comprehensive view of dimensions and metrics associated with purchased products
- `ecomm360.fact_bill_line_vw` — tracks every receipt of the purchase of a GoDaddy customer
- `godaddybilling_txlog.gdshop_resource_mtm_order`
- `godaddybilling_txlog.gdshop_resource_mtm_order_detail`

### Consumers (permissions)
Multiple teams: c2_commerce_analytics, customer_inference, usi, edt, dri_analytics, fdat-engineering, customer_analytics, hivemind, ckp_customer_insights, martech_data, emea_dwh_123reg, dri_domainfind, dri_aftermarketbi, rrd_bi, dri_data, analytics, dri_findml, mktgdata, revenue_and_relevance, imcoreappsvc.

---

## 3. Confluence Page Summary

**Page:** fact_entitlement_bill: Validation switch to lookalike prime (ID: 3941171221)

This page documents a **validation exercise** comparing the "legacy" EDS implementation of `fact_entitlement_bill` vs the new "prime" (EDS Prime lookalike) implementation, across 26 years of data (~2.118 billion rows, snapshot as of 2025-09-30).

### Key Findings Relevant to Column Understanding

**Natural/Composite Key:** The validation JOIN was performed on:
`resource_id + product_family_name + bill_id + bill_line_num + prorated_bill_line_num`
This confirms these five columns together form the effective composite key.

**Column-level match rates:**

| Column | Match % | Notes |
|--------|---------|-------|
| bill_id | 100.000000% | Perfect match |
| product_family_name | 100.000000% | Perfect match |
| source_system_name | 100.000000% | Perfect match |
| source_table_name | 100.000000% | Perfect match |
| bill_line_num | 100.000000% | Perfect match |
| prorated_bill_line_num | 100.000000% | Perfect match |
| pf_id | 100.000000% | Perfect match |
| resource_id | 100.000000% | Perfect match |
| entitlement_addon_id | 100.000000% | Perfect match |
| bill_modified_mst_ts | 100.000000% | Perfect match |
| bill_modified_mst_date | 100.000000% | Perfect match |
| bill_auto_renewal_flag | 100.000000% | Perfect match |
| payable_bill_line_flag | 100.000000% | Perfect match |
| current_payable_subscription_flag | 100.000000% | Perfect match |
| refund_flag | 100.000000% | Perfect match |
| chargeback_flag | 100.000000% | Perfect match |
| unit_qty | 100.000000% | Perfect match |
| duration_qty | 100.000000% | Perfect match |
| msrp_duration_unit_trxn_amt | 100.000000% | Perfect match |
| receipt_price_usd_amt | 100.000000% | Perfect match |
| receipt_price_trxn_amt | 100.000000% | Perfect match |
| list_price_usd_amt | 100.000000% | Perfect match |
| list_price_trxn_amt | 100.000000% | Perfect match |
| injected_icann_fee_usd_amt | 100.000000% | Perfect match |
| fee_usd_amt | 100.000000% | Perfect match |
| entitlement_id | ~100% (1 mismatch) | Near-perfect |
| subscription_id | ~100% (1 mismatch) | Near-perfect |
| product_type_id | ~100% (1 mismatch) | Near-perfect |
| originating_payable_subscription_flag | ~100% (1 mismatch) | Near-perfect |
| msrp_duration_unit_usd_amt | 99.999991% (191 mismatches) | Minor differences |
| billing_subscription_status_name | 99.999489% (10,825 mismatches) | Some status differences between legacy/prime |
| product_month_qty | 99.999935% (1,368 mismatches) | Minor differences |
| subscription_paid_through_mst_ts | 99.999384% (13,052 mismatches) | Minor timestamp rounding differences |
| subscription_bill_due_mst_ts | 99.999366% (13,427 mismatches) | Minor timestamp rounding differences |
| gcr_trxn_amt | 99.999903% (2,049 mismatches) | Minor |
| gcr_usd_amt | 99.999888% (2,369 mismatches) | Minor |
| margin_gcr_usd_amt | 99.993233% (143,359 mismatches) | 141,409 virtual orders expected; 416 non-virtual under investigation |
| sale_price_usd_amt | 99.987483% (265,183 mismatches) | Differences mainly in DBP and domains; legacy has null values for some historical records (pre-2013) |
| sale_price_trxn_amt | 99.978692% (451,421 mismatches) | Similar to USD amount; legacy null for older records |
| trxn_currency_code | 98.473481% (32,339,499 mismatches) | Virtual_order reflow defaulted to 'USD' in prime |

**Note on sale_price_usd_amt:** Legacy has null values for records going back to ~2009–2012 while prime backfilled values. Source was `signals_platform_cln.ecomm_order_item_event_cln` / `godaddy.gdshop_receipt_item_snap`.

**Note on trxn_currency_code:** ~32M mismatches due to virtual_order reflow defaulting trxn_currency_code to 'USD' in prime, suggesting virtual orders may not have a meaningful transaction currency in the source.

---

## 4. Alation Lookup

**Status: UNAVAILABLE** — The Alation refresh token is expired (`401000: Refresh token provided is expired or revoked`). The `ALATION_REFRESH_TOKEN` environment variable is not set. All Alation data (target table columns, reference table columns, and Certified Data Dictionary) could not be retrieved.

---

## 5. Certified Data Dictionary Mappings

Alation Certified Data Dictionary (Document Folder ID 6) was **not accessible** due to expired credentials. The following abbreviations appear in column names and are resolved based on industry-standard knowledge:

| Abbreviation | Official Name | Source |
|---|---|---|
| GCR | Gross Cash Receipts | Industry standard / GoDaddy financial metric (could not verify via Alation) |
| MSRP | Manufacturer's Suggested Retail Price | Industry standard |
| MST | Mountain Standard Time | Standard timezone abbreviation |
| USD | US Dollar | ISO 4217 currency code |
| ETL | Extract, Transform, Load | Standard data engineering term |
| PF | Product Family | Inferred from context (product_family_name + pf_id) |
| ICANN | Internet Corporation for Assigned Names and Numbers | Standard domain industry term |
| EDS | Enterprise Dataset | GoDaddy internal term |
| DBP | Domain By Proxy | GoDaddy product/service name |

**NOTE:** GCR = Gross Cash Receipts is the standard GoDaddy financial abbreviation, consistent with `margin_gcr_usd_amt` naming pattern (margin on gross cash receipts). However, Alation dictionary confirmation was not possible.

---

## 6. Per-Column Analysis

### Identifiers

| Column | Type | DDL Comment | Analysis |
|--------|------|-------------|----------|
| entitlement_id | string | (none) | Unique identifier for the customer entitlement; links to enterprise.dim_entitlement. Combined with resource/bill identifiers forms row identity. |
| subscription_id | string | (none) | Unique identifier for the subscription; links to enterprise.dim_subscription. |
| resource_id | bigint | (none) | Numeric identifier for the resource (product instance) associated with the entitlement; part of the composite key. |
| product_family_name | string | (none) | Product family category (e.g., Domains, Hosting, Email); part of the composite key. |
| product_type_id | int | (none) | Numeric identifier for the product type; links to dp_stage.nds_product_type. |
| pf_id | int | (none) | Numeric product family identifier; companion to product_family_name; matches 100% vs prime. |
| entitlement_addon_id | bigint | (none) | Identifier for the add-on entitlement, if the bill line is for an add-on product. |
| source_system_name | string | (none) | Name of the upstream source system that originated the bill record. |
| source_table_name | string | (none) | Name of the upstream source table that originated the bill record. |

### Subscription Dates

| Column | Type | DDL Comment | Analysis |
|--------|------|-------------|----------|
| subscription_paid_through_mst_ts | timestamp | (none) | Timestamp (MST) through which the subscription has been paid; used for renewal scheduling. ~13K mismatches vs legacy likely due to timezone rounding. |
| subscription_paid_through_mst_date | date | (none) | Date (MST) through which the subscription has been paid; date-only companion to subscription_paid_through_mst_ts. |
| subscription_bill_due_mst_ts | timestamp | (none) | Timestamp (MST) when the subscription bill is due for payment. ~13K mismatches vs legacy. |
| subscription_bill_due_mst_date | date | (none) | Date (MST) when the subscription bill payment is due; date-only companion to subscription_bill_due_mst_ts. |
| billing_subscription_status_name | string | 'subscription status at bill_modified_mst_ts' | Subscription status captured at the time of bill modification (bill_modified_mst_ts); indicates the renewal/active state of the subscription at that billing event. |

### Bill Identifiers and Metadata

| Column | Type | DDL Comment | Analysis |
|--------|------|-------------|----------|
| bill_id | string | (none) | Unique bill (order/receipt) identifier; links to ecomm360.fact_bill_line_vw. Part of the composite key. |
| bill_line_num | int | (none) | Line number within the bill for this product; part of the composite key alongside bill_id. |
| prorated_bill_line_num | int | (none) | Prorated line number for partial-period billing calculations; part of the composite key. |
| bill_sequence_number | int | (none) | Sequential number indicating the billing event sequence for this entitlement (e.g., 1st, 2nd renewal). |
| bill_modified_mst_ts | timestamp | (none) | Timestamp (MST) when the bill record was last modified; used as the partition basis (partition_bill_modified_mst_year_month). |
| bill_modified_mst_date | date | (none) | Date (MST) when the bill record was last modified; date-only companion to bill_modified_mst_ts. |

### Flags

| Column | Type | DDL Comment | Analysis |
|--------|------|-------------|----------|
| refund_flag | boolean | (none) | True if this bill line represents a refund transaction. |
| chargeback_flag | boolean | (none) | True if this bill line represents a chargeback (disputed transaction reversal). |
| payable_bill_line_flag | boolean | (none) | True if this bill line is payable (represents actual revenue). |
| originating_payable_subscription_flag | boolean | (none) | True if this is the originating (first) payable subscription bill event. |
| current_payable_subscription_flag | boolean | (none) | True if this bill line belongs to the current (most recent) payable subscription. |
| bill_auto_renewal_flag | boolean | (none) | True if this bill was generated by an auto-renewal event (sourced from ecomm_mart.nds_resource_auto_renew_delta). |

### Quantities

| Column | Type | DDL Comment | Analysis |
|--------|------|-------------|----------|
| product_month_qty | decimal(18,6) | (none) | Quantity expressed in product months; represents the duration of the billing period in months. |
| unit_qty | decimal(18,6) | 'Prorated unit quantity from receipts' | Prorated number of units billed, derived from receipt data; accounts for partial-period billing. |
| duration_qty | decimal(18,6) | 'Prorated quantity of duration units which are described in product_period_name (dim_product)' | Prorated quantity of duration units (e.g., months, years) as defined by product_period_name in dim_product; complements unit_qty with the duration dimension. |

### Amounts (USD and Transaction Currency)

| Column | Type | DDL Comment | Analysis |
|--------|------|-------------|----------|
| msrp_duration_unit_usd_amt | decimal(18,6) | (none) | Manufacturer's Suggested Retail Price (MSRP) per duration unit, expressed in USD. |
| msrp_duration_unit_trxn_amt | decimal(18,6) | (none) | Manufacturer's Suggested Retail Price (MSRP) per duration unit, expressed in the transaction currency (trxn_currency_code). |
| gcr_usd_amt | decimal(18,6) | (none) | Gross Cash Receipts (GCR) for this bill line in USD; primary revenue metric. |
| gcr_trxn_amt | decimal(18,6) | (none) | Gross Cash Receipts (GCR) for this bill line in the transaction currency (trxn_currency_code). |
| trxn_currency_code | string | (none) | ISO currency code of the transaction (e.g., 'USD', 'EUR'); note: virtual orders may default to 'USD' in the prime pipeline. |
| margin_gcr_usd_amt | decimal(18,6) | (none) | Margin-adjusted Gross Cash Receipts in USD; GCR net of partner/reseller margins. Some expected differences for virtual orders. |
| receipt_price_usd_amt | decimal(18,6) | (none) | Actual receipt (charged) price in USD as recorded in the billing system. |
| receipt_price_trxn_amt | decimal(18,6) | (none) | Actual receipt (charged) price in the transaction currency. |
| list_price_usd_amt | decimal(18,6) | (none) | Standard catalog list price for the product in USD. |
| list_price_trxn_amt | decimal(18,6) | (none) | Standard catalog list price in the transaction currency. |
| sale_price_usd_amt | decimal(18,6) | (none) | Discounted sale price paid by the customer in USD; may be null for historical records predating 2013; differences vs legacy due to backfill from ecomm order item events. |
| sale_price_trxn_amt | decimal(18,6) | (none) | Discounted sale price paid by the customer in the transaction currency; may be null for historical records predating 2013. |
| injected_icann_fee_usd_amt | decimal(18,6) | (none) | ICANN (Internet Corporation for Assigned Names and Numbers) fee amount in USD, injected for domain product bill lines. |
| fee_usd_amt | decimal(18,6) | (none) | Total fee amount in USD for this bill line (may include taxes, surcharges, or other fees). |

### Technical / ETL

| Column | Type | DDL Comment | Analysis |
|--------|------|-------------|----------|
| etl_build_mst_ts | timestamp | (none) | Timestamp (MST) when this record was built/loaded by the ETL pipeline; used for data lineage and freshness monitoring. |

---

## 7. Composite Key / Grain

Based on the Confluence validation JOIN, the grain of this table is:
**`resource_id + product_family_name + bill_id + bill_line_num + prorated_bill_line_num`**

Each row represents a single prorated bill line for a specific resource within a specific billing event (order/receipt).

---

## 8. Additional Context Notes

- Table covers ~2.118 billion rows as of 2025-09-30 snapshot (26 years of billing data)
- Partitioned by `partition_bill_modified_mst_year_month` for query performance
- EDS Tier 1 data product with daily refresh SLA (7 AM MST)
- `trxn_currency_code` has known data quality note: virtual order reflows default to 'USD'
- `sale_price_usd_amt` / `sale_price_trxn_amt`: null for some pre-2013 records (historical limitation)
- `margin_gcr_usd_amt`: ~141K virtual order differences expected in comparison; 416 non-virtual differences flagged for investigation
- The table is an EDS (Enterprise Dataset) produced as a "prime" lookalike to the legacy billing fact table


**The agent's final response to the user was:**
The research output has been written. Here is a summary of the work completed:

---

## Summary

**Stage: Research for `enterprise.fact_entitlement_bill` column enrichment**

### Work Completed

1. **Read INPUT.md** — identified the target table, DDL/YAML paths, Confluence page, reference tables, and Alation configuration.

2. **Read DDL and YAML** from `repos/lake/catalog/config/prod/us-west-2/enterprise/fact-entitlement-bill/`:
   - DDL has 44 columns, 3 with existing COMMENT clauses
   - Table is a Tier-1 EDS Parquet dataset partitioned by `partition_bill_modified_mst_year_month`
   - Table description: "comprehensive view of renewals of purchase GoDaddy orders"

3. **Fetched Confluence page** (ID: 3941171221) — "fact_entitlement_bill: Validation switch to lookalike prime":
   - Validation of ~2.118B rows across 26 years of data
   - Confirmed composite key: `resource_id + product_family_name + bill_id + bill_line_num + prorated_bill_line_num`
   - Column-level match rates documented with known data quality notes (trxn_currency_code virtual-order defaults, sale_price historical nulls, margin_gcr virtual order diffs)

4. **Alation Lookup** — **Failed**: refresh token expired (`401000`), `ALATION_REFRESH_TOKEN` env var not set. Reference table lookups and Certified Data Dictionary (Folder 6) could not be retrieved.

5. **Research output appended to `research.md`** — includes:
   - Full DDL, YAML metadata, upstream lineage
   - Confluence validation findings
   - Abbreviation resolution table (GCR, MSRP, MST, ICANN, etc.) with caveat that Alation dict was unavailable
   - Per-column analysis covering inferred purpose, data type context, and relevant notes for all 44 columns + partition key