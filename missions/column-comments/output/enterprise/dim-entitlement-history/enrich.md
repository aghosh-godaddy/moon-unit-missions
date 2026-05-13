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

- Target: enterprise.dim_entitlement_history
- Columns touched: 36
- Columns with pre-existing comments preserved: 0
- Columns newly annotated: 36

## Certified Data Dictionary terms applied

| Abbreviation | Official expansion | Where used |
|---|---|---|
| pf_id | Product Family ID | pf_id, base_pf_id |
| mst | Mountain Standard Time | entitlement_create_mst_ts, entitlement_create_mst_date, entitlement_modify_mst_ts, entitlement_modify_mst_date, entitlement_mst_year, entitlement_mst_month, etl_build_mst_ts |
| ts | Timestamp | entitlement_create_mst_ts, entitlement_modify_mst_ts, tx_write_time, tx_source_time, etl_build_mst_ts |
| amt | Amount | base_original_list_price_usd_amt |
| desc | Description | product_type_desc, exclude_reason_desc |
| tx | Change Data Capture (CDC) transaction | tx_source_database, tx_source_table, tx_action, tx_write_time, tx_source_id, tx_source_time, tx_date |
| etl | Extract, Transform, Load | etl_build_mst_ts |
| usd | US dollars | base_original_list_price_usd_amt |
| NES | New eCommerce System | entitlement_id, source_system_name |
| CES | Classic eCommerce System | entitlement_id, resource_id, product_type_id, product_family_name, entitlement_addon_id, source_system_name |

Note: No financial metric abbreviations (GCR, MRR, NRU, MAU, etc.) appear in this table. Alation Certified Data Dictionary (Document Folder 6) was unavailable due to expired token; mappings above are drawn from Confluence and standard GoDaddy data lake conventions documented in research.md.

## Notable decisions

- No pre-existing DDL comments — all 36 annotations are net-new.
- `entitlement_id`: Annotated @PrimaryKey per Confluence page 76447948; description covers both NES (UUID) and CES (composite key) construction to eliminate common confusion.
- `subscription_id`: Annotated @ForeignKey(enterprise.dim_subscription_history) and included the join-key caveat (partition_history_mst_date) per Confluence guidance.
- `pf_id`: Annotated @ForeignKey(gdmastercatalog.catalog_product_snap) (primary reference per Confluence); bigreporting.dim_product_snap secondary reference omitted to stay within limit.
- `exclude_reason_desc`: Full @Enumerated list included (all 5 known values from Confluence). At 222 chars — the longest comment — this was carefully validated.
- `entitlement_obsolete_resource_id`: Comment reflects author's own design note ("Business meaning is not well defined") per Confluence page 3278396895 to set accurate consumer expectations.
- `product_family_name`: Legacy alias `name_space` (from UDS system) included as context per Confluence.
- `entitlement_external_resource_id`: Legacy alias `orion_id` (from UDS system) included as context per Confluence.
- `tx_*` columns: Expanded `tx` prefix as "Change Data Capture (CDC)" throughout for clarity; no Alation source comments were available to preserve.
- `etl_build_mst_ts`: Expanded ETL in full per standard; noted MST timezone per audit-column rule.
- Alation token expired: No Source Comments from DDL or reference table (enterprise.dim_entitlement, id 6229554) were available to preserve or merge.

## Longest comments (for QA)

| Column | Length | Comment |
|---|---|---|
| exclude_reason_desc | 222 | Reason for excluding this entitlement from standard analysis. NULL indicates a valid entitlement. @Enumerated(add-on product, Internal Shopper, Obsolete row, extra external resource, Shopper_ID is null in the source table) |
| entitlement_id | 220 | @PrimaryKey Unique identifier for an entitlement. For NES (New eCommerce System), a UUID generated by the eCommerce platform. For CES (Classic eCommerce System), a composite of resource_id, product_type_id, and addon_id. |
| subscription_id | 212 | @ForeignKey(enterprise.dim_subscription_history) Subscription identifier linking this entitlement to its parent subscription. One subscription may have multiple entitlements. Join with partition_history_mst_date. |
| entitlement_obsolete_resource_id | 208 | Obsolete resource identifier from external_resource.obsolete_resource_id in the source system. Represents a superseded resource; retained for lineage and troubleshooting. Business meaning is not well defined. |
| resource_id | 197 | Resource identifier from the source eCommerce system. For CES bundle subscriptions, the same resource_id may appear on multiple entitlement rows when bundle parent and children share an identifier. |

**The agent's final response to the user was:**
All work is complete. Here's what was done:

## Summary

**Target:** `enterprise.dim_entitlement_history`
**DDL:** `catalog/config/prod/us-west-2/enterprise/dim-entitlement-history/table.ddl`

### What was done

1. **Read all inputs** — DDL (36 columns, no existing comments), YAML metadata, and the research.md produced by the prior stage (Confluence pages + column analysis; Alation token was expired).

2. **Wrote COMMENT clauses for all 36 columns**, following the Data Governance Council standard:
   - `entitlement_id` → `@PrimaryKey` with NES/CES construction explained
   - `subscription_id` → `@ForeignKey(enterprise.dim_subscription_history)` + join hint
   - `pf_id` → `@ForeignKey(gdmastercatalog.catalog_product_snap)` + Product Family ID expansion
   - `exclude_reason_desc` → `@Enumerated` with all 5 known non-null values
   - `etl_build_mst_ts` → audit timestamp with MST timezone noted
   - CDC `tx_*` columns → "Change Data Capture (CDC)" expanded throughout
   - Legacy aliases preserved (`orion_id`, `name_space`, etc.)

3. **Validated all 36 comments ≤ 255 characters** — longest is `exclude_reason_desc` at **222 chars**. All pass.

4. **Appended enrichment summary to `enrich.md`** with audit trail, certified term mappings, notable decisions, and QA table of longest comments.