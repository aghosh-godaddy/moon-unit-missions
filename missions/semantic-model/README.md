# OSI Semantic Model Generation Mission

Generates an **OSI-compliant semantic model** (YAML) for a Data Lake table by
analyzing the authoritative ETL code (PySpark + Airflow DAG) and auto-discovering
related upstream/dimension tables, foreign-key relationships, fields, and metrics.

Output conforms to the [Open Semantic Interchange (OSI)](https://github.com/open-semantic-interchange/OSI)
Core Spec v0.2.0.dev0.

## How It Works

A four-stage Moon Units mission. The container workspace is bind-mounted to the
host via `mu launch --mount-workspace`, so stage outputs appear on the host
filesystem as they're written.

1. **Gather** (`gather.md`) — clones the source repo + `gdcorp-dna/lake`, reads the
   target PySpark file and its calling DAG, and fetches supporting docs (Confluence,
   Alation). Enumerates all referenced tables and column schemas.
2. **Analyze** (`analyze.md`) — resolves local/intermediate tables to lake tables,
   classifies fact vs dimension, extracts FK relationships and candidate metrics.
3. **Generate** (`generate.md`) — writes `SEMANTIC_MODEL.yaml` conforming to OSI spec.
4. **Validate** (`validate.md`) — validates schema structure, relationship consistency,
   and accuracy against source evidence.

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
| `INPUT.md` | Parameters the mission ran with |
| `gather.md` | Stage 1 — raw facts from source repo, lake, Confluence, Alation |
| `analyze.md` | Stage 2 — lineage resolution + OSI concept mapping |
| `generate.md` | Stage 3 — generation summary |
| `validate.md` | Stage 4 — validation report |
| `<schema>.<table>.yaml` | Final OSI semantic model (authoritative deliverable) |
| `.workspace/repos/<repo>/<...>/src/semantics/<schema>.<table>.yaml` | Same model placed in source repo layout (workspace preserved on success) |

Stage `.md` files follow the Moon Units convention: the framework pre-writes a
header, the agent appends its content, the framework appends a footer.

## OSI Spec Reference

See `docs/osi-spec-reference.md` for the condensed OSI schema used by this mission.
