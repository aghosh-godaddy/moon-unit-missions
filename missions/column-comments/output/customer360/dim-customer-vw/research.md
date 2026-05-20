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

## Research Summary: customer360.dim_customer_vw

**Date:** 2026-05-20  
**Analyst:** Data Governance Research Stage

---

## 1. Current DDL

```sql
CREATE TABLE dim_customer_vw(
    customer_id                 string COMMENT '@PrimaryKey Unique UUID representing the customer entity across GoDaddy systems',
    shopper_id                  string COMMENT '@UniqueKey Unique numeric ID for the shopper profile used in eCommerce transactions',
    external_reseller_customer_id int COMMENT 'Customer identifier provided by an external reseller system',
    federation_partner_id       string COMMENT 'Federation partner identifier (FPID) used for partner-scoped authorization',
    federation_partner_name     string COMMENT 'Brand name associated with the federation partner ID (FPID)',
    parent_customer_id          string COMMENT 'Customer identifier used as the parent customer in hierarchy',
    parent_shopper_id           string COMMENT 'Shopper identifier used as the parent shopper in hierarchy',
    private_label_id            int COMMENT 'Private label identifier associated with the customer profile',
    company_flag                boolean COMMENT 'True if customer is classified as a company account',
    internal_shopper_flag       boolean COMMENT 'True if shopper is classified as an internal account',
    temporary_shopper_flag      boolean COMMENT 'True if shopper is classified as temporary',
    closed_shopper_flag         boolean COMMENT 'True if shopper account is closed',
    city_name                   string COMMENT 'City from customer profile',
    state_code                  string COMMENT 'State or province code from customer profile',
    zip_code                    string COMMENT 'Postal or ZIP code from customer profile',
    country_code                string COMMENT 'Country code from customer profile',
    email_domain_name           string COMMENT 'Domain portion of the customer email address',
    email_hash                  string COMMENT 'Hashed customer email value',
    primary_phone_flag          boolean COMMENT 'True if a primary phone number is available for customer',
    mobile_phone_flag           boolean COMMENT 'True if a mobile phone number is available for customer',
    secondary_phone_flag        boolean COMMENT 'True if a secondary phone number is available for customer',
    default_currency_code       string COMMENT 'Default currency code associated with the customer',
    market_code                 string COMMENT 'Market identifier associated with the customer',
    created_mst_ts              timestamp COMMENT 'MST timestamp when customer profile was created',
    updated_mst_ts              timestamp COMMENT 'MST timestamp when customer profile was last updated',
    closed_mst_ts               timestamp COMMENT 'MST timestamp when shopper account was closed',
    deleted_mst_ts              timestamp COMMENT 'MST timestamp when customer was closed or deleted',
    current_record_flag         boolean COMMENT 'True if record is the current active customer record',
    etl_build_mst_ts            timestamp COMMENT 'MST timestamp when this record was built by ETL system'
);
```

---

## 2. Table YAML Metadata

- **Description:** "shopper and profile data in customer360"
- **Table type:** ICEBERG (SCD2 Slowly Changing Dimension Type 2)
- **Storage format:** Parquet
- **Data tier:** 2
- **SLA:** Daily refresh by 3 AM MST (cron: `00 10 * * ? *` UTC)
- **SLO identifier:** `customer360.dim_customer_vw`
- **Underlying table:** `dim_customer_v2`
- **Upstream dependencies (lineage):**
  - `global_profile_service_cln.profile_snapshot`
  - `fortknox.fortknox_shopper_snap`
  - `godaddy.rp_salesmonitor_internalshopper_snap`
  - `customers.customer_id_mapping_snapshot`
- **Row-level filter applied for consumers:** `current_record_flag = true` (SCD2 current-record filter)

---

## 3. Confluence Page Findings

### Page 3779199819 — Customer360 (Main Overview)

Customer360 is the foundational data product for GoDaddy's customer domain. It provides a trusted, unified view of customers for analytics, reporting, and data science.

