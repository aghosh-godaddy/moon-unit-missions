Enrich column descriptions in a Data Lake table DDL file following the
Data Governance Council's Column Description Standard for Data Lake Assets.

## TARGET TABLE
- Database: ecomm360
- Table: dim-bill-vw
- DDL path: catalog/config/prod/dlms-api/us-west-2/ecomm360/dim-bill-vw/table.ddl
- YAML path: catalog/config/prod/dlms-api/us-west-2/ecomm360/dim-bill-vw/table.yaml

## CONFLUENCE PAGES
- https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3732834951/Dim_Bill_Vw
  (Dim_Bill_Vw — design page linked from Alation table description and Catalog Set shared Description (resolved from tiny link /wiki/x/h4p_3g).)
## REFERENCE TABLES
- signals_platform_cln.ecomm_unified_order_event_cln (Alation table_id: 6968214)
  Upstream dependency from data lake registry lineage — signals_platform_cln.ecomm_unified_order_event_cln: Unified order event table
## ALATION
- Enabled: true
- User ID: 213
- Refresh token: use $ALATION_REFRESH_TOKEN env var
- Certified Data Dictionary: Document Folder ID 6
