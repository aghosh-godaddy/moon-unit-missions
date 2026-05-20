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

- Target: customer360.dim_customer_history_vw
- Columns touched: 34
- Columns with pre-existing comments preserved: 3 (customer_id, federation_partner_id, federation_partner_name — all rewritten to meet standard while preserving core meaning)
- Columns newly annotated: 31

## Certified Data Dictionary terms applied

| Abbreviation | Official expansion | Where used |
|---|---|---|
| MST | Mountain Standard Time | created_mst_ts, updated_mst_ts, closed_mst_ts, deleted_mst_ts, effective_start_mst_ts, effective_end_mst_ts, etl_build_mst_ts, etl_insert_mst_ts, etl_update_mst_ts |
| ETL | Extract, Transform, Load | etl_build_mst_ts, etl_insert_mst_ts, etl_update_mst_ts |
| SCD2 | Slowly Changing Dimension Type 2 | effective_start_mst_ts, effective_end_mst_ts, current_record_flag |
| FPID | Federation Partner ID | federation_partner_id, federation_partner_name |
| PL | Private Label | private_label_id |

Note: Alation Certified Data Dictionary (Folder 6) was unavailable due to expired token. No GCR/MRR/NRU-family abbreviations are present in this table's column names; all expansions above are from DDL comments and Confluence research.

## Notable decisions

- **customer_id**: Existing comment 'Primary key' was enhanced to full standard format with `@PrimaryKey` annotation and SCD2 context; original was too minimal.
- **federation_partner_id**: Existing verbose DDL comment was rewritten to cleaner standard format preserving all key semantics (grouping, authorization scoping, brand-to-GoDaddy federation, FPID alias).
- **federation_partner_name**: Existing comment 'brand name associated with a federation partner ID (FPID)' was enhanced with concrete examples (123Reg, Heart Internet) per Confluence research.
- **email_domain_name / email_hash**: PII context explicitly called out; email itself is not stored — only domain portion and hash retained for analytics.
- **internal_shopper_flag / closed_shopper_flag**: Confluence explicitly noted these flags as added by dim_customer_history_vw (not present in base view); described their analytics filtering purpose.
- **SCD2 columns**: All three SCD2 mechanics columns (effective_start_mst_ts, effective_end_mst_ts, current_record_flag) explicitly tagged with "SCD2" prefix per Confluence architecture notes.
- **ETL audit columns**: Spell out "Extract, Transform, Load" in full per standard (avoid ETL abbreviation); timezone (Mountain Standard Time) stated explicitly as required by audit column rule.
- **Alation unavailable**: No source column_comment or description data from Alation could be retrieved (expired token). All descriptions are based on DDL comments, table.yaml, and Confluence page 3779199819.

## Longest comments (for QA)

| Column | Length | Comment |
|---|---|---|
| federation_partner_id | 163 | Numeric identifier grouping users under an acquired brand federation for scoping authorization of brand-to-GoDaddy federation access (federation partner id, FPID). |
| temporary_shopper_flag | 148 | Indicates whether the shopper account is temporary (e.g., created for a single transaction); these accounts may be excluded from retention analysis. |
| effective_start_mst_ts | 148 | SCD2 start-of-validity timestamp (Mountain Standard Time) for this historical record version; marks when this customer row became the active record. |
| internal_shopper_flag | 145 | Indicates whether the shopper is an internal GoDaddy employee or test account; excludes internal traffic from customer analytics (true=internal). |
| email_hash | 144 | Hashed value of the customer primary email address; used for privacy-preserving identity resolution and cross-system joins without exposing PII. |
| federation_partner_name | 141 | Brand name associated with a federation partner identifier (FPID); human-readable label for an acquired brand (e.g., 123Reg, Heart Internet). |

**The agent's final response to the user was:**
Enrichment complete. Here's a summary of what was done:

**DDL updated:** `catalog/config/prod/dlms-api/us-west-2/customer360/dim-customer-history-vw/table.ddl`

- **34 columns** annotated; all comments validated at ≤255 characters (longest: 163 chars on `federation_partner_id`)
- **3 pre-existing comments** enhanced: `customer_id` (promoted to `@PrimaryKey` standard), `federation_partner_id` and `federation_partner_name` (rewritten to meet style standard while preserving core semantics)
- **31 newly annotated** columns with descriptions covering identity, federation, hierarchy, status flags, geography, contact, locale, lifecycle timestamps, SCD2 mechanics, and ETL audit

**Key decisions:**
- All 9 `*_mst_ts` timestamps spell out "Mountain Standard Time" per the audit column rule
- ETL columns spell out "Extract, Transform, Load" to comply with the no-abbreviations rule
- SCD2 trio (`effective_start_mst_ts`, `effective_end_mst_ts`, `current_record_flag`) explicitly tagged with "SCD2" prefix
- `email_hash` and `email_domain_name` call out PII suppression context
- Certified Data Dictionary (Alation Folder 6) was inaccessible due to expired token; no GCR/MRR/NRU abbreviations exist in this table anyway, so no certified expansions were at risk of being misused