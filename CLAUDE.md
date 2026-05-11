# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A collection of Moon Units missions — automated AI agent workflows that run inside Docker containers via GoDaddy's internal `mu` CLI. Each mission is a multi-stage pipeline (manifest) that clones repos, calls external APIs, and produces artifacts.

Currently contains one mission: **column-comments** — enriches Data Lake table DDL files with standardized column descriptions by researching Confluence, Alation, and the Certified Data Dictionary.

## Running a Mission

```bash
cd missions/column-comments
./run.sh <db_name> <table_name>    # e.g. ./run.sh customer360 customer-lifecycle-vw
./run.sh                           # shows available configs
```

Prerequisites: `mu` CLI installed, Docker running (`colima start`), `AWS_PROFILE` set, `~/.config/mu/mu.env` configured with MOONUNIT_* credentials, `.env.local` present in the mission directory.

## Architecture

```
missions/column-comments/
├── config/<db_name>/<table_name>.yaml   # Per-table config (only file to edit for new tables)
├── manifest.yaml                        # Static template — generic stage prompts
├── run.sh                               # Reads config, generates .manifest.generated.yaml, launches mu
├── .env.local                           # Local env vars (secrets, not committed)
├── output/<db_name>/<table_name>/       # Mission output (enriched DDL, research)
└── docs/                                # Data flow diagrams, architecture docs
```

**Key design principle:** `manifest.yaml` is never edited for new tables. All per-table variables live in `config/<db_name>/<table_name>.yaml`. `run.sh` assembles the two into `.manifest.generated.yaml` at launch time.

**Mission stages:**
1. **research** (Sonnet) — reads DDL from cloned `gdcorp-dna/lake` repo, fetches Confluence pages, queries Alation for column metadata and Certified Data Dictionary terms, produces `research.md`
2. **enrich** (Sonnet) — applies the Column Description Standard to produce `enriched-table.ddl` with COMMENT clauses on every column

**Watcher daemon:** `run.sh` spawns a background process that monitors for mission completion, pulls output from the Docker container via `docker cp`, kills mu, and sends a macOS notification. Exit code 143 (SIGTERM) from `run.sh` is expected on success.

## Adding a New Table

1. Create `config/<db_name>/<table_name>.yaml` (copy an existing one as template)
2. Set `target.db_name`, `target.table_name`, `target.registry_path`
3. Add Confluence page URLs under `confluence_pages`
4. Optionally add `reference_tables` with Alation table IDs
5. Run `./run.sh <db_name> <table_name>`

## Config YAML Structure

The `registry_path` field determines the DDL location in the lake repo:
- `"standard"` → `catalog/config/prod/us-west-2/<db>/<table>/table.ddl`
- `"dlms-api"` → `catalog/config/prod/dlms-api/us-west-2/<db>/<table>/table.ddl`

## Gotchas

- The `mu` agent sometimes writes the enriched DDL to the cloned repo path instead of the workspace root. The watcher tries multiple paths and validates with a `CREATE TABLE` check.
- `apiKeySource: "none"` in mu logs + `ConnectionRefused` error means the Anthropic API credentials in `mu.env` are stale or missing — re-authenticate.
- Confluence page IDs are extracted from URLs (the numeric segment after `/pages/`).
- Alation credentials use a refresh token flow — the agent calls `createAPIAccessToken` at runtime.
