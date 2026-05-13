Enrich column descriptions in a Data Lake table DDL file following the
Data Governance Council's Column Description Standard for Data Lake Assets.

## TARGET TABLE
- Database: enterprise
- Table: fact-entitlement-bill
- DDL path: catalog/config/prod/us-west-2/enterprise/fact-entitlement-bill/table.ddl
- YAML path: catalog/config/prod/us-west-2/enterprise/fact-entitlement-bill/table.yaml

## CONFLUENCE PAGES
- https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3941171221/fact_entitlement_bill+Validation+switch+to+lookalike+prime
  (fact_entitlement_bill Validation — column-level match rates vs EDS Prime lookalike (26 years of data, 2025-09 snapshot))
## REFERENCE TABLES
- ecomm_mart.nds_resource_auto_renew_delta (Alation table_id: 6837294)
  Upstream dependency from data lake registry lineage — ecomm_mart.nds_resource_auto_renew_delta: Conversion of nds_resource_auto_renew to Delta Lake
- enterprise.dim_entitlement (Alation table_id: 6229554)
  Upstream dependency from data lake registry lineage — enterprise.dim_entitlement: Entitlement information of customers products
- enterprise.dim_subscription (Alation table_id: 6229558)
  Upstream dependency from data lake registry lineage — enterprise.dim_subscription: A comprehensive view of dimensions and metrics associated with purchased products
- ecomm360.fact_bill_line_vw (Alation table_id: 7027689)
  Upstream dependency from data lake registry lineage — ecomm360.fact_bill_line_vw: tracks every receipt of the purchase of a godaddy customer.
## ALATION
- Enabled: true
- User ID: 213
- Refresh token: use $ALATION_REFRESH_TOKEN env var
- Certified Data Dictionary: Document Folder ID 6
