-- ============================================================================
-- Finance DE Demo :: Governance (1/3) - schema + demo consumer role
-- Creates a low-privilege analyst role to demonstrate dynamic masking
-- (analyst sees masked PII; ACCOUNTADMIN / PII reader sees clear text).
-- Run with: snow sql -c default -f sql/governance/00_role.sql
-- ============================================================================
USE ROLE ACCOUNTADMIN;

CREATE SCHEMA IF NOT EXISTS FINANCE_DE_DEMO.GOVERNANCE
  COMMENT = 'Tags, masking policies and data metric functions for the demo';

-- Demo consumer role: can read the marts but is NOT a PII reader
CREATE ROLE IF NOT EXISTS FINANCE_ANALYST_RL
  COMMENT = 'Demo analyst - sees masked PII in the gold layer';

GRANT USAGE ON DATABASE FINANCE_DE_DEMO TO ROLE FINANCE_ANALYST_RL;
GRANT USAGE ON SCHEMA FINANCE_DE_DEMO.MARTS TO ROLE FINANCE_ANALYST_RL;
GRANT USAGE ON SCHEMA FINANCE_DE_DEMO.SEMANTIC TO ROLE FINANCE_ANALYST_RL;
GRANT SELECT ON ALL TABLES IN SCHEMA FINANCE_DE_DEMO.MARTS TO ROLE FINANCE_ANALYST_RL;
GRANT SELECT ON FUTURE TABLES IN SCHEMA FINANCE_DE_DEMO.MARTS TO ROLE FINANCE_ANALYST_RL;
GRANT USAGE ON WAREHOUSE FINANCE_DE_DEMO_WH TO ROLE FINANCE_ANALYST_RL;

-- Let the current user assume the analyst role for the demo
GRANT ROLE FINANCE_ANALYST_RL TO USER JHILL;
