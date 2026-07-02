-- ============================================================================
-- Apollo Bank DE Demo :: Environment setup
-- Target account: SFSENORTHAMERICA-DEMO_JHILL  (connection: default)
-- Run with: snow sql -c default -f sql/setup/00_environment.sql
-- ============================================================================
USE ROLE ACCOUNTADMIN;

CREATE DATABASE IF NOT EXISTS APOLLO_FIN
  COMMENT = 'Apollo Bank financial DE demo: Openflow CDC -> dbt -> Iceberg gold -> semantic view + lineage for AI';

CREATE SCHEMA IF NOT EXISTS APOLLO_FIN.RAW      COMMENT = 'Bronze: raw CDC landing from Openflow (3 financial sources)';
CREATE SCHEMA IF NOT EXISTS APOLLO_FIN.STAGING  COMMENT = 'Silver: dbt cleansed & conformed models';
CREATE SCHEMA IF NOT EXISTS APOLLO_FIN.MARTS    COMMENT = 'Gold: business marts incl. CUSTOMER_360 (Iceberg)';
CREATE SCHEMA IF NOT EXISTS APOLLO_FIN.SEMANTIC COMMENT = 'Semantic views for Cortex Analyst / AI';

CREATE WAREHOUSE IF NOT EXISTS APOLLO_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'Apollo Bank DE demo warehouse (dbt + queries)';

-- Iceberg storage. Reuses the existing, pre-verified external volume on this account.
-- s3://jh-iceberg/tt (us-east-1). Verify before first Iceberg DDL:
SELECT SYSTEM$VERIFY_EXTERNAL_VOLUME('MY_EXTERNAL_VOL');
