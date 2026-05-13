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

## Research Summary

**Target Table:** ecomm-mart.renewal_360  
**DDL Path:** catalog/config/prod/us-west-2/ecomm-mart/renewal-360/table.ddl  
**YAML Path:** catalog/config/prod/us-west-2/ecomm-mart/renewal-360/table.yaml  
**Alation Status:** Token expired — Alation data unavailable for this run  

---

## Table Overview (from table.yaml)

- **Description:** renewal 360
- **Storage Format:** Parquet
- **Table Type:** LATEST_SNAPSHOT
- **SLA:** Full table refresh delivered by 9:45 AM MST daily (cron 45 16 * * ? *)
- **Data Tier:** 3
- **Upstream Dependencies:**
  - analytic_feature.customer_type
  - bi_reports.ads_entitlement_bill
  - bi_reports.pricing_mart
  - finance360.dim_product_history_vw
  - dp_stage.ref_order_constant_currency
  - enterprise.dim_bill_shopper_id_xref
  - ecomm_mart.entitlement_bill_type
  - gmode.customer_type_gcr_logic_lookup
  - godaddy.gdshop_product_snap

---

## Confluence Page 1: Renewal 360 (Page ID: 3293352384)

**Key Table-Level Description:**
- Renewal 360 provides a comprehensive view of subscriptions; surfacing renewal-related fields as point-in-time data.
- Primary source: ADS_Entitlement_Bill; includes derived dimensions and measures.
- Will become the source of truth for Renewal data after migration from Product Renewal.
- Data history dating back to 2018.

**Data Attributes:**
- Presents entitlement data in "prior and renewal" format. Fields prefixed with "prior" show point-in-time data for that row, whereas fields prefixed with "renewal" show the renewal data related to the prior point-in-time instance.
- One subscription can have many rows (i.e. entitlements), each showing the point-in-time "prior" and related "renewal" data.
- Includes data for add-ons (filter with `prior_bill_primary_product_flag = FALSE` to remove add-ons).
- Does NOT include one-time products (not applicable for renewal).
- Includes both payable and not-payable data (use `payable_bill_line_flag`, `originating_payable_subscription_flag`, or `current_payable_subscription_flag` to adjust).
- Expiration dates sourced from `dim_subscription` (reads directly from source billing tables).
- Designed to keep expiration dates (aka `prior_bill_paid_through_mst_date`) constant.

**Notable Data Quirks:**
- Domain by Proxy (product_family_name = 'dbp') renewal rates incorrect prior to 09/2020.
- SSL expiration dates in Renewal 360 may differ from dim_subscription (~8% of 1yr forward SSL expirations).
- Some product_family_name values have no values for bill_paid_through_mst_date (expiration).
- product_family_name = 'unknown' accounts for ~5.5% of total population with missing expiration data.

**Full Field Reference Table from Confluence (Renewal 360 Fields page):**

