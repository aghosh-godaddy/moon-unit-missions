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

- Target: ecomm360.fact_bill_line_vw
- Columns touched: 98
- Columns with pre-existing comments preserved: 0 (all comments rewritten/enhanced; no 'Employee PII' or other protected annotations were present)
- Columns newly annotated: 98

## Certified Data Dictionary terms applied

| Abbreviation | Official expansion | Where used |
|---|---|---|
| GCR | Gross Cash Receipts | gcr_usd_amt, gcr_trxn_amt, margin_gcr_usd_amt, margin_gcr_trxn_amt, free_order_flag |
| MSRP | Manufacturer Suggested Retail Price | msrp_duration_unit_usd_amt, msrp_duration_unit_trxn_amt, msrp_total_usd_amt, msrp_total_trxn_amt |
| ISC | Internal Sales Channel | bill_isc_source_code |
| ICANN | Internet Corporation for Assigned Names and Numbers | fee_usd_amt, fee_trxn_amt, injected_icann_fee_usd_amt, injected_icann_fee_trxn_amt |
| MST | Mountain Standard Time | bill_modified_mst_ts, bill_modified_mst_date |
| UTC | Coordinated Universal Time | etl_insert_utc_ts, etl_update_utc_ts |
| PF | Product Family | pf_id, upgraded_pf_id |
| ISC | Internal Sales Channel | bill_isc_source_code |

## Notable decisions

- **GCR correction**: Previous DDL comments said "Gross Customer Receipt"; Confluence context and research.md explicitly flag this as likely incorrect and recommend "Gross Cash Receipts". Applied "Gross Cash Receipts" to all four GCR columns. Alation Certified Data Dictionary was unavailable (token expired) so this is based on Confluence research — should be confirmed when Alation access is restored.
- **fee_usd_amt / fee_trxn_amt**: Original comments said "Additional fees charged" (too generic). Confluence confirms these map specifically to `tax_item_icann_fee_usd_amt` / `trxn_amt`. Rewritten to explicitly name the ICANN regulatory fee.
- **receipt_regular_price_usd_amt / trxn_amt**: Original comments said "Regular price before discounts" which is misleading — this column uses `adjusted_current_price` (already discounted). Rewritten to "Current-period sale price including any active discounts."
- **msrp_duration_unit vs msrp_total**: Distinguished clearly — `msrp_duration_unit` uses current product list price; `msrp_total` uses the original undiscounted list price.
- **Unpopulated columns**: Four columns noted as currently not populated (product_uri, translation_language_name, virtual_order_flag, bill_friendly_id) — comments now state "Currently not populated; reserved for future use."
- **accounting_company_id**: Enriched with subsidiary consolidation context (Canadian/Indian subsidiaries remapped to parent entity IDs).
- **PK annotation**: Added @PrimaryKey to both bill_id and bill_line_num (composite primary key per Confluence).
- **FK annotation**: Added @ForeignKey(dim_product) to pf_id per Confluence design page.
- **@Enumerated**: Added to intent column with known values (FREEMIUM_PURCHASE, FREE_PURCHASE, FREE_TRIAL_MODIFY).
- **Audit columns**: etl_insert_utc_ts and etl_update_utc_ts include UTC and ISO 8601 timezone context.
- **bill_modified_mst_ts naming**: Comment notes the "modified" naming reflects legacy convention; the column actually holds the order date converted to MST.
- **commission columns**: Noted as Channel 3 (C3) commissions per Confluence source mapping.

## Longest comments (for QA)

| Column | Length | Comment |
|---|---|---|
| gcr_usd_amt | 171 | Gross Cash Receipts (GCR) for this line item in US dollars (USD). Derived: fair_market_value + item_subtotal - ICANN fee - injected fair market value - injected ICANN fee. |
| msrp_duration_unit_trxn_amt | 170 | Manufacturer Suggested Retail Price (MSRP) per subscription period in transaction currency, based on current product list price times quantity and period, plus ICANN fee. |
| msrp_total_trxn_amt | 170 | Total Manufacturer Suggested Retail Price (MSRP) in transaction currency, based on the original undiscounted product list price times quantity and period, plus ICANN fee. |
| gcr_trxn_amt | 165 | Gross Cash Receipts (GCR) for this line item in the transaction currency. Derived: fair_market_value + item_subtotal - ICANN fee - injected FMV - injected ICANN fee. |
| aftermarket_seller_commission_usd_amt | 164 | Commission paid to the domain aftermarket seller in US dollars (USD). Derived: fair market value minus auction commission when commission_product_flag=1, else zero. |

**The agent's final response to the user was:**
The DDL enrichment is complete. Here's a summary of what was done:

**Target:** `ecomm360.fact_bill_line_vw`
**DDL path:** `catalog/config/prod/dlms-api/us-west-2/ecomm360/fact-bill-line-vw/table.ddl`

**Results:**
- **98 columns** enriched with compliant COMMENT clauses
- **Max comment length: 171 chars** — all well under the 255-char hard limit
- **0 comments** exceed the limit

**Key corrections applied:**
| Column(s) | Change |
|---|---|
| `gcr_*`, `margin_gcr_*` | Corrected "Gross Customer Receipt" → **"Gross Cash Receipts (GCR)"** per research.md recommendation |
| `fee_usd_amt`, `fee_trxn_amt` | Replaced generic "Additional fees" → **ICANN regulatory fee** (specific source mapping from Confluence) |
| `receipt_regular_price_*` | Replaced misleading "Regular price before discounts" → **"Current-period sale price including any active discounts"** |
| `product_uri`, `translation_language_name`, `virtual_order_flag`, `bill_friendly_id` | Added **"Currently not populated; reserved for future use"** |
| `msrp_total_*` vs `msrp_duration_unit_*` | Clarified distinction: `total` uses original undiscounted list price; `duration_unit` uses current list price |

**Annotations added:** `@PrimaryKey` (bill_id, bill_line_num), `@ForeignKey(dim_product)` (pf_id), `@Enumerated(...)` (intent)