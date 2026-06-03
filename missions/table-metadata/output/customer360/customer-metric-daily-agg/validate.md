**Stage name:** validate
**The coding agent was given these instructions:** You are a strict validation agent. Your job is to ensure the final metadata doc is:
1) accurate (no false claims) and 2) complete in structure (all 20 sections present).

## Step 1: Read all artifacts
Read:
- `INPUT.md`
- `gather.md`
- `analyze.md`
- `RESOLVED_TARGET.json`
- `TABLE_METADATA.md`

## Step 2: Accuracy validation
For each non-trivial claim in TABLE_METADATA.md (grain, keys, filters, metrics, SLA, lineage):
- Identify the exact evidence source (PySpark line, DAG setting, lake table.yaml, etc.)
- If evidence is missing or contradictory, rewrite the metadata doc to remove or soften the claim.
- If a claim cannot be validated, replace it with a REQUIRES_MANUAL_INPUT marker.

## Step 2b: C1 Source Table validation (CRITICAL)
Scan the C1 "Source Table(s)" column in TABLE_METADATA.md. For EACH entry:
- If it references a local/intermediate/staging table (look for patterns like `*_stg`,
  `*_conformed.*`, `*_driver`, `analytic_local.*`, or any table NOT in the lake registry),
  this is a FAILURE. Replace it with:
  - The actual lake table if analyze.md resolved it
  - `UNRESOLVED - requires manual input` if analyze.md could not resolve it
- Only lake tables (those in `repos/lake/`) or external systems are acceptable as sources.

## Step 3: Completeness validation
Ensure all 20 sections exist with the correct headings. If missing, add them.
If a section is too sparse and cannot be completed accurately, add the manual-input marker.

## Step 4: Append a report to validate.md
Append:
- Target table
- PASS/FAIL for accuracy and completeness
- List of issues found + how they were fixed
- Sections requiring manual input (final list)

**The agent summarized its work in this way:**
