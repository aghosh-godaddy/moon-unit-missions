Enrich column descriptions in a Data Lake table DDL file following the
Data Governance Council's Column Description Standard for Data Lake Assets.

## TARGET TABLE
- Database: ecomm-mart
- Table: renewal-360
- DDL path: catalog/config/prod/us-west-2/ecomm-mart/renewal-360/table.ddl
- YAML path: catalog/config/prod/us-west-2/ecomm-mart/renewal-360/table.yaml

## CONFLUENCE PAGES
- https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3293352384/Renewal+360
  (Renewal 360 — linked from Alation table description)
- https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3435340877/Renewal+360+Gap+Resolution-+Order+Sequence+1
  (Renewal 360 Gap Resolution- Order Sequence 1 — linked from Alation table description)
## REFERENCE TABLES
- analytic_feature.customer_type (Alation table_id: 6304551)
  Upstream dependency from data lake registry lineage — analytic_feature.customer_type: migrated-customer_type
- bi_reports.ads_entitlement_bill (Alation table_id: 6623325)
  Upstream dependency from data lake registry lineage — bi_reports.ads_entitlement_bill: Analytic Dataset (ADS) that provides a comprehensive view of a renewals of purchase Godaddy orders.
- bi_reports.pricing_mart (Alation table_id: 6285483)
  Upstream dependency from data lake registry lineage — bi_reports.pricing_mart: legacy-hive-pricing_mart
- finance360.dim_product_history_vw (Alation table_id: 7021957)
  Upstream dependency from data lake registry lineage — finance360.dim_product_history_vw: SCD2 Conformed Dimension table containing product-level reporting attributes.
- enterprise.dim_bill_shopper_id_xref (Alation table_id: 6332248)
  Upstream dependency from data lake registry lineage — enterprise.dim_bill_shopper_id_xref: Hadoop legacy table dp_enterprise.dim_bill_shopper_id_xref
- ecomm_mart.entitlement_bill_type (Alation table_id: 6850845)
  Upstream dependency from data lake registry lineage — ecomm_mart.entitlement_bill_type: Enterprise Dataset (EDS) that provides bill_type for all the bills
## ALATION
- Enabled: true
- User ID: 213
- Refresh token: use $ALATION_REFRESH_TOKEN env var
- Certified Data Dictionary: Document Folder ID 6
