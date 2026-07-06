# Governance — classification, masking, and data quality

The governance layer is built with Cortex Code from intent and demonstrates AI/auto
governance on the asset-manager data. It is a **one-time bootstrap** (policies become
attached objects, so the scripts are not re-runnable in place — see note at the end).

Objects live in `FINANCE_DE_DEMO.GOVERNANCE`. Deploy order:

```bash
snow sql -c default -f sql/governance/00_role.sql          # demo analyst role
snow sql -c default -f sql/governance/10_classify.sql      # auto PII classification + tags
snow sql -c default -f sql/governance/20_masking_policies.sql  # tag-based dynamic masking
snow sql -c default -f sql/governance/30_dmfs.sql          # data-quality metric functions
```

## 1. Classification (auto PII tagging)
`EXTRACT_SEMANTIC_CATEGORIES` + `ASSOCIATE_SEMANTIC_CATEGORY_TAGS` auto-detect and tag PII
on the relational source (EMAIL -> IDENTIFIER, COUNTRY -> QUASI_IDENTIFIER). Name columns
and the Iceberg gold columns are tagged explicitly (`ALTER ICEBERG TABLE ... SET TAG`).

```sql
SELECT SYSTEM$GET_TAG('SNOWFLAKE.CORE.PRIVACY_CATEGORY',
       'FINANCE_DE_DEMO.MARTS.INVESTOR_360.EMAIL','COLUMN');   -- IDENTIFIER
```

## 2. Tag-based dynamic masking
A single policy `GOVERNANCE.PII_MASK` is attached to a scoped custom tag `GOVERNANCE.PII`.
The policy branches on the classified semantic category (email keeps its domain; other PII
becomes `****MASKED****`). Privileged roles see clear text.

Demo the difference:
```sql
-- clear (privileged)
USE ROLE ACCOUNTADMIN;
SELECT investor_id, first_name, email FROM FINANCE_DE_DEMO.MARTS.INVESTOR_360 LIMIT 3;

-- masked (analyst)
USE ROLE FINANCE_ANALYST_RL;
SELECT investor_id, first_name, email FROM FINANCE_DE_DEMO.MARTS.INVESTOR_360 LIMIT 3;
```
| Role | FIRST_NAME | EMAIL |
|------|-----------|-------|
| ACCOUNTADMIN | First373 | cust373@apollobank.com |
| FINANCE_ANALYST_RL | ****MASKED**** | ****@apollobank.com |

**Talk-track nuance:** dynamic masking is enforced at **Snowflake query time**. An external
engine reading the raw Iceberg Parquet bypasses it — which is exactly why open-format
governance needs Snowflake Open Catalog / external catalog policies. Governance and the
open-format story intersect here.

## 3. Data quality (DMFs)
System DMFs (`DUPLICATE_COUNT`, `NULL_COUNT`, `ROW_COUNT`) plus a custom business DMF
`GOVERNANCE.NEGATIVE_AUM_COUNT` are attached to the gold tables on a 60-minute schedule.
Immediate results:

```sql
SELECT 'negative_aum' metric, FINANCE_DE_DEMO.GOVERNANCE.NEGATIVE_AUM_COUNT(
  SELECT assets_under_management FROM FINANCE_DE_DEMO.MARTS.INVESTOR_360) value
UNION ALL SELECT 'dup_investor_id', SNOWFLAKE.CORE.DUPLICATE_COUNT(
  SELECT investor_id FROM FINANCE_DE_DEMO.MARTS.INVESTOR_360)
UNION ALL SELECT 'null_email', SNOWFLAKE.CORE.NULL_COUNT(
  SELECT email FROM FINANCE_DE_DEMO.MARTS.INVESTOR_360);
```
Reference result: `negative_aum = 426` (investors whose cash + holdings is negative — a real
data-quality/business signal to investigate), `dup_investor_id = 0`, `null_email = 0`.
Scheduled results accumulate in `SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS`.

## 4. Lineage (Horizon)
`sql/lineage/lineage_checks.sql` traces both gold products back to all raw sources
(structured + the unstructured transcripts) and shows downstream impact from
`RAW.CUSTOMERS` through the marts to the semantic views. Column-level lineage is available
in the Snowsight lineage graph.

## Re-run / teardown note
Because masking policies attach to a tag and DMFs attach to columns, the scripts are a
one-time bootstrap:
- `CREATE OR REPLACE MASKING POLICY` fails while the policy is attached — `UNSET` it first.
- `ADD DATA METRIC FUNCTION` errors if the metric is already attached — `DROP` it first.
To reset: `ALTER TAG GOVERNANCE.PII UNSET MASKING POLICY`, drop/re-add DMFs, then re-run.
This is why governance is deployed as a bootstrap step and not in per-merge CI.