**dim_customer_vw specific notes:**
- Described as the **Customer Master Dataset** — conformed customer profiles with consistent identifiers and enriched attributes.
- **Adds SCD2** for full customer history (over the deprecated fortknox snapshots).
- New attributes include: flags on whether phone/email exists, internal & closed accounts.
- **Replaces (deprecated):** `fortknox.fortknox_shopper_snap`, `fortknox.fortknox_shopperaudit_filter1_snap`, `fortknox_secure.fortknox_shopperaudit_filter1_snap`, `marketing_mart.customer`, `marketing_mart.marketable_customer`
- **Recommended over:** `signals_platform_cln.profile_audit_lake_cln`, `global_profile_service_cln.profile_snapshot`
- Consumers are recommended to use Customer360 for all customer attribute lookups, barring specific hour-latency requirements.

### Page 3780706383 — Customer Master Data (Design Doc)

This is the detailed design document for dim_customer_vw. Contains the Physical Data Model and per-column definitions.

**Schema DB: customer_core_conformed.dim_customer** (design name; deployed as customer360.dim_customer_vw)

| # | Column | Data Source(s) | Design Description / Business Logic |
|---|--------|----------------|--------------------------------------|
| 1 | customer_id | customers.customer_id_mapping_snapshot.customer_id; global_profile_service_cln.profile_snapshot.customer_id where profile_type='Account' | Customer ID — the canonical GoDaddy UUID for the customer entity |
| 2 | shopper_id | customers.customer_id_mapping_snapshot (type='shopper'); fortknox.fortknox_shopper_snap.shopper_id | Shopper ID — legacy numeric eCommerce identifier |
| 3 | external_reseller_customer_id | fortknox.fortknox_shopper_snap.externalid | External reseller customer ID |
| 4 | federation_partner_id | sso_permissions_cln.identity_mapping_snapshot_cln JOIN sso_metadata_cln.federation_metadata_snapshot_cln ON namespace_id=federation_partner_id WHERE namespace_type='FPID' AND internal_type='CUSTOMER_ID' | Federation Partner ID (FPID) for partner-scoped authorization |
| 5 | federation_partner_name | sso_permissions_cln + sso_metadata_cln | Brand name associated with the federation partner |
| 6 | parent_customer_id | customers.customer_id_mapping_snapshot.customer_id | Parent customer ID — identifies delegated/sub-account hierarchy |
| 7 | parent_shopper_id | fortknox.fortknox_shopper_snap.parent_shopper_id | Parent shopper ID — see gdshop_usertypeid (userTypeID==3 = parentShopperId != null) |
| 8 | private_label_id | global_profile_service_cln.profile_snapshot.private_label_id; fortknox.fortknox_shopper_snap.privatelabelid | Private label ID — aka reseller ID |
| 9 | company_flag | profile_snapshot.organization IS NOT NULL OR fortknox.iscompany | Is this shopper a company? True if Organization field is not NULL |
| 10 | internal_shopper_flag | godaddy.rp_salesmonitor_internalshopper_snap.shopper_id; fortknox.fortknox_shopper_snap.shopper_id | Is this an internal GoDaddy shopper? True if 3-letter account or in rp_salesmonitor_internalshopper (Internal Shopper Exclusions list) |
| 11 | temporary_shopper_flag | fortknox.fortknox_shopper_snap.email_hash IS NULL | Is this a temporary shopper? True if no email address (email_hash is NULL) |
| 12 | closed_shopper_flag | fortknox.fortknox_shopper_snap.closed_date IS NOT NULL OR deleted_date IS NOT NULL | Is this a closed shopper? True if closed_date or deleted_date is not NULL |
| 13 | city_name | fortknox.fortknox_shopper_snap.city | City name from customer address |
| 14 | state_code | global_profile_service_cln.profile_snapshot.state_name; fortknox.fortknox_shopper_snap.state | State or province code from customer address |
| 15 | zip_code | fortknox.fortknox_shopper_snap.zip | Postal/ZIP code — for UK postal codes, only the outward code (first half) is retained |
| 16 | country_code | global_profile_service_cln.profile_snapshot.country_name; fortknox.fortknox_shopper_snap.country | Country code from customer address |
| 17 | email_domain_name | global_profile_service_cln.profile_snapshot.email_domain; fortknox.fortknox_shopper_snap.emaildomain | Domain portion of customer email address |
| 18 | email_hash | global_profile_service_cln.profile_snapshot.email_hash; fortknox.fortknox_shopper_snap.emailhash | Hashed email address value |
| 19 | primary_phone_flag | fortknox.fortknox_shopper_snap.primary_phone_flag | True if primary phone number is available |
| 20 | mobile_phone_flag | fortknox.fortknox_shopper_snap.mobile_phone_flag | True if mobile phone number is available |
| 21 | secondary_phone_flag | fortknox.fortknox_shopper_snap.secondary_phone_flag | True if home/secondary phone number is available |
| 22 | default_currency_code | global_profile_service_cln.profile_snapshot.currency_code; fortknox.fortknox_shopper_snap.gdshop_currencytype | Default currency for this shopper |
| 23 | market_code | global_profile_service_cln.profile_snapshot.market_id; fortknox.fortknox_shopper_snap.catalog_marketid | Market identifier for this shopper |
| 24 | created_mst_ts | fortknox.fortknox_shopper_snap.date_created | Account creation timestamp |
| 25 | updated_mst_ts | fortknox.fortknox_shopper_snap.last_changed_date | Last profile update timestamp |
| 26 | closed_mst_ts | fortknox.fortknox_shopper_snap.closed_date | Account closed timestamp |
| 27 | deleted_mst_ts | fortknox.fortknox_shopper_snap.deleted_date | Account deleted timestamp |
| 28 | current_record_flag | (SCD2 control column) | True if this is the current active SCD2 record for the customer |
| 29 | etl_build_mst_ts | (ETL control column) | MST timestamp when this record was built by the ETL pipeline |

