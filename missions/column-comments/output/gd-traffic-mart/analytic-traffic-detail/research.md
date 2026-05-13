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

## Research Summary: analytic_traffic_detail

**Researcher:** Data Governance Analyst Agent  
**Date:** 2026-05-13  
**Target Table:** `gd_traffic_mart.analytic_traffic_detail`  
**DDL Path:** `catalog/config/prod/us-west-2/gd-traffic-mart/analytic-traffic-detail/table.ddl`

---

## 1. Table Metadata (from table.yaml)

| Field | Value |
|---|---|
| Description | "Analytic Dataset for CSP Traffic Session and Order Data" |
| Storage Format | Parquet |
| Table Type | PARTITIONED |
| Partition Key | `partition_mst_date` (string) |
| Data Tier | 1 |
| Delivery SLA | Daily by 10:30 AM MST (`cron(30 17 * * ? *)`) |
| SLO Identifier | `gd_traffic_mart.analytic_traffic_detail` |

**Upstream Lineage:**
- `gd_traffic_mart.traffic_session` — CSP Traffic session level data. Tier3 DATAGOVER-1503
- `analytic.ads_bill_line` — analytic data set for bill line
- `gd_traffic_mart.gd_bill_id_session_xref` — Mapping table between Orders (bill_id) and Traffic (session_id)
- `gd_traffic_mart.gd_traffic_session_last_nondirect_attribution` — Session level last non-direct attribution channel using GoDaddy traffic data. Tier3 DATAGOVER-1504
- `analytic_feature.shopper_tenure`
- `analytic_feature.customer_type`

**Consumers:** dnai, unified_metrics, dri_data, websites_and_marketing, dri_findml, data_lab, ckpetlbatch, dri_analytics, martech_data, edt, care_analytics, partners, signals_platform, c2_commerce_analytics, usi, mdpe, gxcoreservices (hivemind), revenue_and_relevance, mktgdata, analytics

---

## 2. Full DDL (Current State)

