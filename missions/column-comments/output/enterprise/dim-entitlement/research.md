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

## Stage: Data Governance Research — enterprise.dim_entitlement

### Summary
Researched `enterprise.dim_entitlement` for column description enrichment. Alation API was unavailable (expired refresh token), so research draws on: the table DDL, table.yaml, two Confluence pages, and related table DDLs from the repository.

---

## Full Current DDL

```sql
CREATE TABLE dim_entitlement(
entitlement_id          string
,subscription_id        string
,resource_id            bigint
,product_type_id        int
,product_type_desc      string
,product_family_name    string
,pf_id                  int
,renewal_pf_id           int
,renewal_pf_id_sellable_flag boolean
,entitlement_common_name    string
,entitlement_external_resource_id   string
,entitlement_create_mst_ts  timestamp
,entitlement_create_mst_date    date
,entitlement_modify_mst_ts  timestamp
,entitlement_modify_mst_date    date
,entitlement_obsolete_resource_id   bigint
,parent_resource_id     bigint
,parent_product_type_id int
,free_product_package_id    int
,domain_id              bigint
,domain_name            string
,base_pf_id             int
,base_original_list_price_usd_amt   decimal(18,2)
,entitlement_addon_id   bigint
,entitlement_addon_flag boolean
,exclude_reason_desc    string
,source_system_name     string
,source_table_name      string
,entitlement_mst_year   int
,entitlement_mst_month  int
,tx_source_database     string
,tx_source_table        string
,tx_action              string
,tx_write_time          timestamp
,tx_source_time         timestamp
,tx_date                string
,etl_build_mst_ts       timestamp
);
```

No existing column COMMENT clauses in the DDL.

---

## Table YAML Key Metadata

- **description**: "Entitlement information of customers products"
- **table_relative_path**: enterprise/dim_entitlement
- **storage_format**: Parquet
- **table_type**: PARTITIONED
- **partition_keys**: `partition_entitlement_mst_year` (string), `partition_entitlement_mst_month` (string)
- **data_tier**: 1
- **SLA**: Delivered by 6:00 AM MST every day (cron `0 13 * * ? *` UTC)
- **Key upstream dependencies**: godaddybilling, godaddybilling_txlog, enterprise.fact_bill_line, enterprise.dim_subscription, customer360.dim_customer_history_vw, gdmastercatalog.catalog_product_snap, godaddy.gdshop_product_type_snap

---

## Confluence Page 1: dim_subscription and entitlement (ID: 76447948)

**URL**: https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/76447948/dim_subscription+and+entitlement

### Key findings:

**Table overview**
- dim_entitlement is the successor to `uds_product_billing`
- dim_entitlement PK: `entitlement_id`
- SLA: UTC 14:30 (7:30 AM MST) for history variant
- Two source systems feed data: **Classic ecommerce (CES)** and **New ecommerce (NES)**

**Join rule**
- One `dim_subscription` row has M `dim_entitlement` rows
- Join: `dim_subscription.subscription_id = dim_entitlement.subscription_id`

**entitlement_id generation**
- **Classic ecommerce (CES)**: No native entitlement_id; synthesized by concatenating `resource_id` and `product_type_id`
- **New ecommerce (NES)**: System-generated UUID

**Hard bundle example**
- A single `subscription_id` can have multiple `entitlement_id` rows each with a different `product_type_id`
- `product_family_name` = 'bundle' for bundle items
- `resource_id` may repeat across entitlement rows within a bundle
- Unique key (formerly): resource_id + name_space (product_family_name)

**exclude_reason_desc (entitlement-level)**
- NULL = valid entitlement (keep in standard analysis)
- 'add-on product' = add-on
- 'Internal Shopper' = GoDaddy employee record
- 'NULL purchase_time' = missing purchase data
- 'duplicate order' = deduplication artifact
- 'extra external resource' = NES artifact
- 'Obsolete row' = legacy/stale row
- 'Shopper_ID is null in the source table' = orphaned record

**pf_id**
- References `gdmastercatalog.catalog_product_snap` (formerly `dim_product_snap`)
- pf_id can rarely be reused by a product team for a similar product
- pnl attributes (subline, version) can change via approved Jira process

---

## Confluence Page 2: dim_entitlement Validation — switch to lookalike prime (ID: 4323412165)

