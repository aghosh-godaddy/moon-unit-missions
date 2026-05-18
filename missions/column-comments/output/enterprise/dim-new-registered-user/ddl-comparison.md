# Column Comments Comparison: enterprise.dim-new-registered-user

Generated: 2026-05-18T14:33

| # | Column | Original | Enriched | Validated | Len |
|---|--------|----------|----------|-----------|-----|
| 1 | `bill_shopper_id` | — | @PrimaryKey Unique shopper account identifier at time of New Registered User (NRU) event; one row per shopper. For merged shoppers, reflects pre-merge state at event time. Source: enterprise.fact_bill_line. | @PrimaryKey Unique shopper account identifier at time of New Registered User (NRU) event; one row per shopper. For merged shoppers, reflects pre-merge state at event time. Source: enterprise.fact_bill_line. | 206 |
| 2 | `new_registered_user_bill_id` | — | Bill identifier for the qualifying New Registered User (NRU) order. First free order (fair market value=$0) before any paid order. Excludes refunds, chargebacks, and Domain Change-of-Ownership (pf_id IN 112, 260112, 912, 260912). | Bill identifier for the qualifying New Registered User (NRU) order. First free order (fair market value=$0) before any paid order. Excludes refunds, chargebacks, and Domain Change-of-Ownership (pf_id IN 112, 260112, 912, 260912). | 229 |
| 3 | `new_registered_user_bill_mst_date` | — | Calendar date of the qualifying New Registered User (NRU) order in Mountain Standard Time (MST). Source: enterprise.fact_bill_line. | Calendar date of the qualifying New Registered User (NRU) order in Mountain Standard Time (MST). Source: enterprise.fact_bill_line. | 131 |
| 4 | `new_registered_user_bill_mst_ts` | — | Timestamp of the qualifying New Registered User (NRU) order in Mountain Standard Time (MST). Source: enterprise.fact_bill_line. | Timestamp of the qualifying New Registered User (NRU) order in Mountain Standard Time (MST). Source: enterprise.fact_bill_line. | 127 |