```sql
CREATE TABLE analytic_traffic_detail (
    website_activity_id                                     string            COMMENT 'Primary Key'
   ,website_activity_mst_date                               date              COMMENT 'Session date for sessions, order date for unattributed web orders'
   ,website_activity_exclusion_reason_desc                  string            COMMENT 'Reason for exclusion of low quality sessions'
   ,visitor_id                                              string            COMMENT 'Unique identifier of a traffic visitor'
   ,session_id                                              string            COMMENT 'Unique identifier of a traffic session'
   ,session_flag                                            boolean           COMMENT 'True if this is a traffic session. False for unattributed orders'
   ,session_mst_date                                        date              COMMENT 'Session (beginning) date in MST'
   ,session_mst_ts                                          timestamp         COMMENT 'Session (beginning) timestamp in MST'
   ,session_end_mst_date                                    date              COMMENT 'Session end date in MST'
   ,session_end_mst_ts                                      timestamp         COMMENT 'Session end timestamp in MST'
   ,visit_first_repeat_name                                 string            COMMENT 'For a given session, values are First Visit or Repeat Visit. NULL for unattributed orders'
   ,fos_session_name                                        string            COMMENT 'For a given session, Front of Site if visitors visited FOS, else Not Front of Site. NULL for unattributed orders'
   ,sso_mya_visit_name                                      string            COMMENT 'For a given session, state if SSO and/or MYA pages were visited. NULL for unattributed orders'
   ,session_type_name                                       string            COMMENT 'Values are buyer, shopper or visitor for a given record'
   ,traffic_brand_name                                      string            COMMENT 'Brand name of the traffic source: Godaddy, 123-Reg'
   ,traffic_source_ad_content_name                          string            COMMENT 'The ad content of the traffic source'
   ,traffic_source_campaign_name                            string            COMMENT 'The campaign value of the traffic source'
   ,traffic_source_keyword                                  string            COMMENT 'The keyword of the traffic source'
   ,traffic_source_medium_name                              string            COMMENT 'The medium of the traffic source'
   ,traffic_source_name                                     string            COMMENT 'The source of the traffic source. Could be the name of the search engine, the referring hostname, or a value of the utm_source URL parameter'
   ,traffic_source_referral_path                            string            COMMENT 'Set to the path of the referrer if the medium of the traffic source is referrer'
   ,traffic_source_true_direct_flag                         boolean           COMMENT 'True if the source of the session was Direct'
   ,true_direct_name                                        string            COMMENT 'For a given session, True Direct if the source of the session was direct, else Other. Not Attributed for unattributed orders'
   ,google_ads_campaign_id                                  string            COMMENT 'Google Ads campaign ID'
   ,google_click_id                                         string            COMMENT 'Google Click ID'
   ,gclid_segment_utc_date                                  date              COMMENT 'Date to which Google Ads click metrics apply'
   ,first_hit_referrer_desc                                 string            COMMENT 'Referrer of 1st page view'
   ,first_hit_page_path                                     string            COMMENT 'Page path of 1st page view'
   ,first_hit_content_group_base                            string            COMMENT 'Content group 1 (base) of 1st page view'
   ,first_hit_content_group_2_name                          string            COMMENT 'Content group 2 of 1st page view'
   ,second_hit_page_path                                    string            COMMENT 'Page path of 2nd page view'
   ,second_hit_content_group_base                           string            COMMENT 'Content group 1 (base) of 2nd page view'
   ,second_hit_content_group_2_name                         string            COMMENT 'Content group 2 of 2nd page view'
   ,third_hit_page_path                                     string            COMMENT 'Page path of 3rd page view'
   ,third_hit_content_group_base                            string            COMMENT 'Content group 1 (base) of 3rd page view'
   ,third_hit_content_group_2_name                          string            COMMENT 'Content group 2 of 3rd page view'
   ,last_hit_referrer_desc                                  string            COMMENT 'Referrer of last page view'
   ,last_hit_page_path                                      string            COMMENT 'Page path of last page view'
   ,last_hit_content_group_base                             string            COMMENT 'Content group 1 (base) of last page view'
   ,last_hit_content_group_2_name                           string            COMMENT 'Content group 2 of last page view'
   ,channel_grouping_name                                   string            COMMENT 'The attribution channel of the session. Not Attributed for unattributed orders'
   ,device_browser_name                                     string            COMMENT 'Device browser name from 1st page view'
   ,device_browser_desc                                     string            COMMENT 'Device browser description from 1st page view'
   ,device_browser_version_desc                             string            COMMENT 'Device browser version description from 1st page view'
   ,device_category_name                                    string            COMMENT 'The type of device (Mobile, Tablet, Desktop) from 1st page view'
   ,device_operating_system_name                            string            COMMENT 'Device operating system name from 1st page view'
   ,device_screen_resolution_group                          string            COMMENT 'Device screen resolution group from 1st page view'
   ,device_screen_resolution_size                           string            COMMENT 'Device screen resolution size from 1st page view'
   ,ip_country_name                                         string            COMMENT 'Client IP geo country name from 1st page view'
   ,ip_focal_country_name                                   string            COMMENT 'Client IP geo focal country name from 1st page view'
   ,ip_region_1_name                                        string            COMMENT 'Client IP geo report region 1 name from 1st page view'
   ,ip_region_2_name                                        string            COMMENT 'Client IP geo report region 2 name from 1st page view'
   ,ip_region_3_name                                        string            COMMENT 'Client IP geo report region 3 name from 1st page view'
   ,ip_dma_number                                           string            COMMENT 'Client IP geo DMA (Designated Marketing Area) number from 1st page view'
   ,ip_postal_code                                          string            COMMENT 'Client IP geo zip code of the incoming request corresponding to the 1st page view'
   ,ip_city_name                                            string            COMMENT 'Client IP geo city name from 1st page view'
   ,market_site_code                                        string            COMMENT 'Site market code. ie. en-US from last page view'
   ,market_site_language_code                               string            COMMENT 'Site language code (extracted from market site code)'
   ,market_site_country_code                                string            COMMENT 'Site country code (extracted from market site code)'
   ,market_site_country_name                                string            COMMENT 'Site country name'
   ,market_site_domestic_international_ind                  string            COMMENT 'Site is International or Domestic'
   ,market_site_focal_country_name                          string            COMMENT 'Site focal country name'
   ,market_site_region_1_name                               string            COMMENT 'Site region 1 name'
   ,market_site_region_2_name                               string            COMMENT 'Site region 2 name'
   ,market_site_region_3_name                               string            COMMENT 'Site region 3 name'
   ,total_page_view_all_qty                                 bigint            COMMENT 'Total number of page views within the session'
   ,total_page_view_qty                                     bigint            COMMENT 'Total number of page views within the session, excluding virtual pages'
   ,session_duration_sec                                    bigint            COMMENT 'Session duration in seconds'
   ,session_cnt                                             int               COMMENT '1 for traffic sessions; 0 for unattributed orders'
   ,add_to_cart_session_cnt                                 int               COMMENT '1 for sessions where add_to_cart events are present, 0 otherwise. NULL for unattributed orders'
   ,new_visit_session_cnt                                   int               COMMENT '1 for sessions where add_to_cart events are present, 0 otherwise. NULL for unattributed orders'
   ...
```

