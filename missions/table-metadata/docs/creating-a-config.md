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

## 3) Optional: provide a lake table override

If the PySpark writes to a lake table that is difficult to auto-detect, set:

- `target.lake_table_override: "<db>/<table>"` (hyphenated, lake registry path form)

Example: `enterprise/payment-cogs-audit`

## 4) Optional: add supporting docs

Add any URLs that help explain the business meaning (design docs, definitions,
data contracts). These are **secondary sources** and are only used when they do
not conflict with code.

## Config schema

Minimal config:

```yaml
target:
  pyspark_url: "https://github.com/<org>/<repo>/blob/<ref>/<path>.py"
  lake_table_override: null  # optional: "<db>/<table>" using hyphenated lake registry table name

sources:
  confluence_pages: []
  alation:
    enabled: true
    search_query: null
  additional_docs: []
```

Notes:
- `pyspark_url` must be a GitHub **blob** URL. The mission parses the org/repo/ref/path from it.
- `lake_table_override` should be the lake registry form (hyphenated table name), e.g. `enterprise/payment-cogs-audit`.
- Confluence/Alation are optional but recommended; **code remains the source of truth**.

## 5) Run

From `missions/table-metadata/`:

```bash
./run.sh <identifier> <name>
```

Outputs appear under `output/<identifier>/<name>/`.

