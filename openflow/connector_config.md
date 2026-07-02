# Openflow — PostgreSQL CDC Connector configuration (Apollo Bank)

Config-as-code reference for the Openflow **PostgreSQL** connector that replicates the
three financial sources into Snowflake `APOLLO_FIN.RAW`.

> The Openflow *runtime* is provisioned once via the Snowflake Control Plane UI
> (Data > Openflow). It cannot be created via SQL/CLI. Once the runtime exists,
> import the connector below and set these parameters.

## Snowflake side prerequisites

Run `sql/setup/00_environment.sql` first, then the EAI below so the runtime can
reach the source database.

```sql
-- External Access Integration for the source Postgres endpoint
CREATE NETWORK RULE IF NOT EXISTS APOLLO_FIN.PUBLIC.PG_SOURCE_RULE
    MODE = EGRESS
    TYPE = HOST_PORT
    VALUE_LIST = ('<pg-host>:5432');

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION APOLLO_PG_EAI
    ALLOWED_NETWORK_RULES = (APOLLO_FIN.PUBLIC.PG_SOURCE_RULE)
    ENABLED = TRUE;

GRANT USAGE ON INTEGRATION APOLLO_PG_EAI TO ROLE OPENFLOW_RUNTIME_ROLE;
```

## Connector parameters

| Parameter | Value |
|-----------|-------|
| Connector type | PostgreSQL (CDC / logical replication) |
| Source host:port | `<pg-host>:5432` |
| Database | `apollo` |
| Publication | `apollo_cdc_pub` |
| Replication slot | `apollo_slot` |
| Included tables (regex) | `(core_banking\.transactions|customer_crm\.customers|market_ref\.instrument_prices)` |
| Destination database | `APOLLO_FIN` |
| Destination schema | `RAW` |
| Destination table strategy | one table per source table |
| Snowflake auth | `SNOWFLAKE_MANAGED` (SPCS runtime) |
| External Access Integration | `APOLLO_PG_EAI` |

## Landing tables produced (Bronze)

| Source table | Lands as |
|--------------|----------|
| `customer_crm.customers` | `APOLLO_FIN.RAW.CUSTOMERS` |
| `market_ref.instrument_prices` | `APOLLO_FIN.RAW.INSTRUMENT_PRICES` |
| `core_banking.transactions` | `APOLLO_FIN.RAW.TRANSACTIONS` |

Each landed row also carries CDC metadata columns from the connector
(`_snowflake_inserted_at`, `_snowflake_deleted`, operation type). The dbt
staging layer reads these tables directly.

## Demo note

For environments without a provisioned Openflow runtime, `sql/setup/10_raw_landing.sql`
creates the identical RAW landing tables and loads representative data so the
downstream dbt -> Iceberg -> semantic-view -> lineage flow runs live. Swap in the
live connector above when a runtime is available; the RAW contract is identical.
