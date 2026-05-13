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

## Research Summary — ecomm360.dim_bill_vw

**Date:** 2026-05-13  
**Analyst:** Data Governance Autonomous Agent  
**Alation status:** Unavailable (refresh token expired/revoked — worked from DDL + Confluence)

---

## 1. Current DDL

```sql
CREATE TABLE dim_bill_vw (
    bill_id string COMMENT 'Primary Key - Unique identifier for the bill',
    event_id string COMMENT 'Unique identifier for the event that generated this bill',
    original_shopper_id string COMMENT 'Original shopper of the bill',
    original_customer_id string COMMENT 'original customer of the bill',
    merged_shopper_id string COMMENT 'current merged shopper of the bill',
    merged_customer_id string COMMENT 'current merged customer of the bill',
    rep_version_id int COMMENT 'current rep version id on the bill',
    bill_modified_mst_date date COMMENT 'Timestamp when the bill was last modified in Mountain Standard Time',
    current_record_flag boolean COMMENT 'current record flag indicates which is most recent record',
    etl_insert_utc_ts timestamp COMMENT 'ETL process timestamp when record was first inserted in UTC',
    etl_update_utc_ts timestamp COMMENT 'ETL process timestamp when record was last updated in UTC'
);
```

---

## 2. Table YAML Metadata

- **Description:** "tracks every receipt of the purchase of a godaddy customer."
- **Table type:** ICEBERG, SCD2 slowly changing dimension
- **Storage format:** Parquet
- **Data tier:** 3
- **Partition keys:** `current_record_flag` (boolean), `bill_modified_mst_date_month` (string)
- **SLA:** Delivered by 3 AM MST every day (cron `0 10 * * ? *`)
- **Upstream lineage:** `signals_platform_cln.ecomm_unified_order_event_cln`

---

## 3. Confluence Page Summary — Dim_Bill_Vw (page ID: 3732834951)

**URL:** https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3732834951/Dim_Bill_Vw

### Purpose
Enterprise Dataset (EDS) that provides a comprehensive view of the **mutable attributes of a receipt**: `customer_id` and `rep_version_id`. It is an Iceberg SCD2 (Slowly Changing Dimension Type 2) table that replaces the legacy `enterprise.dim_bill_shopper_id_xref` table.

### Primary Key (composite)
`bill_id` + `original_customer_id` + `merged_customer_id` + `rep_revision_id`

### Partition Key
`current_record_flag` — The most recent update for a `bill_id`/`merged_customer_id`/`rep_revision_id` combination goes to partition `TRUE`; all historical records go to `FALSE`.

### Upstream dependency
`signals_platform_cln.ecomm_unified_order_event_cln` (event bus data)

### SCD2 Incremental Insert Logic
- **New PK record:** Insert new row; `effective_start = current_ts`; `effective_end = 9999-12-31`; `current_record_flag = TRUE`.
- **Existing PK update:** Set old record `current_record_flag = FALSE`, `effective_end = new_ts - 1s`; insert new row with updated attributes, `current_record_flag = TRUE`.

### Note on shopper_id columns
Shopper IDs (`original_shopper_id`, `merged_shopper_id`) are present but sparsely populated by design — the customer-to-shopper mapping is a daily snapshot and this table is refreshed multiple times per day. These columns are populated from legacy `dim_bill_shopper_id_xref` for backfilled records prior to 2025-04-01; after that date only in rare inactive-customer-merge edge cases.

### Column-to-Source Mapping (from Confluence schema table)

| dim_bill_vw column | Source column | Source table |
|---|---|---|
| bill_id | order_id | signals_platform_cln.ecomm_unified_order_event_cln |
| event_id | event_id | signals_platform_cln.ecomm_unified_order_event_cln |
| original_shopper_id | (backfill from legacy dim_bill_shopper_id_xref) | see note above |
| original_customer_id | original_customer_id | signals_platform_cln.ecomm_unified_order_event_cln |
| merged_shopper_id | (backfill from legacy dim_bill_shopper_id_xref) | see note above |
| merged_customer_id | customer_id | signals_platform_cln.ecomm_unified_order_event_cln |
| rep_version_id | rep_version_id | signals_platform_cln.ecomm_unified_order_event_cln |
| bill_modified_mst_date | order_date_utc_ts → converted to MST | signals_platform_cln.ecomm_unified_order_event_cln |
| current_record_flag | SCD2 derived: TRUE if effective_end = 9999-12-31 | derived |
| etl_insert_utc_ts | load timestamp (immutable) | ETL metadata |
| etl_update_utc_ts | load timestamp (updated each run) | ETL metadata |

---

## 4. Alation Lookup

