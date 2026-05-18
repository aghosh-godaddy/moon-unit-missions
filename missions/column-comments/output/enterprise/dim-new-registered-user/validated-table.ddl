CREATE TABLE `dim_new_registered_user` (
    bill_shopper_id string COMMENT '@PrimaryKey Unique shopper account identifier at time of New Registered User (NRU) event; one row per shopper. For merged shoppers, reflects pre-merge state at event time. Source: enterprise.fact_bill_line.',
    new_registered_user_bill_id string COMMENT 'Bill identifier for the qualifying New Registered User (NRU) order. First free order (fair market value=$0) before any paid order. Excludes refunds, chargebacks, and Domain Change-of-Ownership (pf_id IN 112, 260112, 912, 260912).',
    new_registered_user_bill_mst_date date COMMENT 'Calendar date of the qualifying New Registered User (NRU) order in Mountain Standard Time (MST). Source: enterprise.fact_bill_line.',
    new_registered_user_bill_mst_ts timestamp COMMENT 'Timestamp of the qualifying New Registered User (NRU) order in Mountain Standard Time (MST). Source: enterprise.fact_bill_line.'

);
