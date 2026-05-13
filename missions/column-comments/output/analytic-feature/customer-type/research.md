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

## Research Summary: analytic-feature.customer_type

### Step 2: DDL and YAML Files

**DDL** (`catalog/config/prod/us-west-2/analytic-feature/customer-type/table.ddl`):
```sql
CREATE TABLE customer_type (
    shopper_id                        string,
    evaluation_mst_date               date,
    as_of_date                        date,
    first_order_country_code          string,
    first_order_mst_date              date,
    partner_investor_start_mst_date   date,
    customer_type_assignment_mst_date date,
    customer_type_name                string,
    customer_type_reason_desc         string,
    customer_independent_desc         string,
    customer_independent_reason_desc  string,
    load_date                         date
);
```

No existing COMMENT clauses in the DDL — all columns are uncommented.

**YAML Metadata** (`catalog/config/prod/us-west-2/analytic-feature/customer-type/table.yaml`):
- `description`: "migrated-customer_type"
- `table_type`: LATEST_SNAPSHOT
- `storage_format`: Parquet
- `data_tier`: 2
- `sla`: Daily snapshot delivered by 6:00 AM MST
- `sloIdentifier`: `analytic_feature.customer_type`
- **Upstream dependencies** (lineage):
  - `analytic_feature.shopper_domain_portfolio`
  - `bigreporting.dim_product_snap`
  - `partner360.dim_reseller_vw`
  - `ecomm360.fact_bill_line_vw`
  - `hmt_sites_cln.pro_dashboard_opts_history_cln`
  - `hmt_sites_cln.pro_clients_client_cln`
  - `customers.customer_id_mapping_snapshot`
  - `ecomm360.dim_bill_vw`
  - `customer360.dim_customer_history_vw`
- **Consumers**: data_platform, dnai, edt, care_analytics, c2_commerce_analytics, dri_analytics, customer_analytics, mdpe, revenue_and_relevance, analytics, mktgdata, imcoreappsvc, usi_social_platform, ckp_customer_insights, gdml_tecton

---

### Step 3: Confluence Page — Customer Type (ID: 10364300)

**URL**: https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/10364300/Customer+Type

**Purpose**:
- Evaluates acquired shoppers' customer type for classification and GCR PnL pillar.
- Customer type values: **International Independent**, **Investor**, **Partner**, **US Independent**
- Common use cases: Shopper classification and GCR PnL pillar assignment.

**Key Notes**:
- `analytic_feature.customer_type` — **latest snapshot only**. Should be decommissioned at some point.
- `analytic_feature.customer_type_history` — SCD2 table (recommended to use). Can retrieve latest snapshot or customer type at any point in time after 2016.
- Once a customer becomes Partner or Investor, the type does not change.
- `customer_type_history` contains a maximum of 2 records per `shopper_id`.
- Data produced daily via Spark on EMR.

**Acronyms defined**:
- **GCR** = Gross Cash Receipts
- **PnL** = Profit and Loss

**Dependencies** (original source systems):
- `hosting_webpro_api.dashboard_optshistory_snap`
- `hosting_webpro_api.clients_client_snap`
- `analytic_feature.shopper_domain_portfolio`
- `godaddy.gdshop_receipt_header_snap`
- `enterprise.fact_bill`, `enterprise.fact_bill_line`, `enterprise.dim_bill_shopper_id_xref`
- `dp_enterprise.dim_reseller`
- `enterprise.dim_new_acquisition_shopper`
- `bigreporting.dim_product_snap`

**GitHub**: https://github.com/gdcorp-dna/dof-ecomm-customer/tree/main/customer/analytic-customer-type/src

**Data Dictionary from Confluence** (for `customer_type_history`, highly analogous to `customer_type`):

| Column | Data Type | Description |
|---|---|---|
| shopper_id | string | The shopper |
| record_start_mst_date | date | Date start for customer to be identified as type in customer_type_name column |
| record_end_mst_date | date | Last date for customer to be identified as type in customer_type_name column. For customers never converted to Partner/Investor it is a date in the future like 2100-12-31. For customers that became Partner/Investor this is the day prior to conversion. |
| customer_type_name | string | The shopper's customer type |
| customer_type_reason_desc | string | How customer type was determined (50+ active domains, Web Pro, etc.) |
| customer_independent_desc | string | Customer type prior to customer becoming Partner/Investor |
| customer_independent_reason_desc | string | How customer type was determined at that time (US first order or International first order) |
| active_flag | boolean | Currently active record |
| load_date | date | Date data was processed |

---

### Step 4: Alation Lookup