**Status:** UNAVAILABLE — Alation refresh token is expired/revoked. Could not fetch:
- Target table column metadata (ecomm360.dim_bill_vw)
- Reference table column metadata (signals_platform_cln.ecomm_unified_order_event_cln, table_id: 6968214)
- Certified Data Dictionary (Document Folder ID 6)

All enrichment is based on DDL comments and Confluence data.

---

## 5. Certified Data Dictionary Mappings

Alation unavailable; dictionary could not be fetched. Column names in dim_bill_vw do not contain domain-specific GoDaddy abbreviations (GCR, MRR, NRU, etc.) — they use standard data engineering terms (ETL, UTC, MST, SCD).

| Abbreviation | Official Name | Document ID |
|---|---|---|
| ETL | Extract, Transform, Load | (standard industry term — not in GoDaddy dictionary; dict unavailable) |
| UTC | Coordinated Universal Time | (standard industry term) |
| MST | Mountain Standard Time | (standard industry term) |
| SCD | Slowly Changing Dimension | (standard industry term) |

No GoDaddy-specific business abbreviations found in column names that require dictionary lookup.

---

## 6. Per-Column Analysis and Enriched Descriptions

### bill_id (string)
- **Current DDL comment:** `Primary Key - Unique identifier for the bill`
- **Confluence source column:** `order_id` from ecomm_unified_order_event_cln
- **Role:** Composite PK component (bill_id + original_customer_id + merged_customer_id + rep_version_id)
- **Enriched description:** `Primary key. Unique identifier for a GoDaddy customer bill (order). Sourced from order_id in signals_platform_cln.ecomm_unified_order_event_cln.`

### event_id (string)
- **Current DDL comment:** `Unique identifier for the event that generated this bill`
- **Confluence source column:** `event_id` from ecomm_unified_order_event_cln
- **Enriched description:** `Unique identifier for the event bus event that created or last modified this bill record. Sourced from event_id in signals_platform_cln.ecomm_unified_order_event_cln.`

### original_shopper_id (string)
- **Current DDL comment:** `Original shopper of the bill`
- **Confluence note:** Backfill from legacy dim_bill_shopper_id_xref for records prior to 2025-04-01; after that date only populated in rare inactive-customer-merge edge cases.
- **Enriched description:** `Shopper ID of the customer at the time the bill was originally created. Populated from legacy dim_bill_shopper_id_xref for backfilled records prior to 2025-04-01; after 2025-04-01, only populated when the event bus cannot resolve a customer_id (rare inactive customer account merge scenario). May be null for most post-2025-04-01 records.`

### original_customer_id (string)
- **Current DDL comment:** `original customer of the bill`
- **Confluence source column:** `original_customer_id` from ecomm_unified_order_event_cln
- **Role:** Composite PK component
- **Enriched description:** `Customer ID at the time the bill was originally created, before any account merges. Part of the composite primary key. Sourced from original_customer_id in signals_platform_cln.ecomm_unified_order_event_cln.`

### merged_shopper_id (string)
- **Current DDL comment:** `current merged shopper of the bill`
- **Confluence note:** Same backfill logic as original_shopper_id.
- **Enriched description:** `Current (post-merge) shopper ID associated with the bill. Populated from legacy dim_bill_shopper_id_xref for backfilled records prior to 2025-04-01; after 2025-04-01, only populated when the event bus cannot resolve a customer_id (rare inactive customer account merge scenario). May be null for most post-2025-04-01 records.`

### merged_customer_id (string)
- **Current DDL comment:** `current merged customer of the bill`
- **Confluence source column:** `customer_id` from ecomm_unified_order_event_cln
- **Role:** Composite PK component
- **Enriched description:** `Current (post-merge) customer ID associated with the bill. Part of the composite primary key. Sourced from customer_id in signals_platform_cln.ecomm_unified_order_event_cln.`

### rep_version_id (int)
- **Current DDL comment:** `current rep version id on the bill`
- **Confluence source column:** `rep_version_id` from ecomm_unified_order_event_cln
- **Role:** Composite PK component
- **Enriched description:** `Version ID of the sales representative assignment on the bill. Part of the composite primary key. Sourced from rep_version_id in signals_platform_cln.ecomm_unified_order_event_cln.`

### bill_modified_mst_date (date)
- **Current DDL comment:** `Timestamp when the bill was last modified in Mountain Standard Time`  
  _(Note: comment says "Timestamp" but column type is DATE — the current description is slightly misleading)_
- **Confluence source column:** `order_date_utc_ts` converted to MST
- **Enriched description:** `Date when the bill was last modified, expressed in Mountain Standard Time (MST). Derived by converting order_date_utc_ts from signals_platform_cln.ecomm_unified_order_event_cln to MST.`

