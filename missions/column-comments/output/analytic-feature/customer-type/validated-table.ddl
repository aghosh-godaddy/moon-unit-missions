CREATE TABLE customer_type (
    shopper_id                        string    COMMENT '@PrimaryKey Unique identifier for the GoDaddy shopper; one record per shopper representing their current customer type classification.',
    evaluation_mst_date               date      COMMENT 'Date (MST) on which the shopper''s customer type was evaluated in the current classification run.',
    as_of_date                        date      COMMENT 'Business date for which this customer type snapshot is valid; the effective date of the classification.',
    first_order_country_code          string    COMMENT 'ISO country code of the shopper''s first-ever GoDaddy order; determines classification as US Independent or International Independent.',
    first_order_mst_date              date      COMMENT 'Date (MST) of the shopper''s first GoDaddy order; marks the acquisition date and anchors the customer type classification timeline.',
    partner_investor_start_mst_date   date      COMMENT 'Date (MST) when the shopper was first classified as a Partner or Investor; null for Independent-type shoppers.',
    customer_type_assignment_mst_date date      COMMENT 'Date (MST) when the current customer type classification was assigned to the shopper.',
    customer_type_name                string    COMMENT '@Enumerated(International Independent, US Independent, Partner, Investor) Shopper customer type classification; drives Gross Cash Receipts (GCR) Profit and Loss (PnL) pillar assignment.',
    customer_type_reason_desc         string    COMMENT 'Business rule or criterion that determined the customer type (e.g., 50+ active domains for Investor, Web Pro participation for Partner).',
    customer_independent_desc         string    COMMENT 'Customer type before reclassification as Partner or Investor (US Independent or International Independent); null for Independent-type shoppers.',
    customer_independent_reason_desc  string    COMMENT 'Reason the shopper was originally classified as Independent before becoming a Partner or Investor (e.g., US first order, International first order).',
    load_date                         date      COMMENT 'Date the record was processed and loaded by the ETL pipeline; used for data lineage and audit tracking.'
);
