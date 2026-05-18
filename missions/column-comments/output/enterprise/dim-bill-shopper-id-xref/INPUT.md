Enrich column descriptions in a Data Lake table DDL file following the
Data Governance Council's Column Description Standard for Data Lake Assets.

## TARGET TABLE
- Database: enterprise
- Table: dim-bill-shopper-id-xref
- DDL path: catalog/config/prod/us-west-2/enterprise/dim-bill-shopper-id-xref/table.ddl
- YAML path: catalog/config/prod/us-west-2/enterprise/dim-bill-shopper-id-xref/table.yaml

## CONFLUENCE PAGES
- https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/10372130/Dim_Bill_Shopper_ID_Xref
  (Dim_Bill_Shopper_ID_Xref design doc — purpose, primary key (bill_id), source repo (gdcorp-dna/de-ecomm-gcr), Airflow DAG (ecomm_unified_bill), SLA, upstream dependencies, data flow diagram, and a full column-level schema with descriptions and source tables (gdshop_receipt_header, gdshop_receipt_virtual_order, nds_smartline_event, rp_salesMonitor_internalShopper_snap, fortknox_shopper_snap).)
## REFERENCE TABLES
- ecomm360.dim_bill_vw (Alation table_id: 7028947)
  Upstream dependency from data lake registry lineage — ecomm360.dim_bill_vw: tracks every receipt of the purchase of a godaddy customer. Source of bill_id and shopper-id attribution columns.
- ecomm360.fact_bill_line_vw (Alation table_id: 7027689)
  Upstream dependency from data lake registry lineage — ecomm360.fact_bill_line_vw: tracks every receipt of the purchase of a godaddy customer. Provides bill-line grain context that the xref aggregates to bill grain.
- customer360.dim_customer_vw (Alation table_id: 7022291)
  Upstream dependency from data lake registry lineage — customer360.dim_customer_vw: shopper and profile data in customer360. Source of shopper-merge metadata used to derive original_shopper_id / merged_shopper_id.
## ALATION
- Enabled: true
- User ID: 213
- Refresh token: use $ALATION_REFRESH_TOKEN env var
- Certified Data Dictionary: Document Folder ID 6