---

## 3. Confluence Page Summaries

### 3.1 EDT - Traffic Data Consumer Responsibilities (Page 3510968264)

**Key points:**
- WADv2 uses internally captured CSP traces instead of Google Analytics (WADv1), offering lower data loss but requiring stricter compliance.
- Data is pseudonymized — includes customer_id and session associations enabling individual-level tracing.
- Three consent flags control how traffic data may be used:
  - `consent_analytics_flag` — required for Performance use: recording user sessions, model inferencing on session/user granularity (e.g., Fullstory)
  - `consent_marketing_flag` — required for Advertising use: serving relevant ads, building customer segments (e.g., Salesforce audience loading)
  - `consent_support_flag` — required for delivering 3rd party support services
- **Essential use** (no consent filter required): aggregate data for website performance trends (e.g., hivemind), session-level data for service continuity defect investigation, identity verification, fraud detection, managing shopping cart.
- **Consent-based use**: Analytics/Marketing must filter on respective consent flags. Data consumers are responsible for confirming their use type.

### 3.2 EDT - WAD v2 Design (Page 3318415585)

This page documents the full WAD v2 schema with per-column descriptions. Key column definitions used to enrich comments:

| Column | WAD v2 Description |
|---|---|
| website_activity_id | Website activity ID: session ID or order ID (unattributed web orders). Primary key. Source: global.context.sessionId or uds_order.order_id |
| website_activity_mst_date | Session date (1st page view) or order date (unattributed web orders) |
| website_activity_exclusion_reason_desc | Null for non-low-quality sessions; populated with Low Quality Traffic reason code otherwise |
| visitor_id | Unique visitor ID from 1st page view (global.context.visitorId). GUID representing browser/computer pair |
| session_id | Session ID from 1st page view (global.context.sessionId) |
| session_flag | true = traffic session; false = unattributed web order |
| visit_first_repeat_name | 'First Visit' if visitorId = sessionId (first-ever visit); 'Repeat Visit' otherwise |
| fos_session_name | 'Front of Site' if godaddy.com pages visited in session; 'Not Front of Site' otherwise |
| sso_mya_visit_name | Values based on content group 2 containing 'SSO' and/or 'MYA' |
| session_type_name | 'buyer' if order present, 'shopper' if cart page visited, 'visitor' otherwise |
| traffic_source_ad_content_name | Ad content of traffic source (utm_content URL parameter). Source: global.attribution.content |
| traffic_source_campaign_name | Campaign value: from Google Ads GCLID → campaign map, DCM campaign map, or utm_campaign |
| traffic_source_keyword | Keyword usually set when medium is 'organic' or 'cpc'. Can be set by utm_term URL parameter |
| traffic_source_medium_name | Medium: 'organic', 'cpc', 'referral', or utm_medium parameter value |
| traffic_source_name | Source: search engine name, referring hostname, or utm_source value |
| traffic_source_referral_path | Path of referrer when medium = 'referral'; host name in traffic_source_name |
| traffic_source_true_direct_flag | True if session was Direct (typed URL/bookmark) or two successive sessions with identical campaign details |
| true_direct_name | 'True Direct' if traffic_source_true_direct_flag=true; 'Other' otherwise |
| google_ads_campaign_id | Google Ads campaign ID from page attribution clean layer |
| google_click_id | Google Click ID (gclid) from global.attribution.googleClickId |
| gclid_segment_utc_date | UTC date segment for Google Ads click metrics; used to join Google Ads click data |
| new_visit_session_cnt | **CORRECTED**: 1 if new visit (visitorId = sessionId); 0 otherwise; NULL for unattributed orders |
| logged_in_status_session_cnt | 1 if session has authenticated/logged-in user (global.context.customerId present); 0 otherwise |
| sitecore_session_cnt | 1 if sitecore pages visited in session (via content group logic); 0 otherwise |
| homepage_session_cnt | 1 if homepage visited in session (via content_group_2_name_list); 0 otherwise |
| gd_sales_session_cnt | 1 if GoDaddy sales site visited in session; 0 otherwise |
| help_session_cnt | 1 if 'help' pages visited (/help path); 0 otherwise |
| dpp_find_session_cnt | 1 if DPP Find related pages visited (/dpp/find path); 0 otherwise |
| saw_cart_session_cnt | 1 if cart actions present (add-to-cart, checkout step 1) OR total GCR > 0; 0 otherwise |
| new_purchase_saw_cart_session_cnt | 1 if new purchase in checkout progress (step 1) OR new GCR > 0; 0 otherwise |
| renewal_saw_cart_session_cnt | 1 if renewal product in cart (checkout step 1) OR renewal GCR > 0; 0 otherwise |
| payment_success_session_cnt | 1 if payment made successfully (checkout step 4); 0 otherwise |
| transaction_session_cnt | 1 if any order present in session; 0 otherwise |
| new_transaction_session_cnt | 1 if new product present in session (order_new_product_unit_qty > 0); 0 otherwise |
| page_advance_session_cnt | 1 if page views > 1, OR content_group_2 like '%cart', OR GCR > 0; 0 otherwise |
| free_trial_session_cnt | 1 if free trial product present in session; 0 otherwise |
| dpp_serp_session_cnt | 1 if DPP or SERP related event present in session; 0 otherwise |
| new_purchase_dpp_session_cnt | 1 if DPP pages in purchase path AND new GCR > 0; 0 otherwise |
| gcr_session_cnt | 1 if session has GCR > 0 from orders; 0 otherwise |
| new_gcr_session_cnt | 1 if session has new purchase GCR > 0; 0 otherwise |
| renewal_gcr_session_cnt | 1 if session has renewal GCR > 0 (product_pnl_new_renewal_name = 'Renewal'); 0 otherwise |
| order_private_label_id | The PLID on the order. PLID 1 = GoDaddy; other PLIDs = resellers |
| order_gcr_usd_amt | GCR (Gross Cash Receipts) amount in USD from orders |
| order_new_gcr_usd_amt | New purchase GCR amount in USD |
| order_renewal_gcr_usd_amt | Renewal GCR amount in USD (product_pnl_new_renewal_name = 'Renewal') |
| order_ccgcr_usd_amt | Constant currency analog of order_gcr_usd_amt |
| order_new_ccgcr_usd_amt | Constant currency New GCR amount in USD |
| order_renewal_ccgcr_usd_amt | Constant currency Renewal GCR amount in USD |
| order_o365_order_cnt | Order count where product_pnl_line_name in ('MS Office 365', 'Value Adds') |
| order_o365_gcr_usd_amt | GCR amount where product_pnl_line_name in ('MS Office 365', 'Value Adds') |
| order_o365_new_gcr_usd_amt | New GCR amount where product_pnl_line_name in ('MS Office 365', 'Value Adds') |
| order_wsb_order_cnt | Order count for WSB (Website Builder / Websites and Marketing) products |
| order_wsb_free_order_cnt | Free trial order count for WSB products |
| order_wsb_freemat_order_cnt | FreeMAT order count for WSB products (subline='Freemat', free_trial=true) |
| order_wsb_freemium_order_cnt | Freemium order count for WSB products (subline='Freemium', free_trial=true) |
| order_pro_signup_order_cnt | Order count for Web Pro products (product_pnl_line_name='Web Pro') |
| web_customer_state_name | 'Existing Customer' or 'New Prospect' derived from session and order shopper metrics |
| web_customer_type_name | Customer type from session shopper (existing customer) or 'New Prospect' |
| web_focal_country_name | Focal country: session IP focal country → order focal country → 'Unknown' |
| web_region_2_name | Region 2: session IP region 2 → order region 2 → 'Unknown' |
| web_business_unit_name | 'Partner' (PLID≠1), 'Investor' (New Prospect+China), 'US Independent', 'International Independent' |
| total_page_view_qty | Total page views excluding virtual pages (from page-view events) |
| total_page_view_all_qty | Total page views including virtual pages |
| channel_grouping_name | Default Channel Group (attribution channel) per Channel Assignment Logic; 'Not Attributed' for unattributed orders |
| promo_click_list | Distinct promotions clicked (from click events, promotion.name) |
| promo_impression_list | Distinct promotions viewed (from impression events, promotion.name) |
| item_tracking_code_impression_list | Distinct ITCs from impression events (product.products[i].itemTrackingCode) |
| item_tracking_code_click_list | Distinct ITCs from click events |
| item_tracking_code_add_to_cart_list | Distinct ITCs from add-to-cart events |
| item_tracking_code_begin_checkout_list | Distinct ITCs from begin-checkout events (checkout.step=1) |
| item_tracking_code_payment_attempt_list | Distinct ITCs from payment attempt events (checkout.step=3) |
| purchase_path_impression_list | Distinct purchase paths from impression events (via ITC → item tracking group description) |
| purchase_path_click_list | Distinct purchase paths from click events |
| purchase_path_add_to_cart_list | Distinct purchase paths from add-to-cart events |
| purchase_path_begin_checkout_list | Distinct purchase paths from begin-checkout events (checkout.step=1) |
| purchase_path_payment_attempt_list | Distinct purchase paths from payment attempt events (checkout.step=3) |
| order_purchase_path_list | Distinct purchase paths from orders where paid purchase was made |

