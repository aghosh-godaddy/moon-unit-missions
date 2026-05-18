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

- Target: enterprise.dim_new_registered_user
- Columns touched: 4
- Columns with pre-existing comments preserved: 0 (prior-stage comments rewrote all 4, but were non-compliant; all were re-authored)
- Columns newly annotated: 4

## Certified Data Dictionary terms applied

| Abbreviation | Official expansion | Where used |
|---|---|---|
| NRU | New Registered User | bill_shopper_id, new_registered_user_bill_id, new_registered_user_bill_mst_date, new_registered_user_bill_mst_ts |
| MST | Mountain Standard Time | new_registered_user_bill_mst_date, new_registered_user_bill_mst_ts |

Note: Alation Certified Data Dictionary (Folder 6) was inaccessible (expired token). NRU and MST expansions sourced from Confluence design doc (page 10369242) and are consistent with expected dictionary entries. FMV (fair market value) expanded inline; not in dictionary.

## Notable decisions

- `bill_shopper_id`: Prior-stage comment was 301 chars (over 255) and lacked `@PrimaryKey`. Rewrote to 206 chars starting with `@PrimaryKey` per Rule 10.
- `new_registered_user_bill_id`: Prior-stage comment was 279 chars (over 255) and used an escaped apostrophe (`\'`). Rewrote to 229 chars without contractions. The outer double-parens around the pf_id exclusion list were simplified to a single set to save characters. "Source:" annotation dropped to stay under limit.
- `new_registered_user_bill_mst_date` and `new_registered_user_bill_mst_ts`: Prior-stage comments were compliant (131 and 127 chars); retained with minor wording kept identical.
- `FMV` expanded to "fair market value" inline in the `new_registered_user_bill_id` comment rather than using the abbreviation, per the standard's "avoid abbreviations" rule.
- No `Employee PII` or other special annotations existed in source comments.

## Longest comments (for QA)

| Column | Length | Comment |
|---|---|---|
| new_registered_user_bill_id | 229 | Bill identifier for the qualifying New Registered User (NRU) order. First free order (fair market value=$0) before any paid order. Excludes refunds, chargebacks, and Domain Change-of-Ownership (pf_id IN 112, 260112, 912, 260912). |
| bill_shopper_id | 206 | @PrimaryKey Unique shopper account identifier at time of New Registered User (NRU) event; one row per shopper. For merged shoppers, reflects pre-merge state at event time. Source: enterprise.fact_bill_line. |
| new_registered_user_bill_mst_date | 131 | Calendar date of the qualifying New Registered User (NRU) order in Mountain Standard Time (MST). Source: enterprise.fact_bill_line. |
| new_registered_user_bill_mst_ts | 127 | Timestamp of the qualifying New Registered User (NRU) order in Mountain Standard Time (MST). Source: enterprise.fact_bill_line. |

**The agent's final response to the user was:**
All done. Here's what was accomplished:

## DDL Enrichment: `enterprise.dim_new_registered_user`

The prior stage had written comments that violated two hard constraints. Both were corrected:

| Column | Issue | Fix | Final Length |
|---|---|---|---|
| `bill_shopper_id` | 301 chars (over 255); missing `@PrimaryKey` at start | Rewrote to lead with `@PrimaryKey`, condensed verbose context | **206 chars** |
| `new_registered_user_bill_id` | 279 chars (over 255); escaped apostrophe | Rewrote without contractions, dropped redundant "Source:" to fit | **229 chars** |
| `new_registered_user_bill_mst_date` | Compliant (131 chars) | No change | **131 chars** |
| `new_registered_user_bill_mst_ts` | Compliant (127 chars) | No change | **127 chars** |

**Key decisions:**
- `@PrimaryKey` annotation added to `bill_shopper_id` per Rule 10
- Business rules preserved in `new_registered_user_bill_id`: FMV=$0 filter, refund/chargeback exclusion, and Domain Change-of-Ownership pf_id list
- `FMV` expanded to "fair market value" per the avoid-abbreviations rule
- Official `NRU` = "New Registered User" and `MST` = "Mountain Standard Time" expansions applied from Confluence design doc (Alation dictionary unavailable)