| Field Name | Source | Data Type | Description |
|---|---|---|---|
| bill_country_name | Renewal 360 (Derived) | STRING | coalesce(renewal_bill_country_name, prior_bill_country_name) |
| bill_domestic_international_name | Renewal 360 (Derived) | STRING | coalesce(renewal_bill_domestic_international_name, prior_bill_domestic_international_name) |
| bill_report_region_2_name | Renewal 360 (Derived) | STRING | coalesce(renewal_bill_report_region_2_name, prior_bill_report_region_2_name) |
| bill_exclude_reason_desc | ads_entitlement_bill | STRING | Field to identify bill with any applicable exclusions. |
| current_auto_renewal_flag | ads_entitlement_bill | BOOLEAN | True = Current auto renew status for the entitlement is turned on. False = off. |
| data_through_mst_date | Renewal 360 (Derived) | DATE | The latest date that data is available for. (max(renewal_bill_modified_mst_date)) |
| domain_cancel_reason_desc | ads_entitlement_bill | STRING | Provides Domain Cancel reason, if available. Options: Domain COA (Change of Account) Out, Domain Transfer Out, Null |
| entitlement_event_code | Renewal 360 (Derived) | STRING | Event type (Renewal ts/ cancel ts/ expiration ts) for which historical auto renew status is applicable. Values: renewal_bill_modified_mst_date, subscription_cancel_mst_ts, bill_paid_through_mst_ts, current_date |
| entitlement_event_mst_ts | Renewal 360 (Derived) | DATETIME | Event timestamp (Renewal ts/ cancel ts/ expiration ts) at which historical auto renew status is applicable. |
| entitlement_id | ads_entitlement_bill | STRING | Entitlement id for a resource under subscription. |
| entitlement_cancel_mst_date | Renewal 360 (Derived) | DATE | Cancellation date for the entitlement which resulted in subscription cancellation. (subscription_cancel_mst_date for the max(prior_bill_sequence_num) for the subscription) |
| expected_customer_type_name | Renewal 360 (Derived) | STRING | Name of Customer Type resource renewal is expected to be attributed to. |
| expected_pnl_international_independent_flag | Renewal 360 (Derived) | BOOLEAN | True = Entitlement is in International Independent group. False = not. |
| expected_pnl_investor_flag | Renewal 360 (Derived) | BOOLEAN | True = Entitlement is in Investor group. False = not. |
| expected_pnl_partner_flag | Renewal 360 (Derived) | BOOLEAN | True = Entitlement is in Partner group. False = not. |
| expected_pnl_us_independent_flag | Renewal 360 (Derived) | BOOLEAN | True = Entitlement is in US Independent group. False = not. |
| expected_renewal_pf_id | Renewal 360 (Derived) | INT | PF ID for the expected renewal. |
| expected_renewal_product_name | Renewal 360 (Derived) | STRING | Product name for the expected renewal. |
| expected_renewal_product_period_name | Renewal 360 (Derived) | STRING | The period of time the product is sold for. One of: 6-month, month, onetime, quarter, year |
| expected_renewal_product_period_qty | Renewal 360 (Derived) | INT | The count of the number of periods of Expected Renewal Product Period Name. |
| expected_renewal_product_pnl_category_name | Renewal 360 (Derived) | STRING | 2nd level of the Finance approved P&L hierarchy of the expected renewal product. |
| expected_renewal_product_pnl_group_name | Renewal 360 (Derived) | STRING | 1st level of the Finance approved P&L hierarchy of the expected renewal product. |
| expected_renewal_product_pnl_line_name | Renewal 360 (Derived) | STRING | 3rd level of the Finance approved P&L hierarchy of the expected renewal product. |
| expected_renewal_product_pnl_subline_name | Renewal 360 (Derived) | STRING | 4th level of the Finance approved P&L hierarchy of the expected renewal product. |
| expected_renewal_product_pnl_version_name | Renewal 360 (Derived) | STRING | Finance approved P&L hierarchy version — flexible classification of the expected renewal product. |
| expiry_qty | Renewal 360 (Derived) | INT | The count of the number of resources expiring. (always 1 per row) |
| first_expiry_sequence_flag | Renewal 360 (Derived) | BOOLEAN | True = Entitlement is on 1st expiry sequence. False = Entitlement is on 2nd-nth expiry sequence. (case when bill_sequence_number=1 then True else False end) |
| historical_auto_renewal_flag | autorenew feature table | BOOLEAN | Auto renew status for the entitlement as of entitlement_event_mst_ts. |
| on_time_renewal_flag | Renewal 360 (Derived) | BOOLEAN | Flag to identify if the renewal was on time or not. |
| outcome_code | Renewal 360 (Derived) | STRING | Code to identify the outcome of the entitlement. Values: 'Cancel' (renewal_bill_modified_mst_date is null and subscription_cancel_mst_date is not null), 'Renewal' (renewal_bill_modified_mst_date is not null) |
| outcome_mst_date | Renewal 360 (Derived) | DATE | Date on which the entitlement was cancelled or renewed. |
| point_of_purchase_name | Renewal 360 (Derived) | STRING | Point of purchase on the applicable bill (renewal/prior). (coalesce(renewal_bill_point_of_purchase_name, prior_bill_point_of_purchase_name)) |
| potential_receipt_price_amt | Renewal 360 (Derived) | DECIMAL | The potential receipt price amount if the resource is renewed for the expected term length. |
| prior_bill_country_code | Ads_entitlement_bill | STRING | Country code of the prior bill. Can be used to join to Dim geography for more attributes. |
| prior_bill_country_name | Ads_entitlement_bill | STRING | Country name of the prior bill. |
| prior_bill_crm_portfolio_type_name | Ads_entitlement_bill | STRING | CRM portfolio type name on the prior bill. |
| prior_bill_customer_type_name | Ads_entitlement_bill | STRING | Customer type name on the prior bill. |
| prior_bill_domain_bulk_pricing_flag | Ads_entitlement_bill | BOOLEAN | True = Domain was considered bulk purchased (6+ domains) in prior bill. False = not. |
| prior_bill_domestic_international_name | Ads_entitlement_bill | STRING | Domestic International Name of prior bill. |
| prior_bill_fee_usd_amt | Ads_entitlement_bill | DECIMAL | The ICANN fee for the prior bill row. |
| prior_bill_free_receipt_price_flag (prior_free_receipt_price_flag) | Renewal 360 (Derived) | BOOLEAN | True = Product was free on prior bill. False = not. |
| prior_bill_fraud_flag | Ads_entitlement_bill | BOOLEAN | True = Prior bill was marked as fraud. False = not. |
| prior_bill_gcr_usd_amt | Ads_entitlement_bill | DECIMAL | Gross Cash Receipts (GCR) USD amount on the prior bill. |
| prior_bill_gcr_trxn_amt | Ads_entitlement_bill | DECIMAL | Prior bill Gross Cash Receipts (GCR) represented in the native (transaction) currency. |
| prior_bill_gcr_constant_currency_amt | ref_order_constant_currency | DECIMAL | GCR tied to the prior bill using a set (constant) foreign exchange rate to convert from the transaction currency to USD, for better trending by eliminating foreign exchange fluctuations. |
| prior_bill_id | ads_entitlement_bill | STRING | Bill ID of prior bill. |
| prior_bill_item_tracking_code | Ads_entitlement_bill | STRING | Item tracking code for the prior bill. |
| prior_bill_line_num | ads_entitlement_bill | INT | Row ID of entitlement in prior bill. |
| prior_bill_list_price_usd_amt | Renewal 360 (Derived) | DECIMAL | The list price of entitlement on prior bill in USD. (MAX of receipt_price_usd_amt and msrp_duration_unit_usd_amt) |
| prior_bill_list_price_trxn_amt | Ads_entitlement_bill | DECIMAL | Prior bill list price represented in the native (transaction) currency. |
| prior_bill_modified_mst_date | Ads_entitlement_bill | DATE | Prior bill order date (MST). |
| prior_bill_modified_mst_ts | Ads_entitlement_bill | DATETIME | Prior bill order timestamp (MST). |
| prior_bill_pf_id | ads_entitlement_bill | INT | Product family (PF) ID of entitlement on prior bill. |
| prior_bill_pnl_international_independent_flag | Ads_entitlement_bill | BOOLEAN | True = Entitlement is in International Independent P&L group. False = not. |
| prior_bill_pnl_investor_flag | Ads_entitlement_bill | BOOLEAN | True = Entitlement is in Investor P&L group. False = not. |
| prior_bill_pnl_partner_flag | Ads_entitlement_bill | BOOLEAN | True = Entitlement is in Partner P&L group. False = not. |
| prior_bill_pnl_us_independent_flag | Ads_entitlement_bill | BOOLEAN | True = Entitlement is in US Independent P&L group. False = not. |
| prior_bill_pnl_pillar_name | Ads_entitlement_bill | STRING | [Existing DDL comment: Prior bill P&L pillar classification for major business segments. Examples: Core, Applications and Commerce, Domains.] |
| prior_bill_point_of_purchase_name | Ads_entitlement_bill | STRING | Point of purchase name on prior bill. |
| prior_bill_price_group_id | Ads_entitlement_bill | INT | [Existing DDL comment: Prior bill price group id, integer range from 0 to 34] |
| prior_bill_price_group_name | Ads_entitlement_bill | STRING | [Existing DDL comment: Prior bill price group name with value such as Default, uk-United Kingdom, ar-Argentina] |
| prior_bill_private_label_id | Ads_entitlement_bill | INT | Specific private label (GoDaddy/Reseller) associated with entitlement. |
| prior_bill_product_month_qty | Ads_entitlement_bill | INT | Quantity in months of the entitlement on prior bill. |
| prior_bill_product_name | Ads_entitlement_bill | STRING | Product name associated with the purchased PF ID on the prior bill row. |
| prior_bill_product_period_name | Ads_entitlement_bill | STRING | The billing period of the product on prior bill. One of: 6-month, month, onetime, quarter, year |
| prior_bill_product_period_qty | Ads_entitlement_bill | INT | The count of the number of periods for Prior Bill Product Period Name. |
| prior_bill_product_pnl_new_renewal_name | Ads_entitlement_bill | STRING | P&L new/renewal classification of the product on prior bill. Indicates if the prior bill was a New Purchase or Renewal. |
| prior_bill_product_pnl_category_name | Ads_entitlement_bill | STRING | 2nd level of the Finance approved P&L hierarchy for product on prior bill. |
| prior_bill_product_pnl_group_name | Ads_entitlement_bill | STRING | 1st level of the Finance approved P&L hierarchy for product on prior bill. |
| prior_bill_product_pnl_line_name | Ads_entitlement_bill | STRING | 3rd level of the Finance approved P&L hierarchy for product on prior bill. |
| prior_bill_product_pnl_subline_name | Ads_entitlement_bill | STRING | 4th level of the Finance approved P&L hierarchy for product on prior bill. |
| prior_bill_product_pnl_version_name | Ads_entitlement_bill | STRING | Finance approved P&L hierarchy version for product on prior bill. |
| prior_bill_paid_through_mst_date | Ads_entitlement_bill | DATE | Expiration date for the entitlement. (= prior_bill_paid_through_mst_date in the model, kept constant) |
| prior_bill_paid_through_mst_month_start_date | Renewal 360 (Derived) | DATE | Start of expiration month for the entitlement. (date_trunc('month', bill_paid_through_mst_date)) |
| prior_bill_paid_through_mst_ts | Ads_entitlement_bill | DATETIME | Expiration timestamp for the entitlement. |
| prior_bill_purchase_path_name | Ads_entitlement_bill | STRING | Purchase path name on the prior bill. |
| prior_bill_receipt_price_usd_amt | Ads_entitlement_bill | DECIMAL | Receipt price USD amount on the prior bill. |
| prior_bill_receipt_price_trxn_amt | Ads_entitlement_bill | DECIMAL | Receipt price transaction amount on the prior bill (in native currency). |
| prior_bill_refund_flag | Ads_entitlement_bill | BOOLEAN | [Existing DDL comment: represents whether the prior bill related to renewal was refunded.] |
| prior_bill_region_2_name | Ads_entitlement_bill | STRING | Report region 2 name of prior bill. |
| prior_bill_reseller_name | Ads_entitlement_bill | STRING | Reseller name on the prior bill. |
| prior_bill_reseller_type_name | Ads_entitlement_bill | STRING | Type of reseller (e.g., GoDaddy, Pro, Super Reseller) tied to the entitlement on the prior bill. |
| prior_bill_sequence_number | Ads_entitlement_bill | INT | Bill sequence number of prior bill. (order sequence, starting at 1 for New Purchase) |
| prior_bill_shopper_id | Ads_entitlement_bill | STRING | Shopper ID on the prior bill. |
| prior_bill_subscription_status_name | Ads_entitlement_bill | STRING | [Existing DDL comment: subscription status at the time of prior_bill_modified_mst_ts] |
| prior_bill_trxn_currency_code | Ads_entitlement_bill | STRING | Transaction currency code of prior bill. |
| prior_bill_variant_price_type_id | Ads_entitlement_bill | INT | [Existing DDL comment: Price bill price type id with value as 0, 8, 16, 32, 64, 128 or 256] |
| prior_bill_variant_price_type_name | Ads_entitlement_bill | STRING | Variant price type name on the prior bill — a lever the pricing team uses to change prices. |
| prior_entitlement_bill_type | Ads_entitlement_bill | STRING | Entitlement bill type on the prior bill (e.g., Freemium, Free Term, Free Trial, Free Plan Change). |
| product_family_name | Ads_entitlement_bill | STRING | Product family name (namespace) for the subscription. |
| product_period_name | Renewal 360 (Derived) | STRING | The billing period for the product based on the most recent renewal. One of: 6-month, month, onetime, quarter, year. (coalesce(renewal_bill_product_period_name, expected_renewal_product_period_name, prior_bill_product_period_name)) |
| product_period_qty | Renewal 360 (Derived) | INT | The count of periods of Product Period Name. (coalesce(renewal_bill_product_period_qty, expected_renewal_product_period_qty, prior_bill_product_period_qty)) |
| product_pnl_category_name | Renewal 360 (Derived) | STRING | 2nd level of the Finance approved P&L hierarchy. (coalesce(renewal, expected, prior)) |
| product_pnl_group_name | Renewal 360 (Derived) | STRING | 1st level of the Finance approved P&L hierarchy. (coalesce(renewal, expected, prior)) |
| product_pnl_line_name | Renewal 360 (Derived) | STRING | 3rd level of the Finance approved P&L hierarchy. (coalesce(renewal, expected, prior)) |
| product_pnl_subline_name | Renewal 360 (Derived) | STRING | 4th level of the Finance approved P&L hierarchy. (coalesce(renewal, expected, prior)) |
| product_pnl_version_name | Renewal 360 (Derived) | STRING | Finance approved P&L version hierarchy — more flexible classification. (coalesce(renewal, expected, prior)) |
| product_type_desc | Ads_entitlement_bill | STRING | Product type description. |
| product_type_id | Ads_entitlement_bill | INT | Product type identifier. |
| relative_bill_paid_through_mst_date | dim_relative_calendar | DATE | Relative expiration date for entitlement, used for rolling year analysis. |
| relative_bill_paid_through_date_period_name | dim_relative_calendar | STRING | Expiration date expressed as Current Year, Future Year (n years), or Prior Year (n years). |
| relative_bill_paid_through_mst_week_start_date | dim_relative_calendar | DATE | Start date of the relative expiration week. |
| relative_bill_paid_through_week_period_name | dim_relative_calendar | STRING | Relative expiration week period designation. |
| relative_bill_paid_through_mst_month_start_date | dim_relative_calendar | DATE | Start date of the relative expiration month. |
| relative_bill_paid_through_month_period_name | dim_relative_calendar | STRING | Relative expiration month period designation. |
| relative_renewal_bill_modified_mst_date | dim_relative_calendar | DATE | Relative renewal date for the entitlement. |
| relative_renewal_bill_modified_date_period_name | dim_relative_calendar | STRING | Renewal date expressed as Current Year, Future Year (n years), or Prior Year (n years). |
| relative_renewal_bill_modified_mst_week_start_date | dim_relative_calendar | DATE | Start date of the relative renewal week. |
| relative_renewal_bill_modified_week_period_name | dim_relative_calendar | STRING | Relative renewal week period designation. |
| relative_renewal_bill_modified_mst_month_start_date | dim_relative_calendar | DATE | Start date of the relative renewal month. |
| relative_renewal_bill_modified_month_period_name | dim_relative_calendar | STRING | Relative renewal month period designation. |
| renewal_bill_country_code | Ads_entitlement_bill | STRING | Country code for the renewal bill. |
| renewal_bill_country_name | Ads_entitlement_bill | STRING | The bill country the entitlement was renewed from. |
| renewal_bill_crm_portfolio_type_name | Ads_entitlement_bill | STRING | CRM portfolio type name on the renewal bill. |
| renewal_bill_customer_type_name | Ads_entitlement_bill | STRING | Customer type on the renewal bill. |
| renewal_bill_domain_bulk_pricing_flag | Ads_entitlement_bill | BOOLEAN | True = Domain was considered bulk purchased (6+ domains) in renewal bill. False = not. |
| renewal_bill_domestic_international_name | Ads_entitlement_bill | STRING | Domestic/international classification of the renewal bill. |
| renewal_bill_exclude_reason_desc | Ads_entitlement_bill | STRING | Field to identify renewal bill with any applicable exclusions. |
| renewal_bill_fee_usd_amt | Ads_entitlement_bill | DECIMAL | The ICANN fee for the renewal bill row. |
| renewal_bill_fraud_flag | Ads_entitlement_bill | BOOLEAN | True = Renewal bill was marked as fraud. False = not. |
| renewal_bill_gcr_usd_amt | Ads_entitlement_bill | DECIMAL | Gross Cash Receipts (GCR) USD amount on the renewal bill. |
| renewal_bill_gcr_trxn_amt | Ads_entitlement_bill | DECIMAL | Renewal bill Gross Cash Receipts (GCR) in the native (transaction) currency. |
| renewal_bill_gcr_constant_currency_amt | ref_order_constant_currency | DECIMAL | GCR tied to the renewal bill using a set (constant) foreign exchange rate to convert from transaction currency to USD, for better trending by eliminating foreign exchange fluctuations. |
| renewal_bill_id | Ads_entitlement_bill | STRING | Bill ID of the entitlement's renewal. |
| renewal_bill_item_tracking_code | Ads_entitlement_bill | STRING | Item tracking code for the renewal bill. |
| renewal_bill_line_num | Ads_entitlement_bill | INT | Row ID of entitlement in renewal bill. |
| renewal_bill_list_price_usd_amt | Renewal 360 (Derived) | DECIMAL | List price in USD on the renewal bill for the entitlement. (MAX of receipt_price_usd_amt and msrp_duration_unit_usd_amt) |
| renewal_bill_list_price_trxn_amt | Ads_entitlement_bill | DECIMAL | Renewal bill list price represented in the native (transaction) currency. |
| renewal_bill_modified_mst_date | Ads_entitlement_bill | DATE | Renewal bill date for the entitlement (MST). |
| renewal_bill_modified_mst_ts | Ads_entitlement_bill | DATETIME | Renewal bill timestamp for the entitlement (MST). |
| renewal_bill_pf_id | Ads_entitlement_bill | INT | Product family (PF) ID tied to the entitlement's renewal bill. |
| renewal_bill_pnl_international_independent_flag | Ads_entitlement_bill | BOOLEAN | True = Entitlement is in International Independent P&L group. False = not. |
| renewal_bill_pnl_investor_flag | Ads_entitlement_bill | BOOLEAN | True = Entitlement is in Investor P&L group. False = not. |
| renewal_bill_pnl_partner_flag | Ads_entitlement_bill | BOOLEAN | True = Entitlement is in Partner P&L group. False = not. |
| renewal_bill_pnl_us_independent_flag | Ads_entitlement_bill | BOOLEAN | True = Entitlement is in US Independent P&L group. False = not. |
| renewal_bill_pnl_pillar_name | Ads_entitlement_bill | STRING | Renewal bill P&L pillar classification for major business segments (e.g., Core, Applications and Commerce, Domains). |
| renewal_bill_point_of_purchase_name | Ads_entitlement_bill | STRING | Point of purchase on the renewal bill. |
| renewal_bill_price_group_id | Ads_entitlement_bill | INT | [Existing DDL comment: Renewal bill price group id, integer range from 0 to 34] |
| renewal_bill_price_group_name | Ads_entitlement_bill | STRING | [Existing DDL comment: Renewal bill price group name with value such as Default, uk-United Kingdom, ar-Argentina] |
| renewal_bill_product_month_qty | Ads_entitlement_bill | INT | Number of months the product was renewed for. |
| renewal_bill_product_name | Ads_entitlement_bill | STRING | Product name associated with the purchased PF ID on the renewal bill row. |
| renewal_bill_product_period_name | Ads_entitlement_bill | STRING | The billing period the product is renewed for. One of: 6-month, month, onetime, quarter, year |
| renewal_bill_product_period_qty | Ads_entitlement_bill | INT | The count of periods of Renewal Bill Product Period Name. |
| renewal_bill_product_pnl_new_renewal_name | Ads_entitlement_bill | STRING | P&L new/renewal classification of the product on renewal bill. |
| renewal_bill_product_pnl_category_name | Ads_entitlement_bill | STRING | 2nd level of the Finance approved P&L hierarchy for renewal. |
| renewal_bill_product_pnl_group_name | Ads_entitlement_bill | STRING | 1st level of the Finance approved P&L hierarchy for renewal. |
| renewal_bill_product_pnl_line_name | Ads_entitlement_bill | STRING | 3rd level of the Finance approved P&L hierarchy for renewal. |
| renewal_bill_product_pnl_subline_name | Ads_entitlement_bill | STRING | 4th level of the Finance approved P&L hierarchy for renewal. |
| renewal_bill_product_pnl_version_name | Ads_entitlement_bill | STRING | 5th level (version) of the Finance approved P&L hierarchy for renewal. |
| renewal_bill_purchase_path_name | Ads_entitlement_bill | STRING | Purchase path on the renewal bill. |
| renewal_bill_receipt_price_usd_amt | Ads_entitlement_bill | DECIMAL | Receipt price USD amount of the entitlement's renewal. |
| renewal_bill_receipt_price_trxn_amt | Ads_entitlement_bill | DECIMAL | Receipt price transaction amount on the renewal bill (in native currency). |
| renewal_bill_refund_flag | Ads_entitlement_bill | BOOLEAN | [Existing DDL comment: represents whether the renewal bill associated with the renewal was refunded] |
| renewal_bill_report_region_2_name | Ads_entitlement_bill | STRING | Report region 2 name of the renewal bill. |
| renewal_bill_reseller_name | Ads_entitlement_bill | STRING | Reseller name on the renewal bill. |
| renewal_bill_reseller_type_name | Ads_entitlement_bill | STRING | Type of reseller (e.g., GoDaddy, Pro, Super Reseller) tied to the entitlement on the renewal bill. |
| renewal_bill_shopper_id | Ads_entitlement_bill | STRING | Shopper ID on the renewal bill. May differ from prior_bill_shopper_id due to shopper merges. |
| renewal_bill_subscription_status_name | Ads_entitlement_bill | STRING | [Existing DDL comment: subscription status at renewal_bill_modified_mst_ts] |
| renewal_bill_trxn_currency_code | Ads_entitlement_bill | STRING | Native (transaction) currency code on the renewal bill. |
| renewal_bill_variant_price_type_id | Ads_entitlement_bill | INT | [Existing DDL comment: Renewal bill price type id with value as 0, 8, 16, 32, 64, 128 or 256] |
| renewal_bill_variant_price_type_name | Ads_entitlement_bill | STRING | Variant price type name on the renewal bill — a lever the pricing team uses to change prices. |
| renewal_entitlement_bill_type | Ads_entitlement_bill | STRING | Entitlement bill type on the renewal order. |
| renewal_qty | Renewal 360 (Derived) | INT | Number of entitlements renewed. (1 if renewal_bill_modified_mst_date is not null, else 0) |
| renewal_timing_desc | Renewal 360 (Derived) | STRING | Type of renewal timing. Values: Cancelled, Delayed, Early Cancel, Full Term, No Expiration Data, Not Yet Expired, Past Expiry - In Grace Period, Pull Forward |
| resource_id | ads_entitlement_bill | INT | Resource ID for the subscription entitlement. |
| source_table_name | ads_entitlement_bill | STRING | Source table name. |
| subscription_cancel_by_name | ads_entitlement_bill | STRING | Name of the entity that cancelled the subscription. |
| subscription_cancel_mst_date | ads_entitlement_bill | DATE | Cancellation date for the subscription. Applicable to all subscription order sequences. |
| subscription_cancel_mst_ts | ads_entitlement_bill | DATETIME | Cancellation timestamp for the subscription. Applicable to all subscription order sequences. |
| subscription_exclude_reason_desc | ads_entitlement_bill | STRING | Field to identify subscriptions with any applicable exclusions. |
| subscription_id | ads_entitlement_bill | STRING | Subscription ID. |
| subscription_migration_type | ads_entitlement_bill | STRING | Migration type for the subscription (e.g., Media Temple, Reg123). |
| subscription_migration_mst_ts | ads_entitlement_bill | DATETIME | Migration timestamp for the subscription based on subscription_migration_type. |
| transaction_currency_code | Renewal 360 (Derived) | STRING | Currency code on the applicable bill. (coalesce(renewal_bill_trxn_currency_code, prior_bill_trxn_currency_code)) |

