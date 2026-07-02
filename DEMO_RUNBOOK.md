# Finance DE Demo — Build Runbook

Internal runbook for building/resetting the demo and the exact **Cortex Code (CoCo)**
prompts used at each stage. For the customer-facing narrative, see `CUSTOMER_WALKTHROUGH.md`.

**Target account:** `SFSENORTHAMERICA-DEMO_JHILL` (connection `default`)
**Database:** `FINANCE_DE_DEMO`  |  **Warehouse:** `FINANCE_DE_DEMO_WH`  |  **Repo:** https://github.com/jordandhill/finance-de-demo

---

## Architecture

```
Core banking (Postgres)  ┐
Customer CRM (Postgres)  ├─ Openflow CDC ─> FINANCE_DE_DEMO.RAW (Bronze)
Market / reference data  ┘                       │
                                    dbt (Snowflake-native) STAGING (Silver, views)
                                                 │
                       FINANCE_DE_DEMO.MARTS.CUSTOMER_360  (Gold, managed Iceberg)
                                                 │
                          Semantic View  +  Horizon column/table lineage
                                                 │
                                Cortex Analyst / Snowflake Intelligence
```

## The CoCo prompts used to build each stage

### 1. Environment + Iceberg storage
> "Set up the FINANCE_DE_DEMO database with RAW, STAGING, MARTS and SEMANTIC schemas
> and an XSMALL warehouse, and verify the MY_EXTERNAL_VOL external volume so we can
> build Iceberg tables."

### 2. Version control
> "Create a GitHub repo for this project and register it as a Snowflake GIT REPOSITORY
> object so we can browse and deploy from Snowflake."

### 3. Openflow CDC ingestion (3 sources)
> "Build an Openflow PostgreSQL CDC pipeline that lands core banking transactions,
> customer CRM, and market reference data into FINANCE_DE_DEMO.RAW. Generate the source
> schema, the connector configuration, and the external access integration."

### 4. dbt transformations (Bronze -> Silver -> Gold), all on Snowflake
> "Create a dbt project with Silver staging models over RAW and a Gold CUSTOMER_360
> model that joins customers, their transactions, and market prices into a single
> relationship-value table. Add tests. Deploy and run it natively on Snowflake."

### 5. Gold as Snowflake-managed Iceberg
> "Materialize the Gold CUSTOMER_360 model as a Snowflake-managed Iceberg table on
> MY_EXTERNAL_VOL."

### 6. Semantic view + lineage for AI
> "Create a semantic view over CUSTOMER_360 with dimensions for segment, risk rating
> and country and metrics for customer count, total relationship value and holdings
> value. Then show me the lineage from the gold table back to the raw sources."

### 7. CI/CD + version control
> "Add a GitHub Actions workflow that deploys and builds the dbt project on every PR
> and deploys the semantic view when we merge to main."

---

## Build / reset from scratch
```bash
snow sql -c default -f sql/setup/00_environment.sql
snow sql -c default -f sql/setup/10_raw_landing.sql
snow dbt deploy finance_de_demo --source dbt/finance_de_demo --database FINANCE_DE_DEMO --schema PUBLIC -c default
snow dbt execute -c default --database FINANCE_DE_DEMO --schema PUBLIC finance_de_demo build
snow sql -c default -f sql/semantic/customer_360_semantic_view.sql
```

## Verification queries
```sql
-- Bronze row counts (3 sources)
SELECT 'CUSTOMERS' t, COUNT(*) FROM FINANCE_DE_DEMO.RAW.CUSTOMERS
UNION ALL SELECT 'INSTRUMENT_PRICES', COUNT(*) FROM FINANCE_DE_DEMO.RAW.INSTRUMENT_PRICES
UNION ALL SELECT 'TRANSACTIONS', COUNT(*) FROM FINANCE_DE_DEMO.RAW.TRANSACTIONS;

-- Gold is Snowflake-managed Iceberg
SHOW ICEBERG TABLES IN SCHEMA FINANCE_DE_DEMO.MARTS;

-- Ask a business question through the semantic layer
SELECT * FROM SEMANTIC_VIEW(
  FINANCE_DE_DEMO.SEMANTIC.CUSTOMER_360_SV
  DIMENSIONS customers.segment
  METRICS customers.customer_count, customers.total_book_value
) ORDER BY total_book_value DESC;

-- Lineage: gold Iceberg table back to the 3 raw sources
SELECT source_object_name, target_object_name, distance
FROM TABLE(SNOWFLAKE.CORE.GET_LINEAGE('FINANCE_DE_DEMO.MARTS.CUSTOMER_360','TABLE','UPSTREAM',3))
ORDER BY distance;
```

## Openflow note
The Openflow runtime is provisioned once via the Snowflake Control Plane UI (not CLI/SQL).
The connector configuration lives as config-as-code in `openflow/`. In environments
without a provisioned runtime, `sql/setup/10_raw_landing.sql` loads representative CDC
data into RAW (identical contract) so the rest of the pipeline runs live.

## CI/CD secrets to configure (repo settings)
`SNOWFLAKE_ACCOUNT`, `SNOWFLAKE_USER`, `SNOWFLAKE_PRIVATE_KEY` (PEM contents for key-pair auth).
