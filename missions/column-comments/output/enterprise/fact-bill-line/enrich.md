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

- Target: enterprise.fact_bill_line
- Columns touched: 76
- Columns with pre-existing comments preserved: 0
- Columns newly annotated: 76

## Certified Data Dictionary terms applied

| Abbreviation | Official expansion | Where used |
|---|---|---|
| GCR | Gross Cash Receipts | gcr_usd_amt, gcr_trxn_amt, margin_gcr_usd_amt, margin_gcr_trxn_amt, fair_market_value_usd_amt, fair_market_value_trxn_amt, injected_fair_market_value_usd_amt, exclude_reason_desc, exclude_reason_month_end_desc |
| MSRP | Manufacturers Suggested Retail Price | msrp_duration_unit_usd_amt, msrp_duration_unit_trxn_amt, msrp_total_usd_amt, msrp_total_trxn_amt |
| ICANN | Internet Corporation for Assigned Names and Numbers | fee_usd_amt, fee_trxn_amt, injected_icann_fee_usd_amt, injected_icann_fee_trxn_amt, msrp_duration_unit_usd_amt, msrp_duration_unit_trxn_amt, msrp_total_usd_amt, msrp_total_trxn_amt |
| COGS | Cost of goods sold | cost_usd_amt, cost_trxn_amt |
| MST | Mountain Standard Time | bill_modified_mst_ts, bill_modified_mst_date, etl_build_mst_ts, bill_mst_year, bill_mst_month |
| trxn | Transaction | All _trxn_amt and trxn_currency_code columns |
| pf | Product Family | pf_id, upgraded_pf_id |
| NES | Next E-Commerce System | product_uri |

## Notable decisions

- **No pre-existing comments** — all 76 columns were undocumented; all annotations are net-new.
- **Composite PK**: bill_id, bill_line_num, and source_system_name all received `@PrimaryKey` per Confluence design spec (Section 10.3.1). No single-column `@UniqueKey` is appropriate; all three are required together.
- **pf_id @ForeignKey**: Annotated as `@ForeignKey(dim_product)` per Confluence (joins to dim_product for product attributes).
- **Apostrophe avoidance**: "Manufacturer's" written as "Manufacturers" throughout to prevent SQL single-quote escaping issues in DDL comment strings.
- **source_system_name @Enumerated**: Used without internal quotes to avoid breaking single-quoted DDL strings.
- **exclude_reason_desc @Enumerated**: Included `Original_order_id != -1` enum value verbatim from Confluence; special characters (!=, -1) are safe in DDL comment strings.
- **original_receipt_price_***: Not documented in Confluence; descriptions inferred from column name and position in schema following the pattern of other receipt_price_* columns.
- **product_uri**: Noted as not currently populated, planned for NES integration per Confluence.
- **Alation unavailable**: Refresh token was expired (HTTP 401); all descriptions sourced from Confluence page 10371978 and DDL analysis only.
- **_trxn_amt columns**: Consistently described as "in the transaction currency" with reference to trxn_currency_code where appropriate, rather than repeating the currency resolution formula.
- **etl_build_mst_ts**: Labeled as an "Audit timestamp" to flag its role as an ETL audit column per the Column Description Standard.

## Longest comments (for QA)

| Column | Length | Comment |
|---|---|---|
| bill_id | 229 | @PrimaryKey Unique identifier of the billing receipt (order). Maps to order_id in legacy e-commerce source tables or subscription_order_id for Smartline. Part of composite primary key (bill_id, bill_line_num, source_system_name). |
| gcr_trxn_amt | 176 | Gross Cash Receipts (GCR) for this line item, in the transaction currency. Smartline app-store and free product conversions excluded. Requires join to dim_bill_shopper_id_xref. |
| msrp_duration_unit_trxn_amt | 175 | Manufacturers Suggested Retail Price (MSRP) for the full duration and quantity using the unit list price, plus ICANN fee, in the transaction currency. Zero for virtual orders. |
| injected_fair_market_value_usd_amt | 173 | Fair market value injected for non-primary product components (e.g., bundled add-ons), in US dollars. Used in Gross Cash Receipts (GCR) calculation. Zero for virtual orders. |
| msrp_total_usd_amt | 170 | Total Manufacturers Suggested Retail Price (MSRP) using the original list price across full duration and quantity, plus ICANN fee, in US dollars. Zero for virtual orders. |

**The agent's final response to the user was:**
All done. Here's a summary of what was completed:

**DDL enriched:** `catalog/config/prod/us-west-2/enterprise/fact-bill-line/table.ddl`

- **76 columns** annotated (0 had pre-existing comments)
- **Composite PK** — `bill_id`, `bill_line_num`, `source_system_name` all carry `@PrimaryKey`
- **Foreign key** — `pf_id` annotated `@ForeignKey(dim_product)`
- **@Enumerated** — applied to `source_system_name` (3 source system values) and `exclude_reason_desc` (3 exclusion reason values)
- **Official terminology** enforced:
  - GCR = Gross Cash Receipts (not "Gross Customer Receipt")
  - MSRP = Manufacturers Suggested Retail Price (apostrophe dropped to avoid DDL quote escaping)
  - ICANN = Internet Corporation for Assigned Names and Numbers
  - COGS used for cost columns; MST used for all timestamp/date columns
- **Hard limit compliance** — longest comment is 229 chars (bill_id); all 76 are under the 255-char ceiling
- **Audit column** — `etl_build_mst_ts` labeled as "Audit timestamp … in Mountain Standard Time (MST)"
- **Source:** Descriptions sourced from Confluence page 10371978; Alation was unavailable (expired refresh token)