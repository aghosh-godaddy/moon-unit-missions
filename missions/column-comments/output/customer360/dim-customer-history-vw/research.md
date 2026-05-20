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

## Target Table

**Database:** customer360  
**Table:** dim_customer_history_vw  
**DDL Path:** catalog/config/prod/dlms-api/us-west-2/customer360/dim-customer-history-vw/table.ddl  
**YAML Path:** catalog/config/prod/dlms-api/us-west-2/customer360/dim-customer-history-vw/table.yaml

---

## Full DDL

```sql
CREATE TABLE dim_customer_history_vw(
    customer_id                 string COMMENT 'Primary key',
    shopper_id                  string,
    external_reseller_customer_id int,
    federation_partner_id       string COMMENT 'federation partner id (fpid) was created to group users for the purposes of scoping the authorization of acquired brand-to-GoDaddy federation partner',
    federation_partner_name     string COMMENT 'brand name associated with a federation partner ID (FPID)',
    parent_customer_id          string,
    parent_shopper_id           string,
    private_label_id            int,
    company_flag                boolean,
    internal_shopper_flag       boolean,
    temporary_shopper_flag      boolean,
    closed_shopper_flag         boolean,
    city_name                   string,
    state_code                  string,
    zip_code                    string,
    country_code                string,
    email_domain_name           string,
    email_hash                  string,
    primary_phone_flag          boolean,
    mobile_phone_flag           boolean,
    secondary_phone_flag        boolean,
    default_currency_code       string,
    market_code                 string,
    created_mst_ts              timestamp,
    updated_mst_ts              timestamp,
    closed_mst_ts               timestamp,
    deleted_mst_ts              timestamp,
    effective_start_mst_ts      timestamp,
    effective_end_mst_ts        timestamp,
    current_record_flag         boolean,
    etl_build_mst_ts            timestamp,
    etl_insert_mst_ts           timestamp,
    etl_update_mst_ts           timestamp
);
```

---

## Table YAML Metadata

- **Description:** "shopper and profile data in customer360"
- **Storage Format:** Parquet
- **Table Type:** ICEBERG
- **Data Tier:** 2
- **Table Relative Path:** dim_customer_v2
- **SLA:** Airflow job delivers delta table refresh by 3 AM MST daily (cron 10:00 UTC)
- **Upstream Dependencies:**
  - global_profile_service_cln.profile_snapshot
  - fortknox.fortknox_shopper_snap
  - godaddy.rp_salesmonitor_internalshopper_snap
  - customers.customer_id_mapping_snapshot

---

## Confluence Page: Customer360 (Page ID 3779199819)

**Summary of relevant content:**

Customer360 is GoDaddy's first foundational data product establishing an end-to-end physical architecture. It provides a trusted, unified view of customers for analytics, reporting, and data science.

### dim_customer_history_vw specific context:
- Listed as the **Customer Master Dataset** component.
- **Adds SCD2 for full customer history** — this is a Slowly Changing Dimension Type 2 view that tracks all historical states of a customer record, with `effective_start_mst_ts` / `effective_end_mst_ts` / `current_record_flag` as SCD2 columns.
- Adds additional attributes: **flags on whether phone/email exists**, **internal & closed accounts**.
- Replaces (deprecated): fortknox.fortknox_shopper_snap, fortknox.fortknox_shopperaudit_filter1_snap, fortknox_secure.fortknox_shopperaudit_filter1_snap, marketing_mart.customer, marketing_mart.marketable_customer.
- Provides feature parity with the "1800 360 dataset" and dim_customer_vw.
- Upstream clean sources: signals_platform_cln.profile_audit_lake_cln, global_profile_service_cln.profile_snapshot.

### Key architecture notes:
- Customer attributes were previously spread across 10+ databases (finance_cln, customer_mart, enterprise, analytic_feature, marketing_mart, etc.).
- Customer360 is the single certified layer owned by FORGE.
- Uses Iceberg and SCD2 modeling to eliminate redundant snapshots.
- Daily refresh cadence; data delivered by 3 AM MST.

### Consumer domains: customer_analytics, edt, finance_data_mart, martech_data, revenue_and_relevance, dri_data, analytics.

---

## Alation Lookup

**Status: FAILED — Refresh token expired/revoked.**  
The Alation API returned `{"detail":"Refresh token provided is expired or revoked.","code":"401000"}` for both the MOONUNIT_ALATION refresh_token and the ALATION_REFRESH_TOKEN env var (empty). No Alation column metadata (description, column_comment) could be retrieved for the target table, reference tables (dim_customer_vw id=7022291, customer_life_cycle_vw id=7038345), or the Certified Data Dictionary (Folder 6).