### 3.3 EDT - CSP Traffic EDS Design (Page 3318415788)

**Key points:**
- CSP (Customer Signal Platform) is the internal traffic capture system replacing Google Analytics (WADv1)
- Data flows: CSP page_view_event_cln → traffic_page_view (EDS) → WAD v2 aggregation
- Traffic session = identified by global.context.sessionId (GoDaddy's own sessionization, different from GA)
- visitor_id = GUID for browser/computer pair (global.context.visitorId)
- session_id = GUID for user session (global.context.sessionId)
- Page view sourced from `urn:shared:user:event:/data-platform/signals/page-view/v1`
- Events sourced from click, impression, add-to-cart, checkout-progress signal schemas
- Attribution data (source, medium, campaign, content, term, gclid) from page attribution clean layer

---

## 4. Alation Lookup

**Status:** UNAVAILABLE — Alation API access token could not be obtained due to expired refresh token. The `MOONUNIT_ALATION` environment variable's `refresh_token` is expired/revoked. No `ALATION_REFRESH_TOKEN` env var was found. Reference table column lookups and target table Alation metadata were therefore not retrievable.

---

## 5. Certified Data Dictionary Mappings

Alation Document Folder 6 was not accessible due to expired credentials. However, based on the Confluence design docs and column names, the following abbreviation expansions are used with high confidence:

| Abbreviation | Official Name | Source |
|---|---|---|
| GCR | Gross Cash Receipts | WAD v2 Design page (explicit: "GCR amount", "gcr_session_cnt: 1 if gcr >0 from uds_order") |
| ccGCR | Constant Currency Gross Cash Receipts | WAD v2 Design page (explicit: "Constant currency analog of order_gcr_usd_amt") |
| PLID | Private Label ID | WAD v2 Design page (explicit: "The PLID for GoDaddy is 1") |
| DPP | Domain Purchase Path | WAD v2 Design page (explicit: "purchase path is 'DPP'", "uds_order.purchase_path_name") |
| SERP | Search Engine Results Page | Standard industry term, confirmed by context |
| WSB | Website Builder / Websites and Marketing | WAD v2 Design page (explicit: "product_pnl_line_name ('Website Builder', 'Websites and Marketing')") |
| FOS | Front of Site | Confluence page (explicit: "Front of Site if godaddy.com") |
| SSO | Single Sign-On | Standard GoDaddy term |
| MYA | Manage Your Account | Standard GoDaddy term |
| LNDA | Last Non-Direct Attribution | Upstream table: `gd_traffic_session_last_nondirect_attribution` |
| ITC | Item Tracking Code | WAD v2 Design page (explicit: "product.products[i].itemTrackingCode") |
| EID | Event ID | WAD v2 Design page (explicit: "event_info_action (aka event_action or EID)") |
| CSP | Customer Signal Platform | Confluence EDS Design page |
| MST | Mountain Standard Time | DDL (session_mst_date, etc.) |
| DMA | Designated Marketing Area | DDL inline comment (ip_dma_number) |
| EDS | Enterprise Data Set | Standard GoDaddy term |
| WAD | Website Activity Detail | Confluence page titles |

---

## 6. Column-by-Column Analysis

### IDENTIFIED ISSUES IN CURRENT DDL

**CRITICAL BUG — `new_visit_session_cnt`:**
- **Current comment:** `'1 for sessions where add_to_cart events are present, 0 otherwise. NULL for unattributed orders'`
- **Correct meaning (from WAD v2 Design, row 118):** `1 if session is a new visit (visitorId = sessionId, first-ever visit); 0 otherwise; NULL for unattributed orders`
- **Root cause:** This appears to be a copy-paste error — the add_to_cart comment was accidentally duplicated from `add_to_cart_session_cnt`

### COLUMNS WITH SUFFICIENT EXISTING COMMENTS

Most columns have adequate comments. The following have clear, accurate descriptions:
- `website_activity_id`, `website_activity_mst_date`, `website_activity_exclusion_reason_desc`
- `visitor_id`, `session_id`, `session_flag`
- All `session_mst_*` / `session_end_mst_*` timestamp columns
- All `traffic_source_*` columns (though can be enhanced with source info)
- All `first_hit_*`, `second_hit_*`, `third_hit_*`, `last_hit_*` columns
- All `device_*` columns
- All `ip_*` geo columns
- All `market_site_*` columns
- All `order_*` count and GCR columns
- All consent flag columns
- `etl_build_utc_ts`

### COLUMNS THAT BENEFIT FROM ENRICHMENT

| Column | Current Comment | Recommended Enrichment |
|---|---|---|
| `website_activity_id` | 'Primary Key' | Add context: primary key, session_id for sessions or order_id for unattributed web orders |
| `new_visit_session_cnt` | WRONG — copy of add_to_cart comment | Fix to: 1 if new visit session (first-ever visitor, visitorId=sessionId); 0 for repeat visit; NULL for unattributed orders |
| `fos_session_name` | Good but expand FOS | Expand: 'Front of Site' if GoDaddy.com pages visited; 'Not Front of Site' otherwise |
| `sso_mya_visit_name` | Vague — expand SSO/MYA | Expand abbreviations: SSO=Single Sign-On, MYA=Manage Your Account |
| `session_type_name` | Good | Add source logic: buyer if order present; shopper if cart page visited; visitor otherwise |
| `traffic_source_campaign_name` | Brief | Add: derived from GCLID→Google Ads campaign map, DCM campaign tables, or utm_campaign |
| `traffic_source_keyword` | Brief | Add: set when medium is 'organic' or 'cpc', or via utm_term URL parameter |
| `traffic_source_referral_path` | Brief | Note: host name in traffic_source_name; path here when medium='referral' |
| `gclid_segment_utc_date` | Good | Keep as-is or add: UTC date used to join Google Ads click metrics (GCLID) |
| `add_to_cart_session_cnt` | Good | Keep |
| `new_visit_session_cnt` | **WRONG** | Fix |
| `saw_cart_session_cnt` | Brief | Expand: 1 if cart actions present (add-to-cart/checkout events) OR attributed GCR > 0 |
| `new_purchase_saw_cart_session_cnt` | Brief | Expand: 1 if new product in checkout process OR new GCR > 0 |
| `dpp_find_session_cnt` | Good | Keep, note DPP=Domain Purchase Path |
| `dpp_serp_session_cnt` | Good | Keep, note DPP=Domain Purchase Path, SERP=Search Engine Results Page |
| `new_purchase_dpp_session_cnt` | Brief | Expand: 1 if DPP (Domain Purchase Path) pages in purchase path AND new GCR > 0 |
| `page_advance_session_cnt` | Brief | Expand: 1 if page views > 1, or cart page visited, or GCR > 0 |
| `gcr_session_cnt` | Good | Keep, note GCR=Gross Cash Receipts |
| `new_gcr_session_cnt` | Good | Keep |
| `renewal_gcr_session_cnt` | Good | Keep |
| `order_private_label_id` | Brief (PLID) | Expand: PLID=Private Label ID; PLID 1 = GoDaddy; other PLIDs = reseller partners |
| `order_cnt` | Good | Keep |
| `order_gcr_usd_amt` | Good | Add GCR expansion |
| `order_new_gcr_usd_amt` | Good | Add GCR expansion |
| `order_renewal_gcr_usd_amt` | Good | Add GCR expansion |
| `order_ccgcr_usd_amt` | Good | Expand: ccGCR = Constant Currency Gross Cash Receipts |
| `order_new_ccgcr_usd_amt` | Brief | Expand ccGCR |
| `order_renewal_ccgcr_usd_amt` | Brief | Expand ccGCR |
| `order_o365_order_cnt` | Brief "o365" | Expand: Microsoft Office 365 (o365), includes MS Office 365 and Value Adds product lines |
| `order_o365_gcr_usd_amt` | Brief "o365" | Expand |
| `order_o365_new_gcr_usd_amt` | Brief "o365" | Expand |
| `order_wsb_order_cnt` | Brief "WSB" | Expand: WSB = Website Builder / Websites and Marketing |
| `order_wsb_free_order_cnt` | Brief | Expand WSB |
| `order_wsb_freemat_order_cnt` | Brief "freemat" | Expand: FreeMAT = free marketing trial type |
| `order_wsb_freemium_order_cnt` | Brief | Expand: freemium product sub-type |
| `order_wsb_gcr_usd_amt` | Brief | Expand WSB + GCR |
| `order_wsb_new_gcr_usd_amt` | Brief | Expand |
| `order_pro_signup_order_cnt` | Brief | Keep, expand: Web Pro product line |
| `web_customer_state_name` | Brief | Add values: 'Existing Customer' or 'New Prospect' |
| `web_customer_type_name` | Brief | Add: 'Existing Customer' types or 'New Prospect' if no prior order |
| `web_business_unit_name` | Good | Keep with values: Partner, Investor, US Independent, International Independent |
| `web_focal_country_name` | Brief | Expand: derived from session IP geo or order geo (IP focal country, else order focal country) |
| `web_region_2_name` | Brief | Expand: from IP geo or order geo, in that order |
| `shopper_id_list` | Good | Keep |
| `session_customer_type_list` | Good | Keep |
| `event_list` | Good: 'List of all distinct EIDs' | Keep, note EID=Event ID |
| `original_session_id_list` | Good | Keep |
| `traffic_origin_name` | Good | Keep: CSP or EFD origins |
| `consent_marketing_flag` | Good | Expand: required for advertising/marketing use (serving personalized ads, building audiences) |
| `consent_analytics_flag` | Good | Expand: required for analytics/performance use (session recording, model training) |
| `consent_support_flag` | Good | Expand: required for delivering 3rd party support services |

---

## 7. Consent Flag Notes (from Consumer Responsibilities page)

Critical compliance context for downstream users:

- **consent_analytics_flag**: Must be True to use data for Performance/Analytics purposes (non-aggregate session-level analysis, session recording, ML model training on individual sessions).
- **consent_marketing_flag**: Must be True to use data for Advertising purposes (building audiences, serving personalized ads, Salesforce segment loading).
- **consent_support_flag**: Must be True to use data for 3rd-party support services on GoDaddy's website.
- **Essential use** does NOT require consent filtering: aggregate metrics (hivemind), fraud detection, identity verification, service continuity defect investigation.


**The agent's final response to the user was:**
Here is a summary of the research conducted:

---

## Research Summary

### Target Table
`gd_traffic_mart.analytic_traffic_detail` — an analytic dataset combining CSP (Customer Signal Platform) traffic session data with order/GCR metrics. Data Tier 1, delivered daily by 10:30 AM MST.

### DDL Review
- 187 columns covering: session identifiers, traffic attribution, page view sequences, device/geo dimensions, session behavioral metrics (cart, purchase, help, etc.), order GCR metrics by product line, shopper/customer attributes, consent flags, and ETL metadata.
- Most existing COMMENT annotations are reasonable but terse.

### Confluence Findings (3 pages fetched)
1. **EDT - Traffic Data Consumer Responsibilities**: Documents the three consent flags (`consent_analytics_flag`, `consent_marketing_flag`, `consent_support_flag`) and their required use cases. Critical compliance context for all downstream consumers of WADv2 data.
2. **EDT - WAD v2 Design**: Full column-by-column design specification with data sources, derivation logic, and business definitions for all ~100+ columns. Rich source of enrichment content.
3. **EDT - CSP Traffic EDS Design**: Architecture context for how CSP traffic events are captured and flow into WAD v2.

### Alation Status
**Unavailable** — the refresh token in `MOONUNIT_ALATION` is expired/revoked. Neither target table metadata nor reference table column descriptions could be fetched.

### Key Finding: Bug in DDL
`new_visit_session_cnt` has an **incorrect comment** — it's a copy-paste of the `add_to_cart_session_cnt` description. Per WAD v2 Design, it should indicate a new/first-time visitor session (visitorId = sessionId).

### Certified Data Dictionary Mappings
Compiled from Confluence context (Alation folder unavailable): GCR=Gross Cash Receipts, ccGCR=Constant Currency Gross Cash Receipts, DPP=Domain Purchase Path, WSB=Website Builder/Websites and Marketing, PLID=Private Label ID, FOS=Front of Site, LNDA=Last Non-Direct Attribution, ITC=Item Tracking Code, EID=Event ID, CSP=Customer Signal Platform.