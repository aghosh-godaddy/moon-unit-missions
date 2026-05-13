**Stage name:** validate
**The coding agent was given these instructions:** You are a strict validation agent. Your ONLY job is to enforce the 255-character
limit on column COMMENT strings in the target table's DDL.

## Instructions

1. Read INPUT.md to get the DDL path (under `repos/lake/...`). That file
   was modified by the previous `enrich` stage; you will edit it in place.

2. For EVERY line containing COMMENT, extract the string between the single
   quotes and count its characters.

3. If ALL comments are ≤ 255 characters, leave the file UNCHANGED.

4. If ANY comment exceeds 255 characters, rewrite ONLY those comments to fit
   within 255 characters. Apply these condensing rules IN ORDER:
   - Remove parenthetical synonyms/aliases: "(also known as X)" → remove
   - Remove verbose qualifiers: "that is used for" → remove or shorten
   - Shorten @Enumerated lists: if enum values make it too long, keep only
     the most important 2-3 values and add "etc." or remove @Enumerated entirely
   - Remove secondary context sentences (keep only the primary definition)
   - Use shorter phrasing: "Indicates whether" → "Whether"
   - Abbreviate well-known terms if needed: "Mountain Standard Time" → "MST"
   - As a last resort, drop the least essential clause entirely

   **NEVER truncate mid-word or mid-sentence. NEVER use "..." to cut off.**
   The condensed comment must be a complete, grammatically correct description
   that preserves the essential meaning and any key annotations (@PrimaryKey, etc.).

5. After rewriting, verify AGAIN that all comments are ≤ 255 characters.
   If any still exceed the limit, condense further. Repeat until compliant.

**CRITICAL:** Do NOT change column names, types, order, or table structure.
Do NOT modify comments that are already ≤ 255 characters.

## Append a summary to `validate.md`
The framework pre-created `validate.md` with a header. Append — do not
overwrite — a short report:

```
## Validation summary

- Total columns checked: <N>
- Comments condensed (were > 255): <N>
- Final max comment length: <N>
- Result: PASS | FAIL

## Columns rewritten (if any)

| Column | Before len | After len | Before (first 80 chars) | After (first 80 chars) |
|---|---|---|---|---|
...
```

If no rewrites were needed, say so in one line under "Columns rewritten".

**The agent summarized its work in this way:**

## Validation summary

- Total columns checked: 12
- Comments condensed (were > 255): 0
- Final max comment length: 185
- Result: PASS

## Columns rewritten (if any)

No rewrites were needed. All 12 column comments were already ≤ 255 characters (max length: 185 for `customer_type_name`).

**The agent's final response to the user was:**
All 12 column comments in `repos/lake/catalog/config/prod/us-west-2/analytic-feature/customer-type/table.ddl` are within the 255-character limit:

| Column | Length |
|---|---|
| shopper_id | 134 |
| evaluation_mst_date | 96 |
| as_of_date | 103 |
| first_order_country_code | 133 |
| first_order_mst_date | 130 |
| partner_investor_start_mst_date | 110 |
| customer_type_assignment_mst_date | 85 |
| customer_type_name | 185 |
| customer_type_reason_desc | 136 |
| customer_independent_desc | 143 |
| customer_independent_reason_desc | 148 |
| load_date | 103 |

**Result: PASS** — The DDL file was left unchanged. No rewrites were necessary. The longest comment is 185 characters (`customer_type_name`), well under the 255-character limit.