---

## Certified Data Dictionary Mappings

Unable to fetch from Alation (token expired). No certified abbreviation expansions available from Folder 6.

Abbreviations found in column names — inferred from GoDaddy domain knowledge:

| Abbreviation | Inferred Meaning | Source | Confidence |
|---|---|---|---|
| FPID | Federation Partner ID | DDL comment explicit | High |
| MST | Mountain Standard Time | GoDaddy standard timestamp suffix | High |
| ETL | Extract, Transform, Load | Universal data engineering standard | High |
| SCD2 | Slowly Changing Dimension Type 2 | Confluence page explicit | High |
| PL | Private Label | GoDaddy white-label channel program | High |

---

## Per-Column Research Notes

### Identity & Key Columns

| Column | Type | DDL Comment | Inferred Purpose | Notes |
|---|---|---|---|---|
| customer_id | string | 'Primary key' | Surrogate/unique key for a customer in the Customer360 domain | SCD2 primary key; stable across history versions |
| shopper_id | string | (none) | Legacy shopper identifier; GoDaddy's historical term for a customer account | Maps to fortknox.fortknox_shopper_snap shopper_id |
| external_reseller_customer_id | int | (none) | Customer ID assigned by an external reseller or partner channel | Used for reseller/white-label channel attribution |

### Federation / Brand Columns

| Column | Type | DDL Comment | Inferred Purpose |
|---|---|---|---|
| federation_partner_id | string | 'federation partner id (fpid) was created to group users for the purposes of scoping the authorization of acquired brand-to-GoDaddy federation partner' | Numeric ID grouping users under an acquired brand federation (e.g., 123Reg, Heart Internet) |
| federation_partner_name | string | 'brand name associated with a federation partner ID (FPID)' | Human-readable brand name for the federation partner (e.g., "123Reg") |

### Hierarchy Columns

| Column | Type | DDL Comment | Inferred Purpose |
|---|---|---|---|
| parent_customer_id | string | (none) | customer_id of the parent account (reseller, agency, or corporate hierarchy) |
| parent_shopper_id | string | (none) | shopper_id of the parent account; legacy identifier for hierarchy traversal |
| private_label_id | int | (none) | Identifies the private-label (white-label) channel through which the customer was acquired; links to GoDaddy's reseller program |

### Status/Flag Columns

| Column | Type | DDL Comment | Inferred Purpose |
|---|---|---|---|
| company_flag | boolean | (none) | True if the account is registered as a company/business entity rather than an individual |
| internal_shopper_flag | boolean | (none) | True if the shopper is an internal GoDaddy employee or test account; used to exclude internal traffic from analytics |
| temporary_shopper_flag | boolean | (none) | True if the shopper account is temporary (e.g., created for a single transaction) |
| closed_shopper_flag | boolean | (none) | True if the shopper account has been closed/deactivated; corresponds to closed_mst_ts |

### Geographic / Location Columns

| Column | Type | DDL Comment | Inferred Purpose |
|---|---|---|---|
| city_name | string | (none) | City from the customer's billing or profile address |
| state_code | string | (none) | State or province code from the customer's billing or profile address |
| zip_code | string | (none) | Postal/ZIP code from the customer's billing or profile address |
| country_code | string | (none) | ISO 3166-1 alpha-2 country code from the customer's billing or profile address |

### Contact Columns

| Column | Type | DDL Comment | Inferred Purpose |
|---|---|---|---|
| email_domain_name | string | (none) | Domain portion of the customer's primary email address (e.g., 'gmail.com'); partial email retained for analytics while suppressing PII |
| email_hash | string | (none) | Hashed value of the customer's primary email address; used for privacy-preserving identity resolution and cross-system joins |
| primary_phone_flag | boolean | (none) | True if the customer has a primary phone number on file (Confluence: "flags on whether phone/email exists") |
| mobile_phone_flag | boolean | (none) | True if the customer has a mobile phone number on file |
| secondary_phone_flag | boolean | (none) | True if the customer has a secondary phone number on file |

### Locale / Market Columns

| Column | Type | DDL Comment | Inferred Purpose |
|---|---|---|---|
| default_currency_code | string | (none) | ISO 4217 currency code for the customer's default billing currency (e.g., 'USD', 'GBP') |
| market_code | string | (none) | Market or locale code indicating the customer's primary market (e.g., 'en-US') |

