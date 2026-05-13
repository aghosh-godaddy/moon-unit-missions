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

- Target: analytic.ads_bill_line
- Columns touched: 199
- Columns with pre-existing comments preserved: 10
- Columns newly annotated: 189

## Certified Data Dictionary terms applied

| Abbreviation | Official expansion | Where used |
|---|---|---|
| GCR | Gross Cash Receipts | gcr_usd_amt, gcr_trxn_amt, gcr_constant_currency_amt, margin_gcr_usd_amt, margin_gcr_trxn_amt, free_bill_flag, accounting_deferred_flag, free_bill_line_flag, free_bill_line_with_fair_market_value_flag, pnl_priority_num |
| ISC | Internet Source Code | bill_isc_source_code, bill_isc_source_code_desc, bill_isc_company_id, bill_isc_campaign_id, bill_isc_channel_id, bill_isc_product_id, bill_isc_vendor_id, bill_isc_media_specialist_id, bill_isc_sub_channel_id, bill_isc_channel_name, bill_isc_sub_channel_name, bill_isc_vendor_name, bill_isc_product_name, bill_isc_media_specialist_name, bill_isc_viral_flag |
| C3 | Customer Care Center | entered_by_name, c3_rep_name, c3_rep_supervisor_name, c3_rep_department_name, c3_call_center_location_name, c3_bill_source_code, c3_bill_process_name, c3_receipt_move_flag, c3_bill_flag, c3_attribution_type_name |
| CRM | Customer Relationship Management | crm_portfolio_type_name, crm_portfolio_rep_id, crm_portfolio_rep_name, current_crm_portfolio_type_name, current_crm_portfolio_rep_id, current_crm_portfolio_rep_name |
| PnL | Profit and Loss | product_pnl_category_name, product_pnl_group_name, product_pnl_line_name, product_pnl_subline_name, product_pnl_version_name, pnl_priority_num, pnl_usi_flag, pnl_gdii_flag, pnl_partner_flag, pnl_dri_flag, pnl_commerce_flag, product_pnl_new_renewal_name |
| PLID | Private Label ID | private_label_id, reseller_type_name, accounting_company_id |
| CPL | Common Purchase Log | bill_payment_cpl_trxn_currency_code, bill_payment_cpl_trxn_amt |
| FMV | Fair Market Value | fair_market_value_usd_amt, fair_market_value_trxn_amt, injected_fair_market_value_usd_amt, injected_fair_market_value_trxn_amt, accounting_deferred_flag, free_bill_line_with_fair_market_value_flag |
| MSRP | Manufacturer's Suggested Retail Price | msrp_duration_unit_usd_amt, msrp_duration_unit_trxn_amt, msrp_total_usd_amt, msrp_total_trxn_amt |
| COGS | Cost of Goods Sold | margin_gcr_usd_amt |
| ICANN | Internet Corporation for Assigned Names and Numbers | fee_usd_amt, fee_trxn_amt, injected_icann_fee_usd_amt, injected_icann_fee_trxn_amt, margin_gcr_usd_amt |
| GAAP | Generally Accepted Accounting Principles | fair_market_value_usd_amt, accounting_deferred_flag |
| WWD | Wild West Domains | reseller_type_name, accounting_company_id |
| MST | Mountain Standard Time | bill_modified_mst_ts, bill_modified_mst_date, etl_build_mst_ts, new_acquisition_bill_mst_date, new_registered_user_bill_mst_date, bill_modified_mst_date_prior_year |
| TLD | Top-Level Domain | domain_back_end_registry_name, domain_front_end_registry_name, domain_registry_family_name, domain_parent_tld_name |
| USI | Unified Storefront Initiative | pnl_usi_flag |
| DRI | Digital River Inc. | pnl_dri_flag |

## Notable decisions

