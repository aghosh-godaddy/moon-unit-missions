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

- Target: customer360.dim_customer_vw
- Columns touched: 29
- Columns with pre-existing comments preserved verbatim: 4 (customer_id, shopper_id, federation_partner_id, federation_partner_name)
- Columns enhanced with additional context: 25
- Columns newly annotated (no prior comment): 0

## Certified Data Dictionary terms applied

No financial/metric abbreviations (GCR, MRR, NRU, MAU, etc.) appear in this table's column names.
Alation was unavailable (refresh token expired); Certified Data Dictionary could not be fetched.
Abbreviations expanded using Confluence-confirmed or industry-standard definitions:

| Abbreviation | Official expansion | Where used |
|---|---|---|
| MST | Mountain Standard Time | created_mst_ts, updated_mst_ts, closed_mst_ts, deleted_mst_ts, etl_build_mst_ts |
| ETL | Extract, Transform, Load | etl_build_mst_ts |
| FPID | Federation Partner ID | federation_partner_id, federation_partner_name |
| SCD2 | Slowly Changing Dimension Type 2 | current_record_flag |

## Notable decisions

- **deleted_mst_ts**: Prior comment read "closed or deleted" which conflated two separate events. Corrected to "deleted" only; closed_date is covered by closed_mst_ts.
- **temporary_shopper_flag**: Added business rule from Confluence — "true when no email address is on file (email_hash is NULL)".
- **internal_shopper_flag**: Enriched with Confluence logic — "3-letter account or entry in the Internal Shopper Exclusions registry".
- **closed_shopper_flag**: Added derivation — "true when closed_date or deleted_date is not null in the source system".
- **private_label_id**: Added reseller ID alias per Confluence Customer Master Data design doc.
- **zip_code**: Added UK outward-code-only truncation note from Confluence design doc.
- **current_record_flag**: Added SCD2 context and consumer filter guidance (filter to true for current records).
- **Apostrophes**: Escaped as '' in DDL per SQL single-quoted string convention (city_name, state_code, zip_code, country_code, default_currency_code). Stored character counts do not include the escape character.
- **Alation unavailable**: No Source Comments (column_comment) from Alation could be retrieved; all enrichment sourced from existing DDL comments + Confluence pages 3779199819 and 3780706383.

## Longest comments (for QA)

| Column | Length | Comment |
|---|---|---|
| current_record_flag | 155 | Indicates whether this is the current active record for the customer in this SCD2 (Slowly Changing Dimension Type 2) table; consumers should filter to true |
| deleted_mst_ts | 150 | Timestamp (Mountain Standard Time) when the customer account was deleted; null if not deleted. Distinct from closed_mst_ts which tracks account closure |
| internal_shopper_flag | 143 | Indicates whether the shopper is a GoDaddy-internal account, such as a 3-letter account or an entry in the Internal Shopper Exclusions registry |
| closed_shopper_flag | 136 | Indicates whether the shopper account has been closed or deleted; true when closed_date or deleted_date is not null in the source system |
| company_flag | 131 | Indicates whether the customer is classified as a company account; true when the customer profile has an organization name on record |

**The agent's final response to the user was:**
All done. Here's a summary of the work completed:

## Enrichment complete — `customer360.dim_customer_vw`

**DDL updated:** `catalog/config/prod/dlms-api/us-west-2/customer360/dim-customer-vw/table.ddl`

All 29 columns now have compliant COMMENT clauses. Key changes:

| Column | Change |
|---|---|
| `customer_id` | Preserved — `@PrimaryKey` annotation and UUID description unchanged |
| `shopper_id` | Preserved — `@UniqueKey` annotation unchanged |
| `federation_partner_id/name` | Preserved — FPID descriptions unchanged |
| `temporary_shopper_flag` | **Enriched** — added business rule: true when `email_hash IS NULL` (guest/anonymous) |
| `internal_shopper_flag` | **Enriched** — clarified: 3-letter accounts or Internal Shopper Exclusions registry |
| `closed_shopper_flag` | **Enriched** — added: true when `closed_date OR deleted_date IS NOT NULL` |
| `deleted_mst_ts` | **Corrected** — was "closed or deleted"; now correctly scoped to deletion only (closure = `closed_mst_ts`) |
| `private_label_id` | **Enriched** — added reseller ID alias |
| `zip_code` | **Enriched** — added UK outward-code-only truncation note |
| `current_record_flag` | **Enriched** — added SCD2 context and consumer filter guidance |
| Timestamp columns | **Enriched** — expanded MST to "Mountain Standard Time" per audit column standard |

All comment strings verified ≤ 255 characters. Longest: `current_record_flag` at 155 chars.