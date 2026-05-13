Enrich column descriptions in a Data Lake table DDL file following the
Data Governance Council's Column Description Standard for Data Lake Assets.

## TARGET TABLE
- Database: analytic-feature
- Table: customer-type
- DDL path: catalog/config/prod/us-west-2/analytic-feature/customer-type/table.ddl
- YAML path: catalog/config/prod/us-west-2/analytic-feature/customer-type/table.yaml

## CONFLUENCE PAGES
- https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/10364300/Customer+Type
  (Customer Type — design page linked from Alation table description (resolved from tiny link /wiki/x/jCWe).)
## REFERENCE TABLES
- analytic_feature.shopper_domain_portfolio (Alation table_id: 6304430)
  Upstream dependency from data lake registry lineage — analytic_feature.shopper_domain_portfolio: migrated-shopper_domain_portfolio
- partner360.dim_reseller_vw (Alation table_id: 7041966)
  Upstream dependency from data lake registry lineage — partner360.dim_reseller_vw: reseller data in partner360
- ecomm360.fact_bill_line_vw (Alation table_id: 7027689)
  Upstream dependency from data lake registry lineage — ecomm360.fact_bill_line_vw: tracks every receipt of the purchase of a godaddy customer.
- ecomm360.dim_bill_vw (Alation table_id: 7028947)
  Upstream dependency from data lake registry lineage — ecomm360.dim_bill_vw: tracks every receipt of the purchase of a godaddy customer.
- customer360.dim_customer_history_vw (Alation table_id: 7022324)
  Upstream dependency from data lake registry lineage — customer360.dim_customer_history_vw: shopper and profile data in customer360
## ALATION
- Enabled: true
- User ID: 213
- Refresh token: use $ALATION_REFRESH_TOKEN env var
- Certified Data Dictionary: Document Folder ID 6
