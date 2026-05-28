# Table Metadata Generation Mission

Generates a **5-pillar / 20-section** metadata document for a Data Lake table by
analyzing the authoritative ETL code (PySpark + Airflow DAG) and resolving all
intermediate/local tables to their corresponding **lake** tables.

The generated metadata is designed to be consumed by downstream agents to
answer business questions accurately.

## How It Works

A four-stage Moon Units mission. The container workspace is bind-mounted to the
host via `mu launch --mount-workspace`, so stage outputs appear on the host
filesystem as they're written.

1. **Gather** (`gather.md`) — clones the source repo + `gdcorp-dna/lake`, reads the
   target PySpark file and its calling DAG, and fetches supporting docs (Confluence,
   Alation).
2. **Analyze** (`analyze.md`) — resolves local/intermediate tables to lake tables,
   traces lineage, identifies grain/keys/partitions, extracts metrics and filters.
3. **Generate** (`generate.md`) — writes the final business-context doc following
   the structure in `docs/Metadata-Structure.pdf`, plus a short stage summary.
4. **Validate** (`validate.md`) — checks **accuracy** (no claims beyond sources)
   and **completeness** (all 20 sections present), correcting any inaccuracies.

## Quick Start

```bash
# Run using config/<identifier>/<name>.yaml
./run.sh example payment-cogs-audit

# List available configs
./run.sh
```

## Prerequisites

- `mu` CLI installed
- Docker running (`colima start`) with **virtiofs** mount type
- `AWS_PROFILE` set (non-PCI account for ECR access)
- `~/.config/mu/mu.env` with MOONUNIT_* credentials (GitHub, Confluence/Atlassian, Alation, GoCode)
- `.env.local` in this directory (see `.env.local.example`)

## Adding a New Table

1. Create a config at `config/<identifier>/<name>.yaml` (copy an existing one).
2. Run `./run.sh <identifier> <name>`.

## Output

Results are saved to `output/<identifier>/<name>/`:

| File | Contents |
|------|----------|
| `INPUT.md` | Parameters the mission ran with (framework-written from `input.content`) |
| `gather.md` | Stage 1 output — raw facts gathered from source repo, lake, Confluence, Alation |
| `analyze.md` | Stage 2 output — lineage resolution + derived structure (grain/keys/filters/metrics) |
| `generate.md` | Stage 3 output — generation summary (not the final metadata doc) |
| `validate.md` | Stage 4 output — accuracy + completeness validation report |
| `<schema>.<table>-metadata.md` | Final metadata doc (authoritative deliverable) |

Stage `.md` files follow the Moon Units convention: the framework pre-writes a
header, the agent appends its content, the framework appends a footer.

