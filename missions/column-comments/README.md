# Column Comments Enrichment Mission

Automatically enriches Data Lake table DDL files with standardized column descriptions following GoDaddy's Data Governance Council Column Description Standard.

## How It Works

A three-stage Moon Units mission. The container's workspace is bind-mounted
to the host via `mu launch --mount-workspace`, so stage outputs appear on
the host filesystem as they're written — no post-run `docker cp` needed.

1. **Research** (`research.md`) — Clones `gdcorp-dna/lake`, reads the table
   DDL/YAML, fetches Confluence design pages, queries Alation for existing
   column metadata and reference-table descriptions, and pulls official term
   definitions from the Certified Data Dictionary (Folder 6).
2. **Enrich** (`enrich.md`) — Rewrites the cloned `table.ddl` in place with
   COMMENT clauses on every column, applying annotation rules (`@PrimaryKey`,
   `@ForeignKey`, `@Enumerated`), the 255-char limit, and official
   terminology; appends an enrichment summary with dictionary terms applied,
   notable decisions, and a longest-comments QA table.
3. **Validate** (`validate.md`) — Re-reads the enriched DDL, confirms every
   comment is ≤255 characters, condenses any that overflow (intelligent
   rewrite, never mid-word truncation); appends a short pass/fail report.

`run.sh` snapshots the in-repo `table.ddl` at three moments — post-bootstrap
(original), after "Finished stage: enrich" (enriched), and at SUCCEEDED
(validated) — then generates a side-by-side `ddl-comparison.md`.

## Quick Start

```bash
# Run for a specific table
./run.sh customer360 customer-life-cycle-vw
./run.sh enterprise fact-bill-line
./run.sh pricing-mart product-price-catalog

# List available configs
./run.sh
```

## Prerequisites

- `mu` CLI installed
- Docker running (`colima start`) with **virtiofs** mount type.
  colima's default `sshfs` rejects the container's bootstrap chown —
  re-create with `colima delete && colima start --vm-type=vz --mount-type=virtiofs`.
- `AWS_PROFILE` set (non-PCI account for ECR access)
- `~/.config/mu/mu.env` with MOONUNIT_* credentials (JIRA, ATLASSIAN, ALATION, GOCODE, GITHUB)
- `.env.local` in this directory (see `.env.local.example`)

## Adding a New Table

1. Create `config/<db_name>/<table_name>.yaml`:

```yaml
target:
  db_name: "your_database"
  table_name: "your-table-name"
  registry_path: "standard"  # or "dlms-api"

confluence_pages:
  - url: "https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/<page_id>/<Title>"
    description: "Brief description of what this page covers"

reference_tables: []
# Or with reference tables:
# reference_tables:
#   - name: "related_table_vw"
#     schema: "some_schema"
#     alation_table_id: 1234567    # optional — omit to let the agent search by name
#     description: "Why this table is relevant"

alation:
  enabled: true
  search_query: null
```

2. Run: `./run.sh <db_name> <table_name>`

## Output

Results are saved to `output/<db_name>/<table_name>/`:

| File | Contents |
|------|----------|
| `INPUT.md` | Parameters the mission ran with (framework-written from `input.content`) |
| `research.md` | Stage 1 output — Confluence summaries, Alation metadata, Certified Data Dictionary mappings |
| `enrich.md` | Stage 2 output — enrichment summary: counts, dictionary terms applied, notable decisions, longest-comment QA table |
| `validate.md` | Stage 3 output — validation summary: 255-char check, columns condensed (if any) |
| `original-table.ddl` | Pre-enrich DDL snapshot from the lake repo |
| `enriched-table.ddl` | Post-enrich DDL snapshot (same file the agent edited in-place, captured at stage boundary) |
| `validated-table.ddl` | Post-validate DDL snapshot — authoritative output |
| `ddl-comparison.md` | Side-by-side per-column table: Column \| Original \| Enriched \| Validated \| Len |

Stage `.md` files follow the Moon Units convention: the framework pre-writes a header, the agent appends its summary, the framework appends a footer with the agent's final reply.

## File Structure

```
config/                         # Per-table configs (the only files you edit)
  customer360/
    customer-life-cycle-vw.yaml
  enterprise/
    fact-bill-line.yaml
  pricing-mart/
    product-price-catalog.yaml
manifest.yaml                   # Static template (do not edit)
run.sh                          # Launcher script
.env.local                      # Local secrets (not committed)
.env.local.example              # Template for .env.local
output/                         # Mission outputs (committed, for diffs across runs)
docs/                           # Architecture diagrams and data flow
```

## Column Description Standard (Summary)

The enrichment follows these rules:
- Every column must have a COMMENT (max 255 characters)
- Use `@PrimaryKey`, `@ForeignKey(table)`, `@Enumerated(val1, val2, ...)` annotations
- Expand abbreviations using Certified Data Dictionary terms (e.g., GCR = Gross Cash Receipts)
- Include units/scale (USD, percentage, MST timezone)
- Audit columns must note timezone
- Preserve existing annotations (e.g., "Employee PII")
- Optimize for AI search with semantic-rich descriptions

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `EACCES: permission denied, chown '/tmp/moonunit-workspace/INPUT.md'` | colima's default `sshfs` mount type doesn't allow the container's bootstrap chown | `colima delete && colima start --vm-type=vz --mount-type=virtiofs` |
| `ConnectionRefused` / 0 tokens used | Anthropic API creds missing in mu.env | Re-authenticate with `mu` or update MOONUNIT_GOCODE |
| `manifest failed mu lint` | Manifest template or generated input malformed | Check the `mu lint` stderr output; often a YAML indentation issue in the config |
| `sso jwt not available` warning | Non-critical bootstrap warning | Ignore unless SSO is required |
| Table not found in lake repo | Wrong `registry_path` or table name | Check path variant (standard vs dlms-api), verify the folder exists in gdcorp-dna/lake. Folder names use hyphens (e.g., `customer-life-cycle-vw`). |
| Workspace left behind after failure | run.sh preserves the bind-mounted workspace on failure for debugging | `rm -rf output/<db>/<table>/.workspace` once you're done inspecting |
