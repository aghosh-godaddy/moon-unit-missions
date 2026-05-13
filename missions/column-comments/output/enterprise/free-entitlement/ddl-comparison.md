# Column Comments Comparison: enterprise.free-entitlement

Generated: 2026-05-13T16:08

| # | Column | Original | Enriched | Validated | Len |
|---|--------|----------|----------|-----------|-----|
| 1 | `entitlement_id` | — | — | @PrimaryKey Unique identifier for a customer entitlement to a product or service. Shared key across enterprise entitlement tables (dim_entitlement, fact_entitlement_bill). | 171 |
| 2 | `resource_id` | — | — | Identifier for the customer account (shopper) holding this entitlement. Corresponds to the shopper or customer resource entity in the GoDaddy entitlement model. | 160 |
| 3 | `product_type_id` | — | — | Numeric identifier for the product type category (e.g., domain, hosting, email). Classifies the product at a high level. | 120 |
| 4 | `product_family_name` | — | — | Human-readable name of the product family for the free entitlement (e.g., WordPress Hosting, Domain Registration). Corresponds to the free Product Family ID. | 157 |
| 5 | `free_pf_id` | — | — | Product Family ID of the free product. Used as a hard-coded filter to identify free trial entitlements from virtual orders in the Classic eComm system. | 151 |
| 6 | `free_type_name` | — | — | @Enumerated(freemium, freemat, bmat, cmat) Type of free product giveaway. Derived via business logic from source data; source tables do not directly provide this taxonomy. | 171 |
| 7 | `free_bill_id` | — | — | Bill (order) identifier from Classic eComm (CES) or FeedDB that originated the free entitlement. References the virtual order record that provisioned the free product. | 167 |
| 8 | `free_bill_line_num` | — | — | Line item number within the free bill. Combined with free_bill_id, uniquely identifies the specific order line that created this free entitlement. | 146 |
| 9 | `free_bill_mst_ts` | — | — | Timestamp when the free bill (order) was created or processed (Mountain Standard Time). Represents when the free entitlement was provisioned in Classic eComm. | 158 |
| 10 | `free_bill_mst_date` | — | — | Date when the free bill was created (Mountain Standard Time). Date-grain of free_bill_mst_ts for efficient date-based filtering in analytical queries. | 150 |
| 11 | `free_bill_type_name` | — | — | Billing transaction type for the free order line (e.g., new, renewal, upgrade). Describes the nature of the free billing event, sourced from Classic eComm or FeedDB. | 165 |
| 12 | `free_target_expiration_mst_ts` | — | — | Timestamp when the free entitlement is scheduled to expire (Mountain Standard Time). Defines the end of the intended free trial window; set at provisioning time. | 161 |
| 13 | `free_target_expiration_mst_date` | — | — | Date when the free entitlement is scheduled to expire (Mountain Standard Time). Date-grain of free_target_expiration_mst_ts for date-based analysis. | 148 |
| 14 | `free_acquisition_mst_ts` | — | — | Timestamp when the customer first received the free entitlement (Mountain Standard Time). Marks the start of the free trial or free product period. | 147 |
| 15 | `free_acquisition_mst_date` | — | — | Date when the customer acquired the free entitlement (Mountain Standard Time). Date-grain of free_acquisition_mst_ts for cohort and trend analysis. | 147 |
| 16 | `paid_pf_id` | — | — | Product Family ID of the paid product the customer converted to after the free trial. NULL if no paid conversion has occurred. Only the first paid conversion is captured. | 170 |
| 17 | `paid_bill_id` | — | — | Bill (order) identifier of the first paid order after free trial conversion. NULL if no paid conversion has occurred. Only the first paid conversion is tracked. | 160 |
| 18 | `paid_bill_line_num` | — | — | Line item number within the paid conversion bill. Combined with paid_bill_id, uniquely identifies the order line representing conversion from the free trial. | 157 |
| 19 | `paid_bill_mst_ts` | — | — | Timestamp when the first paid conversion bill was created (Mountain Standard Time). Marks the moment a customer converted from free to paid. NULL if no conversion has occurred. | 176 |
| 20 | `paid_bill_mst_date` | — | — | Date of the first paid conversion bill (Mountain Standard Time). Date-grain of paid_bill_mst_ts for conversion rate analysis by cohort. NULL if no conversion. | 158 |
| 21 | `etl_build_mst_ts` | — | — | Audit timestamp when this row was loaded by the ETL pipeline (Mountain Standard Time). Represents pipeline processing time, not business event time. Updated on each daily snapshot refresh. | 188 |