**Status: Unavailable** — The Alation refresh token is expired/revoked (HTTP 401). Unable to fetch:
- Target table column metadata and `column_comment` (Source Comments)
- Reference table columns for: `analytic_feature.shopper_domain_portfolio`, `partner360.dim_reseller_vw`, `ecomm360.fact_bill_line_vw`, `ecomm360.dim_bill_vw`, `customer360.dim_customer_history_vw`
- Certified Data Dictionary (Document Folder 6)

All column descriptions must be derived from the Confluence page data dictionary, DDL structure, and contextual inference.

---

### Step 4b: Certified Data Dictionary Mappings

Alation API unavailable; only abbreviations found in Confluence page source are confirmed:

| Abbreviation | Official Name | Source |
|---|---|---|
| GCR | Gross Cash Receipts | Confluence page 10364300 — explicit definition |
| PnL | Profit and Loss | Confluence page 10364300 — explicit definition |
| MST | Mountain Standard Time | Standard timezone abbreviation; used consistently in date column naming convention |
| desc | Description | Standard naming convention in DDL column names |

No other abbreviations found in column names that require lookup (column names use plain English).

---

### Step 5: Per-Column Analysis

**Table context**: `analytic_feature.customer_type` is a latest snapshot of shopper customer type classification. Customer types are: International Independent, Investor, Partner, US Independent. Used for GCR (Gross Cash Receipts) Profit and Loss pillar assignment. Grain: one record per shopper_id (latest snapshot).

---

#### Column: `shopper_id`
- **DDL comment**: (none)
- **Alation column_comment**: (unavailable)
- **Alation description**: (unavailable)
- **Confluence data dictionary**: "The shopper" — shopper identifier
- **Inferred purpose**: Unique identifier for the GoDaddy shopper/customer. Primary key of this table. Matches `shopper_id` in upstream tables (`analytic_feature.shopper_domain_portfolio`, `customer360.dim_customer_history_vw`).
- **Proposed description**: Unique identifier for the GoDaddy shopper. Primary key of this table; one record per shopper representing their current customer type classification.

---

#### Column: `evaluation_mst_date`
- **DDL comment**: (none)
- **Alation column_comment**: (unavailable)
- **Confluence data dictionary**: Not explicitly listed (this column is specific to `customer_type`, not `customer_type_history`)
- **Inferred purpose**: The Mountain Standard Time (MST) date on which the shopper's customer type was evaluated/assessed. Represents the date of the classification run.
- **Proposed description**: Date (MST) on which the shopper's customer type was evaluated in the current classification run.

---

#### Column: `as_of_date`
- **DDL comment**: (none)
- **Alation column_comment**: (unavailable)
- **Confluence data dictionary**: Not explicitly listed
- **Inferred purpose**: The effective "as of" date for this snapshot record — the business date for which the classification is valid. Common pattern in latest-snapshot tables.
- **Proposed description**: Business date for which this customer type snapshot is valid; represents the effective date of the classification.

---

#### Column: `first_order_country_code`
- **DDL comment**: (none)
- **Alation column_comment**: (unavailable)
- **Confluence data dictionary**: Not explicitly listed; however, `customer_independent_reason_desc` references "US first order or International first order" — indicating first-order country is a key determinant of type
- **Inferred purpose**: ISO country code of the shopper's first order. Used to distinguish US Independent (first order placed in the US) from International Independent (first order placed outside the US).
- **Proposed description**: ISO country code of the shopper's first-ever order, used to classify shoppers as US Independent or International Independent.

---

#### Column: `first_order_mst_date`
- **DDL comment**: (none)
- **Alation column_comment**: (unavailable)
- **Confluence data dictionary**: Not explicitly listed
- **Inferred purpose**: The MST date of the shopper's first order. Marks the shopper as "acquired" and establishes the baseline for customer type assignment.
- **Proposed description**: Date (MST) of the shopper's first GoDaddy order; marks the acquisition date and anchors the customer type classification timeline.

---

#### Column: `partner_investor_start_mst_date`
- **DDL comment**: (none)
- **Alation column_comment**: (unavailable)
- **Confluence data dictionary**: Not explicitly listed; Confluence notes "Once customer became partner or investor, type shouldn't change after that"
- **Inferred purpose**: The MST date when the shopper first qualified as a Partner or Investor. Null for shoppers whose type is Independent.
- **Proposed description**: Date (MST) when the shopper was first classified as a Partner or Investor; null for Independent-type shoppers.

---

#### Column: `customer_type_assignment_mst_date`
- **DDL comment**: (none)
- **Alation column_comment**: (unavailable)
- **Confluence data dictionary**: Not explicitly listed; analogous to `record_start_mst_date` in `customer_type_history`
- **Inferred purpose**: The MST date when the current customer type was assigned. For the latest-snapshot table, this is the effective start date of the current type assignment.
- **Proposed description**: Date (MST) when the current customer type classification was assigned to the shopper.

---

