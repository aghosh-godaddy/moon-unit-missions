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

# Research: customer360.customer_metric_daily_agg_vw

## 1. Table DDL (current)

```sql
CREATE TABLE customer_metric_daily_agg_vw(
    customer_type_reason_desc                           string          COMMENT '@PrimaryKey: Reason for customer type classification',
    customer_acquisition_mst_month                      string          COMMENT '@PrimaryKey: Customer acquisition month (MST), as yyyy-MM',
    customer_domestic_international_name                string          COMMENT '@PrimaryKey: Domestic vs International classification',
    customer_region_1_name                              string          COMMENT '@PrimaryKey: Geographic region level 1',
    customer_region_2_name                              string          COMMENT '@PrimaryKey: Geographic region level 2',
    customer_region_3_name                              string          COMMENT '@PrimaryKey: Geographic region level 3',
    customer_country_name                               string          COMMENT '@PrimaryKey: Customer country name at evaluation date',
    customer_country_code                               string          COMMENT '@PrimaryKey: Customer country code at evaluation date',
    customer_type_name                                  string          COMMENT '@PrimaryKey: Customer type at evaluation date',
    acquisition_channel_name                            string          COMMENT '@PrimaryKey: Acquisition channel',
    customer_tenure_year_count                          int             COMMENT '@PrimaryKey: Customer tenure in years (integer)',
    product_ownership_category_list                     string          COMMENT '@PrimaryKey: Owned product category list (string-encoded)',
    product_ownership_line_list                         string          COMMENT '@PrimaryKey: Owned product line list (string-encoded)',
    reseller_type_name                                  string          COMMENT '@PrimaryKey: Reseller type name',
    fraud_flag                                          boolean         COMMENT '@PrimaryKey: True if customer marked as fraud as of evaluation date',
    brand_name_list                                     string          COMMENT '@PrimaryKey: List of all brands associated with the customer',
    product_category_qty                                int             COMMENT 'Number of owned product categories',
    ttm_gcr_usd_amt                                     decimal(18, 2)  COMMENT 'Total gross cash received (GCR) USD in trailing twelve months',
    ending_customer_qty                                 bigint          COMMENT 'Ending customer count as of evaluation date',
    churn_customer_qty                                  bigint          COMMENT 'Customers churned on evaluation date',
    merge_customer_qty                                  bigint          COMMENT 'Customers merged on evaluation date',
    new_customer_qty                                    bigint          COMMENT 'New customers on evaluation date',
    reactivate_customer_qty                             bigint          COMMENT 'Reactivated customers on evaluation date',
    beginning_customer_qty                              bigint          COMMENT 'Beginning customer count from prior day',
    net_move_qty                                        bigint          COMMENT 'Net move quantity',
    net_add_qty                                         bigint          COMMENT 'Net additions (ending - beginning)',
    net_churn_qty                                       bigint          COMMENT 'Net churn (churned - reactivated)',
    point_of_purchase_name                              string          COMMENT 'Point of purchase name from acquisition bill',
    customer_acquisition_bill_fraud_flag                boolean         COMMENT 'True if acquisition bill has fraud record',
    etl_build_mst_ts                                    timestamp       COMMENT 'ETL build timestamp in MST'
)
PARTITIONED BY (partition_eval_mst_date string)
```

## 2. Table YAML Metadata

- **Description:** Customer Metric Daily Aggregated on Reporting Dims for a given day
- **Storage format:** Parquet
- **Table type:** PARTITIONED
- **Partition key:** `partition_eval_mst_date` (string) — evaluation date in MST
- **Data tier:** 4
- **SLA:** Delivered by 08:00 AM MST every day (`cron(00 15 * * ? *)` UTC)
- **Upstream dependency:** `customer360.customer_life_cycle_vw`
- **Consumers:** ckpetlbatch, data_lab, analytics, data_platform, martech_data, revenue_and_relevance

## 3. Confluence Page Summaries

### 3a. Customer Lifecycle (Page 3970861345)

**Purpose:** Physical model for the Customer Lifecycle table, which acts as a driver for Customer Metrics requested by Finance.

