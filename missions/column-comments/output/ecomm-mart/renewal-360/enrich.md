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

- Target: ecomm-mart.renewal_360
- Columns touched: 246
- Columns with pre-existing comments preserved (enhanced): 15
- Columns newly annotated: 231

## Certified Data Dictionary terms applied

| Abbreviation | Official expansion | Where used |
|---|---|---|
| GCR | Gross Cash Receipts | prior_bill_gcr_usd_amt, prior_bill_gcr_trxn_amt, prior_bill_gcr_constant_currency_amt, renewal_bill_gcr_usd_amt, renewal_bill_gcr_trxn_amt, renewal_bill_gcr_constant_currency_amt |
| P&L / PNL | Profit and Loss | All pnl_* columns (prior, renewal, expected, finance, product-level) |
| PF ID / pf_id | Product Family ID | prior_bill_pf_id, renewal_bill_pf_id, expected_renewal_pf_id |
| MST | Mountain Standard Time | All date/timestamp columns |
| CRM | Customer Relationship Management | prior_bill_crm_portfolio_type_name, renewal_bill_crm_portfolio_type_name |
| COA / COO | Change of Account / Change of Ownership | coa_flag, coa_resource_id, original_prior_bill_sequence_number, domain_cancel_reason_desc |
| ICANN | Internet Corporation for Assigned Names and Numbers | prior_bill_fee_usd_amt, renewal_bill_fee_usd_amt |
| ETL | Extract, Transform, Load | etl_build_mst_ts |

## Notable decisions

- **Composite @UniqueKey**: No single primary key exists; `entitlement_id` and `prior_bill_sequence_number` annotated as `@UniqueKey` each referencing the composite with the other — satisfying the standard's PK requirement.
- **Existing comments enhanced, not discarded**: All 15 pre-existing COMMENT strings were rewritten in standard format (capitalized, active voice, true/false indicator) rather than preserved verbatim, as they were informal/lowercase but semantically valid.
- **P&L spelled out**: Per the standard's "avoid abbreviations" rule, "P&L" was expanded to "Profit and Loss" in all 40+ pnl_* column comments.
- **COO abbreviation retained in context**: "COO" (Change of Ownership) is retained alongside its expansion in comments for `coa_resource_id`, `original_prior_bill_sequence_number`, and `original_bill_paid_through_mst_date` where the acronym aids readability.
- **entitlement_event_code**: Enumerated values listed verbatim from Confluence (renewal_bill_modified_mst_date, subscription_cancel_mst_ts, bill_paid_through_mst_ts, current_date) within the 255-char limit (175 chars).
- **renewal_timing_desc**: All 8 enumerated timing values listed (158 chars) — within limit, no truncation needed.
- **prior_bill_pnl_pillar_name**: Existing comment "Prior bill P&L pillar classification…" rewritten to spell out "Profit and Loss" (126 chars).
- **finance_* columns**: Noted "may differ from" standard counts/types to flag that finance overrides exist, without explaining computation logic.
- **federation_partner_id / federation_partner_name**: Existing verbose comments ("represents the brand...") condensed to standard format while preserving the key business context (brand origin, examples).
- **@Enumerated on variant_price_type_id**: Applied to both prior and renewal bill variant_price_type_id columns, listing the 7 known values (0, 8, 16, 32, 64, 128, 256).

## Longest comments (for QA)

| Column | Length | Comment |
|---|---|---|
| entitlement_event_code | 175 | Code identifying the event type for historical auto-renewal status. Values: renewal_bill_modified_mst_date, subscription_cancel_mst_ts, bill_paid_through_mst_ts, current_date. |
| entitlement_cancel_mst_date | 172 | Cancellation date for the entitlement that resulted in subscription cancellation (MST), derived from subscription_cancel_mst_date at the maximum prior_bill_sequence_number. |
| renewal_timing_desc | 158 | Type of renewal timing. Values: Cancelled, Delayed, Early Cancel, Full Term, No Expiration Data, Not Yet Expired, Past Expiry - In Grace Period, Pull Forward. |
| product_period_name | 155 | Billing period for the product based on most recent bill, derived as coalesce of renewal, expected, or prior bill (6-month, month, onetime, quarter, year). |
| prior_bill_sequence_number | 152 | @UniqueKey Bill sequence number of the prior bill, adjusted for COO continuity. Starts at 1 for new purchase. Part of composite key with entitlement_id. |
| renewal_bill_gcr_constant_currency_amt | 136 | Gross Cash Receipts (GCR) on the renewal bill using a constant foreign exchange rate to USD, for trend analysis without FX fluctuations. |
| finance_sequence_num | 136 | Order sequence number used for finance reporting. May differ from prior_bill_sequence_number due to Change of Account/Ownership mapping. |

**The agent's final response to the user was:**
All done. Here's a summary of the enrichment work completed:

**DDL enriched:** `catalog/config/prod/us-west-2/ecomm-mart/renewal-360/table.ddl`

- **246 columns** annotated — every column now has a `COMMENT` clause
- **Zero violations** — all comments ≤ 255 characters (longest: 175 chars)
- **15 pre-existing comments** enhanced (rewritten to standard format — capitalized, active voice, true/false indicators added)
- **231 columns** newly annotated from Confluence research

**Key decisions:**
- `entitlement_id` + `prior_bill_sequence_number` both annotated `@UniqueKey` (composite key — no single PK exists) to satisfy the standard's PK requirement
- All `pnl_*` abbreviations expanded to "Profit and Loss" per the no-abbreviations rule
- **GCR** expanded to "Gross Cash Receipts" (certified term) in all 6 GCR amount columns
- COA/COO explained in-context for gap-resolution columns (`coa_flag`, `coa_resource_id`, `original_prior_bill_sequence_number`)
- `@Enumerated` applied to both `variant_price_type_id` columns and `outcome_code`
- `etl_build_mst_ts` includes timezone (MST) per the audit column standard