#### Column: `customer_type_name`
- **DDL comment**: (none)
- **Alation column_comment**: (unavailable)
- **Confluence data dictionary**: "The shopper's customer type"
- **Inferred purpose**: The classification label. Values include: International Independent, Investor, Partner, US Independent. Used for GCR PnL pillar segmentation.
- **Proposed description**: Customer type classification of the shopper. Values: International Independent, US Independent, Partner, Investor. Used for Gross Cash Receipts (GCR) Profit and Loss (PnL) pillar assignment.

---

#### Column: `customer_type_reason_desc`
- **DDL comment**: (none)
- **Alation column_comment**: (unavailable)
- **Confluence data dictionary**: "How customer type was determined (50+ active domains, Web Pro, etc.)"
- **Inferred purpose**: Free-text description of the business rule or criterion that resulted in the current customer type assignment.
- **Proposed description**: Description of the business rule or criterion used to determine the customer type (e.g., 50+ active domains for Investor, Web Pro participation for Partner).

---

#### Column: `customer_independent_desc`
- **DDL comment**: (none)
- **Alation column_comment**: (unavailable)
- **Confluence data dictionary**: "Customer type prior to customer became Partner/Investor"
- **Inferred purpose**: Preserves the pre-Partner/Investor customer type (US Independent or International Independent). Populated only when `customer_type_name` is Partner or Investor.
- **Proposed description**: The shopper's customer type before they were reclassified as a Partner or Investor (e.g., US Independent or International Independent); null for shoppers who remain Independent.

---

#### Column: `customer_independent_reason_desc`
- **DDL comment**: (none)
- **Alation column_comment**: (unavailable)
- **Confluence data dictionary**: "How customer type was determined at that time (US first order or International first order)"
- **Inferred purpose**: Explains why the shopper was originally classified as US or International Independent, before becoming a Partner or Investor.
- **Proposed description**: Description of the reason for the shopper's original Independent customer type classification prior to becoming a Partner or Investor (e.g., US first order, International first order).

---

#### Column: `load_date`
- **DDL comment**: (none)
- **Alation column_comment**: (unavailable)
- **Confluence data dictionary**: "Date data was processed"
- **Inferred purpose**: The date the ETL pipeline processed and loaded this record into the table. Standard audit/lineage column.
- **Proposed description**: Date the record was processed and loaded by the ETL pipeline; used for data lineage and audit tracking.

---

### Summary of Findings

- **Table grain**: One row per shopper_id (latest snapshot of customer type classification)
- **Customer type values**: International Independent, US Independent, Partner, Investor
- **Key business context**: Classification drives GCR (Gross Cash Receipts) PnL pillar assignment
- **Alation API**: Unavailable — expired refresh token; no `column_comment` or reference table metadata retrieved
- **Confluence**: Rich data dictionary available for the analogous `customer_type_history` table; 9 out of 12 DDL columns mapped directly or by close analogy
- **Certified Data Dictionary**: Alation API unavailable; confirmed GCR = Gross Cash Receipts from Confluence source
- **MST columns**: All date columns use Mountain Standard Time (MST) naming convention consistently


**The agent's final response to the user was:**
Here is a summary of the research completed for `analytic-feature.customer_type`:

## Research Summary

### Sources Consulted

1. **DDL** — 12 columns, all without existing COMMENT clauses
2. **YAML** — Latest snapshot table, daily SLO, 9 upstream dependencies, data tier 2
3. **Confluence page 10364300** — "Customer Type" design page with full data dictionary for the analogous `customer_type_history` SCD2 table
4. **Alation API** — Unavailable (refresh token expired/revoked); no column_comment, reference table metadata, or Certified Data Dictionary could be retrieved

### Key Business Context

- **Purpose**: Classifies acquired shoppers into customer types for **GCR (Gross Cash Receipts) Profit and Loss pillar assignment**
- **Customer type values**: International Independent, US Independent, Partner, Investor
- **Table type**: Latest snapshot (one row per `shopper_id`)
- **Partner/Investor rule**: Once classified as Partner or Investor, the type never changes

### Certified Data Dictionary

| Abbreviation | Official Name | Source |
|---|---|---|
| GCR | Gross Cash Receipts | Confluence page 10364300 |
| PnL | Profit and Loss | Confluence page 10364300 |
| MST | Mountain Standard Time | Naming convention |

### Column Descriptions Derived

All 12 columns analyzed. 8 columns mapped directly or by close analogy from the Confluence data dictionary (`customer_type_history`). 4 columns (`evaluation_mst_date`, `as_of_date`, `first_order_country_code`, `first_order_mst_date`, `partner_investor_start_mst_date`, `customer_type_assignment_mst_date`) inferred from business context and the Confluence note that first-order country determines US vs International Independent classification.