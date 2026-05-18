Enrich column descriptions in a Data Lake table DDL file following the
Data Governance Council's Column Description Standard for Data Lake Assets.

## TARGET TABLE
- Database: enterprise
- Table: dim-new-acquisition-shopper
- DDL path: catalog/config/prod/us-west-2/enterprise/dim-new-acquisition-shopper/table.ddl
- YAML path: catalog/config/prod/us-west-2/enterprise/dim-new-acquisition-shopper/table.yaml

## CONFLUENCE PAGES
- https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/10369719/Dim_New_Acquisition_Shopper
  (Dim_New_Acquisition_Shopper design doc — purpose (historical view of newly-acquired shoppers; New Customer Acquisition = state transition to Active Customer in Customer Account Lifecycle), primary key (bill_shopper_id), source repo (gdcorp-dna/de-ecomm-bill-line), Airflow DAG (ecomm_unified_bill), SLA, upstream dependency, and full column-level schema with descriptions, source columns (all from enterprise.fact_bill_line), example data, and special notes (e.g., bill_shopper_id was merged_shopper_id prior to 2021-08-09; new_acquisition_bill_id is first paid order with GCR > $0 or domain change-of-ownership, pf_id in {112, 260112, 912, 260912}).)
## REFERENCE TABLES
- enterprise.fact_bill_line (Alation table_id: 6332236)
  Per the design doc, every column in dim_new_acquisition_shopper sources from enterprise.fact_bill_line (bill_shopper_id, new_acquisition_bill_id, bill_country_code, new_acquisition_bill_mst_date, new_acquisition_bill_mst_ts). EDS receipt-grain table — high-signal source for column descriptions.
- enterprise.dim_bill_shopper_id_xref (Alation table_id: 6332248)
  Related table — enterprise.dim_bill_shopper_id_xref maps original_shopper_id ↔ merged_shopper_id at bill grain. The design doc explicitly references this table for bill_shopper_id semantics (post-2021-08-09 the column tracks original_shopper_id; prior backfill used merged_shopper_id).
## ALATION
- Enabled: true
- User ID: 213
- Refresh token: use $ALATION_REFRESH_TOKEN env var
- Certified Data Dictionary: Document Folder ID 6
