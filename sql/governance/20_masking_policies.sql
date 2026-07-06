-- ============================================================================
-- Finance DE Demo :: Governance (3/4) - tag-based dynamic masking
-- One masking policy, attached to a custom GOVERNANCE.PII tag (scoped to our
-- columns so it does not affect other databases on a shared account). The policy
-- branches on the classified SNOWFLAKE.CORE.SEMANTIC_CATEGORY of the column.
-- Privileged roles (ACCOUNTADMIN) see clear text; everyone else (e.g. the demo
-- FINANCE_ANALYST_RL) sees masked values.
-- Run with: snow sql -c default -f sql/governance/20_masking_policies.sql
-- ============================================================================
USE ROLE ACCOUNTADMIN;
USE DATABASE FINANCE_DE_DEMO;
USE SCHEMA GOVERNANCE;

-- Trigger tag for tag-based masking (scoped: we only set it on our PII columns)
CREATE TAG IF NOT EXISTS FINANCE_DE_DEMO.GOVERNANCE.PII
  ALLOWED_VALUES 'Y'
  COMMENT = 'Presence triggers dynamic PII masking';

-- Single policy; branches on the column semantic category
CREATE OR REPLACE MASKING POLICY FINANCE_DE_DEMO.GOVERNANCE.PII_MASK
  AS (val STRING) RETURNS STRING ->
  CASE
    WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN') THEN val
    WHEN SYSTEM$GET_TAG_ON_CURRENT_COLUMN('SNOWFLAKE.CORE.SEMANTIC_CATEGORY') = 'EMAIL'
         THEN REGEXP_REPLACE(val, '^[^@]+', '****')      -- keep domain, mask local part
    ELSE '****MASKED****'
  END;

-- Tag-based masking: attach the policy to the tag
ALTER TAG FINANCE_DE_DEMO.GOVERNANCE.PII SET MASKING POLICY FINANCE_DE_DEMO.GOVERNANCE.PII_MASK;

-- Apply the trigger tag to PII columns on the Iceberg gold table (analyst query target)
ALTER ICEBERG TABLE FINANCE_DE_DEMO.MARTS.INVESTOR_360 MODIFY COLUMN EMAIL      SET TAG FINANCE_DE_DEMO.GOVERNANCE.PII = 'Y';
ALTER ICEBERG TABLE FINANCE_DE_DEMO.MARTS.INVESTOR_360 MODIFY COLUMN FIRST_NAME SET TAG FINANCE_DE_DEMO.GOVERNANCE.PII = 'Y';
ALTER ICEBERG TABLE FINANCE_DE_DEMO.MARTS.INVESTOR_360 MODIFY COLUMN LAST_NAME  SET TAG FINANCE_DE_DEMO.GOVERNANCE.PII = 'Y';

-- Also protect the relational source
ALTER TABLE FINANCE_DE_DEMO.RAW.CUSTOMERS MODIFY COLUMN EMAIL      SET TAG FINANCE_DE_DEMO.GOVERNANCE.PII = 'Y';
ALTER TABLE FINANCE_DE_DEMO.RAW.CUSTOMERS MODIFY COLUMN FIRST_NAME SET TAG FINANCE_DE_DEMO.GOVERNANCE.PII = 'Y';
ALTER TABLE FINANCE_DE_DEMO.RAW.CUSTOMERS MODIFY COLUMN LAST_NAME  SET TAG FINANCE_DE_DEMO.GOVERNANCE.PII = 'Y';
