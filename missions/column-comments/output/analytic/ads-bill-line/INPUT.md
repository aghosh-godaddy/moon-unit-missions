Enrich column descriptions in a Data Lake table DDL file following the
Data Governance Council's Column Description Standard for Data Lake Assets.

## TARGET TABLE
- Database: analytic
- Table: ads-bill-line
- DDL path: catalog/config/prod/us-west-2/analytic/ads-bill-line/table.ddl
- YAML path: catalog/config/prod/us-west-2/analytic/ads-bill-line/table.yaml

## CONFLUENCE PAGES
- https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/10368952/ADS_Bill_Line
  (ADS_Bill_Line — primary design page linked from Alation table description (resolved from tiny link /wiki/x/uDee; legacy /display/BI/ADS+Bill+Line path returns 404 post-migration).)
- https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/10370083/ADS+Bill+Line+and+Extended+-+Data+Flow+Diagram
  (ADS Bill Line and Extended — Data Flow Diagram (resolved from tiny link /wiki/x/Izye).)
- https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/10366689/ADS+Bill+Line+and+Extended+-+Table+Definition
  (ADS Bill Line and Extended — Table Definition (resolved from tiny link /wiki/x/4S6e).)
## REFERENCE TABLES
- analytic_feature.customer_type_history (Alation table_id: 6365364)
  Upstream dependency from data lake registry lineage — analytic_feature.customer_type_history: migrated-customer_type_history
- analytic_feature.shopper_crm_portfolio (Alation table_id: 6295886)
  Upstream dependency from data lake registry lineage — analytic_feature.shopper_crm_portfolio: Stores Shoppers and their CRM Portfolio features by evaluation date
- analytic_feature.shopper_domain_portfolio (Alation table_id: 6304430)
  Upstream dependency from data lake registry lineage — analytic_feature.shopper_domain_portfolio: migrated-shopper_domain_portfolio
- ecomm360.dim_bill_vw (Alation table_id: 7028947)
  Upstream dependency from data lake registry lineage — ecomm360.dim_bill_vw: tracks every receipt of the purchase of a godaddy customer.
- ecomm360.fact_bill_line_vw (Alation table_id: 7027689)
  Upstream dependency from data lake registry lineage — ecomm360.fact_bill_line_vw: tracks every receipt of the purchase of a godaddy customer.
- enterprise.free_entitlement (Alation table_id: 6276873)
  Upstream dependency from data lake registry lineage — enterprise.free_entitlement: Enterprise dataset (EDS) used for checking free conversions to paid products
- ecomm_mart.dim_bill_line_purchase_attribution (Alation table_id: 6952789)
  Upstream dependency from data lake registry lineage — ecomm_mart.dim_bill_line_purchase_attribution: Dimension containing bill line level point-of-purchase and attribution columns.
- customer360.dim_customer_vw (Alation table_id: 7022291)
  Upstream dependency from data lake registry lineage — customer360.dim_customer_vw: shopper and profile data in customer360
## ALATION
- Enabled: true
- User ID: 213
- Refresh token: use $ALATION_REFRESH_TOKEN env var
- Certified Data Dictionary: Document Folder ID 6