**Key column context:**
- `customer_id` / `shopper_id`: enterprise.dim_new_acquisition_shopper — the day a user made a payment; churned when turning from paid to free trial or service lapsed
- `customer_acquisition_mst_month`: derived as the first day of the month of `customer_acquisition_mst_date` (logic in DAC). Format: yyyy-MM (first day of month)
- `customer_tenure_year_count`: `shopper_tenure.shopper_tenure_days_count / 365`, sourced from `analytic_feature.shopper_tenure`; represents integer years since acquisition
- `customer_domestic_international_name`, `customer_region_1/2/3_name`, `customer_country_name`, `customer_country_code`: from `dim_geography`, joined on `acq_country_code`
- `customer_type_name`: from `analytic_feature.customer_type_history` (join on shopper_id) — type of customer at evaluation date
- `customer_type_reason_desc`: from `analytic_feature.customer_type_history` (join on shopper_id) — reason text for customer type classification
- `acquisition_channel_name`: `channel_grouping_name` from `ecomm_mart.bill_line_traffic_ext`, joined on `new_acquisition_bill_id = acquisition_bill_id`
- `reseller_type_name` (source: reseller_type_id): `shopper_account_detail.private_label_id` → `dp_enterprise_linked.dim_reseller` on `private_label_id`
- `ttm_gcr_usd_amt`: sourced from `ttm_total_gcr_usd_amt` in `fact_customer_ttm_payment` (join on shopper_id/customer_id) — trailing twelve months total GCR USD
- **Churn logic:** A customer is churned when they were in the prior day's active customer set but absent from the current partition. Churn date = `evaluation_mst_date`. Source: Alation article #98 (churned-customer). Merge-deactivated customers do NOT get a churn date.
- **Reactivation logic:** Customer appears in current day but was absent prior day AND `customer_acquisition_mst_date` is older than today — implies reactivation.
- **Merge logic:** `shopper_merge_end_mst_date` from `analytic_feature.shopper_merge` — set for the original (churned) shopper only.
- **Fraud:** from `analytic_feature.customer_fraud` joined on customer_id/shopper_id
- `product_pnl_categories`: list of product P&L category values from `customer_core_conformed.fact_active_entitlement_last_payment_detail`
- `product_pnl_category_qty`: count of items in the `product_pnl_categories` list
- `product_pnl_lines`: list of product P&L lines from driver table

### 3b. Customer360 (Page 3779199819)

**Overview:** Customer360 is GoDaddy's foundational data product establishing end-to-end physical architecture for the customer domain. It provides a trusted, unified view of customers to power analytics, reporting, and data science.

**Lifecycle component (`customer_life_cycle_vw`):** SSOT for customer lifecycle holistically — compresses states and logic spread across 3 marts, built with SCD2 to understand change over time. Includes ALL customers (not just "active"), covering lifecycle states: active, inactive, churned, reactivated, new registered, and lapsed.

**Business Metrics Layer (`customer_metric_daily_agg_vw`):**
- Replaces: `customer_mart.daily_active_customers`, `customer_mart.monthly_active_customers`
- In progress: NRU (New Registered User) and Lapsed user metrics co-existing with all externally reported metrics
- This is a daily aggregation of customer lifecycle metrics grouped by reporting dimensions (the PrimaryKey columns)

**Architecture context:**
- The view aggregates per-customer lifecycle data from `customer_life_cycle_vw` into dimensional group-by summaries
- Consumers use the partition key `partition_eval_mst_date` to query a specific day's metrics
- The `@PrimaryKey` columns form the composite grouping key for aggregated counts and amounts
- Metric columns (`ending_customer_qty`, `churn_customer_qty`, etc.) are aggregated counts of customers in each lifecycle state on that evaluation date

## 4. Alation Lookup

**Status:** Alation API access was unavailable — the stored refresh token is expired (HTTP 401, code "401000"). No Alation metadata could be retrieved for:
- Target table: `customer360.customer_metric_daily_agg_vw`
- Reference table: `customer360.customer_life_cycle_vw` (Alation ID 7038345)
- Certified Data Dictionary (Document Folder 6)

## 5. Certified Data Dictionary Mappings

Alation was unavailable, so the dictionary could not be queried. The following abbreviations appear in column names; their expansions are based on the DDL comment and Confluence context:

| Abbreviation | Best-Available Expansion | Source | Verified in Dictionary |
|---|---|---|---|
| GCR | Gross Cash Receipts (or "gross cash received" per DDL comment) | DDL comment + Confluence | No — Alation unavailable |
| TTM | Trailing Twelve Months | DDL comment | No — Alation unavailable |
| MST | Mountain Standard Time | DDL comment + YAML | No — Alation unavailable |
| ETL | Extract, Transform, Load | industry standard | No — Alation unavailable |
| NRU | New Registered User | Confluence Customer360 page | No — Alation unavailable |
| QTY | Quantity | DDL pattern | No — Alation unavailable |
| AMT | Amount | DDL pattern | No — Alation unavailable |
| TS | Timestamp | DDL pattern | No — Alation unavailable |
| PII | Personally Identifiable Information | data governance standard | No — Alation unavailable |

