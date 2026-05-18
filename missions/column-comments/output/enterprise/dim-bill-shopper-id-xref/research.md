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

## Stage: Data Governance Research — enterprise.dim_bill_shopper_id_xref

---

## 1. Full Current DDL

```sql
CREATE TABLE dim_bill_shopper_id_xref(
  bill_id string,
  original_shopper_id string,
  merged_shopper_id string,
  original_shopper_exclude_reason_desc string,
  original_shopper_exclude_reason_month_end_desc string,
  bill_modified_mst_ts timestamp,
  bill_modified_mst_date string,
  etl_build_mst_ts timestamp
);
```

Partition keys (from table.yaml): `bill_mst_year` (string), `bill_mst_month` (string)

**Note:** No existing DDL COMMENT clauses on any column — all columns lack inline descriptions.

---

## 2. Table Metadata (table.yaml)

- **Description**: "Hadoop legacy table dp_enterprise.dim_bill_shopper_id_xref"
- **Table relative path**: enterprise_eds_prime/dim_bill_shopper_id_xref
- **Storage format**: Parquet
- **Table type**: PARTITIONED
- **Data tier**: 2
- **SLA**: Delivered by 6 AM MST every day (`cron(0 13 * * ? *)`)
- **Owner**: producer role
- **Upstream table dependencies**:
  - ecomm360.dim_bill_vw
  - ecomm360.fact_bill_line_vw
  - customers.customer_id_mapping_snapshot
  - customer360.dim_customer_vw

---

## 3. Confluence Page Summary (Page ID: 10372130 — Dim_Bill_Shopper_ID_Xref)

**URL**: https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/10372130/Dim_Bill_Shopper_ID_Xref

### Purpose
- Provides a view of both the **original shopper** and the **current merged shopper** of a given bill_id
- Primary Key: **bill_id** (one row per bill)
- Source repo: gdcorp-dna/de-ecomm-gcr
- Airflow DAG: `ecomm_unified_bill`
- SLA: Data is updated incrementally throughout the day; typically current through prior day by 6 AM MST

### Upstream Sources
- **gdshop_receipt_header** — regular eCommerce orders (shopper_id, date_entered, order_id)
- **gdshop_receipt_virtual_order** — virtual orders (shopper_id, date_entered, order_id)
- **nds_smartline_event** — SmartLine/telephony orders (shopper_id, purchase_date, subscription_order_id)
- **rp_salesMonitor_internalShopper_snap** — internal shopper exclusion flags
- **fortknox_shopper_snap** — month-end shopper snapshot for exclusion logic

### Key Business Logic Notes
- The `original_shopper_id` is captured from the **INSERT transaction** (at time of order creation)
- The `merged_shopper_id` is the **most recent merged shopper** from UPDATE transactions; it does NOT track intermediate merge history
- Original shopper of refunds and chargebacks is not saved for historical data (captured going forward only)
- Orders where shopper doesn't merge: `original_shopper_id = merged_shopper_id`
- All orders in fact_bill will be present in this table
- The exclude reason at the shopper level was moved FROM fact_bill_line TO this table
- Data quality verified: original_shopper_id and merged_shopper_id are never NULL

### Column-Level Schema from Confluence

| Column | Type | Description | Source | Example | Special Notes |
|--------|------|-------------|--------|---------|---------------|
| bill_id | string | Bill_id Primary key column | gdshop_receipt_header.order_id, gdshop_receipt_virtual_order.order_id, nds_smartline_event.subscription_order_id | 15229821 | |
| original_shopper_id | string | The original shopper of the order when it was created | gdshop_receipt_header.shopper_id (INSERT), gdshop_receipt_virtual_order.shopper_id (INSERT), nds_smartline_event.shopper_id | 890251260 | Original Shopper on the bill |
| merged_shopper_id | string | The new shopper on the bill after the current shopper was merged with an existing shopper | gdshop_receipt_header.shopper_id (UPDATE), gdshop_receipt_virtual_order.shopper_id, nds_smartline_event.shopper_id | | Most recent merged shopper on the bill; does NOT track intermediate merge history |
| original_shopper_exclude_reason_desc | string | Exclude reason for the bill based on the original shopper_id (Internal or not) | rp_salesMonitor_internalShopper_snap | "internal shopper" | |
| original_shopper_exclude_reason_month_end_desc | string | Exclude reason for the bill based on the original shopper_id (Internal or not) at the month end | rp_salesMonitor_internalShopper_snap, fortknox_shopper_snap | | |
| bill_modified_mst_ts | timestamp | (no description in Confluence) | gdshop_receipt_header.date_entered, gdshop_receipt_virtual_order.date_entered, nds_smartline_event.purchase_date | | |
| bill_modified_mst_date | string | (no description in Confluence) | gdshop_receipt_header.date_entered, gdshop_receipt_virtual_order.date_entered, nds_smartline_event.purchase_date | 2020-08-19 | |
| etl_build_mst_ts | timestamp | (no description in Confluence) | (not specified) | | |
| bill_mst_year | string | Partition column | | 2020 | Partition key |
| bill_mst_month | string | Partition column | | 01 | Partition key |

