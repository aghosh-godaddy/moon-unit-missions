Enrich column descriptions in a Data Lake table DDL file following the
Data Governance Council's Column Description Standard for Data Lake Assets.

## TARGET TABLE
- Database: enterprise
- Table: dim-subscription-history
- DDL path: catalog/config/prod/us-west-2/enterprise/dim-subscription-history/table.ddl
- YAML path: catalog/config/prod/us-west-2/enterprise/dim-subscription-history/table.yaml

## CONFLUENCE PAGES
- https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/76447948/dim_subscription+and+entitlement
  (dim_subscription and entitlement — overview of the Subscription/Entitlement table pair, SLAs, partition column, PK, and contacts)
- https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3868983705/Dim+Sub+Last+Active+Date+Logic
  (Dim Sub Last Active Date Logic — daily snapshot logic for cancellation state (DimSubActiveDate.py))
- https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3791299219/Data+Model+-+EDS+Prime+Subscription
  (Data Model - EDS Prime Subscription — target schema and data model for the Subscription replacement effort)
## REFERENCE TABLES
- enterprise.dim_subscription (Alation table_id: 6229558)
  Base table — enterprise.dim_subscription_history is the daily snapshot of enterprise.dim_subscription; column semantics are shared.
## ALATION
- Enabled: true
- User ID: 213
- Refresh token: use $ALATION_REFRESH_TOKEN env var
- Certified Data Dictionary: Document Folder ID 6