**Key design notes from Confluence:**
- Customer Master Data does NOT depend on transactional data.
- `customers.customer_id_mapping_snapshot` is the **source of truth** for Customer ID (per the Identify team).
- 15% of customer_id are NULLs in `fortknox.fortknox_shopper_snap` — this is a known data quirk.
- PII fields: full name, address details, organization name, email, phone numbers.
- `state_code` sourced from `state_name` field in upstream; stored as code/abbreviation in dim_customer_vw.
- The closed shoppers count was approximately 3.4 million as of 2025-03-03.
- `temporary_shopper_flag = true` when `email_hash IS NULL` in fortknox.

---

## 4. Alation Lookup

**Status: FAILED — Refresh token expired/revoked**

Attempted to retrieve Alation API access token using `MOONUNIT_ALATION` credentials (user_id=213).  
Response: `{"detail":"Refresh token provided is expired or revoked.","code":"401000"}`

The following data could NOT be retrieved:
- Target table Alation column metadata (target table dim_customer_vw)
- Reference table columns for `customer360.customer_life_cycle_vw` (Alation table_id: 7038345)
- Certified Data Dictionary (Document Folder ID 6)

---

## 5. Certified Data Dictionary Mappings

Alation was unavailable (token expired). The Certified Data Dictionary could not be fetched.

Abbreviations found in column names for this table:

| Abbreviation | Context | Official Name | Source |
|---|---|---|---|
| mst_ts | Timestamp suffix (e.g., created_mst_ts) | Mountain Standard Time timestamp | Inferred from column context — standard GoDaddy Data Lake convention |
| etl | etl_build_mst_ts | Extract, Transform, Load | Standard industry acronym |
| vw | Table name suffix (dim_customer_vw) | View/Virtual table | Standard GoDaddy naming convention |
| fpid | federation_partner_id description | Federation Partner ID | Confirmed by Confluence Customer Master Data design doc |
| scd2 | Table design (not in column name) | Slowly Changing Dimension Type 2 | Confirmed by Customer360 Confluence page |

No GCR, MRR, NRU, MAU, or other financial/metric abbreviations appear in column names for this table.

---

## 6. Per-Column Analysis

### Identity Columns

