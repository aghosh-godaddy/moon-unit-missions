Enrich column descriptions in a Data Lake table DDL file following the
Data Governance Council's Column Description Standard for Data Lake Assets.

## TARGET TABLE
- Database: enterprise
- Table: dim-entitlement-history
- DDL path: catalog/config/prod/us-west-2/enterprise/dim-entitlement-history/table.ddl
- YAML path: catalog/config/prod/us-west-2/enterprise/dim-entitlement-history/table.yaml

## CONFLUENCE PAGES
- https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/76447948/dim_subscription+and+entitlement
  (dim_subscription and entitlement — overview of the Subscription/Entitlement table pair, SLAs, partition column, PK, and contacts)
- https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3791299219/Data+Model+-+EDS+Prime+Subscription
  (Data Model - EDS Prime Subscription — target schema and data model for the Subscription/Entitlement replacement effort)
- https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3278396895/Subscription+Entitlement+-+Brainstorming+Ideas+To+Improve+Design
  (Subscription & Entitlement — Brainstorming Ideas To Improve Design — original-author notes (Mike Zwolak) on dim_subscription / dim_subscription_history / dim_entitlement / dim_entitlement_history design)
## REFERENCE TABLES
- enterprise.dim_entitlement (Alation table_id: 6229554)
  Base table — enterprise.dim_entitlement_history is the daily snapshot of enterprise.dim_entitlement; column semantics are shared.
## ALATION
- Enabled: true
- User ID: 213
- Refresh token: use $ALATION_REFRESH_TOKEN env var
- Certified Data Dictionary: Document Folder ID 6
