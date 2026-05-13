
CREATE TABLE free_entitlement(
	entitlement_id 						string     COMMENT '@PrimaryKey Unique identifier for a customer entitlement to a product or service. Shared key across enterprise entitlement tables (dim_entitlement, fact_entitlement_bill).',
	resource_id 						int        COMMENT 'Identifier for the customer account (shopper) holding this entitlement. Corresponds to the shopper or customer resource entity in the GoDaddy entitlement model.',
	product_type_id 					int        COMMENT 'Numeric identifier for the product type category (e.g., domain, hosting, email). Classifies the product at a high level.',
	product_family_name 					string     COMMENT 'Human-readable name of the product family for the free entitlement (e.g., WordPress Hosting, Domain Registration). Corresponds to the free Product Family ID.',
	free_pf_id 						int        COMMENT 'Product Family ID of the free product. Used as a hard-coded filter to identify free trial entitlements from virtual orders in the Classic eComm system.',
	free_type_name 						string     COMMENT '@Enumerated(freemium, freemat, bmat, cmat) Type of free product giveaway. Derived via business logic from source data; source tables do not directly provide this taxonomy.',
	free_bill_id 						string     COMMENT 'Bill (order) identifier from Classic eComm (CES) or FeedDB that originated the free entitlement. References the virtual order record that provisioned the free product.',
	free_bill_line_num 					int        COMMENT 'Line item number within the free bill. Combined with free_bill_id, uniquely identifies the specific order line that created this free entitlement.',
	free_bill_mst_ts 					timestamp  COMMENT 'Timestamp when the free bill (order) was created or processed (Mountain Standard Time). Represents when the free entitlement was provisioned in Classic eComm.',
	free_bill_mst_date 					date       COMMENT 'Date when the free bill was created (Mountain Standard Time). Date-grain of free_bill_mst_ts for efficient date-based filtering in analytical queries.',
	free_bill_type_name 					string     COMMENT 'Billing transaction type for the free order line (e.g., new, renewal, upgrade). Describes the nature of the free billing event, sourced from Classic eComm or FeedDB.',
	free_target_expiration_mst_ts 				timestamp  COMMENT 'Timestamp when the free entitlement is scheduled to expire (Mountain Standard Time). Defines the end of the intended free trial window; set at provisioning time.',
	free_target_expiration_mst_date 			date       COMMENT 'Date when the free entitlement is scheduled to expire (Mountain Standard Time). Date-grain of free_target_expiration_mst_ts for date-based analysis.',
	free_acquisition_mst_ts 				timestamp  COMMENT 'Timestamp when the customer first received the free entitlement (Mountain Standard Time). Marks the start of the free trial or free product period.',
	free_acquisition_mst_date 				date       COMMENT 'Date when the customer acquired the free entitlement (Mountain Standard Time). Date-grain of free_acquisition_mst_ts for cohort and trend analysis.',
	paid_pf_id 						int        COMMENT 'Product Family ID of the paid product the customer converted to after the free trial. NULL if no paid conversion has occurred. Only the first paid conversion is captured.',
	paid_bill_id 						string     COMMENT 'Bill (order) identifier of the first paid order after free trial conversion. NULL if no paid conversion has occurred. Only the first paid conversion is tracked.',
	paid_bill_line_num 					int        COMMENT 'Line item number within the paid conversion bill. Combined with paid_bill_id, uniquely identifies the order line representing conversion from the free trial.',
	paid_bill_mst_ts 					timestamp  COMMENT 'Timestamp when the first paid conversion bill was created (Mountain Standard Time). Marks the moment a customer converted from free to paid. NULL if no conversion has occurred.',
	paid_bill_mst_date 					date       COMMENT 'Date of the first paid conversion bill (Mountain Standard Time). Date-grain of paid_bill_mst_ts for conversion rate analysis by cohort. NULL if no conversion.',
	etl_build_mst_ts 					timestamp  COMMENT 'Audit timestamp when this row was loaded by the ETL pipeline (Mountain Standard Time). Represents pipeline processing time, not business event time. Updated on each daily snapshot refresh.'
);

