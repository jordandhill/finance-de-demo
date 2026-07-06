-- ============================================================================
-- Finance DE Demo :: Cortex Search service over parsed earnings transcripts
-- Enables natural-language / semantic search over unstructured transcript text
-- for Snowflake Intelligence / AI. Run with:
--   snow sql -c default -f sql/semantic/earnings_search.sql
-- ============================================================================
USE ROLE ACCOUNTADMIN;
USE DATABASE FINANCE_DE_DEMO;
USE SCHEMA SEMANTIC;

CREATE OR REPLACE CORTEX SEARCH SERVICE FINANCE_DE_DEMO.SEMANTIC.EARNINGS_SEARCH
  ON transcript_text
  ATTRIBUTES symbol, fiscal_period, sentiment
  WAREHOUSE = FINANCE_DE_DEMO_WH
  TARGET_LAG = '1 hour'
  AS
    SELECT
        parsed_text   AS transcript_text,
        symbol,
        fiscal_period,
        sentiment,
        summary
    FROM FINANCE_DE_DEMO.STAGING.STG_EARNINGS_TRANSCRIPTS;
