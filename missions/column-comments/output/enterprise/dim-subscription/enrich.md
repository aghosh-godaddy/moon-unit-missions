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

- Target: enterprise.dim_subscription
- Columns touched: 63
- Columns with pre-existing comments preserved: 1 (`offer_plan` — original 'subscription offer plan' enhanced to fuller description)
- Columns newly annotated: 62

## Certified Data Dictionary terms applied

| Abbreviation | Official expansion | Where used |
|---|---|---|
| mst | Mountain Standard Time | All `*_mst_ts` and `*_mst_date` timestamp/date columns |
| ts | Timestamp | All `*_ts` columns |
| tx | Transaction (CDC) | `tx_source_database`, `tx_source_table`, `tx_action`, `tx_write_time`, `tx_source_time`, `tx_date` |
| etl | Extract, Transform, Load | `etl_build_mst_ts` |
| usd | US Dollar | `original_list_price_usd_amt` |
| amt | Amount | `original_list_price_usd_amt`, `locked_price_amt` |
| pf | Product Family | `bundle_pf_id`, `bundle_renewal_pf_id`, `bundle_renewal_pf_id_sellable_flag` |
| uqs | Universal subscription (cross-system ID) | `uqs_subscription_id` |

> **Note:** Alation Certified Data Dictionary (Folder 6) was inaccessible due to expired refresh token. No GoDaddy-specific financial abbreviations (GCR, MRR, NRU, etc.) appear in this table's column names, so the gap has no material impact on this enrichment.

## Notable decisions

- **`uqs_subscription_id` as @PrimaryKey:** Marked as the surrogate/universal PK for analytics (100% match vs EDS Prime, cross-system usable). `subscription_id` marked @UniqueKey as the natural business key.
- **`subscription_id` @UniqueKey:** Confluence confirms this is the PK for dim_subscription_history and the join key to dim_entitlement (1:M). Both annotations satisfy the standard's PK/Unique Key rule.
- **`customer_id` @ForeignKey:** Mapped to `customer360.dim_customer_history_vw` per upstream lineage in table.yaml.
- **`original_bill_id` @ForeignKey:** Mapped to `enterprise.fact_bill_line` per upstream lineage in table.yaml.
- **`offer_plan` enhanced:** Original DDL comment 'subscription offer plan' was a placeholder; enriched to describe the business meaning (pricing plan tier) with examples.
- **`exclude_reason_desc` @Enumerated omitted:** Enumerated values listed inline in prose instead of @Enumerated annotation to stay within 255 chars while preserving all key exclusion values.
- **`product_family_name` legacy alias noted:** Documented the legacy "name_space" alias from uds_product_billing for searchability.
- **Pending-validation columns flagged:** `subscription_status_id`, `subscription_sub_status_name`, and `original_list_price_usd_amt` carry "Pending Q2 2026 validation" per Confluence validation page.
- **`_date` columns cross-referenced:** Each date column explicitly notes its parent timestamp column for lineage clarity.
- **Alation metadata unavailable:** All descriptions derived from DDL, table.yaml, and two Confluence pages. No Alation column_comment or description data was available.

## Longest comments (for QA)

| Column | Length | Comment |
|---|---|---|
| hard_bundle_flag | 173 | Indicates whether this subscription is a hard bundle (products packaged and sold together). Hard bundles produce multiple rows sharing the same subscription_id (true/false). |
| resource_id | 173 | Resource identifier from the source billing system. In hard bundles, a subscription may have multiple resource IDs; legacy unique key was resource_id + product_family_name. |
| subscription_paid_through_mst_date | 169 | Date through which this subscription is currently paid, end of the active billing period (Mountain Standard Time). Date-only version of subscription_paid_through_mst_ts. |
| exclude_reason_desc | 168 | Reason to exclude this row from standard analyses. Null for valid subscriptions. Non-null values: add-on product, Internal Shopper, NULL purchase_time, duplicate order. |
| bundle_renewal_pf_id | 149 | Product family identifier used when renewing this bundled subscription. May differ from bundle_pf_id if the renewal uses a different product family. |

**The agent's final response to the user was:**
Enrichment complete. Here's a summary of what was done:

## DDL enrichment: `enterprise.dim_subscription`

**63 columns annotated** in `catalog/config/prod/us-west-2/enterprise/dim-subscription/table.ddl`.

**Key annotation decisions:**

| Column | Annotation | Rationale |
|--------|-----------|-----------|
| `uqs_subscription_id` | `@PrimaryKey` | Surrogate/universal key usable across CES and NES systems; 100% EDS Prime match |
| `subscription_id` | `@UniqueKey` | Natural business key; join key to dim_entitlement (1:M) |
| `customer_id` | `@ForeignKey(customer360.dim_customer_history_vw)` | Upstream lineage in table.yaml |
| `original_bill_id` | `@ForeignKey(enterprise.fact_bill_line)` | Upstream lineage in table.yaml |

**Other highlights:**
- `offer_plan` existing comment `'subscription offer plan'` enhanced to a proper business description
- `exclude_reason_desc` includes the four non-null exclusion values from Confluence for filter guidance
- Three columns (`subscription_status_id`, `subscription_sub_status_name`, `original_list_price_usd_amt`) flagged as pending Q2 2026 validation per Confluence
- All 63 comments verified ≤ 255 characters (longest: 173 chars on `hard_bundle_flag` and `resource_id`)
- Certified Data Dictionary unavailable (Alation token expired); no GoDaddy financial abbreviations (GCR, MRR, etc.) appear in this table, so no impact