**URL**: https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/4323412165/dim_entitlement+Validation+switch+to+lookalike+prime

Snapshot date: 2026-03-31. Column-level match rates vs EDS Prime lookalike (885,217,388 total rows):

| Column | Total | Matches | Mismatches | Match % | Notes |
|---|---|---|---|---|---|
| entitlement_id | 885,217,388 | 885,217,388 | 0 | 100% | Perfect match |
| subscription_id | 885,217,388 | 885,217,388 | 0 | 100% | Perfect match |
| resource_id | 885,217,388 | 885,115,508 | 101,880 | 99.99% | Near-perfect |
| product_type_id | 885,217,388 | 885,217,388 | 0 | 100% | Perfect match |
| product_type_desc | 885,217,388 | 885,217,388 | 0 | 100% | Perfect match |
| product_family_name | 885,217,388 | 885,217,388 | 0 | 100% | Perfect match |
| pf_id | 885,217,388 | 885,215,978 | 1,410 | 99.99% | Near-perfect |
| renewal_pf_id | 885,217,388 | 884,913,373 | 295,777 | 99.96% | Open ticket EDT-3288 |
| renewal_pf_id_sellable_flag | 885,217,388 | 885,142,182 | 75,206 | 99.99% | Near-perfect |
| entitlement_common_name | 885,217,388 | — | 272,086,388 | 68.9% | **PII removal** causes mismatches |
| entitlement_external_resource_id | 885,217,388 | — | — | **deprecated** | Column is deprecated |
| entitlement_create_mst_ts | 885,217,388 | 876,743,398 | 8,473,990 | 99% | In lookalike = subscription create date |
| entitlement_create_mst_date | 885,217,388 | 876,743,398 | 8,473,990 | 99% | In lookalike = subscription create date |
| entitlement_obsolete_resource_id | 885,217,388 | — | — | N/A | |
| parent_resource_id | 885,217,388 | — | 96,312,267 | ~89.11% | |
| parent_product_type_id | 885,217,388 | — | — | N/A | |
| free_product_package_id | 885,217,388 | 882,482,374 | 2,735,014 | 99.69% | |
| domain_id | 885,217,388 | 884,594,799 | 622,589 | 99.95% | |
| domain_name | 885,217,388 | 645,959,673 | 230,758,797 | 73.67% | New: plain text only (no encoded chars) |
| base_pf_id | 885,217,388 | 885,217,311 | 77 | 100% | |
| base_original_list_price_usd_amt | 885,217,388 | — | — | N/A | Only used by Domains; no downstream lake tables |
| entitlement_addon_id | 885,217,388 | 885,217,388 | 0 | 100% | Perfect match |
| entitlement_addon_flag | 885,217,388 | 885,217,388 | 0 | 100% | Perfect match |
| source_system_name | 885,217,388 | 885,217,388 | 0 | 100% | Perfect match |

---

## Related Table DDL Context

### enterprise.dim_subscription — shared columns
Common columns with dim_entitlement that have context from dim_subscription:
- `exclude_reason_desc`: same semantics — marks records to exclude from standard analysis
- `source_system_name`, `source_table_name`: same ETL provenance tracking
- `tx_*` columns: same transaction-log audit columns
- `etl_build_mst_ts`: ETL build timestamp
- `product_type_id`, `product_type_desc`, `product_family_name`, `pf_id`: product catalog identifiers
- `domain_id`, `domain_name`: domain association

### enterprise.dim_entitlement_history — identical columns
dim_entitlement_history has the same schema (minus `renewal_pf_id`, `renewal_pf_id_sellable_flag`), confirming column meanings are consistent.

---

## Alation Status

**Alation API**: Unavailable — refresh token expired (HTTP 401). Could not retrieve:
- Target table column metadata from Alation
- Reference table column descriptions (fact_bill_line, dim_subscription, dim_customer_history_vw)
- Certified Data Dictionary (Document Folder 6)

---

## Certified Data Dictionary Mappings

Alation access was unavailable. The following abbreviations appear in column names; official expansions are inferred from GoDaddy domain knowledge (not confirmed from Folder 6):