---

## 4. Alation Lookup

**Status: UNAVAILABLE** — The Alation refresh token in `MOONUNIT_ALATION` is expired/revoked (API returned `401000: Refresh token provided is expired or revoked`). No Alation column metadata, Source Comments, or table-level descriptions could be retrieved for:
- Target table: enterprise.dim_bill_shopper_id_xref
- Reference table: ecomm360.dim_bill_vw (table_id: 7028947)
- Reference table: ecomm360.fact_bill_line_vw (table_id: 7027689)
- Reference table: customer360.dim_customer_vw (table_id: 7022291)
- Certified Data Dictionary (Document Folder ID 6)

---

## 5. Certified Data Dictionary Mappings

| Abbreviation | Official Name | Source | Document ID |
|---|---|---|---|
| mst | Mountain Standard Time | Standard GoDaddy timezone convention | N/A |
| ts | Timestamp | Standard abbreviation | N/A |
| etl | Extract, Transform, Load | Standard data engineering term | N/A |
| xref | Cross-reference | Standard data engineering term | N/A |
| id | Identifier | Standard abbreviation | N/A |
| desc | Description | Standard abbreviation | N/A |

**Note:** Alation Certified Data Dictionary (Folder ID 6) could not be fetched due to expired token. No GoDaddy-specific abbreviations (e.g., GCR, NRU, MRR) appear in this table's column names, so the unavailability of the dictionary does not introduce ambiguity for this table.

---

## 6. Per-Column Analysis and Enriched Description Candidates

### bill_id
- **DDL comment**: none
- **Confluence**: "Bill_id Primary key column." Sources: gdshop_receipt_header.order_id, gdshop_receipt_virtual_order.order_id, nds_smartline_event.subscription_order_id
- **Inferred**: Unique identifier for a GoDaddy bill/receipt, one row per bill (primary key of this table). Sourced from eCommerce receipt systems and SmartLine telephony events.
- **Proposed comment**: `Unique identifier for a GoDaddy customer bill (receipt); primary key of this table. Sourced from gdshop_receipt_header.order_id, gdshop_receipt_virtual_order.order_id, and nds_smartline_event.subscription_order_id.`

### original_shopper_id
- **DDL comment**: none
- **Confluence**: "The original shopper of the order when it was created" — captured from INSERT transaction at order creation time (gdshop_receipt_header.shopper_id, gdshop_receipt_virtual_order.shopper_id, nds_smartline_event.shopper_id)
- **Inferred**: Immutable shopper ID at the time the order was originally placed. Does not change with subsequent shopper merges.
- **Proposed comment**: `Shopper ID of the customer who originally placed the order (captured at INSERT time). Remains the shopper at the time of order creation and does not change with subsequent shopper account merges.`

### merged_shopper_id
- **DDL comment**: none
- **Confluence**: "The new shopper on the bill after the current shopper was merged with a existing shopper" — from UPDATE transactions; most recent merged shopper, does NOT track intermediate merge history
- **Inferred**: The current/latest shopper ID after account merges. For orders without a merge, equals original_shopper_id.
- **Proposed comment**: `Most recent shopper ID on the bill after any customer account merges (captured at UPDATE time). Equals original_shopper_id when no merge has occurred. Does not track intermediate merge history, only the final merged-to shopper.`

### original_shopper_exclude_reason_desc
- **DDL comment**: none
- **Confluence**: "exclude reason for the bill based on the original shopper_id (Internal or not)" — sourced from rp_salesMonitor_internalShopper_snap. Example: "internal shopper"
- **Inferred**: Indicates whether the original shopper is an internal GoDaddy employee or otherwise excluded from external revenue reporting. Driven by the internal shopper monitoring snapshot.
- **Proposed comment**: `Exclusion reason for revenue reporting based on the original_shopper_id (e.g., 'internal shopper'). Indicates whether the original shopper is an internal GoDaddy employee or otherwise excluded from external sales metrics. Sourced from rp_salesMonitor_internalShopper_snap.`

