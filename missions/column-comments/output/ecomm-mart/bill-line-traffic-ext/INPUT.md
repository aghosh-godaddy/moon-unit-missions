Enrich column descriptions in a Data Lake table DDL file following the
Data Governance Council's Column Description Standard for Data Lake Assets.

## TARGET TABLE
- Database: ecomm-mart
- Table: bill-line-traffic-ext
- DDL path: catalog/config/prod/us-west-2/ecomm-mart/bill-line-traffic-ext/table.ddl
- YAML path: catalog/config/prod/us-west-2/ecomm-mart/bill-line-traffic-ext/table.yaml

## CONFLUENCE PAGES
- https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3392734327/Bill+Line+Traffic_Extended
  (Bill Line (Traffic_Extended) — design doc: denormalization of Analytic Bill Line + Analytic Traffic Detail (WADv2). Supersedes analytic.ads_bill_line_ext (WADv1). History from 2022-08-01, 9am MST SLA, dedup logic for duplicate WADv2 sessions. Sourced from the Catalog Set 94 shared Description (tiny link https://godaddy-corp.atlassian.net/wiki/x/dwQ5yg resolves here).)
- https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/10368952/ADS_Bill_Line
  (ADS_Bill_Line — upstream Analytic Bill Line design reference (one of the two joined inputs to bill_line_traffic_ext).)
- https://godaddy-corp.atlassian.net/wiki/spaces/ANALYENG/pages/3899489/Enterprise+Data+Lake+Layers
  (Enterprise Data Lake Layers — overview of Analytic Dataset (ADS) layer, the classification for this table.)
## REFERENCE TABLES
- analytic.ads_bill_line (Alation table_id: 6242622)
  Upstream dependency from data lake registry lineage — analytic.ads_bill_line: analytic data set for bill line
- gd_traffic_mart.gd_bill_id_session_xref (Alation table_id: 6636558)
  Upstream dependency from data lake registry lineage — gd_traffic_mart.gd_bill_id_session_xref: Mapping table between Orders (bill_id) and Traffic (session_id)
- gd_traffic_mart.analytic_traffic_detail (Alation table_id: 6951066)
  Upstream dependency from data lake registry lineage — gd_traffic_mart.analytic_traffic_detail: Analytic Dataset for CSP Traffic Session and Order Data
## ALATION
- Enabled: true
- User ID: 213
- Refresh token: use $ALATION_REFRESH_TOKEN env var
- Certified Data Dictionary: Document Folder ID 6