- **Alation unavailable**: Certified Data Dictionary (Folder 6) could not be retrieved due to expired refresh token. All abbreviation expansions sourced from Confluence page 10368952 acronyms section.
- **Employee PII preserved verbatim**: All 6 columns (`entered_by_name`, `bill_isc_media_specialist_name`, `c3_rep_name`, `c3_rep_supervisor_name`, `crm_portfolio_rep_name`, `current_crm_portfolio_rep_name`) retain `Employee PII.` prefix with descriptive text appended after.
- **Composite primary key**: `bill_id` and `bill_line_num` are annotated with `@PrimaryKey` and cross-reference each other as a composite key, as there is no single-column PK.
- **`intent` existing comment**: Rewritten from original enum description to standards-compliant format with `@Enumerated` annotation; business context preserved.
- **`related_subscription` existing comment**: Slightly enhanced to active voice with added context; original meaning preserved.
- **`free_bill_line_flag` and `free_bill_line_with_fair_market_value_flag`**: Original comments rewritten from descriptive noun phrases to boolean True/False format per standard, with GCR expanded to `Gross Cash Receipts (GCR)`.
- **Apostrophes avoided**: Comment for `receipt_regular_price_usd_amt` rephrased to "Regular current-day list price" to avoid SQL single-quote escaping issues inside single-quoted comment strings.
- **GDII abbreviation**: Not found in any available source; retained as-is in `pnl_gdii_flag` description with no invented expansion.
- **`product_pnl_new_renewal_name`**: Distinguished from `pnl_new_renewal` and `original_product_pnl_new_renewal_name` by noting it uses custom logic applied as of April 2017 per Business Analyst Managers, as documented in Confluence.
- **`accounting_company_id`**: Wild West Domains expanded inline per WWD official name; Blue Razor retained as proper name (no expansion in Confluence).

## Longest comments (for QA)

| Column | Length | Comment |
|---|---|---|
| new_acquisition_flag | 164 | True if this bill was the first paid purchase by the shopper. In merge scenarios, use COUNT(DISTINCT bill_id) WHERE new_acquisition_flag = TRUE for accurate counts. |
| c3_rep_name | 162 | Employee PII. Customer Care Center (C3) representative name for this order. "Web" or "Billing Agent" for non-C3 orders; "Missing" for C3 orders with missing data. |
| new_registered_user_flag | 159 | True at the shopper first unpaid bill ID. Cannot be True simultaneously with new_acquisition_flag. Set once per shopper; excludes Change of Ownership products. |
| new_registered_user_bill_mst_date | 157 | Date of the shopper first unpaid order (fair market value <= 0) in Mountain Standard Time (MST). Set once per shopper; excludes Change of Ownership products. |
| units_as_bills_flag | 156 | True if the purchase is for 1 resource regardless of quantity; False if unit_qty represents number of resources. Use product_unit_qty for actual unit count. |
| accounting_deferred_flag | 154 | True when deferral pf_ID is not NULL; value equals Fair Market Value (FMV) subject to GAAP deferred revenue rules. False means GCR recognized immediately. |
| product_pnl_new_renewal_name | 152 | New or renewal designation with custom business logic (as of April 2017). May differ from other Unified Data Sources; consult Business Analyst Managers. |
| c3_rep_supervisor_name | 151 | Employee PII. Supervisor name of the Customer Care Center (C3) representative. "Web" or "Billing Agent" for non-C3 orders; "Missing" if data is absent. |

**The agent's final response to the user was:**
The enrichment is complete. Here's a summary of what was done:

## Work completed

**Target:** `analytic.ads_bill_line` — DDL at `catalog/config/prod/us-west-2/analytic/ads-bill-line/table.ddl`

**DDL enrichment:**
- All **199 columns** now have `COMMENT` clauses
- Every comment is ≤ 255 characters (longest is 164 chars on `new_acquisition_flag`)
- **Composite `@PrimaryKey`** annotated on `bill_id` and `bill_line_num`

**Existing comments preserved:**
- **6 Employee PII columns** — `entered_by_name`, `bill_isc_media_specialist_name`, `c3_rep_name`, `c3_rep_supervisor_name`, `crm_portfolio_rep_name`, `current_crm_portfolio_rep_name` — all retain `Employee PII.` prefix with descriptive text appended
- **4 business-definition columns** — `intent`, `related_subscription`, `free_bill_line_flag`, `free_bill_line_with_fair_market_value_flag` — enhanced to meet the standard while preserving original meaning

**Official terminology applied (from Confluence acronyms, Alation was unavailable):**
- GCR → Gross Cash Receipts
- ISC → Internet Source Code
- C3 → Customer Care Center
- CRM → Customer Relationship Management
- PnL → Profit and Loss
- FMV → Fair Market Value
- MSRP → Manufacturer's Suggested Retail Price
- COGS → Cost of Goods Sold
- PLID → Private Label ID
- WWD → Wild West Domains
- Plus: ICANN, GAAP, CPL, MST, TLD, USI, DRI