**NOTE:** The DDL comment for `ttm_gcr_usd_amt` says "gross cash received" while the standard GoDaddy term (likely in the Certified Data Dictionary) may be "Gross Cash Receipts". The current comment should be preserved as-is or verified before changing the expansion.

## 6. Per-Column Analysis

### PrimaryKey Dimension Columns (composite grouping key for aggregation)

| Column | DDL Comment | Confluence / Context | Inferred Purpose |
|---|---|---|---|
| `customer_type_reason_desc` | `@PrimaryKey: Reason for customer type classification` | From `analytic_feature.customer_type_history` joined on shopper_id | Text description of why a customer has their current type (e.g., "2+ Products", "Single Product") — groups customers for reporting |
| `customer_acquisition_mst_month` | `@PrimaryKey: Customer acquisition month (MST), as yyyy-MM` | Derived as first day of month of `customer_acquisition_mst_date` from `enterprise.dim_new_acquisition_shopper` | Cohort dimension — the month the customer first became a paying customer, in Mountain Standard Time |
| `customer_domestic_international_name` | `@PrimaryKey: Domestic vs International classification` | From `dim_geography` on `acq_country_code` | Whether the customer is domestic (US) or international |
| `customer_region_1_name` | `@PrimaryKey: Geographic region level 1` | From `dim_geography` | Broadest geographic grouping (e.g., continent/major region) |
| `customer_region_2_name` | `@PrimaryKey: Geographic region level 2` | From `dim_geography` | Mid-level geographic grouping (e.g., sub-region) |
| `customer_region_3_name` | `@PrimaryKey: Geographic region level 3` | From `dim_geography` | Finest geographic grouping below country (e.g., state/province equivalent) |
| `customer_country_name` | `@PrimaryKey: Customer country name at evaluation date` | From `dim_geography`; country as of `evaluation_mst_date` | Customer's country at the time of the evaluation date |
| `customer_country_code` | `@PrimaryKey: Customer country code at evaluation date` | ISO country code from `dim_geography` at `evaluation_mst_date` | ISO country code for the customer's country at evaluation date |
| `customer_type_name` | `@PrimaryKey: Customer type at evaluation date` | From `analytic_feature.customer_type_history` on shopper_id | Customer type classification at evaluation date (e.g., Active, Churned, Lapsed) |
| `acquisition_channel_name` | `@PrimaryKey: Acquisition channel` | `channel_grouping_name` from `ecomm_mart.bill_line_traffic_ext` | Marketing/traffic channel through which the customer was originally acquired |
| `customer_tenure_year_count` | `@PrimaryKey: Customer tenure in years (integer)` | `shopper_tenure_days_count / 365` from `analytic_feature.shopper_tenure` | Integer number of years since the customer's acquisition date |
| `product_ownership_category_list` | `@PrimaryKey: Owned product category list (string-encoded)` | List of product P&L category values from active entitlement detail | String-encoded list of product P&L categories owned by customers in this group |
| `product_ownership_line_list` | `@PrimaryKey: Owned product line list (string-encoded)` | List of product P&L lines from active entitlement detail | String-encoded list of product P&L lines owned by customers in this group |
| `reseller_type_name` | `@PrimaryKey: Reseller type name` | From `dp_enterprise_linked.dim_reseller` via `private_label_id` | Name of the reseller/private-label type associated with the customer |
| `fraud_flag` | `@PrimaryKey: True if customer marked as fraud as of evaluation date` | From `analytic_feature.customer_fraud` | Boolean indicator of customer fraud status at evaluation date |
| `brand_name_list` | `@PrimaryKey: List of all brands associated with the customer` | Customer360 brand context | String-encoded list of GoDaddy brand(s) associated with the customer group |

### Metric Columns (aggregated counts/amounts)