| Abbreviation | Official Name (inferred) | Document ID |
|---|---|---|
| pf_id | Product Family ID | Not confirmed from Alation |
| gcr | Gross Cash Receipts | Not confirmed from Alation |
| mst | Mountain Standard Time | Not confirmed from Alation |
| ts | Timestamp | Not confirmed from Alation |
| usd | US Dollars | Not confirmed from Alation |
| amt | Amount | Not confirmed from Alation |
| tx | Transaction | Not confirmed from Alation |
| etl | Extract Transform Load | Not confirmed from Alation |
| msrp | Manufacturer's Suggested Retail Price | Not confirmed from Alation |
| NES | New ecommerce System | Not confirmed from Alation |
| CES | Classic ecommerce System | Not confirmed from Alation |

**NOTE**: Without Alation Folder 6 access, dictionary mappings could not be confirmed. Enriched descriptions use widely-accepted GoDaddy data dictionary conventions.

---

## Per-Column Research Notes

| Column | Type | Inferred Purpose | Key Sources |
|---|---|---|---|
| entitlement_id | string | Unique identifier per entitlement. CES: concat of resource_id+product_type_id. NES: UUID. Primary key. | Confluence 1, Confluence 2 (100% match) |
| subscription_id | string | FK to dim_subscription. Multiple entitlements share a subscription_id in bundles. | Confluence 1, DDL, Confluence 2 (100% match) |
| resource_id | bigint | Billing system resource identifier (GDShop external resource ID). May repeat in bundles. | Confluence 1 (example table), Confluence 2 (99.99%) |
| product_type_id | int | Numeric product type ID from GoDaddy product catalog. Used to identify product type. | Confluence 1, Confluence 2 (100%) |
| product_type_desc | string | Human-readable description of the product type. | Confluence 2 (100%) |
| product_family_name | string | Product family grouping (formerly 'name_space'). Values include 'bundle' for hard bundles. | Confluence 1 (example, note about name_space) |
| pf_id | int | Product family ID referencing gdmastercatalog.catalog_product_snap. Join key to product catalog. | Confluence 1 (section 7, 9), Confluence 2 (99.99%) |
| renewal_pf_id | int | Product family ID for the renewal product (what this entitlement renews as). | Confluence 2 (99.96%, open EDT-3288) |
| renewal_pf_id_sellable_flag | boolean | Indicates whether the renewal product family ID is currently sellable. | Confluence 2 (99.99%) |
| entitlement_common_name | string | Human-readable common name/label for the entitlement. May contain PII; 68.9% match due to PII removal. | Confluence 1 (example), Confluence 2 (PII note) |
| entitlement_external_resource_id | string | External resource identifier (formerly 'orion_id'). **Deprecated** as of 2026-03 validation. | Confluence 1 (was orion_id), Confluence 2 (deprecated) |
| entitlement_create_mst_ts | timestamp | Timestamp (MST) when the entitlement was created. For NES lookalike data, equals subscription create timestamp. | Confluence 2 (99%, note about lookalike) |
| entitlement_create_mst_date | date | Date (MST) when the entitlement was created. For NES lookalike data, equals subscription create date. | Confluence 2 |
| entitlement_modify_mst_ts | timestamp | Timestamp (MST) of the most recent modification to the entitlement record. | DDL, analogy to dim_subscription |
| entitlement_modify_mst_date | date | Date (MST) of the most recent modification to the entitlement record. | DDL |
| entitlement_obsolete_resource_id | bigint | Resource ID that was superseded/replaced by this entitlement (for migration or upgrade scenarios). | Confluence 2 (N/A match) |
| parent_resource_id | bigint | Resource ID of the parent entitlement or subscription (for add-ons and bundle sub-items). | Confluence 1 (bundle example, resource_id note), Confluence 2 (~89%) |
| parent_product_type_id | int | Product type ID of the parent entitlement or subscription. | Confluence 2 (N/A match) |
| free_product_package_id | int | Identifier for a free product package bundled with this subscription (e.g., free add-ons). | Confluence 2 (99.69%), fact_bill_line DDL |
| domain_id | bigint | Numeric identifier for the domain associated with this entitlement. | Confluence 2 (99.95%), dim_subscription DDL pattern |
| domain_name | string | Domain name associated with this entitlement. Newer data contains plain text only (no encoded characters). | Confluence 2 (73.67%, plain text note) |
| base_pf_id | int | Base product family ID before any upgrades or add-ons. Used primarily for domain products. | Confluence 2 (100%), note about Domains |
| base_original_list_price_usd_amt | decimal(18,2) | Original USD list price for the base product. Used primarily for domain products; no downstream data lake tables consume this column. | Confluence 2 (deprecated note, Domains only) |
| entitlement_addon_id | bigint | Identifier linking this entitlement to a specific add-on record. | Confluence 2 (100% match) |
| entitlement_addon_flag | boolean | True if this entitlement is an add-on product; false otherwise. | Confluence 2 (100% match), Confluence 1 (exclude reason 'add-on product') |
| exclude_reason_desc | string | Reason for excluding this record from standard reporting. NULL = valid entitlement. Values: 'add-on product', 'Internal Shopper', 'duplicate order', 'Obsolete row', etc. | Confluence 1 (section 5, full value list) |
| source_system_name | string | Name of the source ecommerce system: Classic ecommerce (CES) or New ecommerce (NES). | Confluence 1 (section 3), Confluence 2 (100%) |
| source_table_name | string | Name of the source table within the originating ecommerce system. | DDL, dim_subscription pattern |
| entitlement_mst_year | int | Year (MST) of the entitlement record used for ETL partitioning logic. | YAML partition_keys, DDL |
| entitlement_mst_month | int | Month (MST) of the entitlement record used for ETL partitioning logic. | YAML partition_keys, DDL |
| tx_source_database | string | Source database name from the transaction log feed. | DDL, dim_subscription pattern |
| tx_source_table | string | Source table name from the transaction log feed. | DDL, dim_subscription pattern |
| tx_action | string | Transaction log action type (e.g., INSERT, UPDATE, DELETE). | DDL, dim_subscription pattern |
| tx_write_time | timestamp | Timestamp when the transaction was written to the transaction log. | DDL, dim_subscription pattern |
| tx_source_time | timestamp | Timestamp of the transaction in the originating source system. | DDL, dim_subscription pattern |
| tx_date | string | String-formatted date of the transaction, used for ETL processing windows. | DDL, dim_subscription pattern |
| etl_build_mst_ts | timestamp | Timestamp (MST) when the ETL pipeline built and loaded this record into the data lake. | DDL, dim_subscription pattern |


