# OSI Core Spec Reference (v0.2.0.dev0)

Condensed reference for the semantic-model mission. Full spec:
https://github.com/open-semantic-interchange/OSI/tree/main/core-spec

**Version:** `0.2.0.dev0` (DRAFT — schema may change before 0.2.0 release)

---

## Root Document Shape

Every OSI file is a single root object with exactly two keys:

```yaml
version: "0.2.0.dev0"   # REQUIRED — must match exactly
semantic_model:          # REQUIRED — array of one or more models
  - name: my_model
    description: ...
    ai_context: ...
    datasets: [...]     # REQUIRED, min 1
    relationships: [...]
    metrics: [...]
    custom_extensions: [...]
```

---

## Semantic Model

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Unique model identifier |
| `datasets` | Yes | Array of logical datasets (min 1) |
| `description` | No | Human-readable summary |
| `ai_context` | No | String or object (instructions, synonyms, examples) |
| `relationships` | No | FK joins between datasets |
| `metrics` | No | Aggregates spanning datasets |
| `custom_extensions` | No | Vendor-specific JSON blobs |

---

## Dataset

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Unique within model |
| `source` | Yes | Physical table, e.g. `schema.table` |
| `primary_key` | No | Array of column names (simple or composite) |
| `unique_keys` | No | Array of unique key arrays |
| `description` | No | Human-readable description |
| `ai_context` | No | String or object |
| `fields` | No | Row-level attributes |
| `custom_extensions` | No | Vendor extensions |

---

## Field

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Unique within dataset |
| `expression` | Yes | Expression object with dialects |
| `dimension` | No | `{ is_time: boolean }` |
| `label` | No | Categorization label |
| `description` | No | Human-readable description |
| `ai_context` | No | String or object |
| `custom_extensions` | No | Vendor extensions |

**Field expressions:** scalar SQL only — column refs or computed scalars. **No aggregations.**

```yaml
- name: order_date
  expression:
    dialects:
      - dialect: ANSI_SQL
        expression: order_date
  dimension:
    is_time: true
  description: Date when order was placed
```

---

## Relationship

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Unique within model |
| `from` | Yes | Dataset on the **many** side (FK side) |
| `to` | Yes | Dataset on the **one** side (PK/UK side) |
| `from_columns` | Yes | FK columns (order matters) |
| `to_columns` | Yes | PK/UK columns (same length & order) |
| `ai_context` | No | String or object |
| `custom_extensions` | No | Vendor extensions |

**Rules:** `len(from_columns) == len(to_columns)`. Column order must align pairwise.

---

## Metric

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Unique within model |
| `expression` | Yes | Expression object with aggregate SQL |
| `description` | No | What the metric measures |
| `ai_context` | No | String or object |
| `custom_extensions` | No | Vendor extensions |

**Metric expressions:** full SQL with aggregates; may reference multiple datasets using `dataset_name.column`.

```yaml
- name: total_revenue
  expression:
    dialects:
      - dialect: ANSI_SQL
        expression: SUM(orders.amount)
  description: Total revenue from all orders
  ai_context:
    synonyms:
      - "total sales"
      - "revenue"
```

---

## Expression Object (fields and metrics)

```yaml
expression:
  dialects:
    - dialect: ANSI_SQL   # required per entry; at least one
      expression: "..."   # scalar for fields, aggregate for metrics
```

**Supported dialects:** `ANSI_SQL`, `SNOWFLAKE`, `MDX`, `TABLEAU`, `DATABRICKS`, `MAQL`

This mission uses **ANSI_SQL** only.

---

## ai_context

Either a string or structured object:

```yaml
ai_context:
  instructions: "Use this model for sales analysis"
  synonyms:
    - "orders"
    - "purchases"
  examples:
    - "Show total sales last month"
    - "What's the revenue by region?"
```

---

## custom_extensions

```yaml
custom_extensions:
  - vendor_name: GODADDY
    data: |
      {
        "lake_table_path": "customer360/customer-life-cycle-vw",
        "dag_name": "customer_life_cycle_dag"
      }
```

`data` must be a **JSON string**, not a nested YAML object. For readability, use a YAML
literal block scalar (`data: |`) with pretty-printed JSON at 2-space indent — when parsed,
the value is still a plain string (same as a single-quoted JSON literal).

### GODADDY vendor schema

Operational keys (always include when known):

| Key | Description |
|-----|-------------|
| `lake_table_path` | Hyphenated lake registry path (e.g. `customer360/customer-life-cycle-vw`) |
| `pyspark_path` | Relative path to PySpark script in source repo |
| `dag_name` | Airflow DAG name |
| `refresh_cadence` | Schedule (e.g. `daily at 07:20 MST`) |
| `sla_delivery` | SLA delivery time if known |
| `data_tier` | Lake data tier (integer) |
| `partition_key` | Partition column name |
| `domain` | Business domain |
| `organization` | Owning organization |

Provenance keys (sourced from `PROVENANCE.json` written in analyze stage):

| Key | Description |
|-----|-------------|
| `pipeline_lineage.intermediate_tables` | Staging/driver tables not in lake catalog |
| `pipeline_lineage.transitive_sources` | Upstream lake tables reached via drivers; includes `materialized_in_fields` |
| `pipeline_lineage.materialized_direct_reads` | Direct-read lake tables denormalized onto the fact |
| `pipeline_lineage.legacy_sources` | Legacy S3 paths or branches with equivalents |
| `query_guards.grain` | What one row represents |
| `query_guards.partition_filter` | Required partition column for point-in-time queries |
| `query_guards.primary_key_notes` | PK caveats (e.g. composite key, nullable columns) |

