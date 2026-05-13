**Stage name:** enrich
**The coding agent was given these instructions:** You are a Data Governance specialist writing column descriptions that comply with
the GoDaddy Data Governance Council's Column Description Standard for Data Lake Assets.

## Step 1: Read INPUT.md
Read `INPUT.md` to understand the target table (database, table, DDL path).

## CRITICAL: Use Official Terminology from Research
The research.md file contains a "Certified Data Dictionary Mappings" section with
the OFFICIAL GoDaddy abbreviation expansions. You MUST use these EXACT terms.
For example:
- GCR = "Gross Cash Receipts" (NOT "Gross Customer Receipt" or any other variation)
- NRU = "New Registered User"
- MRR = "Monthly Recurring Revenue"
If the research lists an official name for an abbreviation, that is the ONLY
acceptable expansion. NEVER invent or guess alternative expansions.

## Column Description Standard (mandatory rules)

1. **Be Clear and Concise** — Use plain, unambiguous language. Avoid jargon unless standard.
2. **Describe What, Not How** — Focus on what the data represents, not how it's computed.
3. **Include Context When Needed** — Add business/domain context for ambiguous terms.
4. **Avoid Abbreviations** — Use full words unless industry standard (SSN, URL, ISO).
5. **Indicate Units and Scale** — Include currency, percentage, milliseconds, etc.
6. **Avoid Redundancy with Column Names** — Provide additional value, don't repeat the name.
7. **Standardize Format** — Use: [What it is] [optional qualifier], [optional business context], [optional format or unit].
8. **Key Annotations**:
   - Add `@PrimaryKey`, `@UniqueKey` or `@ForeignKey(destination_table)` if applicable
   - Add `@Enumerated(value1, value2, ...)` for columns with limited important values
9. **AI Search Optimization**:
   - Use semantic-rich phrases (full sentences or structured fragments)
   - Include synonyms or aliases in parentheses where applicable
   - Tag key data concepts (timestamp, email address, SKU, revenue, etc.)
   - Avoid generic or placeholder descriptions
10. **PK/Primary Key** — Every table must have at least one column with a comment starting
    with PK, Primary Key, Unique Key, or Unique Identifier.
11. **Audit columns** — Must contain timestamp with timezone info (e.g., etl_build_mst_ts).
12. **Preserve existing valid annotations** — Keep comments like 'Employee PII' and append
    descriptive text after them.

## Examples of Good Descriptions
| Column | Description |
|--------|-------------|
| customer_id | @PrimaryKey The UUID identifier of a customer. |
| billing_country_code | @ForeignKey(dm_reference.dim_geography) Billing country code. |
| order_total_usd_amt | Total value of the order in US dollars, including taxes and discounts. |
| create_utc_ts | Timestamp representing when the record was created (UTC, ISO 8601). |
| email_opt_in_flag | Indicates whether the user consented to receive email communications (true/false). |

## Your Task
Using the research output from the previous stage (`research.md`), edit the
target table's DDL file in place at the path given in INPUT.md (under
`repos/lake/...`). Rewrite each column line to include a COMMENT clause
that follows the standard above.

**Rules:**
- Every column MUST have a COMMENT clause.
- **HARD LIMIT: Column comments MUST NOT exceed 255 characters. NO EXCEPTIONS.**
  This is a system constraint — longer comments are TRUNCATED by the database
  engine and cause data loss. For EVERY comment, count characters; if it
  exceeds 255, condense per the rules below.
  - Keep ONLY: the key annotation (@PrimaryKey etc.) + what the data represents.
  - DROP: synonyms, parenthetical aliases, verbose qualifiers, secondary context.
  - DROP: @Enumerated values if the list is too long — summarize instead.
  - NEVER sacrifice the 255-char limit for completeness — brevity wins.
- Preserve the exact column names, types, and order from the original DDL.
- Preserve existing valid comments (like 'Employee PII') — append descriptive text.
- If a column already has a good description, keep or enhance it.
- Use single quotes around comment strings in the DDL.
- Maintain proper DDL syntax (CREATE TABLE, commas, trailing semicolon).
- Do NOT change any column names, types, or table structure.

## MANDATORY VALIDATION (before finishing)
After drafting all comments, verify EVERY comment string between the single
quotes is ≤ 255 characters. If any exceed, rewrite shorter and re-check.
Only then save the edited DDL.

## Step 3: Append a summary to `enrich.md`
The framework pre-created `enrich.md` in your workspace with a header.
Append — do not overwrite — a summary with these sections:

```
## Enrichment summary

- Target: <db>.<table>
- Columns touched: <N>
- Columns with pre-existing comments preserved: <N>
- Columns newly annotated: <N>

## Certified Data Dictionary terms applied

| Abbreviation | Official expansion | Where used |
|---|---|---|
| GCR | Gross Cash Receipts | gcr_usd_amt, margin_gcr_usd_amt |
...

## Notable decisions

- <short bullets on non-obvious judgment calls: which Source Comments
  were preserved verbatim, which reference-table columns were mapped,
  any comments condensed near the 255-char limit, etc.>

## Longest comments (for QA)

| Column | Length | Comment |
|---|---|---|
| <col> | 254 | <comment text> |
```