---

## Confluence Page 2: Renewal 360 Gap Resolution - Order Sequence 1 (Page ID: 3435340877)

**Key Findings:**
- Renewal 360 starts with new purchases at order sequence 1, with subsequent orders as renewals.
- Some renewal orders start with order sequence 1 (instead of continuing from a prior new purchase), creating a gap in renewal metrics vs ADS_Bill_Line.
- Known causes of gap:
  1. **COA/COO (Change of Account/Ownership):** Domain transfer creates a new resource_id and resets order sequence to 1. (~35% of gap based on 2023 GCR)
  2. **Domains from other registrars** moved to GoDaddy.
  3. **Add-ons:** Added at a later stage with order sequence 1 as a renewal.
- Gap amounts by year: 2020: 2.92%, 2021: 2.45%, 2022: 1.98%, 2023: 1.58%

**Gap Resolution Logic:**
- **COO resources:** Mapped new resource ID back to original resource (coa_resource_id, coa_flag). Subscription sequence continues after COO.
- **Non-COO gap:** Extra records appended with null prior order information, starting at order_sequence=0.
- Fields affected by COO logic: prior_bill_sequence_num continues after life of original resource; subscription_cancel_mst_date, subscription_cancel_mst_ts, subscription_cancel_by_name, domain_cancel_reason_desc may reflect new COO resource values.

