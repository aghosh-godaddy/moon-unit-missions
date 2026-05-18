Enrich column descriptions in a Data Lake table DDL file following the
Data Governance Council's Column Description Standard for Data Lake Assets.

## TARGET TABLE
- Database: enterprise
- Table: dim-new-registered-user
- DDL path: catalog/config/prod/us-west-2/enterprise/dim-new-registered-user/table.ddl
- YAML path: catalog/config/prod/us-west-2/enterprise/dim-new-registered-user/table.yaml

## CONFLUENCE PAGES
- https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/10369242/Dim_New_Registered_User
  (Dim_New_Registered_User design doc — purpose (historical view of new registered users; NRU = Prospect → Registered User state transition), primary key (bill_shopper_id), source repo (GDLakeDataProcessors/uds_dag), Airflow DAG (EDT_Ingest_Unified_Bill), SLA, and full column-level schema with descriptions, source columns (all from enterprise.fact_bill_line), example data, and business rules (FMV = $0, exclude refunds/chargebacks/Domain Change-of-Ownership pf_ids 112/260112/912/260912, only orders preceding the first paid order).)
- https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/10355742/DQ+dim_new_registered_user
  (DQ dim_new_registered_user — data-quality validation queries comparing the table to its upstream dp_stage.ref_uds_order_new_registered_user, including shopper-count / order-count parity checks. Useful color on column semantics and known data-quality boundaries.)
## REFERENCE TABLES
- enterprise.fact_bill_line (Alation table_id: 6332236)
  Per the design doc, every column in dim_new_registered_user sources from enterprise.fact_bill_line (bill_shopper_id, new_registered_user_bill_id, new_registered_user_bill_mst_date, new_registered_user_bill_mst_ts). EDS receipt-grain table — high-signal source for column descriptions.
- enterprise.dim_new_acquisition_shopper (Alation table_id: 6332252)
  Sibling table — enterprise.dim_new_acquisition_shopper captures the first PAID order per shopper; dim_new_registered_user captures the first FREE order. Same PK (bill_shopper_id), parallel column structure (bill_id / bill_mst_date / bill_mst_ts), shared upstream registration view. Column descriptions transfer almost directly.
- enterprise.dim_bill_shopper_id_xref (Alation table_id: 6332248)
  Related table — enterprise.dim_bill_shopper_id_xref maps original_shopper_id ↔ merged_shopper_id at bill grain. The design doc notes the table contains shoppers who were subsequently merged; bill_shopper_id reflects the pre-merge state at event time, identical to the convention in dim_new_acquisition_shopper.
## ALATION
- Enabled: true
- User ID: 213
- Refresh token: use $ALATION_REFRESH_TOKEN env var
- Certified Data Dictionary: Document Folder ID 6
