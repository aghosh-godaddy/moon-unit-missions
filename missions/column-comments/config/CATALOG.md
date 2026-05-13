# Column Comments Mission Catalog

An index of tables that have (or are planned to have) a column-comments mission config in this directory. Edit this file when you add, remove, or change the status of a table config.

Per-table configs live at `config/<db_name>/<table_name>.yaml`. This file is **only an index** — `run.sh` does not read it.

## Status legend

- `planned` — identified, config not yet written
- `ready` — config exists, not yet run
- `enriched` — mission has been run and output committed
- `stale` — upstream DDL or Confluence spec has changed since last run
- `blocked` — waiting on access, spec, or upstream fix

## Tables

| DB | Table | Registry | Status | Owner | Config | Notes |
|---|---|---|---|---|---|---|
| customer360 | customer_life_cycle_vw | dlms-api | enriched | @mzwolak | [config](customer360/customer-life-cycle-vw.yaml) | 2 Confluence URLs (manually added); 8 reference tables from lineage (8/11 curated) |
| enterprise | fact_bill_line | standard | enriched | @mzwolak | [config](enterprise/fact-bill-line.yaml) | 1 Confluence URL (manually added); 1 reference table (pre-lineage-automation; 1/2 curated upstreams) |
| pricing_mart | product_price_catalog | standard | enriched | @mzwolak | [config](pricing-mart/product-price-catalog.yaml) | 2 Confluence URLs from Alation (incl. predecessor design); 1 reference table (predecessor pricing_mart.product_price_list with Alation id; lineage curated=0/16 — all upstreams are raw _snap sources) |
| analytic | ads_bill_line | standard | enriched | @mzwolak | [config](analytic/ads-bill-line.yaml) | 3 Confluence URLs from Alation (tiny links resolved; legacy /display/ URL dropped); 8 reference tables from lineage (8/25 curated) |
| analytic_feature | customer_type | standard | enriched | @mzwolak | [config](analytic-feature/customer-type.yaml) | 1 Confluence URL from Alation; 5 reference tables from lineage (5/9 curated) |
| bi_reports | ads_entitlement_bill | standard | enriched | @mzwolak | [config](bi-reports/ads-entitlement-bill.yaml) | 1 Confluence URL from BI space search (validation summary); 10 reference tables from lineage (10/15 curated) |
| ecomm360 | dim_bill_vw | dlms-api | enriched | @mzwolak | [config](ecomm360/dim-bill-vw.yaml) | 1 Confluence URL from Alation; 1 reference tables from lineage (1/1 curated) |
| ecomm360 | fact_bill_line_vw | dlms-api | enriched | @mzwolak | [config](ecomm360/fact-bill-line-vw.yaml) | 1 Confluence URL from Alation; 4 reference tables from lineage (4/4 curated) |
| ecomm_mart | bill_line_traffic_ext | standard | enriched | @mzwolak | [config](ecomm-mart/bill-line-traffic-ext.yaml) | 3 Confluence URLs from Catalog Set 94 shared Description (fetched via /api/v1/table/<id>/shared_catalog_sets[].description); 3 reference tables from lineage (3/3 curated) |
| ecomm_mart | renewal_360 | standard | enriched | @mzwolak | [config](ecomm-mart/renewal-360.yaml) | 2 Confluence URLs from Alation; 6 reference tables from lineage (6/9 curated) |
| enterprise | dim_entitlement | standard | enriched | @mzwolak | [config](enterprise/dim-entitlement.yaml) | 2 Confluence URLs from BI space search. Being replaced by ecomm360.dim_subscription, dim_subscription_product, dim_subscription_addon; 3 reference tables from lineage (3/178 curated) |
| enterprise | dim_entitlement_history | standard | enriched | @mzwolak | [config](enterprise/dim-entitlement-history.yaml) | 3 Confluence URLs from BI space search (overview, EDS Prime data model, brainstorming notes); 1 reference tables from lineage (1/1 curated) |
| enterprise | dim_subscription | standard | enriched | @mzwolak | [config](enterprise/dim-subscription.yaml) | 2 Confluence URLs from BI space search. Being replaced by ecomm360.dim_subscription, dim_subscription_product, dim_subscription_addon; 2 reference tables from lineage (3/109 curated) |
| enterprise | dim_subscription_history | standard | enriched | @mzwolak | [config](enterprise/dim-subscription-history.yaml) | 3 Confluence URLs from BI space search (overview, Last Active Date Logic, EDS Prime data model); 1 reference table (base table enterprise.dim_subscription; history table had 0 lineage deps) |
| enterprise | fact_entitlement_bill | standard | enriched | @mzwolak | [config](enterprise/fact-entitlement-bill.yaml) | 1 Confluence URL from BI space search (validation summary); 4 reference tables from lineage (4/9 curated) |
| enterprise | free_entitlement | standard | enriched | @mzwolak | [config](enterprise/free-entitlement.yaml) | 1 Confluence URL from BI space search (Current Design Challenges); 2 manual reference tables (lake lineage has only raw godaddy_txlog upstream; added sibling enterprise entitlement tables) |
| gd_traffic_mart | analytic_traffic_agg | standard | enriched | @mzwolak | [config](gd-traffic-mart/analytic-traffic-agg.yaml) | 1 Confluence URL from Alation; 1 reference tables from lineage (1/1 curated) |
| gd_traffic_mart | analytic_traffic_detail | standard | enriched | @mzwolak | [config](gd-traffic-mart/analytic-traffic-detail.yaml) | 3 Confluence URLs from Alation; 6 reference tables from lineage (6/6 curated) |
| _example_ | _example-table_ | _standard_ | _planned_ | _@handle_ | _—_ | _one-line purpose / context_ |

## How to add a row

1. Add a row to the table above with `db`, `table`, `registry` (`standard` or `dlms-api`), `status`, `owner`, and a one-line `notes` field describing the table's purpose or why it's in scope.
2. Link the `config` column to the per-table YAML once it exists.
3. When the mission runs successfully and output is committed, flip `status` to `enriched`.
