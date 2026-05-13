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

- Target: enterprise.free_entitlement
- Columns touched: 21
- Columns with pre-existing comments preserved: 0
- Columns newly annotated: 21

## Certified Data Dictionary terms applied

| Abbreviation | Official expansion | Where used |
|---|---|---|
| pf_id | Product Family ID | free_pf_id, paid_pf_id, product_family_name (context) |
| MST | Mountain Standard Time | All _mst_ts and _mst_date columns (14 columns) |
| ETL | Extract, Transform, Load | etl_build_mst_ts |
| CES | Classic eComm System | free_bill_id, free_bill_mst_ts, free_bill_type_name |
| bmat | Bundle Match | free_type_name (@Enumerated list) |
| cmat | Companion Match | free_type_name (@Enumerated list) |
| freemat | Free Match | free_type_name (@Enumerated list) |
| freemium | Freemium (free tier product) | free_type_name (@Enumerated list) |

> Note: Alation Certified Data Dictionary (Folder 6) was unavailable due to expired refresh token.
> Abbreviation expansions are based on Confluence page content and GoDaddy Data Lake domain knowledge.
> No GCR/MRR/NRU abbreviations appear in this table's columns.

## Notable decisions

- `entitlement_id` designated `@PrimaryKey` — no explicit PK was declared in DDL or YAML, but the column name and its shared role across all enterprise entitlement tables (dim_entitlement, fact_entitlement_bill) make it the natural primary/unique key for this snapshot table.
- `free_type_name` annotated `@Enumerated(freemium, freemat, bmat, cmat)` — these four values are documented in the Confluence design notes as the known taxonomy; the comment notes the values are inferred via business logic, not sourced directly.
- `paid_*` columns (paid_pf_id, paid_bill_id, paid_bill_line_num, paid_bill_mst_ts, paid_bill_mst_date) all include "NULL if no paid conversion has occurred" to capture the critical semantic gap noted in the Confluence page (only first paid conversion is tracked).
- `etl_build_mst_ts` framed as an audit column per the standard, explicitly noting it reflects pipeline processing time (not business event time).
- No apostrophes used in any comment string to avoid DDL quoting issues with single-quoted string literals.
- Alation Source Comments were unavailable for all columns (token expired); no prior annotations were preserved as a result.
- `product_family_name` wording links back to `free_pf_id` to make the relationship explicit without cross-referencing a foreign key (no reference table confirmed via Alation).

## Longest comments (for QA)

| Column | Length | Comment |
|---|---|---|
| etl_build_mst_ts | 188 | Audit timestamp when this row was loaded by the ETL pipeline (Mountain Standard Time). Represents pipeline processing time, not business event time. Updated on each daily snapshot refresh. |
| paid_bill_mst_ts | 176 | Timestamp when the first paid conversion bill was created (Mountain Standard Time). Marks the moment a customer converted from free to paid. NULL if no conversion has occurred. |
| free_type_name | 171 | @Enumerated(freemium, freemat, bmat, cmat) Type of free product giveaway. Derived via business logic from source data; source tables do not directly provide this taxonomy. |
| entitlement_id | 171 | @PrimaryKey Unique identifier for a customer entitlement to a product or service. Shared key across enterprise entitlement tables (dim_entitlement, fact_entitlement_bill). |
| paid_pf_id | 170 | Product Family ID of the paid product the customer converted to after the free trial. NULL if no paid conversion has occurred. Only the first paid conversion is captured. |

**The agent's final response to the user was:**
All done. Here's what was completed:

**DDL enriched:** `catalog/config/prod/us-west-2/enterprise/free-entitlement/table.ddl`

- **21/21 columns** annotated with COMMENT clauses
- **0 pre-existing comments** (DDL had none)
- **Longest comment:** `etl_build_mst_ts` at 188 chars — well under the 255-char hard limit
- All 21 comments validated ≤ 255 characters before writing

**Key annotation decisions:**
- `entitlement_id` → `@PrimaryKey` (natural unique key shared across enterprise entitlement tables)
- `free_type_name` → `@Enumerated(freemium, freemat, bmat, cmat)` with note that values are business-logic-derived
- All 5 `paid_*` columns include "NULL if no paid conversion has occurred" to surface the critical lifecycle gap documented in Confluence
- All 14 timestamp/date columns explicitly state "(Mountain Standard Time)"
- `etl_build_mst_ts` framed as an audit column (pipeline processing time, not business event time)