**Implications for `original_prior_bill_sequence_number` and `prior_bill_sequence_number`:**
- `original_prior_bill_sequence_number`: Original sequence number before COO re-mapping.
- `prior_bill_sequence_number`: Adjusted sequence number accounting for COO continuity.

---

## Alation Status

Alation API token retrieval failed (refresh token expired/revoked). Reference table and Certified Data Dictionary lookups were not possible for this run.

---

## Certified Data Dictionary Mappings

Note: Alation was unavailable. The following mappings are derived from Confluence documentation and DDL context:

| Abbreviation | Official Name | Source |
|---|---|---|
| GCR | Gross Cash Receipts | Confluence Renewal 360 page (used consistently for dollar-value financial metric) |
| PNL / P&L | Profit and Loss | DDL comments and Confluence |
| PF ID / pf_id | Product Family ID | Confluence field descriptions |
| MST | Mountain Standard Time | Context (all date/timestamp fields) |
| CRM | Customer Relationship Management | Context |
| COA | Change of Account | Confluence Gap Resolution page |
| COO | Change of Ownership | Confluence Gap Resolution page |
| ICANN | Internet Corporation for Assigned Names and Numbers | Confluence (fee description) |
| ADS | Analytic Dataset | YAML lineage description |
| EDS | Enterprise Dataset | YAML lineage description |
| SCD2 | Slowly Changing Dimension Type 2 | YAML lineage description |
| ETL | Extract, Transform, Load | Context (etl_build_mst_ts) |

---

## Per-Column Enrichment Notes

### Columns with Existing DDL Comments (to preserve/enhance)
- `prior_bill_refund_flag`: "represents whether the prior bill related to renewal was refunded."
- `prior_payable_bill_line_flag`: No DDL comment — should add.
- `current_subscription_status_name`: "subscription status at the time data was loaded in the table"
- `prior_bill_subscription_status_name`: "subscription status at the time of prior_bill_modified_mst_ts"
- `prior_bill_price_group_id`: "Prior bill price group id, integer range from 0 to 34"
- `prior_bill_price_group_name`: "Prior bill price group name with value such as Default, uk-United Kingdom, ar-Argentina"
- `prior_bill_variant_price_type_id`: "Price bill price type id with value as 0, 8, 16, 32, 64, 128 or 256"
- `prior_bill_pnl_pillar_name`: "Prior bill P&L pillar classification for major business segments. Examples: Core, Applications and Commerce, Domains."
- `expected_receipt_price_usd_amt`: "Expected receipt price amount in USD"
- `renewal_bill_price_group_id`: "Renewal bill price group id, integer range from 0 to 34"
- `renewal_bill_price_group_name`: "Renewal bill price group name with value such as Default, uk-United Kingdom, ar-Argentina"
- `renewal_bill_variant_price_type_id`: "Renewal bill price type id with value as 0, 8, 16, 32, 64, 128 or 256"
- `renewal_bill_refund_flag`: "represents whether the renewal bill associated with the renewal was refunded"
- `federation_partner_id`: "represents the brand id from which the shopper associated with prior bill originated"
- `federation_partner_name`: "represents the brand name from which the shopper associated with prior bill originated eg: Google, TsoHost"

