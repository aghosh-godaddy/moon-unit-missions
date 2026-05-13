Enrich column descriptions in a Data Lake table DDL file following the
Data Governance Council's Column Description Standard for Data Lake Assets.

## TARGET TABLE
- Database: bi-reports
- Table: ads-entitlement-bill
- DDL path: catalog/config/prod/us-west-2/bi-reports/ads-entitlement-bill/table.ddl
- YAML path: catalog/config/prod/us-west-2/bi-reports/ads-entitlement-bill/table.yaml

## CONFLUENCE PAGES
- https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3958898790/ads_entitlement_bill+validation+summary+after+switch+to+eds+lookalike+table
  (ads_entitlement_bill validation summary after switch to EDS lookalike table — documents column-level validation and row-count parity vs the EDS Prime lookalike)
## REFERENCE TABLES
- enterprise.fact_bill_line (Alation table_id: 6332236)
  Upstream dependency from data lake registry lineage — enterprise.fact_bill_line: Enterprise Dataset (EDS) that provides a comprehensive view of a receipt for the purchase of GoDaddy products.
- enterprise.dim_entitlement (Alation table_id: 6229554)
  Upstream dependency from data lake registry lineage — enterprise.dim_entitlement: Entitlement information of customers products
- enterprise.dim_subscription (Alation table_id: 6229558)
  Upstream dependency from data lake registry lineage — enterprise.dim_subscription: A comprehensive view of dimensions and metrics associated with purchased products
- analytic_feature.customer_type (Alation table_id: 6304551)
  Upstream dependency from data lake registry lineage — analytic_feature.customer_type: migrated-customer_type
- finance360.dim_product_history_vw (Alation table_id: 7021957)
  Upstream dependency from data lake registry lineage — finance360.dim_product_history_vw: SCD2 Conformed Dimension table containing product-level reporting attributes.
- partner360.dim_reseller_vw (Alation table_id: 7041966)
  Upstream dependency from data lake registry lineage — partner360.dim_reseller_vw: reseller data in partner360
- analytic_feature.customer_type_history (Alation table_id: 6365364)
  Upstream dependency from data lake registry lineage — analytic_feature.customer_type_history: migrated-customer_type_history
- analytic_feature.bill_fraud (Alation table_id: 6619916)
  Upstream dependency from data lake registry lineage — analytic_feature.bill_fraud: fraud dataset on bill_id level
- analytic_feature.shopper_crm_portfolio (Alation table_id: 6295886)
  Upstream dependency from data lake registry lineage — analytic_feature.shopper_crm_portfolio: Stores Shoppers and their CRM Portfolio features by evaluation date
- enterprise.dim_new_acquisition_shopper (Alation table_id: 6332252)
  Upstream dependency from data lake registry lineage — enterprise.dim_new_acquisition_shopper: legacy-hive-dim_new_acquisition_shopper
## ALATION
- Enabled: true
- User ID: 213
- Refresh token: use $ALATION_REFRESH_TOKEN env var
- Certified Data Dictionary: Document Folder ID 6
