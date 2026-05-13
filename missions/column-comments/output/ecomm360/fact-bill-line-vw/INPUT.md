Enrich column descriptions in a Data Lake table DDL file following the
Data Governance Council's Column Description Standard for Data Lake Assets.

## TARGET TABLE
- Database: ecomm360
- Table: fact-bill-line-vw
- DDL path: catalog/config/prod/dlms-api/us-west-2/ecomm360/fact-bill-line-vw/table.ddl
- YAML path: catalog/config/prod/dlms-api/us-west-2/ecomm360/fact-bill-line-vw/table.yaml

## CONFLUENCE PAGES
- https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3688240210/Fact_Bill_Line_Vw
  (Fact_Bill_Line_Vw — design page linked from Alation table description (resolved from tiny link /wiki/x/UhTW2w).)
## REFERENCE TABLES
- signals_platform_cln.ecomm_unified_order_event_cln (Alation table_id: 6968214)
  Upstream dependency from data lake registry lineage — signals_platform_cln.ecomm_unified_order_event_cln: Unified order event table
- signals_platform_cln.ecomm_order_item_event_cln (Alation table_id: 6968215)
  Upstream dependency from data lake registry lineage — signals_platform_cln.ecomm_order_item_event_cln: eComm Unified Order Item
- signals_platform_cln.ecomm_order_finance_item_cln (Alation table_id: 7010016)
  Upstream dependency from data lake registry lineage — signals_platform_cln.ecomm_order_finance_item_cln: Unified Order Finance Item
- signals_platform_cln.ecomm_order_payment_event_cln (Alation table_id: 6968216)
  Upstream dependency from data lake registry lineage — signals_platform_cln.ecomm_order_payment_event_cln: Unified order payment event table
## ALATION
- Enabled: true
- User ID: 213
- Refresh token: use $ALATION_REFRESH_TOKEN env var
- Certified Data Dictionary: Document Folder ID 6