### Columns Without DDL Comments (need enrichment from Confluence/context)

**Identity/Key Columns:**
- `entitlement_id` → Entitlement id for a resource under subscription.
- `subscription_id` → Subscription ID.
- `resource_id` → Resource ID for the subscription entitlement.

**Prior Bill — Dates:**
- `prior_bill_modified_mst_date` → Prior bill order date (MST).
- `prior_bill_modified_mst_ts` → Prior bill order timestamp (MST).
- `prior_bill_paid_through_mst_date` → Expiration date for the entitlement. Kept constant in Renewal 360 (sourced from dim_subscription).
- `prior_bill_paid_through_mst_month_start_date` → First day of the expiration month for the entitlement.
- `prior_bill_paid_through_mst_ts` → Expiration timestamp for the entitlement.
- `original_bill_paid_through_mst_date` → Original expiration date before any adjustments. (pre-COO)
- `prior_bill_billing_due_mst_date` → Billing due date for the prior bill.
- `prior_bill_billing_due_mst_ts` → Billing due timestamp for the prior bill.
- `original_bill_billing_due_mst_date` → Original billing due date before adjustments.

**Prior Bill — Sequence:**
- `original_prior_bill_sequence_number` → Original prior bill sequence number before COO re-mapping.
- `prior_bill_sequence_number` → Bill sequence number of the prior bill, adjusted for COO continuity.

**Prior Bill — Flags:**
- `prior_payable_bill_line_flag` → Indicates whether the prior bill line is a payable bill line.
- `originating_payable_subscription_flag` → Indicates whether the originating subscription was a payable subscription.
- `current_payable_subscription_flag` → Indicates whether the current subscription is a payable subscription.
- `current_auto_renewal_flag` → True = Current auto-renew status for the entitlement is on. False = off.
- `hard_bundle_flag` → Indicates whether the entitlement is part of a hard bundle.
- `historical_auto_renewal_flag` → Auto-renew status for the entitlement as of entitlement_event_mst_ts.
- `prior_bill_domain_bulk_pricing_flag` → True = Domain was bulk purchased (6+ domains) on prior bill. False = not.
- `prior_bill_fraud_flag` → True = Prior bill was marked as fraud. False = not.
- `prior_free_receipt_price_flag` → True = Product was free on prior bill. False = not.
- `prior_bill_pnl_international_independent_flag` → True = Prior bill entitlement is in International Independent P&L group.
- `prior_bill_pnl_investor_flag` → True = Prior bill entitlement is in Investor P&L group.
- `prior_bill_pnl_partner_flag` → True = Prior bill entitlement is in Partner P&L group.
- `prior_bill_pnl_us_independent_flag` → True = Prior bill entitlement is in US Independent P&L group.
- `prior_bill_pnl_commerce_flag` → True = Prior bill entitlement is in Commerce P&L group.
- `prior_bill_primary_product_flag` → True = Prior bill represents the primary product (not an add-on).

**Prior Bill — Product/Hierarchy:**
- `product_family_name` → Product family name (namespace) for the subscription (e.g., domain, hosting).
- `product_type_id` → Product type identifier.
- `product_type_desc` → Product type description.
- `prior_bill_private_label_id` → Private label ID (GoDaddy/Reseller) associated with entitlement.
- `prior_bill_reseller_name` → Reseller name on the prior bill.
- `prior_bill_reseller_type_name` → Type of reseller (e.g., GoDaddy, Pro, Super Reseller) on the prior bill.
- `prior_bill_purchase_path_name` → Purchase path name on the prior bill.
- `prior_bill_pf_id` → Product family (PF) ID of entitlement on prior bill.
- `prior_bill_product_name` → Product name for the purchased PF ID on the prior bill row.
- `prior_bill_product_pnl_new_renewal_name` → P&L new/renewal classification for prior bill product (e.g., New Purchase, Renewal).
- `prior_bill_product_pnl_category_name` → 2nd level of Finance approved P&L hierarchy for prior bill product.
- `prior_bill_product_pnl_group_name` → 1st level of Finance approved P&L hierarchy for prior bill product.
- `prior_bill_product_pnl_line_name` → 3rd level of Finance approved P&L hierarchy for prior bill product.
- `prior_bill_product_pnl_subline_name` → 4th level of Finance approved P&L hierarchy for prior bill product.
- `prior_bill_product_pnl_version_name` → P&L version classification for prior bill product.
- `prior_bill_product_period_name` → Billing period of the product on prior bill (6-month, month, onetime, quarter, year).
- `prior_bill_product_period_qty` → Number of billing periods for Prior Bill Product Period Name.
- `prior_bill_product_month_qty` → Product quantity in months on the prior bill.
- `prior_bill_unit_qty` → Unit quantity on the prior bill.
- `prior_bill_duration_qty` → Duration quantity on the prior bill.

**Prior Bill — Finance P&L:**
- `finance_prior_bill_pnl_group_name` → Finance-specific P&L group for the prior bill.
- `finance_prior_bill_pnl_category_name` → Finance-specific P&L category for the prior bill.
- `finance_prior_bill_pnl_line_name` → Finance-specific P&L line for the prior bill.
- `finance_prior_bill_pnl_subline_name` → Finance-specific P&L subline for the prior bill.
- `finance_prior_bill_investor_relation_class_name` → Finance investor relations class for the prior bill.
- `finance_prior_bill_investor_relation_subclass_name` → Finance investor relations subclass for the prior bill.
- `finance_prior_bill_investor_relation_segment_name` → Finance investor relations segment for the prior bill.
- `finance_prior_bill_subscription_transaction_name` → Finance subscription transaction classification for the prior bill.

**Prior Bill — Geography:**
- `prior_bill_country_code` → Country code of the prior bill. Joinable to dim_geography.
- `prior_bill_country_name` → Country name of the prior bill.
- `prior_bill_region_2_name` → Report region 2 name of the prior bill.
- `prior_bill_domestic_international_name` → Domestic/international classification of the prior bill.

**Prior Bill — Financial Amounts:**
- `prior_bill_fee_usd_amt` → ICANN fee for the prior bill row in USD.
- `prior_bill_gcr_usd_amt` → Gross Cash Receipts (GCR) USD amount on the prior bill.
- `prior_bill_gcr_trxn_amt` → Gross Cash Receipts (GCR) on the prior bill in the native (transaction) currency.
- `prior_bill_gcr_constant_currency_amt` → GCR on the prior bill converted using a constant FX rate to USD for consistent trend analysis.
- `prior_bill_receipt_price_usd_amt` → Receipt price USD amount on the prior bill.
- `prior_bill_receipt_price_trxn_amt` → Receipt price on the prior bill in native (transaction) currency.
- `prior_bill_list_price_usd_amt` → List price of entitlement on prior bill in USD.
- `prior_bill_list_price_trxn_amt` → List price on prior bill in native (transaction) currency.

**Prior Bill — Other:**
- `prior_bill_crm_portfolio_type_name` → CRM portfolio type name on the prior bill.
- `prior_bill_item_tracking_code` → Item tracking code for the prior bill.
- `prior_bill_point_of_purchase_name` → Point of purchase name on the prior bill.
- `prior_bill_trxn_currency_code` → Transaction currency code of the prior bill.
- `prior_bill_variant_price_type_name` → Variant price type name on prior bill — pricing lever for price adjustments.
- `prior_bill_intent` → Purchase intent flag/category for the prior bill.
- `prior_bill_related_subscription` → Related subscription identifier for the prior bill.
- `prior_bill_customer_type_name` → Customer type name on the prior bill.
- `prior_bill_subscription_status_name` (existing comment) → Subscription status at the time of prior_bill_modified_mst_ts.
- `current_subscription_status_name` (existing comment) → Subscription status at the time data was loaded in the table.
- `prior_entitlement_bill_type` → Entitlement bill type on prior bill (e.g., Freemium, Free Term, Free Trial).

**Subscription-Level:**
- `subscription_cancel_mst_date` → Cancellation date for the subscription, applicable to all order sequences.
- `subscription_cancel_mst_ts` → Cancellation timestamp for the subscription.
- `subscription_cancel_by_name` → Name of the entity that cancelled the subscription.
- `subscription_exclude_reason_desc` → Field to identify subscriptions with any applicable exclusions.
- `bill_exclude_reason_desc` → Field to identify bills with any applicable exclusions.
- `subscription_migration_type` → Migration type (e.g., Media Temple, Reg123).
- `subscription_migration_mst_ts` → Migration timestamp based on subscription_migration_type.
- `domain_cancel_reason_desc` → Domain cancellation reason (e.g., COA Out, Transfer Out).

