-- ============================================================================
-- Finance DE Demo :: Governance (4/4) - data quality metric functions (DMFs)
-- System DMFs + one custom business DMF on the gold products. Results are written
-- to SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS on the schedule; the custom
-- DMF is also invoked inline for immediate demo output.
-- Run with: snow sql -c default -f sql/governance/30_dmfs.sql
-- ============================================================================
USE ROLE ACCOUNTADMIN;
USE DATABASE FINANCE_DE_DEMO;
USE SCHEMA GOVERNANCE;

-- Custom business-rule DMF: investors with negative AUM (should be zero)
CREATE OR REPLACE DATA METRIC FUNCTION FINANCE_DE_DEMO.GOVERNANCE.NEGATIVE_AUM_COUNT(
    t TABLE(assets_under_management NUMBER)
) RETURNS NUMBER
AS
$$
    SELECT COUNT(*) FROM t WHERE assets_under_management < 0
$$;

-- Schedule metric evaluation on the gold tables
ALTER ICEBERG TABLE FINANCE_DE_DEMO.MARTS.INVESTOR_360   SET DATA_METRIC_SCHEDULE = '60 MINUTE';
ALTER ICEBERG TABLE FINANCE_DE_DEMO.MARTS.PORTFOLIO_RISK SET DATA_METRIC_SCHEDULE = '60 MINUTE';

-- INVESTOR_360: uniqueness + completeness + freshness + custom rule
ALTER ICEBERG TABLE FINANCE_DE_DEMO.MARTS.INVESTOR_360 ADD DATA METRIC FUNCTION
    SNOWFLAKE.CORE.DUPLICATE_COUNT ON (INVESTOR_ID);
ALTER ICEBERG TABLE FINANCE_DE_DEMO.MARTS.INVESTOR_360 ADD DATA METRIC FUNCTION
    SNOWFLAKE.CORE.NULL_COUNT ON (EMAIL);
ALTER ICEBERG TABLE FINANCE_DE_DEMO.MARTS.INVESTOR_360 ADD DATA METRIC FUNCTION
    FINANCE_DE_DEMO.GOVERNANCE.NEGATIVE_AUM_COUNT ON (ASSETS_UNDER_MANAGEMENT);

-- PORTFOLIO_RISK: row volume + completeness of the join key
ALTER ICEBERG TABLE FINANCE_DE_DEMO.MARTS.PORTFOLIO_RISK ADD DATA METRIC FUNCTION
    SNOWFLAKE.CORE.ROW_COUNT ON ();
ALTER ICEBERG TABLE FINANCE_DE_DEMO.MARTS.PORTFOLIO_RISK ADD DATA METRIC FUNCTION
    SNOWFLAKE.CORE.NULL_COUNT ON (SYMBOL);

-- Immediate results (no need to wait for the schedule)
SELECT 'negative_aum'  AS metric, FINANCE_DE_DEMO.GOVERNANCE.NEGATIVE_AUM_COUNT(
          SELECT assets_under_management FROM FINANCE_DE_DEMO.MARTS.INVESTOR_360) AS value
UNION ALL
SELECT 'dup_investor_id', SNOWFLAKE.CORE.DUPLICATE_COUNT(
          SELECT investor_id FROM FINANCE_DE_DEMO.MARTS.INVESTOR_360)
UNION ALL
SELECT 'null_email', SNOWFLAKE.CORE.NULL_COUNT(
          SELECT email FROM FINANCE_DE_DEMO.MARTS.INVESTOR_360);