### original_shopper_exclude_reason_month_end_desc
- **DDL comment**: none
- **Confluence**: "exclude reason for the bill based on the original shopper_id (Internal or not) at the month end" — sourced from rp_salesMonitor_internalShopper_snap and fortknox_shopper_snap
- **Inferred**: Same as original_shopper_exclude_reason_desc but evaluated at month-end using a dedicated month-end snapshot. Used for month-end financial reporting to ensure consistent internal/external classification.
- **Proposed comment**: `Exclusion reason for revenue reporting based on the original_shopper_id as evaluated at month-end. Uses month-end shopper snapshots (rp_salesMonitor_internalShopper_snap, fortknox_shopper_snap) to provide a stable month-end view of internal vs. external shopper classification.`

### bill_modified_mst_ts
- **DDL comment**: none
- **Confluence**: No description provided. Source: gdshop_receipt_header.date_entered, gdshop_receipt_virtual_order.date_entered, nds_smartline_event.purchase_date
- **Inferred**: The timestamp (Mountain Standard Time) when the bill was last modified. Sourced from the date_entered or purchase_date fields in upstream receipt systems.
- **Proposed comment**: `Timestamp in Mountain Standard Time (MST) of when the bill was last modified or entered. Sourced from gdshop_receipt_header.date_entered, gdshop_receipt_virtual_order.date_entered, and nds_smartline_event.purchase_date.`

### bill_modified_mst_date
- **DDL comment**: none
- **Confluence**: No description provided. Source same as bill_modified_mst_ts. Example: 2020-08-19
- **Inferred**: Date portion (YYYY-MM-DD) of bill_modified_mst_ts. Used as a string for readability and partitioning support.
- **Proposed comment**: `Date (YYYY-MM-DD) in Mountain Standard Time (MST) of when the bill was last modified, derived from bill_modified_mst_ts. Used for date-based filtering. Sourced from gdshop_receipt_header.date_entered, gdshop_receipt_virtual_order.date_entered, and nds_smartline_event.purchase_date.`

### etl_build_mst_ts
- **DDL comment**: none
- **Confluence**: No description provided.
- **Inferred**: Standard ETL audit timestamp indicating when the record was built/loaded by the ETL pipeline. In Mountain Standard Time (MST).
- **Proposed comment**: `Timestamp in Mountain Standard Time (MST) when this record was built or last updated by the ETL pipeline (Airflow DAG: ecomm_unified_bill). Used for data freshness monitoring and incremental load auditing.`

---

## 7. Summary

All 8 DDL columns currently lack inline COMMENT clauses. The Confluence design doc (page 10372130) provides descriptions for 5 of the 8 columns. The remaining 3 (`bill_modified_mst_ts`, `bill_modified_mst_date`, `etl_build_mst_ts`) have no Confluence description but their purpose is clearly inferable from column naming conventions, their source fields in the Confluence schema table, and standard ETL patterns. Alation data was unavailable due to an expired refresh token. No GoDaddy-specific business abbreviations (GCR, MRR, NRU, etc.) appear in this table's column names.


**The agent's final response to the user was:**
The research document has been appended to `research.md`. Here's a summary of what I found and documented:

---

## Research Summary — `enterprise.dim_bill_shopper_id_xref`

**Table Purpose**: A cross-reference table providing both the original and current (merged) shopper for every GoDaddy bill. Primary key is `bill_id`. One row per bill. Sources data from eCommerce receipt systems and SmartLine telephony.

**DDL Status**: 8 columns, 2 partition keys — no existing COMMENT clauses on any column.

**Confluence Page 10372130**: Successfully fetched. Provided:
- Column descriptions for 5/8 columns (`bill_id`, `original_shopper_id`, `merged_shopper_id`, `original_shopper_exclude_reason_desc`, `original_shopper_exclude_reason_month_end_desc`)
- Source field mappings for all columns
- Key business logic: `original_shopper_id` = captured at INSERT time (immutable); `merged_shopper_id` = most recent post-merge shopper (no intermediate history); exclude reason columns classify internal vs. external shoppers for revenue reporting

**Alation**: Unavailable — refresh token is expired (HTTP 401000). No Source Comments, Alation descriptions, or Certified Data Dictionary entries could be retrieved.

**Proposed enriched descriptions** were derived for all 8 columns:
- `bill_id` — primary key, sources noted
- `original_shopper_id` / `merged_shopper_id` — shopper merge lifecycle explained
- `original_shopper_exclude_reason_desc` / `_month_end_desc` — internal shopper exclusion logic for revenue reporting
- `bill_modified_mst_ts` / `bill_modified_mst_date` — bill modification timestamp and date in MST
- `etl_build_mst_ts` — ETL audit timestamp