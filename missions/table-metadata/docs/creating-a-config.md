# Creating a config (table-metadata)

This mission generates a business context metadata document for a Data Lake
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

## 3) Optional: user notes (highest priority above all, even code)

Add expert/owner notes that the agent must honor over Confluence, Alation, and
DDL (but **not** over PySpark/DAG):

```yaml
notes: |
  This table is used for SEC 10-K active customer reporting.
  Always filter on partition_eval_mst_date.
  customer_type_name = '123 Reg' when private_label_id = 587240.
```

Use a YAML block scalar (`|`) for multiline text.

## 4) Optional: lake table override

If the PySpark writes to a lake table that is difficult to auto-detect, set:

- `target.lake_table_override: "<db>/<table>"` (hyphenated, lake registry path form)

Example: `enterprise/payment-cogs-audit`

## 5) Optional: supporting docs and Alation

Add Confluence URLs, enable Alation, and set how many saved queries to pull into
section **B2**:

```yaml
sources:
  confluence_pages:
    - url: "https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/12345/..."
      description: "Parent page — child pages may be explored"

  alation:
    enabled: true
    search_query: null      # optional override for table search
    max_queries: 10         # Alation queries in B2 (default: 10, by last_saved_at)

  additional_docs: []
```

**Alation credentials:** Set `MOONUNIT_ALATION` in `missions/table-metadata/.env.local`
with a **numeric** `user_id` (not email):

```bash
MOONUNIT_ALATION='{"refresh_token":"<token>","user_id":1664,"url":"https://godaddy.alationcloud.com"}'
```

`run.sh` merges `.env.local` into the container env alongside `~/.config/mu/mu.env`.

When Alation works, the mission will:

- Resolve Redshift Serverless Dev + Lake table URLs for **A1**
- Fetch saved queries referencing the table for **B2** (Query ID, Title, Author,
  Description, Schedule, Last Saved, Last Run, Datasource, Alation Query URL, SQL)

## Config schema

Minimal config:

```yaml
target:
  pyspark_url: "https://github.com/<org>/<repo>/blob/<ref>/<path>.py"
  lake_table_override: null

notes: |

sources:
  confluence_pages: []
  alation:
    enabled: true
    search_query: null
    max_queries: 10
  additional_docs: []
```

Notes:

- `pyspark_url` must be a GitHub **blob** URL.
- `lake_table_override` uses hyphenated lake registry paths.
- Confluence/Alation are optional; **code remains the source of truth**.

## 6) Run

From `missions/table-metadata/`:

```bash
./run.sh <identifier> <name>
```

Outputs appear under `output/<identifier>/<name>/`.
