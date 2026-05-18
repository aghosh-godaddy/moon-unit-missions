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

- Target: enterprise.dim_new_acquisition_shopper
- Columns touched: 5
- Columns with pre-existing comments preserved: 0 (original DDL had no comments)
- Columns newly annotated: 5

## Certified Data Dictionary terms applied

| Abbreviation | Official expansion | Where used |
|---|---|---|
| GCR | Gross Cash Receipts | new_acquisition_bill_id |
| MST | Mountain Standard Time | new_acquisition_bill_mst_date, new_acquisition_bill_mst_ts |

**Note:** Alation Certified Data Dictionary (Folder 6) was inaccessible due to an expired token. GCR = "Gross Cash Receipts" is sourced from the Confluence design doc (page 10369719), where it is spelled out explicitly. No other abbreviations appear in column names.

## Notable decisions

- `bill_shopper_id`: Research-stage draft was 281 chars (exceeded limit). Condensed by dropping verbose clause "on the order, prior to any account merges" and shortening "records from 2021-08-09 onward" to "2021-08-09+". Added required `@PrimaryKey` annotation per standard rule 10.
- `new_acquisition_bill_id`: Research-stage draft was 361 chars (exceeded limit by 106). Condensed by dropping the pf_id enumeration ({112, 260112, 912, 260912}), the status-36 detail, and the exclude_reason_description exclusion clause. Core business definition (first paid order, GCR > $0, domain change-of-ownership) retained. Sourced-from attribution preserved.
- `bill_country_code`: No description in Confluence design doc; inferred from example data (US, CA) and context as ISO 3166-1 alpha-2 billing country code.
- All columns source from `enterprise.fact_bill_line` per design doc; attribution retained in each comment.
- Single-quote escaping (`\'`) preserved for apostrophes in `new_acquisition_bill_id`, `bill_country_code`, `new_acquisition_bill_mst_date`, and `new_acquisition_bill_mst_ts` comments.

## Longest comments (for QA)

| Column | Length | Comment |
|---|---|---|
| new_acquisition_bill_id | 198 | Bill identifier of the shopper's first qualifying paid order (New Customer Acquisition). Qualifies if Gross Cash Receipts (GCR) > $0 or domain change-of-ownership. Source: enterprise.fact_bill_line. |
| bill_shopper_id | 194 | @PrimaryKey Unique shopper account identifier (original_shopper_id). Pre-2021-08-09 records reflect merged_shopper_id; 2021-08-09+ reflect original_shopper_id. Source: enterprise.fact_bill_line. |
| bill_country_code | 153 | ISO 3166-1 alpha-2 country code associated with the shopper's new acquisition billing transaction (e.g., US, CA). Sourced from enterprise.fact_bill_line. |
| new_acquisition_bill_mst_ts | 121 | Timestamp of the shopper's new acquisition order in Mountain Standard Time (MST). Sourced from enterprise.fact_bill_line. |
| new_acquisition_bill_mst_date | 116 | Date of the shopper's new acquisition order in Mountain Standard Time (MST). Sourced from enterprise.fact_bill_line. |

**The agent's final response to the user was:**
Done. Here's what was accomplished:

## Enrichment complete — `enterprise.dim_new_acquisition_shopper`

**DDL updated:** `catalog/config/prod/us-west-2/enterprise/dim-new-acquisition-shopper/table.ddl`

All 5 columns now have compliant COMMENT clauses:

| Column | Chars | Key change |
|---|---|---|
| `bill_shopper_id` | 194 | Added `@PrimaryKey`; condensed 281→194 |
| `new_acquisition_bill_id` | 198 | Condensed 361→198; retained GCR (Gross Cash Receipts) |
| `bill_country_code` | 153 | Inferred from example data; no prior description existed |
| `new_acquisition_bill_mst_date` | 116 | Unchanged from research draft |
| `new_acquisition_bill_mst_ts` | 121 | Unchanged from research draft |

**Notable fixes:**
- `bill_shopper_id` was missing the required `@PrimaryKey` annotation; added.
- `new_acquisition_bill_id` (361 chars) was condensed by dropping the pf_id enumeration and exclude-reason clause while keeping the core business definition (GCR > $0, domain change-of-ownership).
- `bill_shopper_id` (281 chars) was condensed by shortening the merge-date historical note.
- All comments are ≤255 chars (hard database limit).
- GCR expanded as "Gross Cash Receipts" per Confluence design doc (Alation dictionary unavailable).