# Apollo Bank — CoCo Data Engineering Demo Runbook

A live, narrated walkthrough of building an end-to-end financial data pipeline on
Snowflake using **Cortex Code (CoCo)**: Openflow CDC ingestion -> dbt transformations ->
Snowflake-managed Iceberg gold table -> semantic view + lineage for AI, all under
GitHub CI/CD and Snowflake Git version control.

**Target account:** `SFSENORTHAMERICA-DEMO_JHILL` (connection `default`)
**Database:** `APOLLO_FIN`  |  **Warehouse:** `APOLLO_WH`  |  **Repo:** https://github.com/jordandhill/apollo-fin-de-demo

---

## The story (2-minute pitch)

Apollo Bank wants a governed **Customer 360 / relationship-value** view for AI. Three
operational systems feed it — core banking, CRM, and market data. We show a data
engineer building the whole pipeline conversationally with CoCo, landing open Iceberg
data, and exposing it to Cortex Analyst with full lineage — version-controlled with CI/CD.

## Architecture

```
Core banking (Postgres)  ┐
Customer CRM (Postgres)  ├─ Openflow CDC ─> APOLLO_FIN.RAW (Bronze)
Market / reference data  ┘                       │
                                    dbt (Snowflake-native) STAGING (Silver, views)
                                                 │
                          APOLLO_FIN.MARTS.CUSTOMER_360  (Gold, Snowflake-managed Iceberg)
                                                 │
                      Semantic View  +  Horizon column/table lineage
                                                 │
                                Cortex Analyst / Snowflake Intelligence
```

---

## Demo flow and the exact CoCo prompts to type

Each step below is driven by a natural-language prompt to CoCo. Speak the business
goal, let CoCo build, then show the result in Snowsight.

### 0. Set the stage
- In CoCo, confirm the active connection is **`default`** (DEMO_JHILL). Everything lands there.

### 1. Environment + Iceberg storage
> **Prompt:** "Set up the APOLLO_FIN database with RAW, STAGING, MARTS and SEMANTIC
> schemas and an XSMALL warehouse APOLLO_WH, and verify the MY_EXTERNAL_VOL external
> volume so we can build Iceberg tables."

Show: `sql/setup/00_environment.sql`; the external-volume verify returns all PASSED.

### 2. Version control
> **Prompt:** "Create a GitHub repo for this project and register it as a Snowflake
> GIT REPOSITORY object so we can browse and deploy from Snowflake."

Show: the repo, and `SHOW GIT BRANCHES IN APOLLO_FIN.PUBLIC.APOLLO_REPO`.

### 3. Openflow CDC ingestion (3 sources)
> **Prompt:** "Build an Openflow PostgreSQL CDC pipeline that lands core banking
> transactions, customer CRM, and market reference data into APOLLO_FIN.RAW. Generate
> the source schema, the connector configuration, and the external access integration."

Show: `openflow/postgres_sample_data.sql`, `openflow/connector_config.md`.
Talk track: the runtime is provisioned once in the Control Plane; the connector config
is config-as-code in git. For this environment we land representative CDC data via
`sql/setup/10_raw_landing.sql` so the rest runs live.

Verify:
```sql
SELECT 'CUSTOMERS' t, COUNT(*) FROM APOLLO_FIN.RAW.CUSTOMERS
UNION ALL SELECT 'INSTRUMENT_PRICES', COUNT(*) FROM APOLLO_FIN.RAW.INSTRUMENT_PRICES
UNION ALL SELECT 'TRANSACTIONS', COUNT(*) FROM APOLLO_FIN.RAW.TRANSACTIONS;
```

### 4. dbt transformations (Bronze -> Silver -> Gold), all on Snowflake
> **Prompt:** "Create a dbt project with Silver staging models over RAW and a Gold
> CUSTOMER_360 model that joins customers, their transactions, and market prices into a
> single relationship-value table. Add tests. Deploy and run it natively on Snowflake."

Show: `dbt/apollo_fin/models/**`; then run natively:
```bash
snow dbt deploy apollo_fin --source dbt/apollo_fin --database APOLLO_FIN --schema PUBLIC -c default
snow dbt execute -c default --database APOLLO_FIN --schema PUBLIC apollo_fin build
```
Talk track: 19 nodes, 15 tests, runs on Snowflake compute — no external orchestrator.

### 5. Gold as Snowflake-managed Iceberg
> **Prompt:** "Materialize the Gold CUSTOMER_360 model as a Snowflake-managed Iceberg
> table on MY_EXTERNAL_VOL."

Show: the model config (`table_format='iceberg'`), then:
```sql
SHOW ICEBERG TABLES IN SCHEMA APOLLO_FIN.MARTS;   -- catalog=SNOWFLAKE, type=MANAGED
SELECT segment, COUNT(*), ROUND(SUM(total_relationship_value)) book_value
FROM APOLLO_FIN.MARTS.CUSTOMER_360 GROUP BY 1 ORDER BY 3 DESC;
```

### 6. Semantic view + lineage for AI
> **Prompt:** "Create a semantic view over CUSTOMER_360 with dimensions for segment,
> risk rating and country and metrics for customer count, total relationship value and
> holdings value. Then show me the lineage from the gold table back to the raw sources."

Show:
```sql
-- Ask a business question through the semantic layer
SELECT * FROM SEMANTIC_VIEW(
  APOLLO_FIN.SEMANTIC.CUSTOMER_360_SV
  DIMENSIONS customers.segment
  METRICS customers.customer_count, customers.total_book_value
) ORDER BY total_book_value DESC;

-- Lineage: gold Iceberg table back to the 3 raw sources
SELECT source_object_name, target_object_name, distance
FROM TABLE(SNOWFLAKE.CORE.GET_LINEAGE('APOLLO_FIN.MARTS.CUSTOMER_360','TABLE','UPSTREAM',3))
ORDER BY distance;
```
Talk track: point Cortex Analyst / Snowflake Intelligence at `CUSTOMER_360_SV` for NL Q&A.

### 7. CI/CD + version control
> **Prompt:** "Add a GitHub Actions workflow that deploys and builds the dbt project on
> every PR and deploys the semantic view when we merge to main."

Show: `.github/workflows/apollo-fin-cicd.yml`. Open a PR to trigger the build/test gate.

---

## Reset / rebuild
```bash
snow sql -c default -f sql/setup/00_environment.sql
snow sql -c default -f sql/setup/10_raw_landing.sql
snow dbt deploy apollo_fin --source dbt/apollo_fin --database APOLLO_FIN --schema PUBLIC -c default
snow dbt execute -c default --database APOLLO_FIN --schema PUBLIC apollo_fin build
snow sql -c default -f sql/semantic/customer_360_semantic_view.sql
```

## Talking points by persona
- **Data engineer:** conversational build, native dbt on Snowflake, tests + CI/CD, git.
- **Architect:** open Iceberg format on your own S3, one governed copy, lineage in Horizon.
- **AI / analytics lead:** semantic view -> Cortex Analyst NL Q&A over governed gold data.

## CI/CD secrets to configure (repo settings)
`SNOWFLAKE_ACCOUNT`, `SNOWFLAKE_USER`, `SNOWFLAKE_PRIVATE_KEY` (PEM contents for key-pair auth).
