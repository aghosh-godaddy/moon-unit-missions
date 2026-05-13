Enrich column descriptions in a Data Lake table DDL file following the
Data Governance Council's Column Description Standard for Data Lake Assets.

## TARGET TABLE
- Database: gd-traffic-mart
- Table: analytic-traffic-agg
- DDL path: catalog/config/prod/us-west-2/gd-traffic-mart/analytic-traffic-agg/table.ddl
- YAML path: catalog/config/prod/us-west-2/gd-traffic-mart/analytic-traffic-agg/table.yaml

## CONFLUENCE PAGES
- https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3292767683/MDPE+-+WAA+v2+Design
  (MDPE - WAA v2 Design — linked from Alation table description)
## REFERENCE TABLES
- gd_traffic_mart.analytic_traffic_detail (Alation table_id: 6951066)
  Upstream dependency from data lake registry lineage — gd_traffic_mart.analytic_traffic_detail: Analytic Dataset for CSP Traffic Session and Order Data
## ALATION
- Enabled: true
- User ID: 213
- Refresh token: use $ALATION_REFRESH_TOKEN env var
- Certified Data Dictionary: Document Folder ID 6