Example with provenance:

```yaml
custom_extensions:
  - vendor_name: GODADDY
    data: |
      {
        "lake_table_path": "customer360/customer-life-cycle-vw",
        "pyspark_path": "customer360/customer-metrics/src/pyspark/customer_life_cycle.py",
        "dag_name": "customer-life-cycle",
        "refresh_cadence": "daily at 07:20 MST",
        "pipeline_lineage": {
          "intermediate_tables": [
            {
              "table": "customer_core_conformed.active_customer_stg",
              "role": "staging",
              "upstream_pyspark": "..."
            }
          ],
          "transitive_sources": [
            {
              "table": "enterprise.dim_subscription_history",
              "via": "customer_core_conformed.customer_active_subscription_detail_driver",
              "materialized_in_fields": ["active_paid_subscription_list"]
            }
          ],
          "materialized_direct_reads": [
            {
              "table": "analytic_feature.customer_type_history",
              "materialized_in_fields": ["customer_type_name"]
            }
          ],
          "legacy_sources": []
        },
        "query_guards": {
          "grain": "one row per (shopper_id, partition_eval_mst_date)",
          "partition_filter": "partition_eval_mst_date",
          "primary_key_notes": "Composite PK; customer_id may be null"
        }
      }
```

### PROVENANCE.json (analyze stage artifact)

Written alongside `RESOLVED_TARGET.json`. Generate and validate stages consume it to
preserve do-not-claim lineage without adding non-joinable OSI datasets.

Top-level keys: `grain`, `primary_key_notes`, `partition_filter`, `intermediate_tables`,
`transitive_sources`, `materialized_direct_reads`, `excluded_dimensions`, `array_fields`,
`legacy_sources`, `do_not_claim`.

Each `do_not_claim` entry has `item`, `reason`, and `preserve_as` (`field_description`,
`ai_context`, and/or `custom_extensions`).

---

## Complete Minimal Example

```yaml
version: "0.2.0.dev0"

semantic_model:
  - name: ecommerce_analytics
    description: E-commerce sales and customer analytics
    ai_context:
      instructions: "Use this model for analyzing sales trends and customer behavior"
      synonyms:
        - "sales analytics"
      examples:
        - "Show total revenue last month"
        - "How many active customers?"

    datasets:
      - name: orders
        source: sales.public.orders
        primary_key: [order_id]
        description: Customer orders
        fields:
          - name: order_id
            expression:
              dialects:
                - dialect: ANSI_SQL
                  expression: order_id
            description: Order identifier

          - name: customer_id
            expression:
              dialects:
                - dialect: ANSI_SQL
                  expression: customer_id
            description: Customer identifier

          - name: order_date
            expression:
              dialects:
                - dialect: ANSI_SQL
                  expression: order_date
            dimension:
              is_time: true
            description: Order date

          - name: amount
            expression:
              dialects:
                - dialect: ANSI_SQL
                  expression: amount
            description: Order amount

      - name: customers
        source: sales.public.customers
        primary_key: [id]
        description: Customer information
        fields:
          - name: id
            expression:
              dialects:
                - dialect: ANSI_SQL
                  expression: id
            description: Customer identifier

          - name: email
            expression:
              dialects:
                - dialect: ANSI_SQL
                  expression: email
            description: Customer email

    relationships:
      - name: orders_to_customers
        from: orders
        to: customers
        from_columns: [customer_id]
        to_columns: [id]

    metrics:
      - name: total_revenue
        expression:
          dialects:
            - dialect: ANSI_SQL
              expression: SUM(orders.amount)
        description: Total revenue from all orders
        ai_context:
          synonyms:
            - "total sales"
            - "revenue"

      - name: customer_count
        expression:
          dialects:
            - dialect: ANSI_SQL
              expression: COUNT(DISTINCT customers.id)
        description: Total number of customers

    custom_extensions:
      - vendor_name: GODADDY
        data: '{"lake_table_path": "sales/orders", "refresh_cadence": "daily"}'
```

---

## Validation Checklist

When validating generated output:

1. Root has `version: "0.2.0.dev0"` and `semantic_model` array
2. Each model has `name` and `datasets` (min 1)
3. Each dataset has `name` and `source`
4. Each field has `name` and `expression.dialects` (min 1 entry)
5. Each metric has `name` and `expression.dialects` (min 1 entry)
6. Each relationship has `name`, `from`, `to`, `from_columns`, `to_columns`
7. Relationship `from`/`to` reference existing dataset names
8. `len(from_columns) == len(to_columns)` for each relationship
9. Field expressions are scalar (no SUM/COUNT/AVG)
10. Metric expressions use aggregates
11. All names unique within their scope (datasets, fields per dataset, metrics, relationships)
12. No `additionalProperties` — only fields defined in the spec

---

## Common Mistakes to Avoid

- Using bare expression lists instead of `expression.dialects[]`
- Putting metrics inside datasets (metrics are model-level)
- Aggregations in field expressions
- Missing `version` at root
- `custom_extensions.data` as YAML object instead of JSON string
- Relationship columns that don't exist on referenced datasets
- Intermediate/staging tables as dataset sources (use lake tables only)
