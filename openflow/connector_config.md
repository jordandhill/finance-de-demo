# Openflow — PostgreSQL CDC Connector configuration (the bank)

Config-as-code reference for the Openflow **PostgreSQL** connector that replicates the
three financial sources into Snowflake `FINANCE_DE_DEMO.RAW`.

> The Openflow *runtime* is provisioned once via the Snowflake Control Plane UI
> (Data > Openflow). It cannot be created via SQL/CLI. Once the runtime exists,
> import the connector below and set these parameters.

## Snowflake side prerequisites

Run `sql/setup/00_environment.sql` first, then the EAI below so the runtime can
reach the source database.

```sql
-- External Access Integration for the source Postgres endpoint
CREATE NETWORK RULE IF NOT EXISTS FINANCE_DE_DEMO.PUBLIC.PG_SOURCE_RULE
    MODE = EGRESS
    TYPE = HOST_PORT
    VALUE_LIST = ('<pg-host>:5432');

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION FINANCE_PG_EAI
    ALLOWED_NETWORK_RULES = (FINANCE_DE_DEMO.PUBLIC.PG_SOURCE_RULE)
    ENABLED = TRUE;

GRANT USAGE ON INTEGRATION FINANCE_PG_EAI TO ROLE OPENFLOW_RUNTIME_ROLE;
```

## Connector parameters

| Parameter | Value |
|-----------|-------|
| Connector type | PostgreSQL (CDC / logical replication) |
| Source host:port | `<pg-host>:5432` |
| Database | `finance_de_demo` |
| Publication | `finance_cdc_pub` |
| Replication slot | `finance_slot` |
| Included tables (regex) | `(core_banking\.transactions|customer_crm\.customers|market_ref\.instrument_prices)` |
| Destination database | `FINANCE_DE_DEMO` |
| Destination schema | `RAW` |
| Destination table strategy | one table per source table |
| Snowflake auth | `SNOWFLAKE_MANAGED` (SPCS runtime) |
| External Access Integration | `FINANCE_PG_EAI` |

## Landing tables produced (Bronze)

| Source table | Lands as |
|--------------|----------|
| `customer_crm.customers` | `FINANCE_DE_DEMO.RAW.CUSTOMERS` |
| `market_ref.instrument_prices` | `FINANCE_DE_DEMO.RAW.INSTRUMENT_PRICES` |
| `core_banking.transactions` | `FINANCE_DE_DEMO.RAW.TRANSACTIONS` |

Each landed row also carries CDC metadata columns from the connector
(`_snowflake_inserted_at`, `_snowflake_deleted`, operation type). The dbt
staging layer reads these tables directly.

## Demo note

For environments without a provisioned Openflow runtime, `sql/setup/10_raw_landing.sql`
creates the identical RAW landing tables and loads representative data so the
downstream dbt -> Iceberg -> semantic-view -> lineage flow runs live. Swap in the
live connector above when a runtime is available; the RAW contract is identical.
