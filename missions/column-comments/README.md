# Column Comments Enrichment Mission

Automatically enriches Data Lake table DDL files with standardized column descriptions following GoDaddy's Data Governance Council Column Description Standard.

## How It Works

A two-stage Moon Units mission:

1. **Research** — Clones `gdcorp-dna/lake`, reads the table DDL/YAML, fetches Confluence design pages, queries Alation for existing column metadata and reference table descriptions, and pulls official term definitions from the Certified Data Dictionary (Folder 6).

2. **Enrich** — Takes the research output and rewrites the DDL with COMMENT clauses on every column, applying annotation rules (@PrimaryKey, @ForeignKey, @Enumerated), 255-character limits, and official terminology.

## Quick Start

```bash
# Run for a specific table
./run.sh customer360 customer-lifecycle-vw
./run.sh enterprise fact-bill-line

# List available configs
./run.sh
```

## Prerequisites

- `mu` CLI installed
- Docker running (`colima start`)
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
#     alation_table_id: 1234567
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
| `enriched-table.ddl` | Final DDL with COMMENT clauses on all columns |
| `research.md` | Research findings (Confluence summaries, Alation metadata, dictionary mappings) |
| `INPUT.md` | The generated input that was sent to the agent |

## File Structure

```
config/                         # Per-table configs (the only files you edit)
  customer360/
    customer-lifecycle-vw.yaml
  enterprise/
    fact-bill-line.yaml
manifest.yaml                   # Static template (do not edit)
run.sh                          # Launcher script
.env.local                      # Local secrets (not committed)
.env.local.example              # Template for .env.local
output/                         # Mission outputs (not committed)
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
| `ConnectionRefused` / 0 tokens used | Anthropic API creds missing in mu.env | Re-authenticate with `mu` or update MOONUNIT_GOCODE |
| Exit code 143 | Normal — watcher kills mu after pulling output | Check `.watcher.log` for success/failure |
| Low column count in watcher log | Watcher pulled stage summary instead of DDL | Fixed in current run.sh (validates `CREATE TABLE`) |
| `sso jwt not available` warning | Non-critical bootstrap warning | Ignore unless SSO is required |
| Table not found in lake repo | Wrong `registry_path` or table name | Check path variant (standard vs dlms-api), verify table exists in gdcorp-dna/lake |
