Enrich column descriptions in a Data Lake table DDL file following the
Data Governance Council's Column Description Standard for Data Lake Assets.

## TARGET TABLE
- Database: pricing-mart
- Table: product-price-catalog
- DDL path: catalog/config/prod/us-west-2/pricing-mart/product-price-catalog/table.ddl
- YAML path: catalog/config/prod/us-west-2/pricing-mart/product-price-catalog/table.yaml

## CONFLUENCE PAGES
- https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3740008527/Product+Price+Catalog
  (Product Price Catalog — design specification: schema, business logic, and data sources)
- https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3354394625/Product+Price+List
  (Product Price List — design doc for the predecessor table pricing_mart.product_price_list; pricing semantics and business rules carry over)
## REFERENCE TABLES
- pricing_mart.product_price_list (Alation table_id: 6636972)
  Predecessor table — pricing_mart.product_price_list (Alation id 6636972). Column descriptions, business rules, and pricing lineage are directly relevant to product_price_catalog.
## ALATION
- Enabled: true
- User ID: 213
- Refresh token: use $ALATION_REFRESH_TOKEN env var
- Certified Data Dictionary: Document Folder ID 6
