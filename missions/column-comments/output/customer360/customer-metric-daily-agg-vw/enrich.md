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

- Target: customer360.customer_metric_daily_agg_vw
- Columns touched: 31 (30 main + 1 partition)
- Columns with pre-existing comments preserved: 30 (all existing comments enhanced, not replaced)
- Columns newly annotated: 1 (partition_eval_mst_date — had no prior comment)

## Certified Data Dictionary terms applied

| Abbreviation | Official expansion | Where used |
|---|---|---|
| GCR | Gross Cash Receipts | ttm_gcr_usd_amt |
| TTM | Trailing Twelve Months | ttm_gcr_usd_amt |
| MST | Mountain Standard Time | customer_acquisition_mst_month, etl_build_mst_ts, partition_eval_mst_date |
| ETL | Extract, Transform, Load | etl_build_mst_ts |
| NRU | New Registered User | referenced in Confluence context only; no column uses NRU directly |
| P&L | Profit and Loss | product_ownership_category_list, product_ownership_line_list, product_category_qty |

**Note:** Alation Certified Data Dictionary (Folder 6) was unavailable (expired token). GCR expansion
"Gross Cash Receipts" is sourced from DDL comment + Confluence; NRU from Confluence Customer360 page.
All expansions are flagged as unverified against the official dictionary.

## Notable decisions

- **@PrimaryKey annotation format**: Original comments used `@PrimaryKey:` (with colon); standardized
  to `@PrimaryKey` (no colon) per the Column Description Standard examples.
- **Partition column added**: `partition_eval_mst_date` had no COMMENT in the original DDL; a comment
  was added in the PARTITIONED BY clause describing it as the evaluation date and primary query predicate.
- **Trailing semicolon added**: Original DDL lacked a trailing semicolon; added per DDL syntax standard.
- **GCR expansion**: DDL used "gross cash received"; enriched to "Gross Cash Receipts (GCR)" aligning
  with the likely official term from Confluence context. Cannot fully confirm without Alation dictionary.
- **net_move_qty** (vague original: "Net move quantity"): Enriched using Confluence context — customers
  moving between dimensional groups due to attribute changes (e.g., country or type reclassification).
- **Churn/merge/reactivation semantics** embedded in comments per Confluence lifecycle design doc:
  churned = absent from current partition after being active prior day; merged = no churn date assigned;
  reactivated = re-appears with acquisition date older than evaluation date.
- **etl_build_mst_ts**: Added "(MST, UTC-7)" for timezone clarity and "Audit column" label per standard.
- **product_category_qty**: Clarified as derived count from `product_ownership_category_list`.
- **Source table references** (e.g., `analytic_feature.customer_type_history`, `dim_geography`,
  `ecomm_mart.bill_line_traffic_ext`, `fact_customer_ttm_payment`) embedded in comments where they
  add lookup value without exceeding the 255-char limit.
- **Trailing whitespace** on `brand_name_list` line in original DDL was removed.

## Longest comments (for QA)

| Column | Length | Comment |
|---|---|---|
| customer_type_reason_desc | 163 | @PrimaryKey Text reason for the customer type classification. Grouping dimension for daily aggregated metrics, sourced from analytic_feature.customer_type_history. |
| customer_acquisition_mst_month | 153 | @PrimaryKey Month when the customer was first acquired as a paying customer, in Mountain Standard Time (MST). Cohort grouping dimension. Format: yyyy-MM. |
| fraud_flag | 146 | @PrimaryKey Boolean indicator that the customer was flagged as fraudulent as of the evaluation date. Sourced from analytic_feature.customer_fraud. |
| reseller_type_name | 145 | @PrimaryKey Name of the reseller or private-label type associated with the customer, from dp_enterprise_linked.dim_reseller via private_label_id. |
| customer_type_name | 144 | @PrimaryKey Customer lifecycle type at the evaluation date (e.g., Active, Churned, Lapsed). Sourced from analytic_feature.customer_type_history. |
| ttm_gcr_usd_amt | 143 | Trailing twelve months (TTM) total Gross Cash Receipts (GCR) in US dollars for customers in this group. Sourced from fact_customer_ttm_payment. |

**The agent's final response to the user was:**
Enrichment complete. Here's what was done:

**DDL file updated:** `catalog/config/prod/dlms-api/us-west-2/customer360/customer-metric-daily-agg-vw/table.ddl`

- **31 columns annotated** (30 main columns + the `partition_eval_mst_date` partition column which had no prior comment)
- **All 30 existing comments enhanced** — existing `@PrimaryKey` annotations preserved and extended with source table context and grouping-dimension semantics from Confluence
- **Zero comments over 255 characters** — max length is 163 chars (`customer_type_reason_desc`)

**Key enrichments:**
- Standardized `@PrimaryKey:` → `@PrimaryKey` (per standard format)
- `ttm_gcr_usd_amt`: expanded to "Gross Cash Receipts (GCR)" with TTM and source table reference
- `net_move_qty`: "Net move quantity" (vague) → clarified as customers moving between dimensional groups due to attribute changes
- `etl_build_mst_ts`: added `(MST, UTC-7)` timezone specificity and "Audit column" label
- `partition_eval_mst_date`: new comment added as evaluation date and primary query predicate
- Churn/merge/reactivation lifecycle semantics embedded in respective metric column comments
- Trailing semicolon added per DDL syntax standard