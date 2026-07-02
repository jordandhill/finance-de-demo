# Apollo Bank — CoCo Data Engineering Demo

End-to-end demo showing how **Cortex Code (CoCo)** builds a governed data-engineering
stack on Snowflake for a financial services customer ("Apollo Bank"):

```
3 financial sources  ->  Openflow CDC  ->  RAW (Bronze)  ->  dbt STAGING (Silver)
   ->  MARTS.CUSTOMER_360 (Snowflake-managed Iceberg, Gold)
   ->  Semantic View + Horizon lineage  ->  Cortex Analyst / AI
```

## Data sources (Bronze)
1. **Core banking transactions** — account debits/credits/transfers
2. **Customer / CRM master** — customer profile, segment, KYC
3. **Market / reference data** — instrument prices & FX rates

## Layers
| Layer | Location | Built by |
|-------|----------|----------|
| Bronze (RAW) | `APOLLO_FIN.RAW` | Openflow CDC connector |
| Silver | `APOLLO_FIN.STAGING` | dbt models |
| Gold | `APOLLO_FIN.MARTS.CUSTOMER_360` (Iceberg) | dbt |
| Semantic | `APOLLO_FIN.SEMANTIC` | semantic view for AI |

## Repo layout
- `sql/setup/` — environment DDL (database, schemas, warehouse, external volume)
- `sql/semantic/` — semantic view definition
- `openflow/` — Openflow flow definitions (config-as-code) + source data generators
- `dbt/apollo_fin/` — dbt project (Bronze -> Silver -> Gold Iceberg)
- `.github/workflows/` — GitHub Actions CI/CD (dbt build + test + deploy)
- `DEMO_RUNBOOK.md` — the live demo script incl. the exact CoCo prompts to type

## Prerequisites
- Snowflake account `SFSENORTHAMERICA-DEMO_JHILL`, role `ACCOUNTADMIN`
- `snow` CLI connection named `default` pointing at the account
- External volume `MY_EXTERNAL_VOL` (already configured -> `s3://jh-iceberg/tt`)

## Quickstart
```bash
snow sql -c default -f sql/setup/00_environment.sql
```
See `DEMO_RUNBOOK.md` for the full narrated flow.
