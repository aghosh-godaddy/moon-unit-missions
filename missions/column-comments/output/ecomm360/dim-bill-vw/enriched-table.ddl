CREATE TABLE dim_bill_vw (
    bill_id string COMMENT '@PrimaryKey Unique identifier for a customer bill (receipt). Part of composite PK with original_customer_id, merged_customer_id, rep_version_id. Sourced from order_id.',
    event_id string COMMENT 'Unique identifier for the event bus event that created or last modified this bill record. Sourced from ecomm_unified_order_event_cln.',
    original_shopper_id	string COMMENT 'Shopper ID at original bill creation. Backfilled from legacy dim_bill_shopper_id_xref for pre-2025-04-01 records; mostly null after that date.',
    original_customer_id string COMMENT 'Customer ID at original bill creation, before any account merges. Composite PK component. Sourced from original_customer_id in ecomm_unified_order_event_cln.',
    merged_shopper_id string COMMENT 'Current post-merge shopper ID on the bill. Backfilled from legacy dim_bill_shopper_id_xref for pre-2025-04-01 records; mostly null after that date.',
    merged_customer_id string COMMENT 'Current post-merge customer ID associated with the bill. Composite PK component. Sourced from customer_id in ecomm_unified_order_event_cln.',
    rep_version_id int COMMENT 'Version identifier for the sales representative assignment on this bill. Composite PK component. Sourced from rep_version_id in ecomm_unified_order_event_cln.',
    bill_modified_mst_date date COMMENT 'Date the bill was last modified, in Mountain Standard Time (MST). Derived from order_date_utc_ts in signals_platform_cln.ecomm_unified_order_event_cln.',
    current_record_flag boolean COMMENT '@Enumerated(TRUE, FALSE) SCD2 partition flag for the current active bill version. TRUE = active (effective end = 9999-12-31); FALSE = superseded historical record. Partition column.',
    etl_insert_utc_ts timestamp COMMENT 'UTC timestamp when this row was first inserted by the Extract, Transform, Load (ETL) process. Immutable unless the table is fully reflowed.',
    etl_update_utc_ts timestamp  COMMENT 'UTC timestamp when this row was last updated by the Extract, Transform, Load (ETL) process.'
);
