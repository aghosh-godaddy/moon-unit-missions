Enrich column descriptions in a Data Lake table DDL file following the
Data Governance Council's Column Description Standard for Data Lake Assets.

## TARGET TABLE
- Database: enterprise
- Table: fact-bill
- DDL path: catalog/config/prod/us-west-2/enterprise/fact-bill/table.ddl
- YAML path: catalog/config/prod/us-west-2/enterprise/fact-bill/table.yaml

## CONFLUENCE PAGES
- https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/10358411/Fact_Bill
  (Fact_Bill design doc — purpose (EDS comprehensive receipt view rolled up at bill level), primary key (bill_id, source_system_name), foreign keys (pf_id → dim_product), source repo (GDLakeDataProcessors/uds), Airflow DAG (EDT_Ingest_Unified_Bill), SLA, upstream tx_log dependencies (gdshop_CommissionJunction, gdshop_receipt_header, gdshop_receipt_header_payment, gdshop_receipt_virtualOrder), data flow steps (raw → clean → EDS), and full multi-layer column schema (clean Layer 1 + EDS bill-grain columns).)
- https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/10357308/DQ+Fact_Bill
  (DQ Fact_Bill — data-quality validation comparing dp_enterprise.fact_bill against the aggregated order-grain dataset dp_enterprise.uds_order; record-count and amount parity checks. Useful color on column semantics (especially exclude_reason_desc and the various *_usd_amt / *_trxn_amt amount columns).)
## REFERENCE TABLES
- enterprise.fact_bill_line (Alation table_id: 6332236)
  Sibling table — enterprise.fact_bill_line is the bill-line-grain receipt EDS that fact_bill rolls up to bill grain. Almost every column in fact_bill (bill_id, source_system_name, bill_modified_mst_ts, refund_flag, chargeback_flag, the *_usd_amt / *_trxn_amt amount columns, exclude_reason_desc, etc.) has an exact-name counterpart in fact_bill_line — column descriptions transfer with minimal adjustment.
- ecomm360.fact_bill_line_vw (Alation table_id: 7027689)
  Upstream dependency from data lake registry lineage — ecomm360.fact_bill_line_vw: tracks every receipt of the purchase of a godaddy customer. EDS Prime successor of the legacy fact_bill_line — useful for current-naming conventions and any column semantics that have evolved post-Prime migration.
- ecomm360.dim_bill_vw (Alation table_id: 7028947)
  Upstream dependency from data lake registry lineage — ecomm360.dim_bill_vw: tracks every receipt of the purchase of a godaddy customer. Bill-grain dimension in EDS Prime — provides current-language descriptions for bill-level attributes (bill_country_code, bill_postal_code, bill_source_name, primary_payment_*, virtual_order_flag, free_order_flag).
## ALATION
- Enabled: true
- User ID: 213
- Refresh token: use $ALATION_REFRESH_TOKEN env var
- Certified Data Dictionary: Document Folder ID 6
