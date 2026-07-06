-- ============================================================================
-- Finance DE Demo :: Lineage checks (Horizon)
-- End-to-end object lineage from the gold Iceberg products back to the six RAW
-- sources (structured + unstructured), plus a downstream impact query.
-- Column-level lineage is viewable in the Snowsight lineage graph (Horizon).
-- Run with: snow sql -c default -f sql/lineage/lineage_checks.sql
-- ============================================================================
USE ROLE ACCOUNTADMIN;
USE DATABASE FINANCE_DE_DEMO;

-- Upstream: INVESTOR_360 (AUM) back to its raw sources
SELECT 'INVESTOR_360' AS product, source_object_domain, source_object_name, target_object_name, distance
FROM TABLE(SNOWFLAKE.CORE.GET_LINEAGE('FINANCE_DE_DEMO.MARTS.INVESTOR_360','TABLE','UPSTREAM',3))
ORDER BY distance, source_object_name;

-- Upstream: PORTFOLIO_RISK back to raw (includes the unstructured transcript source)
SELECT 'PORTFOLIO_RISK' AS product, source_object_domain, source_object_name, target_object_name, distance
FROM TABLE(SNOWFLAKE.CORE.GET_LINEAGE('FINANCE_DE_DEMO.MARTS.PORTFOLIO_RISK','TABLE','UPSTREAM',3))
ORDER BY distance, source_object_name;

-- Downstream impact: what depends on the raw customer source?
SELECT source_object_name, target_object_domain, target_object_name, distance
FROM TABLE(SNOWFLAKE.CORE.GET_LINEAGE('FINANCE_DE_DEMO.RAW.CUSTOMERS','TABLE','DOWNSTREAM',3))
ORDER BY distance, target_object_name;
