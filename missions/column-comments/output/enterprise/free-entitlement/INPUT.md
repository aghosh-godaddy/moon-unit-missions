Enrich column descriptions in a Data Lake table DDL file following the
Data Governance Council's Column Description Standard for Data Lake Assets.

## TARGET TABLE
- Database: enterprise
- Table: free-entitlement
- DDL path: catalog/config/prod/us-west-2/enterprise/free-entitlement/table.ddl
- YAML path: catalog/config/prod/us-west-2/enterprise/free-entitlement/table.yaml

## CONFLUENCE PAGES
- https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/4347200896/Current+Design+Challenges
  (Current Design Challenges — free_entitlement design notes: Classic eComm (CES) / FeedDB sources, virtual-order filtering by hard-coded pf_ids and item_tracking_codes, free-trial type taxonomy (freemium, freemat, bmat, cmat), free→paid→free lifecycle gaps, and the Care-analytics MS SQL Server predecessor dataset. Explains why business logic continually evolves.)
## REFERENCE TABLES
- enterprise.dim_entitlement (Alation table_id: 6229554)
  Related table — enterprise.dim_entitlement holds entitlement dimensions for customer products; shared column semantics (entitlement_id, pf_id, product_type_desc, product_family_name, etc.).
- enterprise.fact_entitlement_bill (Alation table_id: 6607221)
  Related table — enterprise.fact_entitlement_bill tracks billed entitlements; free_entitlement captures the free-conversion side of the same entitlement lifecycle.
## ALATION
- Enabled: true
- User ID: 213
- Refresh token: use $ALATION_REFRESH_TOKEN env var
- Certified Data Dictionary: Document Folder ID 6
