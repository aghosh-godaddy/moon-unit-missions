# Creating a config (semantic-model)

This mission generates an OSI-compliant semantic model YAML for a Data Lake
table based on the **authoritative code** (PySpark + DAG).

## 1) Choose an identifier + name

Configs live at:

`config/<identifier>/<name>.yaml`

- `<identifier>`: a grouping bucket (team, domain, or just `example`)
- `<name>`: a human-friendly short name (often the target table name)

## 2) Provide the PySpark GitHub URL (required)

The mission expects a GitHub **blob** URL pointing to the exact PySpark file,
for example:

- `https://github.com/<org>/<repo>/blob/<ref>/src/.../pyspark/<job>.py`

The mission will clone the repo and checkout `<ref>` to ensure it reads the
exact version you linked.

## 3) Optional: user notes (highest priority after code)

Add expert/owner notes that the agent must honor over Confluence, Alation, and
DDL (but **not** over PySpark/DAG):

```yaml
notes: |
  This table is the primary customer lifecycle snapshot.
  Always filter on partition_eval_mst_date.
  Key metric: active customer count by country.
```

Use a YAML block scalar (`|`) for multiline text.

## 4) Optional: lake table override

If the PySpark writes to a lake table that is difficult to auto-detect, set:

- `target.lake_table_override: "<db>/<table>"` (hyphenated, lake registry path form)

Example: `enterprise/payment-cogs-audit`

## 5) Optional: semantic model name

If you want a specific OSI model name instead of auto-derivation:

- `target.semantic_model_name: "customer_lifecycle_analytics"`

If omitted, the mission derives a name from the resolved schema and table.

## 6) Optional: supporting docs and Alation

Add Confluence URLs, enable Alation, and set how many saved queries to pull for
metric/usage context:

```yaml
sources:
  confluence_pages:
    - url: "https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/12345/..."
      description: "Parent page — child pages may be explored"

  alation:
    enabled: true
    search_query: null
    max_queries: 5

  additional_docs: []
```

**Alation credentials:** Set `MOONUNIT_ALATION` in `missions/semantic-model/.env.local`
with a **numeric** `user_id` (not email):

```bash
MOONUNIT_ALATION='{"refresh_token":"<token>","user_id":1664,"url":"https://godaddy.alationcloud.com"}'
```

`run.sh` merges `.env.local` into the container env alongside `~/.config/mu/mu.env`.

## Config schema

Minimal config:

```yaml
target:
  pyspark_url: "https://github.com/<org>/<repo>/blob/<ref>/<path>.py"
  lake_table_override: null
  semantic_model_name: null

notes: |

sources:
  confluence_pages: []
  alation:
    enabled: true
    search_query: null
    max_queries: 5
  additional_docs: []
```

Notes:

- `pyspark_url` must be a GitHub **blob** URL.
- `lake_table_override` uses hyphenated lake registry paths.
- Confluence/Alation are optional; **code remains the source of truth**.

## 7) Run

From `missions/semantic-model/`:

```bash
./run.sh <identifier> <name>
```

Outputs appear under `output/<identifier>/<name>/`.

## Output

| File | Contents |
|------|----------|
| `INPUT.md` | Run parameters |
| `gather.md` | Stage 1 raw facts |
| `analyze.md` | Stage 2 lineage + OSI concept mapping |
| `PROVENANCE.json` | Stage 2 machine-readable lineage (workspace artifact; used by generate/validate) |
| `generate.md` | Stage 3 summary |
| `validate.md` | Stage 4 validation report |
| `<schema>.<table>.yaml` | Final OSI semantic model (deliverable); includes provenance in field descriptions, `ai_context`, and `custom_extensions.pipeline_lineage` |
| `.workspace/repos/<repo>/<...>/src/semantics/<schema>.<table>.yaml` | Same model placed in source repo `src/semantics/` (workspace preserved on success) |
| PR in source repo | `run.sh` opens a PR in the PySpark repo (not moon-unit-missions) on branch `semantic-model/<schema>.<table>` |
