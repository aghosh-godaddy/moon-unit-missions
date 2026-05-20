Enrich column descriptions in a Data Lake table DDL file following the
Data Governance Council's Column Description Standard for Data Lake Assets.

## TARGET TABLE
- Database: customer360
- Table: dim-customer-history-vw
- DDL path: catalog/config/prod/dlms-api/us-west-2/customer360/dim-customer-history-vw/table.ddl
- YAML path: catalog/config/prod/dlms-api/us-west-2/customer360/dim-customer-history-vw/table.yaml

## CONFLUENCE PAGES
- https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3779199819/Customer360
  (Customer360 design specification — overall Customer360 schema architecture and column definitions)
## REFERENCE TABLES
- customer360.dim_customer_vw (Alation table_id: 7022291)
  Base table — customer360.dim_customer_vw. dim_customer_history_vw is the daily-snapshot history variant; column semantics are inherited from the base view.
- customer360.customer_life_cycle_vw (Alation table_id: 7038345)
  Sibling customer360 table — customer360.customer_life_cycle_vw: Analytic Dataset for Customer Life Cycle. Provides shopper-level context relevant to dim_customer_history_vw.
## ALATION
- Enabled: true
- User ID: 213
- Refresh token: use $ALATION_REFRESH_TOKEN env var
- Certified Data Dictionary: Document Folder ID 6