| Column | Type | Current DDL Comment | Confluence Description | Business Logic | Enrichment Notes |
|--------|------|---------------------|------------------------|----------------|------------------|
| customer_id | string | `@PrimaryKey Unique UUID representing the customer entity across GoDaddy systems` | "Customer ID" — sourced from customer_id_mapping_snapshot (source of truth) and profile_snapshot (profile_type='Account') | Primary/natural key for the customer entity (UUID format); canonical across all GoDaddy systems | Current comment is good. Could add: source of truth is customers.customer_id_mapping_snapshot per Identify team. @PrimaryKey annotation must be preserved. |
| shopper_id | string | `@UniqueKey Unique numeric ID for the shopper profile used in eCommerce transactions` | "Shopper ID" — legacy numeric eCommerce identifier | Unique numeric identifier for the shopper profile in FortKnox/eCommerce systems | Current comment is good. @UniqueKey annotation must be preserved. |
| external_reseller_customer_id | int | `Customer identifier provided by an external reseller system` | "External reseller customer ID" — sourced from fortknox.fortknox_shopper_snap.externalid | Customer ID assigned by an external reseller (not a GoDaddy internal ID) | Current comment is accurate. Could be enhanced with data source note. |
| federation_partner_id | string | `Federation partner identifier (FPID) used for partner-scoped authorization` | FPID; sourced via sso_permissions_cln + sso_metadata_cln JOIN | Partner ID for federated identity; identifies which federation partner (e.g., brand/reseller) the customer is associated with | Current comment is good. FPID acronym expansion is confirmed by Confluence. |
| federation_partner_name | string | `Brand name associated with the federation partner ID (FPID)` | Brand name associated with the federation partner | Display name for the federation partner | Current comment is good. |

### Hierarchy Columns

| Column | Type | Current DDL Comment | Confluence Description | Business Logic | Enrichment Notes |
|--------|------|---------------------|------------------------|----------------|------------------|
| parent_customer_id | string | `Customer identifier used as the parent customer in hierarchy` | "Parent customer ID" — from customer_id_mapping_snapshot | UUID of the parent customer in delegated account hierarchy | Current comment is good; Confluence confirms it's for hierarchical/delegated accounts. |
| parent_shopper_id | string | `Shopper identifier used as the parent shopper in hierarchy` | "Parent shopper ID" — from fortknox.parent_shopper_id; note: userTypeID==3 equivalent to parentShopperId != null | Legacy shopper ID for parent account | Current comment is good. |
| private_label_id | int | `Private label identifier associated with the customer profile` | "Private label ID (aka reseller ID)" — from profile_snapshot.private_label_id or fortknox.privatelabelid | Numeric ID for the reseller/white-label brand the customer belongs to | Could be enhanced: "Private label identifier (reseller ID) — identifies the white-label brand or reseller channel associated with the customer." |

### Flag Columns

| Column | Type | Current DDL Comment | Confluence Description | Business Logic | Enrichment Notes |
|--------|------|---------------------|------------------------|----------------|------------------|
| company_flag | boolean | `True if customer is classified as a company account` | "Is this shopper a company? True if Organization is not NULL" | Derived from organization field in profile_snapshot or fortknox.iscompany | Current comment is good. Could add: derived from organization field being non-NULL. |
| internal_shopper_flag | boolean | `True if shopper is classified as an internal account` | "True if 3-letter account, or in rp_salesmonitor_internalshopper (Internal Shopper Exclusions)" | GoDaddy employee/internal accounts; used for exclusion in customer analytics | Could be enriched: "True if shopper is a GoDaddy internal account (3-letter accounts or listed in the Internal Shopper Exclusions registry)." |
| temporary_shopper_flag | boolean | `True if shopper is classified as temporary` | "True if no email address (email_hash is NULL)" | Guest/anonymous shoppers without an email address on file | Should be enriched: "True if shopper has no email address on file (email_hash is NULL); indicates a temporary or guest account." |
| closed_shopper_flag | boolean | `True if shopper account is closed` | "True if closed_date is not NULL OR deleted_date is not NULL" | Marks deactivated or deleted accounts | Could be enriched: "True if the shopper account has been closed or deleted (closed_date or deleted_date is not NULL)." |

### Address Columns