**Expiry/Renewal Quantities:**
- `original_expiry_qty` → Original expiry quantity before adjustments.
- `expiry_qty` → Count of resources expiring (1 per row).
- `original_renewal_qty` → Original renewal quantity before adjustments.
- `renewal_qty` → Number of entitlements renewed (1 if renewal_bill_modified_mst_date is not null, else 0).

**Renewal Bill — Dates:**
- `renewal_bill_modified_mst_date` → Renewal bill date for the entitlement (MST).
- `renewal_bill_modified_mst_ts` → Renewal bill timestamp for the entitlement (MST).

**Renewal Bill — Flags:**
- `renewal_payable_bill_line_flag` → Indicates whether the renewal bill line is a payable bill line.
- `renewal_bill_domain_bulk_pricing_flag` → True = Domain was bulk purchased (6+ domains) on renewal bill.
- `renewal_bill_fraud_flag` → True = Renewal bill was marked as fraud. False = not.
- `renewal_bill_pnl_international_independent_flag` → True = Renewal bill entitlement is in International Independent P&L group.
- `renewal_bill_pnl_investor_flag` → True = Renewal bill entitlement is in Investor P&L group.
- `renewal_bill_pnl_partner_flag` → True = Renewal bill entitlement is in Partner P&L group.
- `renewal_bill_pnl_us_independent_flag` → True = Renewal bill entitlement is in US Independent P&L group.
- `renewal_bill_pnl_commerce_flag` → True = Renewal bill entitlement is in Commerce P&L group.
- `renewal_bill_primary_product_flag` → True = Renewal bill represents the primary product (not an add-on).

**Renewal Bill — Finance P&L:**
- `finance_renewal_bill_pnl_group_name` → Finance-specific P&L group for the renewal bill.
- `finance_renewal_bill_pnl_category_name` → Finance-specific P&L category for the renewal bill.
- `finance_renewal_bill_pnl_line_name` → Finance-specific P&L line for the renewal bill.
- `finance_renewal_bill_pnl_subline_name` → Finance-specific P&L subline for the renewal bill.
- `finance_renewal_bill_investor_relation_class_name` → Finance investor relations class for the renewal bill.
- `finance_renewal_bill_investor_relation_subclass_name` → Finance investor relations subclass for the renewal bill.
- `finance_renewal_bill_investor_relation_segment_name` → Finance investor relations segment for the renewal bill.
- `finance_renewal_bill_subscription_transaction_name` → Finance subscription transaction classification for the renewal bill.

**Expected Renewal:**
- `expected_receipt_price_usd_amt` (existing comment) → Expected receipt price amount in USD.
- `expected_renewal_pf_id` → PF ID for the expected renewal product.
- `expected_renewal_product_name` → Product name for the expected renewal.
- `expected_renewal_product_period_name` → Billing period for expected renewal (6-month, month, onetime, quarter, year).
- `expected_renewal_product_period_qty` → Number of billing periods for Expected Renewal Product Period Name.
- `expected_renewal_product_pnl_category_name` → 2nd level Finance approved P&L hierarchy for expected renewal.
- `expected_renewal_product_pnl_group_name` → 1st level Finance approved P&L hierarchy for expected renewal.
- `expected_renewal_product_pnl_line_name` → 3rd level Finance approved P&L hierarchy for expected renewal.
- `expected_renewal_product_pnl_subline_name` → 4th level Finance approved P&L hierarchy for expected renewal.
- `expected_renewal_product_pnl_version_name` → P&L version classification for expected renewal product.
- `expected_customer_type_name` → Customer type the renewal is expected to be attributed to.
- `expected_pnl_us_independent_flag` → True = Expected renewal is in US Independent P&L group.
- `expected_pnl_international_independent_flag` → True = Expected renewal is in International Independent P&L group.
- `expected_pnl_partner_flag` → True = Expected renewal is in Partner P&L group.
- `expected_pnl_investor_flag` → True = Expected renewal is in Investor P&L group.
- `expected_pnl_commerce_flag` → True = Expected renewal is in Commerce P&L group.
- `expected_bill_pnl_pillar_name` → P&L pillar classification for the expected renewal (e.g., Core, Applications and Commerce, Domains).

**Expected Renewal — Finance P&L:**
- `finance_expected_renewal_pnl_group_name` → Finance-specific P&L group for the expected renewal.
- `finance_expected_renewal_pnl_category_name` → Finance-specific P&L category for the expected renewal.
- `finance_expected_renewal_pnl_line_name` → Finance-specific P&L line for the expected renewal.
- `finance_expected_renewal_pnl_subline_name` → Finance-specific P&L subline for the expected renewal.
- `finance_expected_renewal_investor_relation_class_name` → Finance investor relations class for the expected renewal.
- `finance_expected_renewal_investor_relation_subclass_name` → Finance investor relations subclass for the expected renewal.
- `finance_expected_renewal_investor_relation_segment_name` → Finance investor relations segment for the expected renewal.
- `finance_expected_renewal_subscription_transaction_name` → Finance subscription transaction classification for expected renewal.

**Derived/Coalesced Product Fields:**
- `product_pnl_group_name` → 1st level P&L hierarchy (coalesce of renewal, expected, prior).
- `product_pnl_category_name` → 2nd level P&L hierarchy (coalesce of renewal, expected, prior).
- `product_pnl_line_name` → 3rd level P&L hierarchy (coalesce of renewal, expected, prior).
- `product_pnl_subline_name` → 4th level P&L hierarchy (coalesce of renewal, expected, prior).
- `product_pnl_version_name` → P&L version hierarchy (coalesce of renewal, expected, prior).
- `product_period_name` → Current product billing period (coalesce of renewal, expected, prior).
- `product_period_qty` → Count of current product billing periods.
- `bill_country_name` → Applicable bill country (coalesce of renewal, prior).
- `bill_domestic_international_name` → Domestic/international classification (coalesce of renewal, prior).
- `bill_report_region_2_name` → Report region 2 (coalesce of renewal, prior).
- `point_of_purchase_name` → Point of purchase (coalesce of renewal, prior).
- `transaction_currency_code` → Currency code on applicable bill (coalesce of renewal, prior).

**Outcome/Timing:**
- `outcome_code` → Outcome of the entitlement: 'Cancel' or 'Renewal'.
- `outcome_mst_date` → Date the entitlement was cancelled or renewed.
- `entitlement_event_mst_ts` → Event timestamp (renewal/cancel/expiration) for historical auto-renew lookup.
- `entitlement_event_code` → Event type code identifying which event timestamp applies.
- `first_expiry_sequence_flag` → True = Entitlement is on 1st expiry sequence (prior_bill_sequence_number=1).
- `prior_free_receipt_price_flag` → True = Product was free on prior bill.
- `renewal_timing_desc` → Type of renewal timing. Values: Cancelled, Delayed, Early Cancel, Full Term, No Expiration Data, Not Yet Expired, Past Expiry - In Grace Period, Pull Forward.
- `renewal_timing_monthly_desc` → Monthly-level renewal timing classification.
- `on_time_renewal_flag` → True = Renewal occurred on or before the renewal timing date.
- `potential_receipt_price_amt` → Potential receipt price if resource is renewed for the expected term length.

**COA/COO:**
- `coa_resource_id` → Original resource ID before Change of Account/Ownership (COA/COO). Used to link COO resources back to their original subscription.
- `coa_flag` → True = Entitlement is a Change of Account/Ownership (COA/COO) resource.
- `entitlement_addon_id` → Add-on entitlement ID associated with the subscription.

