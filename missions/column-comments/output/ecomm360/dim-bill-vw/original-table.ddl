CREATE TABLE dim_bill_vw (
    bill_id string COMMENT 'Primary Key - Unique identifier for the bill',
    event_id string COMMENT 'Unique identifier for the event that generated this bill',
    original_shopper_id	string COMMENT 'Original shopper of the bill',
    original_customer_id string COMMENT 'original customer of the bill',
    merged_shopper_id string COMMENT 'current merged shopper of the bill',
    merged_customer_id string COMMENT 'current merged customer of the bill',	
    rep_version_id int COMMENT 'current rep version id on the bill',	
    bill_modified_mst_date date COMMENT 'Timestamp when the bill was last modified in Mountain Standard Time',
    current_record_flag boolean COMMENT 'current record flag indicates which is most recent record',
    etl_insert_utc_ts timestamp COMMENT 'ETL process timestamp when record was first inserted in UTC',
    etl_update_utc_ts timestamp  COMMENT 'ETL process timestamp when record was last updated in UTC'
);
