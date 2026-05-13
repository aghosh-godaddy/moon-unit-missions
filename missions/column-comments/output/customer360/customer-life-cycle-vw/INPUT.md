Enrich column descriptions in a Data Lake table DDL file following the
Data Governance Council's Column Description Standard for Data Lake Assets.

## TARGET TABLE
- Database: customer360
- Table: customer-life-cycle-vw
- DDL path: catalog/config/prod/dlms-api/us-west-2/customer360/customer-life-cycle-vw/table.ddl
- YAML path: catalog/config/prod/dlms-api/us-west-2/customer360/customer-life-cycle-vw/table.yaml

## CONFLUENCE PAGES
- https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3779199819/Customer360
  (Customer360 design specification — overall Customer360 schema architecture and column definitions)
- https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3970861345/Customer+Lifecycle
  (Customer Lifecycle design — lifecycle stages, transitions, and business logic for customer lifecycle view)
## REFERENCE TABLES
- analytic_feature.shopper_acquisition (Alation table_id: 6300171)
  Upstream dependency from data lake registry lineage — analytic_feature.shopper_acquisition: legacy-hive-shopper_acquisition
- analytic_feature.customer_type_history (Alation table_id: 6365364)
  Upstream dependency from data lake registry lineage — analytic_feature.customer_type_history: migrated-customer_type_history
- analytic_feature.shopper_account_detail (Alation table_id: 6555393)
  Upstream dependency from data lake registry lineage — analytic_feature.shopper_account_detail: shopper feature account detail table
- enterprise.dim_new_acquisition_shopper (Alation table_id: 6332252)
  Upstream dependency from data lake registry lineage — enterprise.dim_new_acquisition_shopper: legacy-hive-dim_new_acquisition_shopper
- analytic_feature.shopper_tenure (Alation table_id: 6300179)
  Upstream dependency from data lake registry lineage — analytic_feature.shopper_tenure: migrated-hive-shopper_tenure
- ecomm_mart.bill_line_traffic_ext (Alation table_id: 6951872)
  Upstream dependency from data lake registry lineage — ecomm_mart.bill_line_traffic_ext: Analytic convenience denormalization of Bill Line and CSP Session Traffic.
- analytic_feature.customer_fraud (Alation table_id: 6620297)
  Upstream dependency from data lake registry lineage — analytic_feature.customer_fraud: fraud dataset on shopper_id level
- analytic_feature.shopper_merge (Alation table_id: 6295888)
  Upstream dependency from data lake registry lineage — analytic_feature.shopper_merge: legacy-hive-shopper_merge
## ALATION
- Enabled: true
- User ID: 213
- Refresh token: use $ALATION_REFRESH_TOKEN env var
- Certified Data Dictionary: Document Folder ID 6