**Finance-specific Overrides:**
- `finance_expiry_qty_filter_flag` → Finance filter flag to exclude certain records from expiry quantity calculations.
- `finance_expiry_qty` → Finance-adjusted expiry quantity (may differ from expiry_qty due to filter rules).
- `finance_pfid_exclusion_flag` → True = Entitlement PF ID is excluded from finance calculations.
- `finance_sequence_num` → Order sequence number used for finance reporting (may differ from prior_bill_sequence_number due to COO mapping).
- `finance_prior_bill_term_qty` → Finance-specific term quantity for the prior bill.
- `finance_renewal_bill_term_qty` → Finance-specific term quantity for the renewal bill.
- `finance_expected_term_qty` → Finance-specific expected term quantity.
- `finance_prior_bill_term_type_name` → Finance-specific term type for the prior bill.
- `finance_renewal_bill_term_type_name` → Finance-specific term type for the renewal bill.
- `finance_expected_renewal_bill_term_type_name` → Finance-specific expected renewal term type.
- `finance_term_type_name` → Finance-specific overall term type name.
- `finance_renewal_qty_filter_flag` → Finance filter flag to exclude certain records from renewal quantity calculations.
- `finance_renewal_qty` → Finance-adjusted renewal quantity (may differ from renewal_qty due to filter rules).

**Relative Calendar Fields:**
- `relative_bill_paid_through_mst_date` → Expiration date aligned to rolling year for trend analysis.
- `relative_bill_paid_through_mst_week_start_date` → Start of the expiration week in relative calendar.
- `relative_bill_paid_through_mst_month_start_date` → Start of the expiration month in relative calendar.
- `relative_bill_paid_through_date_period_name` → Expiration date as Current Year, Future Year (n), or Prior Year (n).
- `relative_bill_paid_through_week_period_name` → Expiration week period designation in relative calendar.
- `relative_bill_paid_through_month_period_name` → Expiration month period designation in relative calendar.
- `relative_renewal_bill_modified_mst_date` → Renewal date aligned to rolling year for trend analysis.
- `relative_renewal_bill_modified_mst_week_start_date` → Start of the renewal week in relative calendar.
- `relative_renewal_bill_modified_mst_month_start_date` → Start of the renewal month in relative calendar.
- `relative_renewal_bill_modified_date_period_name` → Renewal date as Current Year, Future Year (n), or Prior Year (n).
- `relative_renewal_bill_modified_week_period_name` → Renewal week period designation in relative calendar.
- `relative_renewal_bill_modified_month_period_name` → Renewal month period designation in relative calendar.

**Metadata:**
- `source_table_name` → Name of the source table for this record.
- `data_through_mst_date` → Latest date for which data is available. (max(renewal_bill_modified_mst_date))
- `etl_build_mst_ts` → Timestamp when the ETL process built/loaded this record.

**Federation/Identity:**
- `federation_partner_id` (existing comment) → Brand ID from which the shopper associated with prior bill originated.
- `federation_partner_name` (existing comment) → Brand name from which the shopper associated with prior bill originated (e.g., Google, TsoHost).
- `entitlement_cancel_mst_date` → Cancellation date for the entitlement that resulted in subscription cancellation (derived from subscription_cancel_mst_date at max prior_bill_sequence_num).

---

## Full DDL

