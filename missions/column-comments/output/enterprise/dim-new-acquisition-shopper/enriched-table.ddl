CREATE TABLE `dim_new_acquisition_shopper` (
    bill_shopper_id string COMMENT '@PrimaryKey Unique shopper account identifier (original_shopper_id). Pre-2021-08-09 records reflect merged_shopper_id; 2021-08-09+ reflect original_shopper_id. Source: enterprise.fact_bill_line.',
    new_acquisition_bill_id string COMMENT 'Bill identifier of the shopper\'s first qualifying paid order (New Customer Acquisition). Qualifies if Gross Cash Receipts (GCR) > $0 or domain change-of-ownership. Source: enterprise.fact_bill_line.',
    bill_country_code string COMMENT 'ISO 3166-1 alpha-2 country code associated with the shopper\'s new acquisition billing transaction (e.g., US, CA). Sourced from enterprise.fact_bill_line.',
    new_acquisition_bill_mst_date date COMMENT 'Date of the shopper\'s new acquisition order in Mountain Standard Time (MST). Sourced from enterprise.fact_bill_line.',
    new_acquisition_bill_mst_ts timestamp COMMENT 'Timestamp of the shopper\'s new acquisition order in Mountain Standard Time (MST). Sourced from enterprise.fact_bill_line.'

);
