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

- Target: enterprise.fact_bill
- Columns touched: 57
- Columns with pre-existing comments preserved: 3 (entered_by_name, intent, related_subscription)
- Columns newly annotated: 54

## Certified Data Dictionary terms applied

| Abbreviation | Official expansion | Where used |
|---|---|---|
| GCR | Gross Cash Receipts | gcr_usd_amt, gcr_trxn_amt, margin_gcr_usd_amt, margin_gcr_trxn_amt |
| ISC | Internal Sales Channel | bill_isc_source_code |
| ICANN | Internet Corporation for Assigned Names and Numbers | injected_icann_fee_usd_amt, injected_icann_fee_trxn_amt |
| MST | Mountain Standard Time | bill_modified_mst_ts, bill_modified_mst_date, etl_build_mst_ts |
| ADS | Analytics Dataset | original_bill_id (ADS replacement context), bill_source_name |
| PII | Personally Identifiable Information | entered_by_name (preserved annotation) |
| ETL | Extract, Transform, Load | etl_build_mst_ts |

## Notable decisions

- **entered_by_name PII preserved verbatim:** Existing `'PII'` comment retained as leading annotation; descriptive text appended after. Comment now reads `PII. Name or identifier of...`.
- **intent and related_subscription preserved verbatim:** Both had substantive, accurate existing comments matching the ecomm360 reference DDL; kept unchanged as the standard allows.
- **GCR expansion:** Used "Gross Cash Receipts" per instructions' authoritative example. Rejected "Gross Customer Receipt" found in ecomm360.fact_bill_line_vw DDL (Alation was unavailable to confirm via Certified Data Dictionary Folder 6).
- **Composite PK annotated on both columns:** Both `bill_id` and `source_system_name` carry `@PrimaryKey (composite with ...)` to satisfy the standard's PK annotation requirement and make the composite key self-documenting.
- **Single quotes avoided inside comment strings:** To prevent DDL parsing issues in Hive, all example values inside comments use plain text (e.g., `legacy e-comm`, `creditcard`) rather than embedded single quotes.
- **commission_usd_amt / commission_trxn_amt App Store note included:** DQ research confirmed fact_bill values are authoritative for Apple App Store and Google Play; added to both commission columns.
- **etl_build_mst_ts stored-as-string noted:** Column type is `string` (not `timestamp`); comment explicitly flags this to prevent misuse by downstream consumers.
- **NES expansion not used:** `bill_friendly_id` references "New E-Commerce System" in full rather than the unverified NES abbreviation.
- **No comments exceeded 200 chars for the 255-char safety margin concern:** Maximum was 178 chars (commission_trxn_amt), well within limit.

## Longest comments (for QA)

| Column | Length | Comment |
|---|---|---|
| commission_trxn_amt | 178 | Commission amount in transaction currency (see trxn_currency_code). Aggregated from bill lines; null for legacy. fact_bill values are authoritative for App Store and Google Play. |
| commission_usd_amt | 167 | Commission amount in US dollars. Aggregated from bill lines; null for legacy. Differs from uds_order for App Store and Google Play; fact_bill values are authoritative. |
| entered_by_name | 164 | PII. Name or identifier of the agent who entered the bill. For Website+Marketing free product conversions via App Store or Google Play, contains the app store name. |
| exclude_reason_month_end_desc | 159 | Month-end close-specific reason for excluding this bill from period-end revenue calculations. Distinct from exclude_reason_desc which applies to all reporting. |
| exclude_reason_desc | 158 | Reason this bill is excluded from revenue metrics reporting. When set at bill or line level, all metric amount columns for the affected record are zeroed out. |
| injected_icann_fee_usd_amt | 157 | ICANN (Internet Corporation for Assigned Names and Numbers) regulatory fee injected by the system in US dollars. Aggregated from bill lines; null for legacy. |
| rep_version_id | 156 | Reseller/representative version identifier on the bill. Set to -1 for Apple App Store and Google Play orders; sourced from gdshop_receipt_header.repversion. |

**The agent's final response to the user was:**
All done. Here's what was completed:

**DDL enriched:** `catalog/config/prod/us-west-2/enterprise/fact-bill/table.ddl`

- **57 columns** annotated, all comments ≤ 255 chars (max: 178 chars on `commission_trxn_amt`)
- **3 pre-existing comments preserved:**
  - `entered_by_name` — `PII` annotation kept as leading text, descriptive context appended
  - `intent` — existing enum description kept verbatim (accurate, 105 chars)
  - `related_subscription` — existing description kept verbatim (accurate, 73 chars)
- **Composite PK annotated** on both `bill_id` and `source_system_name` with `@PrimaryKey (composite with ...)`
- **GCR = "Gross Cash Receipts"** used per the authoritative instructions example (rejected "Gross Customer Receipt" from ecomm360 DDL)
- **ISC, ICANN, MST, ETL** expanded to full terms throughout
- **`etl_build_mst_ts`** comment flags it is stored as `string` (not `timestamp`) with MST timezone noted — satisfies audit column rule