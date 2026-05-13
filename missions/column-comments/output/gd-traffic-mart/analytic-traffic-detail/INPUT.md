Enrich column descriptions in a Data Lake table DDL file following the
Data Governance Council's Column Description Standard for Data Lake Assets.

## TARGET TABLE
- Database: gd-traffic-mart
- Table: analytic-traffic-detail
- DDL path: catalog/config/prod/us-west-2/gd-traffic-mart/analytic-traffic-detail/table.ddl
- YAML path: catalog/config/prod/us-west-2/gd-traffic-mart/analytic-traffic-detail/table.yaml

## CONFLUENCE PAGES
- https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3510968264/MDPE+-+Traffic+Data+Consumer+Responsibilities
  (MDPE - Traffic Data Consumer Responsibilities — linked from Alation table description)
- https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3318415585/MDPE+-+WAD+v2+Design
  (MDPE - WAD v2 Design — linked from Alation table description)
- https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3318415788/MDPE+-+CSP+Traffic+EDS+Design
  (MDPE - CSP Traffic EDS Design — linked from Alation table description)
## REFERENCE TABLES
- gd_traffic_mart.traffic_session (Alation table_id: 6951082)
  Upstream dependency from data lake registry lineage — gd_traffic_mart.traffic_session: CSP Traffic session level data. Tier3 DATAGOVER-1503
- analytic.ads_bill_line (Alation table_id: 6242622)
  Upstream dependency from data lake registry lineage — analytic.ads_bill_line: analytic data set for bill line
- gd_traffic_mart.gd_bill_id_session_xref (Alation table_id: 6636558)
  Upstream dependency from data lake registry lineage — gd_traffic_mart.gd_bill_id_session_xref: Mapping table between Orders (bill_id) and Traffic (session_id)
- gd_traffic_mart.gd_traffic_session_last_nondirect_attribution (Alation table_id: 6622545)
  Upstream dependency from data lake registry lineage — gd_traffic_mart.gd_traffic_session_last_nondirect_attribution: Session level last non-direct attribution channel using GoDaddy traffic data. Tier3 DATAGOVER-1504
- analytic_feature.shopper_tenure (Alation table_id: 6300179)
  Upstream dependency from data lake registry lineage — analytic_feature.shopper_tenure: migrated-hive-shopper_tenure
- analytic_feature.customer_type (Alation table_id: 6304551)
  Upstream dependency from data lake registry lineage — analytic_feature.customer_type: migrated-customer_type
## ALATION
- Enabled: true
- User ID: 213
- Refresh token: use $ALATION_REFRESH_TOKEN env var
- Certified Data Dictionary: Document Folder ID 6