| Column | Type | Current DDL Comment | Confluence | Business Logic | Enrichment Notes |
|--------|------|---------------------|------------|----------------|------------------|
| city_name | string | `City from customer profile` | "The city name of customer address" from fortknox.city | City name on the customer's registered address | Slightly thin. Could say: "City name from the customer's registered address profile." |
| state_code | string | `State or province code from customer profile` | "State name of customer address" from profile_snapshot.state_name or fortknox.state | State or province code/abbreviation; sourced as state_name from upstream, stored as code | Current comment is accurate. |
| zip_code | string | `Postal or ZIP code from customer profile` | "Zip code of customer address — for UK postal codes, only the outward code (first half) is retained" | Postal code; UK addresses: outward code only (e.g. 'SW1A' not 'SW1A 1AA') | Could be enriched: "Postal or ZIP code from the customer's registered address. For UK addresses, only the outward code (first half) is stored." |
| country_code | string | `Country code from customer profile` | "Country code of customer address" from profile_snapshot.country_name or fortknox.country | ISO country code for the customer's address | Current comment is good. |

### Email Columns

| Column | Type | Current DDL Comment | Confluence | Business Logic | Enrichment Notes |
|--------|------|---------------------|------------|----------------|------------------|
| email_domain_name | string | `Domain portion of the customer email address` | "Email address domain name" from profile_snapshot.email_domain or fortknox.emaildomain | The domain part of the email (e.g. 'gmail.com') — full address is PII and not stored | Current comment is good. |
| email_hash | string | `Hashed customer email value` | "Email address hash value" from profile_snapshot.email_hash or fortknox.emailhash | SHA/MD5 hash of the email address for identity matching without exposing PII | Current comment is good. Note: NULL email_hash => temporary_shopper_flag=true |

### Phone Columns

| Column | Type | Current DDL Comment | Confluence | Business Logic | Enrichment Notes |
|--------|------|---------------------|------------|----------------|------------------|
| primary_phone_flag | boolean | `True if a primary phone number is available for customer` | "True if primary phone number is available" — from fortknox.primary_phone_flag | Indicates whether a primary phone is on file; used for contactability | Current comment is good. |
| mobile_phone_flag | boolean | `True if a mobile phone number is available for customer` | "True if mobile phone number is available" — from fortknox.mobile_phone_flag | Indicates whether a mobile/cell phone is on file | Current comment is good. |
| secondary_phone_flag | boolean | `True if a secondary phone number is available for customer` | "True if home/secondary phone number is available" — from fortknox.secondary_phone_flag | Indicates whether a secondary/home phone is on file | Current comment is good. Confluence calls it "home phone" — could add that context. |

### Currency and Market Columns

| Column | Type | Current DDL Comment | Confluence | Business Logic | Enrichment Notes |
|--------|------|---------------------|------------|----------------|------------------|
| default_currency_code | string | `Default currency code associated with the customer` | "Default currency of this shopper" from profile_snapshot.currency_code or fortknox.gdshop_currencytype | ISO currency code (e.g. 'USD', 'EUR') for the customer's default payment currency | Current comment is good. |
| market_code | string | `Market identifier associated with the customer` | "Market of this shopper" from profile_snapshot.market_id or fortknox.catalog_marketid | GoDaddy market code (e.g. 'godaddy.com', locale-based) for the customer's market/storefront | Current comment is functional but could clarify "market" = GoDaddy storefront/locale market |

### Timestamp Columns

| Column | Type | Current DDL Comment | Confluence | Business Logic | Enrichment Notes |
|--------|------|---------------------|------------|----------------|------------------|
| created_mst_ts | timestamp | `MST timestamp when customer profile was created` | from fortknox.fortknox_shopper_snap.date_created | The date the shopper account was originally created | Current comment is good. |
| updated_mst_ts | timestamp | `MST timestamp when customer profile was last updated` | from fortknox.fortknox_shopper_snap.last_changed_date | The date the shopper record was last modified | Current comment is good. |
| closed_mst_ts | timestamp | `MST timestamp when shopper account was closed` | from fortknox.fortknox_shopper_snap.closed_date | The date the shopper account was closed (NULL if not closed) | Current comment is good. |
| deleted_mst_ts | timestamp | `MST timestamp when customer was closed or deleted` | from fortknox.fortknox_shopper_snap.deleted_date | The date the customer was deleted (NULL if not deleted) | Note: the current DDL comment says "closed or deleted" but the column is specifically for the deleted_date source, not closed_date. Should be clarified. |