```sql
CREATE TABLE renewal_360 (
    entitlement_id string,
    subscription_id string,
    resource_id bigint,
    product_family_name string,
    product_type_id int,
    product_type_desc string,
    prior_bill_modified_mst_date date,
    prior_bill_modified_mst_ts timestamp,
    prior_bill_id string,
    prior_bill_line_num int,
    original_prior_bill_sequence_number int,
    prior_bill_sequence_number int,
    prior_bill_shopper_id string,
    bill_exclude_reason_desc string,
    subscription_exclude_reason_desc string,
    subscription_migration_type string,
    prior_entitlement_bill_type string,
    subscription_cancel_mst_date date,
    subscription_cancel_mst_ts timestamp,
    subscription_cancel_by_name string,
    prior_bill_refund_flag boolean COMMENT 'represents whether the prior bill related to renewal was refunded.',
    prior_payable_bill_line_flag boolean,
    originating_payable_subscription_flag boolean,
    current_payable_subscription_flag boolean,
    current_auto_renewal_flag boolean,
    hard_bundle_flag boolean,
    domain_cancel_reason_desc string,
    prior_bill_paid_through_mst_date date,
    prior_bill_paid_through_mst_month_start_date date,
    prior_bill_paid_through_mst_ts timestamp,
    original_bill_paid_through_mst_date date,
    prior_bill_billing_due_mst_date date,
    prior_bill_billing_due_mst_ts timestamp,
    original_bill_billing_due_mst_date date,
    historical_auto_renewal_flag boolean,
    prior_bill_private_label_id int,
    prior_bill_reseller_name string,
    prior_bill_reseller_type_name string,
    prior_bill_purchase_path_name string,
    prior_bill_pf_id int,
    prior_bill_product_name string,
    prior_bill_product_pnl_new_renewal_name string,
    prior_bill_product_pnl_category_name string,
    prior_bill_product_pnl_group_name string,
    prior_bill_product_pnl_line_name string,
    prior_bill_product_pnl_subline_name string,
    prior_bill_product_pnl_version_name string,
    prior_bill_product_period_name string,
    prior_bill_product_period_qty int,
    finance_prior_bill_pnl_group_name string,
    finance_prior_bill_pnl_category_name string,
    finance_prior_bill_pnl_line_name string,
    finance_prior_bill_pnl_subline_name string,
    finance_prior_bill_investor_relation_class_name string,
    finance_prior_bill_investor_relation_subclass_name string,
    finance_prior_bill_investor_relation_segment_name string,
    finance_prior_bill_subscription_transaction_name string,
    prior_bill_pnl_international_independent_flag boolean,
    prior_bill_pnl_investor_flag boolean,
    prior_bill_pnl_partner_flag boolean,
    prior_bill_pnl_us_independent_flag boolean,
    prior_bill_pnl_commerce_flag boolean,
    current_subscription_status_name string COMMENT 'subscription status at the time data was loaded in the table',
    prior_bill_subscription_status_name string COMMENT 'subscription status at the time of prior_bill_modified_mst_ts',
    prior_bill_customer_type_name string,
    prior_bill_domestic_international_name string,
    prior_bill_country_code string,
    prior_bill_country_name string,
    prior_bill_region_2_name string,
    prior_bill_domain_bulk_pricing_flag boolean,
    prior_bill_intent string,
    prior_bill_related_subscription string,
    prior_bill_price_group_id int COMMENT 'Prior bill price group id, integer range from 0 to 34',
    prior_bill_price_group_name string COMMENT 'Prior bill price group name with value such as Default, uk-United Kingdom, ar-Argentina',
    prior_bill_variant_price_type_id int COMMENT 'Price bill price type id with value as 0, 8, 16, 32, 64, 128 or 256',
    prior_bill_variant_price_type_name string,
    prior_bill_fraud_flag boolean,
    prior_bill_point_of_purchase_name string,
    prior_bill_trxn_currency_code string,
    prior_bill_crm_portfolio_type_name string,
    prior_bill_item_tracking_code string,
    prior_bill_product_month_qty decimal(18,2),
    prior_bill_unit_qty decimal(18,6),
    prior_bill_duration_qty decimal(18,2),
    prior_bill_fee_usd_amt decimal(20,2),
    prior_bill_gcr_usd_amt decimal(20,2),
    prior_bill_gcr_trxn_amt decimal(20,2),
    prior_bill_gcr_constant_currency_amt decimal(20,2),
    prior_bill_receipt_price_usd_amt decimal(20,2),
    prior_bill_receipt_price_trxn_amt decimal(20,2),
    prior_bill_list_price_usd_amt decimal(20,2),
    prior_bill_list_price_trxn_amt decimal(20,2),
    prior_bill_pnl_pillar_name string COMMENT 'Prior bill P&L pillar classification for major business segments. Examples: Core, Applications and Commerce, Domains.',
    original_expiry_qty int,
    expiry_qty int,
    renewal_bill_id string,
    renewal_bill_line_num int,
    renewal_bill_modified_mst_date date,
    renewal_bill_modified_mst_ts timestamp,
    renewal_entitlement_bill_type string,
    renewal_payable_bill_line_flag boolean,
    renewal_bill_shopper_id string,
    renewal_bill_exclude_reason_desc string,
    renewal_bill_reseller_name string,
    renewal_bill_reseller_type_name string,
    renewal_bill_purchase_path_name string,
    renewal_bill_pf_id int,
    renewal_bill_product_name string,
    renewal_bill_product_pnl_new_renewal_name string,
    renewal_bill_product_pnl_category_name string,
    renewal_bill_product_pnl_group_name string,
    renewal_bill_product_pnl_line_name string,
    renewal_bill_product_pnl_subline_name string,
    renewal_bill_product_pnl_version_name string,
    renewal_bill_product_period_name string,
    renewal_bill_product_period_qty int,
    finance_renewal_bill_pnl_group_name string,
    finance_renewal_bill_pnl_category_name string,
    finance_renewal_bill_pnl_line_name string,
    finance_renewal_bill_pnl_subline_name string,
    finance_renewal_bill_investor_relation_class_name string,
    finance_renewal_bill_investor_relation_subclass_name string,
    finance_renewal_bill_investor_relation_segment_name string,
    finance_renewal_bill_subscription_transaction_name string,
    renewal_bill_pnl_international_independent_flag boolean,
    renewal_bill_pnl_investor_flag boolean,
    renewal_bill_pnl_partner_flag boolean,
    renewal_bill_pnl_us_independent_flag boolean,
    renewal_bill_pnl_commerce_flag boolean,
    renewal_bill_subscription_status_name string COMMENT 'subscription status at renewal_bill_modified_mst_ts',
    renewal_bill_customer_type_name string,
    renewal_bill_domestic_international_name string,
    renewal_bill_country_code string,
    renewal_bill_country_name string,
    renewal_bill_report_region_2_name string,
    renewal_bill_domain_bulk_pricing_flag boolean,
    renewal_bill_intent string,
    renewal_bill_related_subscription string,
    renewal_bill_price_group_id int COMMENT 'Renewal bill price group id, integer range from 0 to 34',
    renewal_bill_price_group_name string COMMENT 'Renewal bill price group name with value such as Default, uk-United Kingdom, ar-Argentina',
    renewal_bill_variant_price_type_id int COMMENT 'Renewal bill price type id with value as 0, 8, 16, 32, 64, 128 or 256',
    renewal_bill_variant_price_type_name string,
    renewal_bill_fraud_flag boolean,
    renewal_bill_refund_flag boolean COMMENT 'represents whether the renewal bill associated with the renewal was refunded',
    renewal_bill_point_of_purchase_name string,
    renewal_bill_trxn_currency_code string,
    renewal_bill_crm_portfolio_type_name string,
    renewal_bill_item_tracking_code string,
    renewal_bill_product_month_qty decimal(18,2),
    renewal_bill_unit_qty decimal(18,6),
    renewal_bill_duration_qty decimal(18,2),
    renewal_bill_fee_usd_amt decimal(20,2),
    renewal_bill_gcr_usd_amt decimal(20,2),
    renewal_bill_gcr_trxn_amt decimal(20,2),
    renewal_bill_gcr_constant_currency_amt decimal(20,2),
    renewal_bill_receipt_price_usd_amt decimal(20,2),
    renewal_bill_receipt_price_trxn_amt decimal(20,2),
    renewal_bill_list_price_usd_amt decimal(20,2),
    renewal_bill_list_price_trxn_amt decimal(20,2),
    renewal_bill_pnl_pillar_name string,
    original_renewal_qty int,
    renewal_qty int,
    outcome_code string,
    outcome_mst_date date,
    entitlement_event_mst_ts timestamp,
    entitlement_event_code string,
    first_expiry_sequence_flag boolean,
    prior_free_receipt_price_flag boolean,
    renewal_timing_desc string,
    renewal_timing_monthly_desc string,
    on_time_renewal_flag boolean,
    potential_receipt_price_amt decimal(20,2),
    expected_receipt_price_usd_amt decimal(20,2) COMMENT 'Expected receipt price amount in USD',
    expected_renewal_pf_id int,
    expected_renewal_product_pnl_group_name string,
    expected_renewal_product_pnl_category_name string,
    expected_renewal_product_pnl_line_name string,
    expected_renewal_product_pnl_version_name string,
    expected_renewal_product_pnl_subline_name string,
    expected_renewal_product_name string,
    expected_renewal_product_period_name string,
    expected_renewal_product_period_qty int,
    finance_expected_renewal_pnl_group_name string,
    finance_expected_renewal_pnl_category_name string,
    finance_expected_renewal_pnl_line_name string,
    finance_expected_renewal_pnl_subline_name string,
    finance_expected_renewal_investor_relation_class_name string,
    finance_expected_renewal_investor_relation_subclass_name string,
    finance_expected_renewal_investor_relation_segment_name string,
    finance_expected_renewal_subscription_transaction_name string,
    expected_customer_type_name string,
    expected_pnl_us_independent_flag boolean,
    expected_pnl_international_independent_flag boolean,
    expected_pnl_partner_flag boolean,
    expected_pnl_investor_flag boolean,
    expected_pnl_commerce_flag boolean,
    expected_bill_pnl_pillar_name string,
    product_pnl_group_name string,
    product_pnl_category_name string,
    product_pnl_line_name string,
    product_pnl_version_name string,
    product_pnl_subline_name string,
    product_period_name string,
    product_period_qty int,
    bill_country_name string,
    bill_domestic_international_name string,
    bill_report_region_2_name string,
    point_of_purchase_name string,
    transaction_currency_code string,
    source_table_name string,
    prior_bill_primary_product_flag boolean,
    renewal_bill_primary_product_flag boolean,
    subscription_migration_mst_ts timestamp,
    coa_resource_id bigint,
    coa_flag boolean,
    entitlement_addon_id bigint,
    federation_partner_id string COMMENT 'represents the brand id from which the shopper associated with prior bill originated',
    federation_partner_name string COMMENT 'represents the brand name from which the shopper associated with prior bill originated eg: Google, TsoHost',
    entitlement_cancel_mst_date date,
    finance_expiry_qty_filter_flag boolean,
    finance_expiry_qty int,
    finance_pfid_exclusion_flag boolean,
    data_through_mst_date date,
    relative_bill_paid_through_mst_date date,
    relative_bill_paid_through_mst_week_start_date date,
    relative_bill_paid_through_mst_month_start_date date,
    relative_bill_paid_through_date_period_name string,
    relative_bill_paid_through_week_period_name string,
    relative_bill_paid_through_month_period_name string,
    relative_renewal_bill_modified_mst_date date,
    relative_renewal_bill_modified_mst_week_start_date date,
    relative_renewal_bill_modified_mst_month_start_date date,
    relative_renewal_bill_modified_date_period_name string,
    relative_renewal_bill_modified_week_period_name string,
    relative_renewal_bill_modified_month_period_name string,
    finance_sequence_num int,
    finance_prior_bill_term_qty int,
    finance_renewal_bill_term_qty int,
    finance_expected_term_qty int,
    finance_prior_bill_term_type_name string,
    finance_renewal_bill_term_type_name string,
    finance_expected_renewal_bill_term_type_name string,
    finance_term_type_name string,
    finance_renewal_qty_filter_flag boolean,
    finance_renewal_qty int,
    etl_build_mst_ts timestamp
)
```

**The agent's final response to the user was:**
The research has been appended to `research.md`. Here's a summary of what was accomplished:

## Research Summary

**Target Table:** `ecomm-mart.renewal_360` (246 columns)

**Sources Consulted:**

1. **DDL** (`table.ddl`) — Read all 246 columns; identified 14 existing inline COMMENT clauses that must be preserved.

2. **table.yaml** — Captured table description, upstream lineage (9 dependencies), SLA, data tier, and permissions.

3. **Confluence Page 1: Renewal 360** (ID: 3293352384, 80KB) — Full field reference table with descriptions for nearly all columns including source system, data type, business definition, and derivation logic.

4. **Confluence Page 2: Renewal 360 Gap Resolution - Order Sequence 1** (ID: 3435340877) — Documents the COA/COO gap (~1.58-2.92% of GCR), explains `coa_flag`, `coa_resource_id`, `original_prior_bill_sequence_number`, and gap resolution logic.

5. **Alation** — Token expired; could not access Alation column metadata, reference tables, or Certified Data Dictionary.

**Key Findings:**
- GCR = **Gross Cash Receipts** (confirmed by Confluence financial context)
- The table uses "prior/renewal" dual-sided structure — each row pairs a prior bill (point-in-time) with its corresponding renewal bill
- `finance_*` columns are Finance-specific overrides/calculations that may differ from standard renewal counts
- `original_*` columns preserve pre-COO-adjustment values
- Relative calendar columns support rolling year trend analysis