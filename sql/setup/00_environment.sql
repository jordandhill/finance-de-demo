-- ============================================================================
-- the bank DE Demo :: Environment setup
-- Target account: SFSENORTHAMERICA-DEMO_JHILL  (connection: default)
-- Run with: snow sql -c default -f sql/setup/00_environment.sql
-- ============================================================================
USE ROLE ACCOUNTADMIN;

CREATE DATABASE IF NOT EXISTS FINANCE_DE_DEMO
  COMMENT = 'the bank financial DE demo: Openflow CDC -> dbt -> Iceberg gold -> semantic view + lineage for AI';

CREATE SCHEMA IF NOT EXISTS FINANCE_DE_DEMO.RAW      COMMENT = 'Bronze: raw CDC landing from Openflow (3 financial sources)';
CREATE SCHEMA IF NOT EXISTS FINANCE_DE_DEMO.STAGING  COMMENT = 'Silver: dbt cleansed & conformed models';
CREATE SCHEMA IF NOT EXISTS FINANCE_DE_DEMO.MARTS    COMMENT = 'Gold: business marts incl. INVESTOR_360 / PORTFOLIO_RISK (Iceberg)';
CREATE SCHEMA IF NOT EXISTS FINANCE_DE_DEMO.SEMANTIC COMMENT = 'Semantic views for Cortex Analyst / AI';

CREATE WAREHOUSE IF NOT EXISTS FINANCE_DE_DEMO_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'the bank DE demo warehouse (dbt + queries)';

-- Iceberg storage. Reuses the existing, pre-verified external volume on this account.
-- s3://jh-iceberg/tt (us-east-1). Verify before first Iceberg DDL:
SELECT SYSTEM$VERIFY_EXTERNAL_VOLUME('MY_EXTERNAL_VOL');