### Customer Lifecycle Timestamps

| Column | Type | DDL Comment | Inferred Purpose |
|---|---|---|---|
| created_mst_ts | timestamp | (none) | Timestamp (MST) when the customer account was originally created |
| updated_mst_ts | timestamp | (none) | Timestamp (MST) when the customer record was last updated in the source system |
| closed_mst_ts | timestamp | (none) | Timestamp (MST) when the customer account was closed; NULL for active accounts |
| deleted_mst_ts | timestamp | (none) | Timestamp (MST) when the customer record was soft-deleted; NULL for non-deleted records |

### SCD2 History Columns

| Column | Type | DDL Comment | Inferred Purpose |
|---|---|---|---|
| effective_start_mst_ts | timestamp | (none) | SCD2: Timestamp (MST) marking the start of validity for this historical record version |
| effective_end_mst_ts | timestamp | (none) | SCD2: Timestamp (MST) marking the end of validity for this record version; NULL indicates the currently active record |
| current_record_flag | boolean | (none) | SCD2: True if this row represents the most recent (current) version of the customer record |

### ETL Audit Columns

| Column | Type | DDL Comment | Inferred Purpose |
|---|---|---|---|
| etl_build_mst_ts | timestamp | (none) | Timestamp (MST) when the ETL pipeline processed and built this record |
| etl_insert_mst_ts | timestamp | (none) | Timestamp (MST) when this record was first inserted into the table by the ETL process |
| etl_update_mst_ts | timestamp | (none) | Timestamp (MST) when this record was last updated in the table by the ETL process |

---

## Summary of Key Findings for Description Enrichment

1. **SCD2 Pattern:** `dim_customer_history_vw` is a Slowly Changing Dimension Type 2 table. Columns `effective_start_mst_ts`, `effective_end_mst_ts`, and `current_record_flag` implement full history tracking. All descriptions must reference this SCD2 context.

2. **Shopper vs. Customer:** GoDaddy historically used "shopper" as the account unit. `customer_id` is the new Customer360 canonical identifier; `shopper_id` is the legacy equivalent.

3. **Federation Partner:** Columns `federation_partner_id` and `federation_partner_name` relate to GoDaddy's acquired brands (e.g., 123Reg, Heart Internet) that federate authentication with GoDaddy systems. DDL comments are the primary source.

4. **Phone/Email Existence Flags:** `primary_phone_flag`, `mobile_phone_flag`, `secondary_phone_flag` indicate existence of contact data per Confluence ("flags on whether phone/email exists"). The email itself is not stored — only `email_domain_name` (partial) and `email_hash`.

5. **Internal/Closed Accounts:** `internal_shopper_flag` and `closed_shopper_flag` added by dim_customer_history_vw per Confluence; used to filter analytics.

6. **ETL Timestamps:** Three ETL audit timestamps provide build/insert/update auditability at the data platform level.

7. **Alation data unavailable:** No source comments or descriptions from Alation could be retrieved due to expired token. Descriptions are based solely on DDL comments, YAML, and Confluence content.


**The agent's final response to the user was:**
Here is a summary of the research completed for this stage:

## Research Summary: `customer360.dim_customer_history_vw`

**DDL & YAML Read:** Successfully read the DDL (34 columns, Iceberg/Parquet, data tier 2) and YAML metadata (description, lineage, SLA, permissions).

**Confluence (Page 3779199819):** Fetched and summarized the Customer360 design spec. Key findings:
- `dim_customer_history_vw` is the **SCD2 history variant** of `dim_customer_vw`, tracking full customer history via `effective_start_mst_ts`, `effective_end_mst_ts`, and `current_record_flag`.
- Adds phone/email existence flags and internal/closed account flags not present in the base view.
- Replaces multiple deprecated tables across fortknox and marketing_mart.
- Daily refresh, 3 AM MST via Airflow.

**Alation:** Token expired — no column metadata, source comments, or Certified Data Dictionary entries could be retrieved from reference tables (dim_customer_vw id=7022291, customer_life_cycle_vw id=7038345) or Folder 6. This is documented in research.md.

**Per-column analysis** documented in research.md covering all 34 columns across: identity keys (customer_id, shopper_id), federation/brand columns, hierarchy, status flags, geographic, contact, locale, lifecycle timestamps, SCD2 history columns, and ETL audit timestamps.

The research output has been appended to `research.md` and is ready for the next stage to use when writing enriched column descriptions.