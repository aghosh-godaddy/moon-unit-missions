# Column Comments Comparison: enterprise.dim-new-acquisition-shopper

Generated: 2026-05-18T14:24

| # | Column | Original | Enriched | Validated | Len |
|---|--------|----------|----------|-----------|-----|
| 1 | `bill_shopper_id` | — | @PrimaryKey Unique shopper account identifier (original_shopper_id). Pre-2021-08-09 records reflect merged_shopper_id; 2021-08-09+ reflect original_shopper_id. Source: enterprise.fact_bill_line. | @PrimaryKey Unique shopper account identifier (original_shopper_id). Pre-2021-08-09 records reflect merged_shopper_id; 2021-08-09+ reflect original_shopper_id. Source: enterprise.fact_bill_line. | 194 |
| 2 | `new_acquisition_bill_id` | — | Bill identifier of the shopper\'s first qualifying paid order (New Customer Acquisition). Qualifies if Gross Cash Receipts (GCR) > $0 or domain change-of-ownership. Source: enterprise.fact_bill_line. | Bill identifier of the shopper\'s first qualifying paid order (New Customer Acquisition). Qualifies if Gross Cash Receipts (GCR) > $0 or domain change-of-ownership. Source: enterprise.fact_bill_line. | 199 |
| 3 | `bill_country_code` | — | ISO 3166-1 alpha-2 country code associated with the shopper\'s new acquisition billing transaction (e.g., US, CA). Sourced from enterprise.fact_bill_line. | ISO 3166-1 alpha-2 country code associated with the shopper\'s new acquisition billing transaction (e.g., US, CA). Sourced from enterprise.fact_bill_line. | 154 |
| 4 | `new_acquisition_bill_mst_date` | — | Date of the shopper\'s new acquisition order in Mountain Standard Time (MST). Sourced from enterprise.fact_bill_line. | Date of the shopper\'s new acquisition order in Mountain Standard Time (MST). Sourced from enterprise.fact_bill_line. | 117 |
| 5 | `new_acquisition_bill_mst_ts` | — | Timestamp of the shopper\'s new acquisition order in Mountain Standard Time (MST). Sourced from enterprise.fact_bill_line. | Timestamp of the shopper\'s new acquisition order in Mountain Standard Time (MST). Sourced from enterprise.fact_bill_line. | 122 |
