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

- Target: analytic-feature.customer_type
- Columns touched: 12
- Columns with pre-existing comments preserved: 0
- Columns newly annotated: 12

## Certified Data Dictionary terms applied

| Abbreviation | Official expansion | Where used |
|---|---|---|
| GCR | Gross Cash Receipts | customer_type_name |
| PnL | Profit and Loss | customer_type_name |
| MST | Mountain Standard Time | evaluation_mst_date, first_order_mst_date, partner_investor_start_mst_date, customer_type_assignment_mst_date |

## Notable decisions

- Alation API was unavailable (expired refresh token); all descriptions derived from Confluence page 10364300, DDL structure, and YAML lineage context.
- `shopper_id` annotated @PrimaryKey based on table grain (one record per shopper, latest snapshot); confirmed by Confluence and YAML table type LATEST_SNAPSHOT.
- `customer_type_name` annotated @Enumerated with all four known values (International Independent, US Independent, Partner, Investor) sourced from Confluence.
- Apostrophes in comments escaped as '' per SQL string literal convention (evaluation_mst_date, first_order_country_code, first_order_mst_date); actual stored character counts remain within limit.
- `evaluation_mst_date` and `as_of_date` are not in the Confluence data dictionary for the analogous `customer_type_history` table; descriptions inferred from the LATEST_SNAPSHOT table pattern and MST naming convention.
- `partner_investor_start_mst_date` and `customer_type_assignment_mst_date` inferred from Confluence note: "Once a customer becomes Partner or Investor, the type does not change."
- No audit timestamp columns present (all date, not timestamp); `load_date` described as ETL audit/lineage column consistent with `customer_type_history` data dictionary.
- GCR and PnL confirmed from Confluence page 10364300 explicit definitions (Alation Certified Data Dictionary unavailable).

## Longest comments (for QA)

| Column | Length | Comment |
|---|---|---|
| customer_type_name | 185 | @Enumerated(International Independent, US Independent, Partner, Investor) Shopper customer type classification; drives Gross Cash Receipts (GCR) Profit and Loss (PnL) pillar assignment. |
| customer_independent_reason_desc | 148 | Reason the shopper was originally classified as Independent before becoming a Partner or Investor (e.g., US first order, International first order). |
| customer_independent_desc | 143 | Customer type before reclassification as Partner or Investor (US Independent or International Independent); null for Independent-type shoppers. |
| customer_type_reason_desc | 137 | Business rule or criterion that determined the customer type (e.g., 50+ active domains for Investor, Web Pro participation for Partner). |
| shopper_id | 134 | @PrimaryKey Unique identifier for the GoDaddy shopper; one record per shopper representing their current customer type classification. |

**The agent's final response to the user was:**
The DDL has been enriched and the summary appended. Here's what was done:

**DDL updated:** `catalog/config/prod/us-west-2/analytic-feature/customer-type/table.ddl`

All 12 columns annotated from scratch (no pre-existing comments). Key decisions:

| Column | Annotation | Notes |
|--------|-----------|-------|
| `shopper_id` | `@PrimaryKey` | Table grain is one row per shopper (LATEST_SNAPSHOT) |
| `customer_type_name` | `@Enumerated(...)` | All 4 values from Confluence; includes GCR/PnL expansions |
| Date columns | MST timezone called out | Consistent with column naming convention |
| `customer_independent_*` | Partner/Investor context | Null-behavior documented |

**Certified terms applied:**
- `GCR` → Gross Cash Receipts (Confluence page 10364300)
- `PnL` → Profit and Loss (Confluence page 10364300)

**Validation:** All 12 comment strings are ≤ 255 characters (longest: `customer_type_name` at 185 chars). Apostrophes escaped with `''` in DDL where needed; actual stored lengths remain within limit.