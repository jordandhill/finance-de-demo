-- ============================================================================
-- Finance DE Demo :: Semantic view over the PORTFOLIO_RISK gold Iceberg table
-- Powers Cortex Analyst / Snowflake Intelligence over trades & risk data.
-- Run with: snow sql -c default -f sql/semantic/portfolio_risk_semantic_view.sql
-- ============================================================================
USE ROLE ACCOUNTADMIN;
USE DATABASE FINANCE_DE_DEMO;
USE SCHEMA SEMANTIC;

CREATE OR REPLACE SEMANTIC VIEW FINANCE_DE_DEMO.SEMANTIC.PORTFOLIO_RISK_SV

  TABLES (
    positions AS FINANCE_DE_DEMO.MARTS.PORTFOLIO_RISK
      PRIMARY KEY (customer_id, symbol)
      WITH SYNONYMS ('portfolio', 'holdings', 'book')
      COMMENT = 'Customer x instrument positions valued at market, with earnings sentiment'
  )

  FACTS (
    positions.market_value AS market_value
      COMMENT = 'Signed market value of the net position',
    positions.gross_exposure AS gross_exposure
      COMMENT = 'Absolute market value of the net position',
    positions.unrealized_pnl AS unrealized_pnl
      COMMENT = 'Market value minus net cost',
    positions.net_quantity AS net_quantity,
    positions.trades AS trade_count
  )

  DIMENSIONS (
    positions.customer_id AS customer_id,
    positions.symbol AS symbol
      WITH SYNONYMS ('instrument', 'ticker'),
    positions.asset_class AS asset_class
      WITH SYNONYMS ('asset type'),
    positions.segment AS segment
      WITH SYNONYMS ('customer segment'),
    positions.risk_rating AS risk_rating
      WITH SYNONYMS ('risk level'),
    positions.earnings_sentiment AS earnings_sentiment
      WITH SYNONYMS ('sentiment', 'earnings call sentiment')
      COMMENT = 'Latest earnings-call sentiment for the instrument: positive/negative/neutral/mixed'
  )

  METRICS (
    positions.position_count AS COUNT(positions.customer_id)
      WITH SYNONYMS ('number of positions')
      COMMENT = 'Count of customer-instrument positions',
    positions.total_market_value AS SUM(positions.market_value)
      COMMENT = 'Total signed market value',
    positions.total_gross_exposure AS SUM(positions.gross_exposure)
      WITH SYNONYMS ('total exposure', 'assets at risk')
      COMMENT = 'Total absolute exposure',
    positions.total_unrealized_pnl AS SUM(positions.unrealized_pnl)
      WITH SYNONYMS ('total pnl', 'unrealized gains')
      COMMENT = 'Total unrealized profit and loss',
    positions.total_trades AS SUM(positions.trade_count)
      COMMENT = 'Total trade executions behind the positions'
  )

  COMMENT = 'Portfolio risk semantic view for the bank - trades & risk positions with earnings sentiment for Cortex Analyst / AI';
