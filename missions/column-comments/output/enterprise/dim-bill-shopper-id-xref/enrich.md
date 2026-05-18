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

- Target: enterprise.dim_bill_shopper_id_xref
- Columns touched: 8
- Columns with pre-existing comments preserved: 0
- Columns newly annotated: 8

## Certified Data Dictionary terms applied

| Abbreviation | Official expansion | Where used |
|---|---|---|
| mst | Mountain Standard Time | bill_modified_mst_ts, bill_modified_mst_date, etl_build_mst_ts |
| etl | Extract, Transform, Load | etl_build_mst_ts |
| ts | Timestamp | bill_modified_mst_ts, etl_build_mst_ts |
| desc | Description (label for text field) | original_shopper_exclude_reason_desc, original_shopper_exclude_reason_month_end_desc |
| xref | Cross-reference | table name only (not a column) |

Note: Alation Certified Data Dictionary (Folder ID 6) was unavailable due to an expired refresh token. No GoDaddy-specific business abbreviations (GCR, MRR, NRU, etc.) appear in this table's columns; all abbreviations resolved from standard data-engineering conventions.

## Notable decisions

- Alation was entirely unavailable (HTTP 401000 — expired refresh token). Confluence page 10372130 served as the sole external source; per-column source field mappings provided the basis for bill_modified_mst_ts and bill_modified_mst_date, which had no text description in Confluence.
- Single quotes were avoided inside COMMENT strings to prevent SQL parsing issues. The example value "internal shopper" for original_shopper_exclude_reason_desc was dropped in favour of sourcing context (rp_salesMonitor_internalShopper_snap).
- original_shopper_exclude_reason_desc is the longest comment at 241 chars; the rp_salesMonitor_internalShopper_snap source name was retained because it is the only authoritative pointer for the exclusion logic.
- merged_shopper_id explicitly states it does not track intermediate merge history — this nuance is from the Confluence design doc and is critical for correct analytical use.
- bill_modified_mst_date documents that it is the string representation of bill_modified_mst_ts, preventing consumers from treating it as an independent source of truth.
- etl_build_mst_ts carries the Airflow DAG name (ecomm_unified_bill) for lineage traceability.
- @PrimaryKey annotation applied to bill_id (one row per bill, as documented in Confluence). No @ForeignKey annotations were added as the DDL has no explicit FK constraints declared.

## Longest comments (for QA)

| Column | Length | Comment |
|---|---|---|
| original_shopper_exclude_reason_desc | 241 | Exclusion reason for revenue reporting based on the original shopper identifier. Classifies whether the original shopper is an internal GoDaddy employee excluded from external sales metrics. Sourced from rp_salesMonitor_internalShopper_snap. |
| original_shopper_exclude_reason_month_end_desc | 220 | Exclusion reason for revenue reporting based on the original shopper identifier as evaluated at month-end. Uses month-end snapshots (rp_salesMonitor_internalShopper_snap, fortknox_shopper_snap) for stable classification. |
| original_shopper_id | 201 | Shopper identifier of the customer who originally placed the order, captured at INSERT time. Does not change with subsequent shopper account merges. Equals merged_shopper_id when no merge has occurred. |
| bill_id | 199 | @PrimaryKey Unique identifier for a GoDaddy customer bill (receipt). Sourced from gdshop_receipt_header.order_id, gdshop_receipt_virtual_order.order_id, and nds_smartline_event.subscription_order_id. |

**The agent's final response to the user was:**
All done. Here's a summary of what was produced:

---

## Enrichment complete — `enterprise.dim_bill_shopper_id_xref`

**DDL file updated:** `catalog/config/prod/us-west-2/enterprise/dim-bill-shopper-id-xref/table.ddl`

**8 columns annotated (0 pre-existing, 8 new):**

| Column | Chars | Key decisions |
|---|---|---|
| `bill_id` | 199 | `@PrimaryKey`; three upstream source IDs listed |
| `original_shopper_id` | 201 | Captures INSERT-time immutability and merge-unchanged semantics |
| `merged_shopper_id` | 197 | Flags no intermediate merge history; equals original when no merge |
| `original_shopper_exclude_reason_desc` | 241 | Internal-shopper exclusion logic; source table named |
| `original_shopper_exclude_reason_month_end_desc` | 220 | Month-end snapshot variant; both source tables named |
| `bill_modified_mst_ts` | 187 | Timestamp with MST zone; upstream source fields cited |
| `bill_modified_mst_date` | 177 | String date; calls out it derives from `bill_modified_mst_ts` |
| `etl_build_mst_ts` | 195 | Audit timestamp; Airflow DAG name included for lineage |

All comments are within the 255-character hard limit. The longest is `original_shopper_exclude_reason_desc` at 241 characters.