-- ============================================================================
-- Finance DE Demo :: Semantic view over the Gold Iceberg table (Cortex Analyst / AI)
-- Investor 360 / AUM for an asset manager.
-- Run with: snow sql -c default -f sql/semantic/investor_360_semantic_view.sql
-- ============================================================================
USE ROLE ACCOUNTADMIN;
USE DATABASE FINANCE_DE_DEMO;
USE SCHEMA SEMANTIC;

CREATE OR REPLACE SEMANTIC VIEW FINANCE_DE_DEMO.SEMANTIC.INVESTOR_360_SV

  TABLES (
    investors AS FINANCE_DE_DEMO.MARTS.INVESTOR_360
      PRIMARY KEY (investor_id)
      WITH SYNONYMS ('clients', 'accounts', 'client book')
      COMMENT = 'Investor 360 - one row per client with profile, cash flows, holdings and total AUM'
  )

  FACTS (
    investors.aum AS assets_under_management
      COMMENT = 'Cash balance plus market value of holdings',
    investors.holdings AS holdings_value
      COMMENT = 'Net trade positions valued at latest instrument price',
    investors.cash AS cash_balance
      COMMENT = 'Most recent cash balance',
    investors.subscriptions AS total_subscriptions,
    investors.redemptions AS total_redemptions,
    investors.fees AS total_fees,
    investors.activity AS activity_count,
    investors.instruments AS instruments_held
  )

  DIMENSIONS (
    investors.investor_id AS investor_id
      COMMENT = 'Unique investor / client identifier',
    investors.investor_segment AS investor_segment
      WITH SYNONYMS ('client segment', 'investor type', 'mandate type')
      COMMENT = 'INSTITUTIONAL, PENSION, ENDOWMENT, HNW or WEALTH',
    investors.risk_rating AS risk_rating
      WITH SYNONYMS ('risk', 'risk level'),
    investors.kyc_status AS kyc_status
      WITH SYNONYMS ('kyc', 'know your customer status'),
    investors.country AS country
      WITH SYNONYMS ('country code', 'domicile'),
    investors.tenure_days AS tenure_days
      COMMENT = 'Days since onboarding'
  )

  METRICS (
    investors.investor_count AS COUNT(investors.investor_id)
      WITH SYNONYMS ('number of investors', 'number of clients', 'how many clients')
      COMMENT = 'Count of investors',
    investors.total_aum AS SUM(investors.aum)
      WITH SYNONYMS ('assets under management', 'total AUM', 'book value')
      COMMENT = 'Total assets under management across investors',
    investors.avg_aum AS AVG(investors.aum)
      COMMENT = 'Average AUM per investor',
    investors.total_holdings_value AS SUM(investors.holdings)
      COMMENT = 'Total market value of holdings',
    investors.total_cash AS SUM(investors.cash)
      COMMENT = 'Total cash balances',
    investors.total_net_flows AS SUM(investors.subscriptions) - SUM(investors.redemptions)
      WITH SYNONYMS ('net flows', 'net new money')
      COMMENT = 'Subscriptions minus redemptions'
  )

  COMMENT = 'Investor 360 semantic view for an asset manager - powers Cortex Analyst / Snowflake Intelligence over the Iceberg gold table';
