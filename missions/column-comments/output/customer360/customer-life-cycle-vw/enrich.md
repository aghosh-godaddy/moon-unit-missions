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

- Target: customer360.customer_life_cycle_vw
- Columns touched: 34
- Columns with pre-existing comments preserved: 0 (all 34 rewritten to standard; no 'Employee PII' or equivalent annotations present)
- Columns newly annotated: 34

## Certified Data Dictionary terms applied

| Abbreviation | Official expansion | Where used |
|---|---|---|
| GCR | Gross Cash Receipts | ttm_gcr_usd_amt |
| TTM | Trailing Twelve Months | ttm_gcr_usd_amt, ttm_all_bill_list |
| MST | Mountain Standard Time | etl_build_mst_ts (spelled out), all _mst_ date/ts columns |
| ETL | Extract, Transform, Load | etl_build_mst_ts |
| PNL | P&L (Profit & Loss) | product_pnl_category_list, product_pnl_category_qty, product_pnl_line_list |

> **Note:** Alation Certified Data Dictionary (Folder 6) was inaccessible during research (expired token). GCR expansion used as "Gross Cash Receipts" based on Confluence usage and common GoDaddy convention. All other abbreviations (TTM, MST, ETL, PNL) are industry-standard. GCR should be verified against Alation Folder 6 before publication.

## Notable decisions

- **GCR expansion**: The existing DDL comment used "gross cash received"; the research identified the likely correct expansion as "Gross Cash Receipts" per GoDaddy convention. Used "Gross Cash Receipts (GCR)" in the enriched comment. Needs Alation dict verification.
- **customer_id @PrimaryKey**: Original comment noted "composite with partition_eval_mst_date". Preserved this semantic with condensed wording; dropped dim_customer stable-identifier clause to keep under limit.
- **active_paid_subscription_list**: Closest to limit at 250/255 chars. Retained @ForeignKey annotation plus source table reference `(fact_active_entitlement_last_payment_detail)` as it is operationally important.
- **customer_state_enum**: Original had trailing whitespace; removed. @Enumerated values retained. Inline definitions for each state condensed to one-phrase summaries to fit within 255 chars (230 chars final).
- **customer_acquisition_bill_fraud_flag**: Condensed "indicates potentially fraudulent acquisition activity" and dropped the verbose restatement of customer_fraud_flag to reach 223 chars.
- **customer_churn_mst_date / customer_reactivate_mst_date / customer_merge_mst_date**: All proposed comments from research exceeded 255 chars and were condensed. Key business logic (partition-absence churn detection, reactivation date = eval date, merge applies to source shopper only) was preserved.
- **etl_build_mst_ts**: Fixed typo "build" → "built" from original DDL. Spelled out Mountain Standard Time per audit column standard.
- **No PII annotations**: No 'Employee PII' or equivalent annotations were found in the source DDL; nothing to preserve in that regard.
- **partition_eval_mst_date**: Not a column in the DDL (defined as partition key in YAML only); no COMMENT needed.

## Longest comments (for QA)

| Column | Length | Comment |
|---|---|---|
| active_paid_subscription_list | 250 | @ForeignKey (enterprise.dim_subscription_history): Array of active paid subscription IDs for the customer as of the evaluation date; empty or null for churned customers; sourced from customer driver table (fact_active_entitlement_last_payment_detail) |
| customer_state_enum | 230 | @Enumerated(active, churned, merged, reactivated): Lifecycle state of the customer as of the evaluation date; active = paying subscriber, churned = lapsed, merged = absorbed into another account, reactivated = returned after churn |
| customer_acquisition_bill_fraud_flag | 223 | True if the customer acquisition bill has a corresponding fraud record in dim_bill_fraud_history_vw; indicates potentially fraudulent acquisition; distinct from customer_fraud_flag which reflects customer-level fraud status |
| customer_reactivate_mst_date | 215 | MST date when the customer was most recently reactivated after a churn event; set to evaluation date when a churned customer reappears as active with an acquisition date earlier than today; null if never reactivated |
| customer_merge_mst_date | 205 | MST date when this customer account was merged into another account; sourced from analytic_feature.shopper_merge; populated only for the absorbed/source shopper, not the surviving account; null if no merge |

**The agent's final response to the user was:**
The DDL has been enriched and the summary appended. Here's what was done:

**DDL file updated:** `catalog/config/prod/dlms-api/us-west-2/customer360/customer-life-cycle-vw/table.ddl`

**All 34 columns** now have compliant COMMENT clauses. Key highlights:

| Check | Result |
|---|---|
| All comments ≤ 255 chars | ✓ (longest: 250 chars — `active_paid_subscription_list`) |
| @PrimaryKey present | ✓ (`customer_id`) |
| @UniqueKey present | ✓ (`shopper_id`) |
| @ForeignKey annotations | ✓ (3 columns) |
| @Enumerated annotation | ✓ (`customer_state_enum`) |
| Audit column timezone | ✓ (`etl_build_mst_ts` — spelled out "Mountain Standard Time") |
| GCR expansion | "Gross Cash Receipts" (per Confluence convention; Alation dict unverifiable due to expired token) |

Notable condensations required to meet the 255-char hard limit:
- `customer_churn_mst_date` (268→185 chars): kept partition-absence churn logic, dropped verbose qualifiers
- `customer_reactivate_mst_date` (270→215 chars): preserved reactivation detection logic concisely  
- `customer_merge_mst_date` (263→205 chars): retained "absorbed/source shopper only" semantics
- `customer_state_enum` (336→230 chars): kept enum values, used one-phrase definitions per value