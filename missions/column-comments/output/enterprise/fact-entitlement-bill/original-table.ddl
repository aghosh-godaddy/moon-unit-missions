CREATE TABLE fact_entitlement_bill(
    entitlement_id string
    ,subscription_id string
    ,resource_id bigint
    ,product_family_name string
    ,product_type_id int
    ,pf_id  int
    ,entitlement_addon_id bigint 
    ,source_system_name string
    ,source_table_name string
    ,subscription_paid_through_mst_ts timestamp
    ,subscription_paid_through_mst_date date
    ,subscription_bill_due_mst_ts timestamp 
    ,subscription_bill_due_mst_date date 
    ,billing_subscription_status_name string COMMENT 'subscription status at bill_modified_mst_ts'
    ,bill_id string
    ,bill_line_num int
    ,prorated_bill_line_num int
    ,bill_sequence_number int
    ,bill_modified_mst_ts timestamp
    ,bill_modified_mst_date date
    ,refund_flag boolean
    ,chargeback_flag boolean
    ,payable_bill_line_flag boolean
    ,originating_payable_subscription_flag boolean
    ,current_payable_subscription_flag boolean
    ,bill_auto_renewal_flag boolean
    ,product_month_qty decimal(18,6)
    ,unit_qty decimal(18,6) COMMENT 'Prorated unit quantity from receipts'
    ,duration_qty decimal(18,6) COMMENT 'Prorated quantity of duration units which are described in product_period_name (dim_product)'
    ,msrp_duration_unit_usd_amt decimal(18,6)
    ,msrp_duration_unit_trxn_amt decimal(18,6)
    ,gcr_usd_amt decimal(18,6)
    ,gcr_trxn_amt decimal(18,6)
    ,trxn_currency_code string
    ,margin_gcr_usd_amt decimal(18,6)
    ,receipt_price_usd_amt decimal(18,6)
    ,receipt_price_trxn_amt decimal(18,6)
    ,list_price_usd_amt decimal(18,6)
    ,list_price_trxn_amt decimal(18,6)
    ,sale_price_usd_amt decimal(18,6)
    ,sale_price_trxn_amt decimal(18,6)
    ,injected_icann_fee_usd_amt decimal(18,6)
    ,fee_usd_amt decimal(18,6)
    ,etl_build_mst_ts timestamp          	                    
); 
