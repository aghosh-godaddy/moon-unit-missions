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

- Target: ecomm360.dim_bill_vw
- Columns touched: 11
- Columns with pre-existing comments preserved: 11 (all existing comments enhanced, none discarded)
- Columns newly annotated (formal @-annotations added): 2 (bill_id → @PrimaryKey, current_record_flag → @Enumerated)

## Certified Data Dictionary terms applied

| Abbreviation | Official expansion | Where used |
|---|---|---|
| ETL | Extract, Transform, Load | etl_insert_utc_ts, etl_update_utc_ts |
| UTC | Coordinated Universal Time | etl_insert_utc_ts, etl_update_utc_ts |
| MST | Mountain Standard Time | bill_modified_mst_date |
| SCD | Slowly Changing Dimension | current_record_flag |

_Note: Alation Certified Data Dictionary (Folder 6) was unavailable (expired refresh token). No GoDaddy-specific business abbreviations (GCR, MRR, NRU, etc.) were detected in column names — all terms above are standard industry abbreviations._

## Notable decisions

- **bill_id @PrimaryKey**: The composite PK is `bill_id + original_customer_id + merged_customer_id + rep_version_id` per Confluence. @PrimaryKey placed on bill_id (the natural identifier); other three PK components call out "Composite PK component" in prose to stay under 255 chars without repeating the full @PrimaryKey annotation on all four.
- **bill_modified_mst_date type correction**: Original DDL comment said "Timestamp when…" but the column type is `date`, not `timestamp`. Corrected to "Date the bill was last modified…".
- **original_shopper_id / merged_shopper_id sparsity warning**: Confluence explicitly notes these columns are mostly null for records after 2025-04-01 by design. This business caveat was included in both comments (shortened from the verbose Confluence note to fit the 255-char limit).
- **current_record_flag**: Added @Enumerated(TRUE, FALSE) and SCD2 context; described the 9999-12-31 effective-end sentinel. The original comment was vague ("current record flag indicates which is most recent record") — replaced entirely with the SCD2-accurate description. Also noted it is a partition column.
- **etl_insert_utc_ts immutability**: Confluence states this timestamp is immutable unless the table is fully reflowed. This was preserved from research in the comment.
- **Source table references shortened**: Full qualified name `signals_platform_cln.ecomm_unified_order_event_cln` was used for bill_modified_mst_date (most important for lineage). For other columns, just `ecomm_unified_order_event_cln` was used to save characters.

## Longest comments (for QA)

| Column | Length | Comment |
|---|---|---|
| current_record_flag | 181 | @Enumerated(TRUE, FALSE) SCD2 partition flag for the current active bill version. TRUE = active (effective end = 9999-12-31); FALSE = superseded historical record. Partition column. |
| bill_id | 167 | @PrimaryKey Unique identifier for a customer bill (receipt). Part of composite PK with original_customer_id, merged_customer_id, rep_version_id. Sourced from order_id. |
| rep_version_id | 158 | Version identifier for the sales representative assignment on this bill. Composite PK component. Sourced from rep_version_id in ecomm_unified_order_event_cln. |
| original_customer_id | 157 | Customer ID at original bill creation, before any account merges. Composite PK component. Sourced from original_customer_id in ecomm_unified_order_event_cln. |
| bill_modified_mst_date | 151 | Date the bill was last modified, in Mountain Standard Time (MST). Derived from order_date_utc_ts in signals_platform_cln.ecomm_unified_order_event_cln. |

**The agent's final response to the user was:**
All done. Here's a summary of what was accomplished:

## Enrichment complete — `ecomm360.dim_bill_vw`

**DDL updated:** `catalog/config/prod/dlms-api/us-west-2/ecomm360/dim-bill-vw/table.ddl`

### What changed

All 11 columns received enriched comments. Key improvements over the originals:

| Column | Change |
|---|---|
| `bill_id` | Added `@PrimaryKey` annotation; noted composite PK membership; traced to `order_id` upstream |
| `event_id` | Clarified source is the event bus; added upstream table reference |
| `original_shopper_id` | Added backfill-only / mostly-null-post-2025-04-01 caveat |
| `original_customer_id` | Added composite PK component note; upstream source reference |
| `merged_shopper_id` | Same backfill caveat as `original_shopper_id` |
| `merged_customer_id` | Added composite PK component note; upstream source reference |
| `rep_version_id` | Expanded "rep version id" to "sales representative assignment version"; composite PK noted |
| `bill_modified_mst_date` | **Fixed**: "Timestamp" → "Date" (type is `date`); added MST derivation context |
| `current_record_flag` | Added `@Enumerated(TRUE, FALSE)`; SCD2 semantics with 9999-12-31 sentinel explained; noted as partition column |
| `etl_insert_utc_ts` | Added immutability note per Confluence design spec |
| `etl_update_utc_ts` | Expanded ETL abbreviation to "Extract, Transform, Load" |

**Validation:** All 11 comments ≤ 255 chars (longest: `current_record_flag` at 181 chars).