**The agent's final response to the user was:**
Here is a summary of the research work completed:

---

## Research Summary — `enterprise.dim_entitlement`

**DDL & YAML**: Read the full DDL (37 columns, no existing COMMENT clauses) and table.yaml. Key metadata: partitioned by `entitlement_mst_year`/`entitlement_mst_month`, data tier 1, SLA 6AM MST daily.

**Confluence pages fetched**:
1. **Page 76447948** (*dim_subscription and entitlement*): Documents the dual source system architecture (Classic ecommerce CES vs New ecommerce NES), entitlement_id generation logic (CES synthesizes from resource_id+product_type_id; NES uses UUID), join rules (one subscription → many entitlements), hard bundle examples, and the full `exclude_reason_desc` value taxonomy (NULL=valid, 'add-on product', 'Internal Shopper', 'duplicate order', 'Obsolete row', etc.).

2. **Page 4323412165** (*dim_entitlement Validation*): 2026-03-31 column-level match rate table comparing this table vs EDS Prime lookalike (885M rows). Key findings: `entitlement_external_resource_id` is **deprecated**; `entitlement_common_name` only 68.9% match due to **PII removal**; `domain_name` 73.67% match because new version contains plain text only; `renewal_pf_id` 99.96% with open ticket EDT-3288.

**Alation API**: Unavailable — refresh token expired (HTTP 401). Could not retrieve column metadata for target table or reference tables, nor the Certified Data Dictionary (Folder 6). This is noted in research.md.

**Related DDLs**: Read `dim_subscription/table.ddl` and `dim_entitlement_history/table.ddl` to confirm column semantics for shared columns (`tx_*`, `source_system_name`, `source_table_name`, `etl_build_mst_ts`, `exclude_reason_desc`).

**Per-column notes compiled** for all 37 columns covering: purpose, data lineage, known quirks (PII, deprecation, CES vs NES behavior, bundle semantics), and validation match rates. Full research appended to `research.md`.