### SCD2 / ETL Control Columns

| Column | Type | Current DDL Comment | Business Logic | Enrichment Notes |
|--------|------|---------------------|----------------|------------------|
| current_record_flag | boolean | `True if record is the current active customer record` | SCD2 control flag — when true, this is the latest version of the customer record. Consumers are filtered to current_record_flag=true by default via Lake Formation row filter. | Current comment is functional; could note SCD2 context. |
| etl_build_mst_ts | timestamp | `MST timestamp when this record was built by ETL system` | Pipeline audit field — MST timestamp this record row was constructed by the ETL job | Current comment is good. |

---

## 7. Summary of Recommended Enrichments

The existing DDL comments are generally well-written and accurate. Key enrichment opportunities:

1. **temporary_shopper_flag**: Add the business rule "True if no email address on file (email_hash is NULL); indicates a guest or anonymous account."
2. **internal_shopper_flag**: Clarify the definition — "True if shopper is a GoDaddy-internal account (3-letter accounts or listed in the Internal Shopper Exclusion registry)."
3. **closed_shopper_flag**: Add the derivation logic — "True if closed_date or deleted_date is not NULL in the source FortKnox system."
4. **zip_code**: Note UK postal code truncation — outward code only for UK addresses.
5. **private_label_id**: Clarify it is also known as the reseller ID.
6. **deleted_mst_ts**: Current comment says "closed or deleted" but this column specifically tracks the deletion date (not closure date, which is closed_mst_ts).
7. **secondary_phone_flag**: Confluence uses "home / secondary phone" — could add "home phone" as an alias.
8. **current_record_flag**: Could note the SCD2 context — "True for the current version of the customer record in this SCD2 table."


**The agent's final response to the user was:**
Here is a summary of the research conducted for the `customer360.dim_customer_vw` enrichment task:

## Research Summary

### Sources Consulted

1. **DDL file** (`catalog/config/prod/dlms-api/us-west-2/customer360/dim-customer-vw/table.ddl`) — 30 columns, all with existing comments. Table is an SCD2 Iceberg table.

2. **YAML metadata** — Table described as "shopper and profile data in customer360", Tier 2, daily refresh by 3 AM MST. Upstream dependencies: `global_profile_service_cln.profile_snapshot`, `fortknox.fortknox_shopper_snap`, `godaddy.rp_salesmonitor_internalshopper_snap`, `customers.customer_id_mapping_snapshot`.

3. **Confluence page 3779199819** (Customer360 Overview) — Confirmed dim_customer_vw is the Customer Master Dataset, adds SCD2 history over deprecated FortKnox snapshots, and replaces `marketing_mart.customer` and multiple FortKnox tables.

4. **Confluence page 3780706383** (Customer Master Data Design Doc) — Detailed per-column definitions, data sources, and business logic for all 30 columns, including PII classifications, derivation rules for flag columns, and data quirks (UK postal code truncation, temporary shoppers = NULL email hash, 15% NULL customer_id in FortKnox).

5. **Alation** — **Not available**: Refresh token was expired/revoked. No column metadata, reference table data, or Certified Data Dictionary could be retrieved.

### Key Findings for Enrichment

The existing DDL comments are generally solid. The most important enrichment opportunities identified:
- **`temporary_shopper_flag`**: Missing business rule (True when `email_hash IS NULL`)
- **`internal_shopper_flag`**: Should clarify "3-letter accounts or Internal Shopper Exclusion registry"
- **`closed_shopper_flag`**: Should note derivation from `closed_date OR deleted_date IS NOT NULL`
- **`deleted_mst_ts`**: Current comment incorrectly says "closed or deleted" — it specifically tracks deletion date
- **`zip_code`**: Should note UK outward-code-only truncation
- **`private_label_id`**: Confluence confirms it is also known as the reseller ID