Keep it tight — this is an operator-facing audit trail, not a re-explanation
of the standard.

**The agent summarized its work in this way:**

## Enrichment summary

- Target: enterprise.dim_subscription_history
- Columns touched: 52
- Columns with pre-existing comments preserved: 0
- Columns newly annotated: 52

## Certified Data Dictionary terms applied

| Abbreviation | Official expansion | Where used |
|---|---|---|
| mst | Mountain Standard Time | All _mst_ts and _mst_date columns, etl_build_mst_ts |
| ts | Timestamp | All _ts columns |
| amt | Amount | original_list_price_usd_amt, locked_price_amt |
| usd | US Dollar (United States Dollar) | original_list_price_usd_amt |
| etl | Extract, Transform, Load | etl_build_mst_ts |
| tx | Transaction (Change Data Capture) | tx_source_database, tx_source_table, tx_action, tx_write_time, tx_source_time, tx_source_id, tx_date |
| pf | Product Family | product_family_name (context only) |

> Note: Alation Certified Data Dictionary (Folder 6) was inaccessible due to expired refresh token. No GCR/MRR/NRU/MAU-type abbreviations appear in this table's columns. Abbreviation expansions above are based on GoDaddy Data Lake conventions and ISO standards confirmed in research.

## Notable decisions

- No pre-existing COMMENT clauses existed in the DDL — all 52 annotations are new.
- Alation API was unavailable (expired token); fallback to Confluence pages and reference table DDL for column semantics.
- `subscription_id` annotated `@PrimaryKey` per Confluence page 76447948 (explicit PK documentation).
- `subscription_status_id` uses `@Enumerated` with all known values (NULL/1=active, 3=pendsetup, 4=canceled, 6=BrokerageCompleted, 11=data center final bill) from Confluence page 3868983705; fits within 255 chars at 138 chars.
- `exclude_reason_desc` includes the "Filter to null for standard reports" guidance, as this is a widely misunderstood column; 183 chars (longest comment).
- `subscription_cancel_mst_ts` and `subscription_cancel_mst_date` both document sentinel dates 2099-12-31 and 2101-12-31 — critical business rule preventing false cancellation reporting.
- `source_system_name` uses `@Enumerated(CES=Classic ecommerce, NES=New ecommerce)` to surface the two-source-system architecture.
- `tx_write_time` and `tx_source_time` do not have _mst or _utc suffixes in their names; described as UTC per Change Data Capture convention observed in the lake.
- `subscription_sub_status_name` notes deprecation in EDS Prime to help analysts understand its limited future lifetime.
- `partition_history_mst_date` is the partition key defined outside the CREATE TABLE body and is absent from the column list; not annotated (not a column in the DDL).
- EDS Prime mapping references (e.g., "Maps to next_bill_on_utc_ts in EDS Prime") included only where they add cross-system clarity; omitted where redundant.

## Longest comments (for QA)

| Column | Length | Comment |
|---|---|---|
| exclude_reason_desc | 183 | Exclusion filter for reporting. Null = valid subscription. Non-null values: add-on product, Internal Shopper, NULL purchase_time, duplicate order. Filter to null for standard reports. |
| subscription_id | 163 | @PrimaryKey Unique subscription identifier. CES format: numeric string; NES format: UUID. Joins to dim_entitlement on subscription_id + partition_history_mst_date. |
| resource_id | 154 | Legacy CES numeric resource identifier for the subscription product instance. Used as join key in pre-NES integrations; bundles may have two resource IDs. |
| product_family_name | 149 | Product family namespace for the subscription (formerly name_space). Examples: bundle, domain, wsb, telephony. Required for joins to dim_entitlement. |
| subscription_cancel_mst_ts | 144 | Cancellation timestamp in Mountain Standard Time (MST). Null if not cancelled. Sentinel values 2099-12-31 and 2101-12-31 indicate not cancelled. |

**The agent's final response to the user was:**
Done. Here's a summary of the work completed:

## Enrichment complete — `enterprise.dim_subscription_history`

**DDL path:** `catalog/config/prod/us-west-2/enterprise/dim-subscription-history/table.ddl`

### What was done

- **52 columns** annotated with COMMENT clauses — all newly added (no pre-existing comments existed).
- Every comment is **≤ 255 characters** (longest: `exclude_reason_desc` at 183 chars).
- Standards applied:
  - `@PrimaryKey` on `subscription_id` (confirmed via Confluence page 76447948)
  - `@Enumerated` on `subscription_status_id` (all 5 status codes from DimSubActiveDate.py logic) and `source_system_name` (CES/NES)
  - Timezone suffixes documented on all timestamp columns (`MST` or `UTC`)
  - Sentinel date warning on `subscription_cancel_mst_ts/date` (2099-12-31, 2101-12-31)
  - Deprecation note on `subscription_sub_status_name` (EDS Prime)
  - Exclusion reporting guidance on `exclude_reason_desc`

### Sources used
- Confluence pages 76447948, 3868983705, 3791299219 (all fetched in research stage)
- Reference table DDL (`enterprise/dim-subscription/table.ddl`)
- Alation was unavailable (expired token); no Certified Data Dictionary abbreviations (GCR/MRR/NRU-type) appear in this table's columns