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

- Target: gd-traffic-mart.analytic_traffic_agg
- Columns touched: 85
- Columns with pre-existing comments preserved: 85 (all columns had existing comments; all were enhanced)
- Columns newly annotated: 0 (all had pre-existing comments; enriched in place)

## Certified Data Dictionary terms applied

| Abbreviation | Official expansion | Where used |
|---|---|---|
| GCR | Gross Cash Receipts | order_fraud_name, new_purchase_saw_cart_session_cnt, renewal_saw_cart_session_cnt, saw_cart_session_cnt, dpp_serp_session_cnt, gcr_session_cnt, new_gcr_session_cnt, renewal_gcr_session_cnt, new_purchase_dpp_session_cnt, wsb_ftsu_dpp_session_cnt, all order_*_gcr_* columns (30+ uses) |
| ccGCR | Constant Currency Gross Cash Receipts | order_ccgcr_usd_amt, order_new_ccgcr_usd_amt |
| WSB | Website Builder | wsb_ftsu_dpp_session_cnt, wsb_free_order_session_cnt, wsb_freemium_session_cnt, wsb_freemat_session_cnt, order_wsb_new_gcr_session_cnt, order_wsb_free_order_cnt, order_wsb_new_gcr_usd_amt |
| DPP | Domain/Product Purchase Path | dpp_serp_session_cnt, new_purchase_dpp_session_cnt, wsb_ftsu_dpp_session_cnt |
| SERP | Search Engine Results Page | dpp_serp_session_cnt |
| SSO | Single Sign-On | sso_mya_visit_name |
| MYA | Manage Your Account | sso_mya_visit_name |
| FOS | Front of Site | fos_session_name |
| FTSU | Free Trial Sign-Up | wsb_ftsu_dpp_session_cnt |
| O365 | Office 365 | order_o365_new_gcr_session_cnt, order_o365_new_gcr_usd_amt |

> **Note**: Alation Certified Data Dictionary (Document Folder 6) was unavailable due to expired refresh token. All expansions sourced from DDL inline comments and Confluence page 3292767683 (WAA v2 Design).

## Notable decisions

- **@UniqueKey annotation**: No surrogate primary key exists. Added `@UniqueKey component` to `website_activity_mst_date` as the leading composite-key dimension to satisfy the mandatory PK annotation rule; the full composite key spans all dimension columns.
- **session_duration_sec**: Original comment "Session duration in seconds" was misleading for an aggregated table. Rewritten as "Total aggregated session duration in seconds across all sessions in the group" to clarify it is a SUM. Added lineage note referencing former column name `ga_session_duration_seconds_qty`.
- **page_advance_session_cnt**: Original comment "Distinct count of advanced sessions" left "advanced" undefined. Rewritten to explicitly state "more than one page view" based on WAA v2 Design doc context.
- **order_ccgcr_usd_amt / order_new_ccgcr_usd_amt**: Original comments were terse ("Constant currency analog of order_gcr_usd_amt", "New ccGCR amount in USD"). Both rewritten to fully expand ccGCR and explain the foreign-exchange normalization purpose.
- **website_activity_exclude_reason_name**: Added "NULL for rows that are not excluded" to clarify the NULL semantics, which was absent from the original comment.
- **Abbreviation strategy**: All GCR occurrences expanded to "Gross Cash Receipts (GCR)" on first contextual use within each comment; kept "(GCR)" parenthetical throughout for searchability without exceeding 255 chars.
- **No Alation Source Comments to preserve**: Alation was inaccessible (expired token); no `column_comment` or `description` fields could be retrieved for either the target table or the reference table. No 'Employee PII' or other special annotations were present in the original DDL.
- **Double quotes in comments**: Used double quotes (e.g., `"True Direct"`, `"Front of Site"`) for enumerated value examples inside single-quoted comment strings — valid SQL syntax, avoids escaping complexity.

## Longest comments (for QA)

| Column | Length | Comment |
|---|---|---|
| order_fraud_name | 158 | Indicates if a fraudulent order with positive Gross Cash Receipts (GCR) is present in the session or as an unattributed order. NULL for non-ordering sessions. |
| wsb_ftsu_dpp_session_cnt | 153 | Distinct count of sessions with Domain/Product Purchase Path (DPP) pages in the order path from Website Builder (WSB) Free Trial Sign-Up (FTSU) products. |
| website_activity_mst_date | 147 | @UniqueKey component. Date of website activity: session date for traffic sessions, order date for unattributed web orders (Mountain Standard Time). |
| order_new_ccgcr_usd_amt | 143 | Total Constant Currency Gross Cash Receipts (ccGCR) from new product purchases in USD, adjusted to remove foreign exchange fluctuation effects. |
| fos_session_name | 141 | Indicates if visitors viewed Front of Site (FOS) pages in the session. "Front of Site" or "Not Front of Site". NULL for unattributed orders. |

**The agent's final response to the user was:**
All work is complete. Here's a summary of what was done:

## DDL enrichment complete — `gd-traffic-mart.analytic_traffic_agg`

**85 columns enriched** in `catalog/config/prod/us-west-2/gd-traffic-mart/analytic-traffic-agg/table.ddl`

### Key changes made

| Category | What changed |
|---|---|
| **@UniqueKey annotation** | Added to `website_activity_mst_date` (composite key table — no surrogate PK exists) |
| **GCR expansion** | "Gross Cash Receipts (GCR)" applied across all 30+ GCR columns |
| **ccGCR expansion** | Fully spelled out as "Constant Currency Gross Cash Receipts (ccGCR)" in both ccGCR columns, with FX normalization context added |
| **Abbreviations expanded** | WSB → Website Builder, DPP → Domain/Product Purchase Path, SERP → Search Engine Results Page, SSO → Single Sign-On, MYA → Manage Your Account, FOS → Front of Site, FTSU → Free Trial Sign-Up, O365 → Office 365 |
| **session_duration_sec** | Clarified as a SUM ("Total aggregated…"), added former column name reference |
| **page_advance_session_cnt** | "advanced sessions" defined as "more than one page view" |
| **Exclusion NULL semantics** | Added "NULL for rows that are not excluded" to `website_activity_exclude_reason_name` |
| **ccGCR descriptions** | Expanded minimal originals to include FX normalization purpose |

**Validation**: All 85 comments verified ≤ 255 chars. Longest: 158 chars (`order_fraud_name`).