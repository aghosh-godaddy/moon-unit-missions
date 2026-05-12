Enrich column descriptions in a Data Lake table DDL file following the
Data Governance Council's Column Description Standard for Data Lake Assets.

## TARGET TABLE
- Database: enterprise
- Table: fact-bill-line
- DDL path: catalog/config/prod/us-west-2/enterprise/fact-bill-line/table.ddl
- YAML path: catalog/config/prod/us-west-2/enterprise/fact-bill-line/table.yaml

## CONFLUENCE PAGES
- https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/10371978/Fact_Bill_Line
  (Fact_Bill_Line design specification — includes column-level schema, data sources, and business logic)
## REFERENCE TABLES
- ecomm360.fact_bill_line_vw (Alation table_id: 7027689)
  Successor table — ecomm360.fact_bill_line_vw. Most column descriptions are relevant to enterprise.fact_bill_line.
## ALATION
- Enabled: true
- User ID: 213
- Refresh token: use $ALATION_REFRESH_TOKEN env var
- Certified Data Dictionary: Document Folder ID 6
