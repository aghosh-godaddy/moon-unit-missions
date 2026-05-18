CREATE TABLE dim_bill_shopper_id_xref(
  bill_id string, 
  original_shopper_id string, 
  merged_shopper_id string, 
  original_shopper_exclude_reason_desc string, 
  original_shopper_exclude_reason_month_end_desc string, 
  bill_modified_mst_ts timestamp, 
  bill_modified_mst_date string, 
  etl_build_mst_ts timestamp
);
