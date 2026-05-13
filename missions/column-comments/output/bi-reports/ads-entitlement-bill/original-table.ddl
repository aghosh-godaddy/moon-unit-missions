CREATE TABLE ads_entitlement_bill(
  entitlement_id string 
  ,subscription_id string 
  ,current_subscription_status_name string COMMENT 'subscription status name at the time data was loaded in the table'
  ,resource_id bigint 
  ,product_family_name string 
  ,shopper_id string 
  ,customer_id string
  ,auto_renewal_flag boolean
  ,hard_bundle_flag boolean
  ,bill_id string 
  ,bill_line_num int 
  ,bill_sequence_num int 
  ,entitlement_bill_type string 
  ,migration_type string
  ,subscription_migration_mst_ts timestamp 
  ,subscription_migration_mst_date date 
  ,price_group_id int COMMENT 'Subscription price group id, such as 0, 6, 37'
  ,price_group_name string COMMENT 'Subscription price group name, such as Default, ca-Canada, hk-Hong Kong'
  ,bill_modified_mst_ts timestamp 
  ,bill_modified_mst_date string 
  ,subscription_cancel_mst_ts timestamp 
  ,subscription_cancel_mst_date date 
  ,subscription_cancel_by_name string 
  ,refund_flag boolean 
  ,payable_bill_line_flag boolean
  ,originating_payable_subscription_flag boolean
  ,current_payable_subscription_flag boolean
  ,bill_private_label_id int 
  ,bill_reseller_name string 
  ,bill_reseller_type_name string 
  ,point_of_purchase_name string 
  ,bill_fraud_flag boolean 
  ,trxn_currency_code string 
  ,bill_customer_type_name string 
  ,bill_crm_portfolio_type_name string 
  ,bill_country_code string 
  ,bill_country_name string 
  ,bill_report_region_2_name string 
  ,bill_domestic_international_name string 
  ,intent string COMMENT 'Intent Enum for virtual bill with value such as FREEMIUM_PURCHASE, FREE_PURCHASE, FREE_TRIAL_MODIFY, etc'
  ,related_subscription string COMMENT 'Associate a receiptless or virtual order event to a specific subscription'
  ,variant_price_type_id int COMMENT 'Bill line variant price type id as NULL, 1, 2, 4, 8, 16, 32, 64, 128 or 256'
  ,variant_price_type_name string  COMMENT 'Bill line variant price type such as Standard Price, Costco, GoDaddy Pro Member Price, etc'
  ,item_tracking_code string 
  ,purchase_path_name string 
  ,pf_id int 
  ,entitlement_addon_id bigint
  ,product_type_id int 
  ,product_type_desc string 
  ,product_name string
  ,product_pnl_new_renewal_name string
  ,product_pnl_category_name string 
  ,product_pnl_group_name string 
  ,product_pnl_line_name string 
  ,product_pnl_subline_name string 
  ,product_pnl_version_name string 
  ,product_term_unit_desc string 
  ,product_term_num int 
  ,fin_pnl_group_name string
  ,fin_pnl_category_name string
  ,fin_pnl_line_name string
  ,fin_pnl_subline_name string
  ,fin_investor_relation_class_name string
  ,fin_investor_relation_subclass_name string
  ,fin_investor_relation_segment_name string
  ,fin_subscription_transaction_name string
  ,pnl_international_independent_flag boolean 
  ,pnl_investor_flag boolean 
  ,pnl_partner_flag boolean 
  ,pnl_us_independent_flag boolean 
  ,pnl_commerce_flag boolean
  ,domain_bulk_pricing_flag string  
  ,renewal_pf_id int 
  ,bill_auto_renewal_flag boolean 
  ,bill_paid_through_mst_ts timestamp 
  ,bill_paid_through_mst_date date 
  ,bill_billing_due_mst_ts timestamp 
  ,bill_billing_due_mst_date date 
  ,domain_cancel_reason_desc string 
  ,primary_product_flag boolean
  ,source_table_name string 
  ,source_system_name string 
  ,bill_exclude_reason_desc string 
  ,bill_exclude_reason_month_end_desc string 
  ,subscription_exclude_reason_desc string 
  ,product_month_qty decimal(18,6) 
  ,unit_qty decimal(18,6) COMMENT 'Prorated unit quantity from receipts'
  ,duration_qty decimal(18,6) COMMENT 'Prorated quantity of duration units which are described in product_period_name (dim_product)'
  ,injected_icann_fee_usd_amt decimal(18,6) COMMENT 'Icann fee in USD from fact_entitlemint_bill'
  ,msrp_duration_unit_usd_amt decimal(18,6) 
  ,msrp_duration_unit_trxn_amt decimal(18,6) 
  ,fee_usd_amt decimal(18,6) 
  ,gcr_usd_amt decimal(18,6) 
  ,gcr_trxn_amt decimal(18,6) 
  ,receipt_price_usd_amt decimal(18,6) 
  ,receipt_price_trxn_amt decimal(18,6) 
  ,billing_subscription_status_name string COMMENT 'the subscription status name at bill_modified_mst_ts'
  ,federation_partner_id string COMMENT 'represents the brand id from which the shopper associated with prior bill originated'
  ,federation_partner_name string COMMENT 'represents the brand name from which the shopper associated with prior bill originated eg: Google, TsoHost'
  ,etl_build_mst_ts timestamp
); 
