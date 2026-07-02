-- ============================================================================
-- Apollo Bank :: Semantic View over the Gold Iceberg table (for Cortex Analyst / AI)
-- Run with: snow sql -c default -f sql/semantic/customer_360_semantic_view.sql
-- ============================================================================
USE ROLE ACCOUNTADMIN;
USE DATABASE APOLLO_FIN;
USE SCHEMA SEMANTIC;

CREATE OR REPLACE SEMANTIC VIEW APOLLO_FIN.SEMANTIC.CUSTOMER_360_SV

  TABLES (
    customers AS APOLLO_FIN.MARTS.CUSTOMER_360
      PRIMARY KEY (customer_id)
      WITH SYNONYMS ('clients', 'accounts', 'customer base')
      COMMENT = 'Apollo Bank Customer 360 - one row per customer with profile, cash, holdings and total relationship value'
  )

  FACTS (
    customers.relationship_value AS total_relationship_value
      COMMENT = 'Current cash balance plus market value of holdings',
    customers.holdings AS holdings_value
      COMMENT = 'Net trade positions valued at latest instrument price',
    customers.cash AS current_cash_balance
      COMMENT = 'Most recent account balance',
    customers.deposits AS total_deposits,
    customers.withdrawals AS total_withdrawals,
    customers.fees AS total_fees,
    customers.txns AS txn_count,
    customers.instruments AS instruments_held
  )

  DIMENSIONS (
    customers.customer_id AS customer_id
      COMMENT = 'Unique customer identifier',
    customers.segment AS segment
      WITH SYNONYMS ('tier', 'customer segment', 'banking segment')
      COMMENT = 'RETAIL, PREMIER, PRIVATE or BUSINESS',
    customers.risk_rating AS risk_rating
      WITH SYNONYMS ('risk', 'risk level')
      COMMENT = 'LOW, MEDIUM or HIGH',
    customers.kyc_status AS kyc_status
      WITH SYNONYMS ('kyc', 'know your customer status'),
    customers.country AS country
      WITH SYNONYMS ('country code', 'domicile'),
    customers.tenure_days AS tenure_days
      COMMENT = 'Days since onboarding'
  )

  METRICS (
    customers.customer_count AS COUNT(customers.customer_id)
      WITH SYNONYMS ('number of customers', 'how many customers')
      COMMENT = 'Count of customers',
    customers.total_book_value AS SUM(customers.relationship_value)
      WITH SYNONYMS ('total relationship value', 'book value', 'assets under management')
      COMMENT = 'Total relationship value across customers',
    customers.avg_relationship_value AS AVG(customers.relationship_value)
      COMMENT = 'Average relationship value per customer',
    customers.total_holdings_value AS SUM(customers.holdings)
      COMMENT = 'Total market value of holdings',
    customers.total_cash AS SUM(customers.cash)
      COMMENT = 'Total cash balances',
    customers.total_deposits_amt AS SUM(customers.deposits)
      COMMENT = 'Total deposits'
  )

  COMMENT = 'Customer 360 semantic view for Apollo Bank - powers Cortex Analyst / Snowflake Intelligence over the Iceberg gold table';
