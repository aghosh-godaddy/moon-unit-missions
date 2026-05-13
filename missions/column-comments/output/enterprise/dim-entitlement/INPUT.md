Enrich column descriptions in a Data Lake table DDL file following the
Data Governance Council's Column Description Standard for Data Lake Assets.

## TARGET TABLE
- Database: enterprise
- Table: dim-entitlement
- DDL path: catalog/config/prod/us-west-2/enterprise/dim-entitlement/table.ddl
- YAML path: catalog/config/prod/us-west-2/enterprise/dim-entitlement/table.yaml

## CONFLUENCE PAGES
- https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/76447948/dim_subscription+and+entitlement
  (dim_subscription and entitlement — overview of the Subscription/Entitlement table pair, SLAs, partition column, PK, and contacts)
- https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/4323412165/dim_entitlement+Validation+switch+to+lookalike+prime
  (dim_entitlement Validation — column-level match rates vs EDS Prime lookalike (2026-03 snapshot))
## REFERENCE TABLES
- enterprise.fact_bill_line (Alation table_id: 6332236)
  Upstream dependency from data lake registry lineage — enterprise.fact_bill_line: Enterprise Dataset (EDS) that provides a comprehensive view of a receipt for the purchase of GoDaddy products.
- enterprise.dim_subscription (Alation table_id: 6229558)
  Upstream dependency from data lake registry lineage — enterprise.dim_subscription: A comprehensive view of dimensions and metrics associated with purchased products
- customer360.dim_customer_history_vw (Alation table_id: 7022324)
  Upstream dependency from data lake registry lineage — customer360.dim_customer_history_vw: shopper and profile data in customer360
## ALATION
- Enabled: true
- User ID: 213
- Refresh token: use $ALATION_REFRESH_TOKEN env var
- Certified Data Dictionary: Document Folder ID 6