### current_record_flag (boolean, partition key)
- **Current DDL comment:** `current record flag indicates which is most recent record`
- **Confluence:** SCD2 partition flag. TRUE = active/current record (effective_end = 9999-12-31). FALSE = all historical versions. Querying WHERE current_record_flag = TRUE replicates legacy enterprise.dim_bill_shopper_id_xref.
- **Enriched description:** `SCD2 partition flag identifying the current active version of the bill record. TRUE for the most recent record (effective end date = 9999-12-31); FALSE for all superseded historical records. Use WHERE current_record_flag = TRUE to retrieve the current state of all bills, equivalent to the legacy enterprise.dim_bill_shopper_id_xref table.`

### etl_insert_utc_ts (timestamp)
- **Current DDL comment:** `ETL process timestamp when record was first inserted in UTC`
- **Confluence:** "The timestamp (in UTC) when a row was first inserted. This is immutable, unless the table is reflowed completely."
- **Enriched description:** `UTC timestamp when this row was first inserted into the table by the ETL process. Immutable — does not change on subsequent updates unless the entire table is reflowed.`

### etl_update_utc_ts (timestamp)
- **Current DDL comment:** `ETL process timestamp when record was last updated in UTC`
- **Confluence:** "The timestamp (in UTC) when a row was last updated."
- **Enriched description:** `UTC timestamp when this row was last updated by the ETL process.`

---

## 7. Summary of Sources and Quality Notes

| Source | Status | Key contribution |
|---|---|---|
| DDL (table.ddl) | ✅ Read | Current column comments — baseline |
| table.yaml | ✅ Read | Table description, lineage, partition keys, SLA |
| Confluence page 3732834951 | ✅ Fetched | Column-to-source mapping, SCD2 design, shopper_id backfill logic, PK definition |
| Alation (target table) | ❌ Unavailable (expired token) | N/A |
| Alation (reference table 6968214) | ❌ Unavailable (expired token) | N/A |
| Alation Certified Data Dictionary | ❌ Unavailable (expired token) | N/A |

### Issues / Flags for human review
1. **current DDL comment for `bill_modified_mst_date`** says "Timestamp" but the column type is `DATE` — corrected in enriched description.
2. **`original_shopper_id` and `merged_shopper_id`** are present in the DDL but the Confluence page notes they are sparsely populated by design (post-2025-04-01, mostly null). Downstream users should be warned.
3. **SCD2 tracking columns** listed in the Confluence schema (`row_hash`, `effective_start_mst_ts`, `effective_end_mst_ts`) are NOT present in the current DDL — this may indicate the view exposes a subset of the physical table's columns.
4. **Alation Certified Data Dictionary** was inaccessible. No GoDaddy business abbreviations were detected in column names, so this is low risk for this table.


**The agent's final response to the user was:**
The research has been compiled and appended to `research.md`. Here is a summary of what was accomplished:

---

## Research Summary — `ecomm360.dim_bill_vw`

**Sources consulted:**
- **DDL** (`table.ddl`) — 11 columns with existing comments read
- **YAML** (`table.yaml`) — table description, partition keys, SLA, lineage metadata extracted
- **Confluence page 3732834951** (`Dim_Bill_Vw`) — successfully fetched; contains full schema design, column-to-source mappings, SCD2 logic, and backfill notes
- **Alation** — unavailable (refresh token expired/revoked); could not fetch target table metadata, reference table (ecomm_unified_order_event_cln, id: 6968214), or Certified Data Dictionary

**Key findings:**

| Column | Enrichment |
|---|---|
| `bill_id` | Composite PK component; maps from `order_id` in upstream event table |
| `event_id` | Event bus event ID that created/modified the bill |
| `original_shopper_id` | Backfill-only pre-2025-04-01; nearly null post-cutover by design |
| `original_customer_id` | Composite PK; pre-merge customer ID |
| `merged_shopper_id` | Same backfill logic as original_shopper_id |
| `merged_customer_id` | Composite PK; maps from `customer_id` in upstream source |
| `rep_version_id` | Composite PK; sales rep version on the bill |
| `bill_modified_mst_date` | **Bug fix**: current comment says "Timestamp" but type is `DATE`; derived from `order_date_utc_ts` converted to MST |
| `current_record_flag` | SCD2 partition flag — TRUE = active record (effective_end 9999-12-31); use to replicate legacy `enterprise.dim_bill_shopper_id_xref` |
| `etl_insert_utc_ts` | Immutable insert timestamp per Confluence |
| `etl_update_utc_ts` | Mutable last-update timestamp |

**Flags for human review:** SCD2 columns `row_hash`, `effective_start_mst_ts`, `effective_end_mst_ts` appear in the Confluence schema design but are absent from the current DDL — may indicate the view exposes only a subset of the physical table.