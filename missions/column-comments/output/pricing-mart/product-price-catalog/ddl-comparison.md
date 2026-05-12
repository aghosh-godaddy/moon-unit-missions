# Column Comments Comparison: pricing-mart.product-price-catalog

Generated: 2026-05-11T19:55

| # | Column | Original | Enriched | Validated | Len |
|---|--------|----------|----------|-----------|-----|
| 1 | `pf_id` | @PrimaryKey Product identifier, composite key with price_type_id, price_group_id, private_label_id, and trxn_currency_code | @PrimaryKey Product identifier, composite key with price_type_id, price_group_id, private_label_id, and trxn_currency_code | @PrimaryKey Product identifier, composite key with price_type_id, price_group_id, private_label_id, and trxn_currency_code | 122 |
| 2 | `price_type_id` | @PrimaryKey Identifier for the price type as 0, 1, 2, 4, 8, 16, 32, 64, 128 or 256 | @PrimaryKey Identifier for the price type as 0, 1, 2, 4, 8, 16, 32, 64, 128 or 256 | @PrimaryKey Identifier for the price type as 0, 1, 2, 4, 8, 16, 32, 64, 128 or 256 | 82 |
| 3 | `price_group_id` | @PrimaryKey Identifier for the price group, integer range from 0 to 34 | @PrimaryKey Identifier for the price group, integer range from 0 to 34 | @PrimaryKey Identifier for the price group, integer range from 0 to 34 | 70 |
| 4 | `reseller_type_id` | Identifier for the reseller type, 1 - Go Daddy, 14 - Boutique Resellers | Identifier for the reseller type, 1 - Go Daddy, 14 - Boutique Resellers | Identifier for the reseller type, 1 - Go Daddy, 14 - Boutique Resellers | 71 |
| 5 | `reseller_name` | Name of the reseller, GoDaddy.com vs 123 Reg | Name of the reseller, GoDaddy.com vs 123 Reg | Name of the reseller, GoDaddy.com vs 123 Reg | 44 |
| 6 | `reseller_type_name` | Name of the reseller type, Go Daddy vs Boutique Resellers | Name of the reseller type, Go Daddy vs Boutique Resellers | Name of the reseller type, Go Daddy vs Boutique Resellers | 57 |
| 7 | `department_id` | Identifier for the department associated with the product | Identifier for the department associated with the product | Identifier for the department associated with the product | 57 |
| 8 | `product_name` | Name of the product | Name of the product | Name of the product | 19 |
| 9 | `product_period_name` | @Enumerated(month,quarter,6-month,year,onetime) Name of the product subscription period | @Enumerated(month,quarter,6-month,year,onetime) Name of the product subscription period | @Enumerated(month,quarter,6-month,year,onetime) Name of the product subscription period | 87 |
| 10 | `product_period_qty` | Number of units in the product period (e.g., 12 for a 12-period term) | Number of units in the product period (e.g., 12 for a 12-period term) | Number of units in the product period (e.g., 12 for a 12-period term) | 69 |
| 11 | `product_pnl_group_name` | Profit and Loss group name for financial reporting | Profit and Loss group name for financial reporting | Profit and Loss group name for financial reporting | 50 |
| 12 | `product_pnl_category_name` | Profit and Loss category name for financial reporting | Profit and Loss category name for financial reporting | Profit and Loss category name for financial reporting | 53 |
| 13 | `product_pnl_line_name` | Profit and Loss line name for financial reporting | Profit and Loss line name for financial reporting | Profit and Loss line name for financial reporting | 49 |
| 14 | `product_pnl_subline_name` | Profit and Loss subline name for financial reporting | Profit and Loss subline name for financial reporting | Profit and Loss subline name for financial reporting | 52 |
| 15 | `product_pnl_version_name` | Profit and Loss version name for financial reporting | Profit and Loss version name for financial reporting | Profit and Loss version name for financial reporting | 52 |
| 16 | `product_pnl_new_renewal_name` | Profit and Loss new versus renewal classification name | Profit and Loss new versus renewal classification name | Profit and Loss new versus renewal classification name | 54 |
| 17 | `department_name` | Name of the department associated with the product | Name of the department associated with the product | Name of the department associated with the product | 50 |
| 18 | `price_group_name` | Descriptive name of the price group | Descriptive name of the price group | Descriptive name of the price group | 35 |
| 19 | `country_site_code` | Country site code | Country site code | Country site code | 17 |
| 20 | `country_site_name` | Country site name | Country site name | Country site name | 17 |
| 21 | `default_market_code` | Default market locale code (e.g., en-US, en-GB) | Default market locale code (e.g., en-US, en-GB) | Default market locale code (e.g., en-US, en-GB) | 47 |
| 22 | `price_type_name` | Descriptive name of the price type, such as Standard Price, Costco, Employee Discount, etc | Descriptive name of the price type, such as Standard Price, Costco, Employee Discount, etc | Descriptive name of the price type, such as Standard Price, Costco, Employee Discount, etc | 90 |
| 23 | `trxn_currency_code` | @PrimaryKey ISO 4217 currency code for the transaction currency | @PrimaryKey ISO 4217 currency code for the transaction currency | @PrimaryKey ISO 4217 currency code for the transaction currency | 63 |
| 24 | `usd_conversion_rate` | Exchange rate used to convert transaction currency to US dollars | Exchange rate used to convert transaction currency to US dollars | Exchange rate used to convert transaction currency to US dollars | 64 |
| 25 | `list_price_trxn_amt` | List price of the product in transaction currency | List price of the product in transaction currency | List price of the product in transaction currency | 49 |
| 26 | `list_price_usd_amt` | List price of the product converted to US dollars | List price of the product converted to US dollars | List price of the product converted to US dollars | 49 |
| 27 | `sale_price_trxn_amt` | Promotional or discounted sale price in transaction currency | Promotional or discounted sale price in transaction currency | Promotional or discounted sale price in transaction currency | 60 |
| 28 | `sale_price_usd_amt` | Promotional or discounted sale price converted to US dollars | Promotional or discounted sale price converted to US dollars | Promotional or discounted sale price converted to US dollars | 60 |
| 29 | `sale_start_mst_date` | Start date of the sale period (MST) | Start date of the sale period (MST) | Start date of the sale period (MST) | 35 |
| 30 | `sale_end_mst_date` | End date of the sale period (MST) | End date of the sale period (MST) | End date of the sale period (MST) | 33 |
| 31 | `cost_usd_amt` | Cost of the product in US dollars | Cost of the product in US dollars | Cost of the product in US dollars | 33 |
| 32 | `list_price_change_flag` | Indicates whether the list price changed compared to the prior period (true/false) | Indicates whether the list price changed compared to the prior period (true/false) | Indicates whether the list price changed compared to the prior period (true/false) | 82 |
| 33 | `sale_price_change_flag` | Indicates whether the sale price changed compared to the prior period (true/false) | Indicates whether the sale price changed compared to the prior period (true/false) | Indicates whether the sale price changed compared to the prior period (true/false) | 82 |
| 34 | `cost_change_flag` | Indicates whether the cost changed compared to the prior period (true/false) | Indicates whether the cost changed compared to the prior period (true/false) | Indicates whether the cost changed compared to the prior period (true/false) | 76 |
| 35 | `etl_build_mst_ts` | Timestamp when the ETL process created or last updated this record (MST) | Timestamp when the ETL process created or last updated this record (MST) | Timestamp when the ETL process created or last updated this record (MST) | 72 |