| Column | DDL Comment | Confluence / Context | Inferred Purpose |
|---|---|---|---|
| `product_category_qty` | `Number of owned product categories` | Count of items in product_pnl_categories list | Count of distinct product P&L categories owned by customers in this dimensional group |
| `ttm_gcr_usd_amt` | `Total gross cash received (GCR) USD in trailing twelve months` | Sourced from `ttm_total_gcr_usd_amt` in `fact_customer_ttm_payment` | Summed trailing-twelve-month Gross Cash Receipts in USD for customers in this dimensional group |
| `ending_customer_qty` | `Ending customer count as of evaluation date` | Aggregated from lifecycle view | Total customers in this dimensional group at end of evaluation date |
| `churn_customer_qty` | `Customers churned on evaluation date` | Churned = in d-1 active set but absent from current partition | Count of customers who churned on this evaluation date |
| `merge_customer_qty` | `Customers merged on evaluation date` | Deactivated via account merge (no churn date set) | Count of customers deactivated due to account merge on this date |
| `new_customer_qty` | `New customers on evaluation date` | First-time paying customers on evaluation date | Count of customers who became new paying customers on this date |
| `reactivate_customer_qty` | `Reactivated customers on evaluation date` | Customer re-appears after churn AND acquisition date is older than today | Count of customers who reactivated (returned after churn) on this date |
| `beginning_customer_qty` | `Beginning customer count from prior day` | Ending count of prior day's evaluation date | Total customers in this dimensional group at start of evaluation date (prior day's ending count) |
| `net_move_qty` | `Net move quantity` | Customers who moved between dimensional groups on this date | Net count of customers who moved into/out of this dimensional group on evaluation date |
| `net_add_qty` | `Net additions (ending - beginning)` | `ending_customer_qty - beginning_customer_qty` | Net change in customer count: ending minus beginning for this dimensional group |
| `net_churn_qty` | `Net churn (churned - reactivated)` | `churn_customer_qty - reactivate_customer_qty` | Net churned customers: gross churn offset by reactivations |
| `point_of_purchase_name` | `Point of purchase name from acquisition bill` | From acquisition bill data | Name of the point of purchase (storefront/channel) from the customer's acquisition bill |
| `customer_acquisition_bill_fraud_flag` | `True if acquisition bill has fraud record` | Fraud record on the acquisition bill | Boolean indicating whether the customer's acquisition billing transaction has an associated fraud record |
| `etl_build_mst_ts` | `ETL build timestamp in MST` | Pipeline audit column | Timestamp when this record was built/processed by the ETL pipeline, in Mountain Standard Time |

### Partition Column

| Column | Inferred Purpose |
|---|---|
| `partition_eval_mst_date` | Date of evaluation in MST (yyyy-MM-dd). This is the primary query predicate; consumers filter by this date to retrieve a specific day's customer metrics snapshot. |


**The agent's final response to the user was:**
The research has been compiled and appended to `research.md`. Here is a summary of what was done:

---

## Research Summary

**Target table:** `customer360.customer_metric_daily_agg_vw`
**DDL/YAML path:** `catalog/config/prod/dlms-api/us-west-2/customer360/customer-metric-daily-agg-vw/`

### What was read
- **table.ddl** — 31 columns (16 `@PrimaryKey` dimension columns + 14 metric/audit columns) plus partition key `partition_eval_mst_date`. Most columns already have concise DDL comments; some are vague (`net_move_qty`, `product_category_qty`).
- **table.yaml** — Daily Parquet partitioned view, SLA: 08:00 AM MST daily, upstream dependency: `customer360.customer_life_cycle_vw`, consumers span analytics/finance/martech.

### Confluence pages fetched
- **Customer Lifecycle (3970861345):** Physical model design doc. Provides column-level source mappings: `customer_type_reason_desc` and `customer_type_name` from `analytic_feature.customer_type_history`; `ttm_gcr_usd_amt` from `fact_customer_ttm_payment.ttm_total_gcr_usd_amt`; geography columns from `dim_geography`; `acquisition_channel_name` = `channel_grouping_name` from `ecomm_mart.bill_line_traffic_ext`; churn/reactivation/merge logic details.
- **Customer360 (3779199819):** Architecture overview. Confirms `customer_metric_daily_agg_vw` is the Business Metrics Layer replacing `customer_mart.daily_active_customers` and `customer_mart.monthly_active_customers`. NRU/Lapsed users are in-progress additions. The `@PrimaryKey` columns are the composite grouping dimensions for aggregation.

### Alation
**Unavailable** — the stored refresh token has expired (HTTP 401 "Refresh token provided is expired or revoked"). No column metadata, source comments, or Certified Data Dictionary entries could be retrieved. All GCR/TTM/NRU abbreviation mappings are flagged as unverified against the official dictionary.

### Key findings for enrichment
- Most PrimaryKey dimension columns have good existing comments; enrichment should clarify they are **grouping dimensions** for daily aggregation
- `net_move_qty` comment ("Net move quantity") is vague — Confluence context suggests it tracks customers moving between dimensional groups
- `ttm_gcr_usd_amt` — DDL says "gross cash received" but GoDaddy's standard term is likely "Gross Cash Receipts" (GCR); cannot confirm without Alation dictionary
- `partition_eval_mst_date` has no DDL comment and needs one added
- `product_category_qty` is a derived count from the `product_ownership_category_list`