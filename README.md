# Finance DE Demo — CoCo Data Engineering on Snowflake

End-to-end demo showing how **Cortex Code (CoCo)** builds a governed data-engineering
stack on Snowflake for a financial services use case:

```
3 financial sources  ->  Openflow CDC  ->  RAW (Bronze)  ->  dbt STAGING (Silver)
   ->  MARTS.CUSTOMER_360 (Snowflake-managed Iceberg, Gold)
   ->  Semantic View + Horizon lineage  ->  Cortex Analyst / AI
```

## Data sources (Bronze)
1. **Core banking transactions** — account debits/credits/transfers and trades
2. **Customer / CRM master** — customer profile, segment, KYC
3. **Market / reference data** — instrument prices & FX rates

## Layers
| Layer | Location | Built by |
|-------|----------|----------|
| Bronze (RAW) | `FINANCE_DE_DEMO.RAW` | Openflow CDC connector |
| Silver | `FINANCE_DE_DEMO.STAGING` | dbt models |
| Gold | `FINANCE_DE_DEMO.MARTS.CUSTOMER_360` (Iceberg) | dbt |
| Semantic | `FINANCE_DE_DEMO.SEMANTIC` | semantic view for AI |

## Repo layout
- `sql/setup/` — environment DDL (database, schemas, warehouse, external volume)
- `sql/semantic/` — semantic view definition
- `openflow/` — Openflow flow definitions (config-as-code) + source data generators
- `dbt/finance_de_demo/` — dbt project (Bronze -> Silver -> Gold Iceberg)
- `.github/workflows/` — GitHub Actions CI/CD (dbt build + test + deploy)
- `DEMO_RUNBOOK.md` — internal run/reset steps and the CoCo prompts used to build it
- `CUSTOMER_WALKTHROUGH.md` — customer-facing showcase narrative

## Prerequisites
- `snow` CLI connection named `default` pointing at the account
- External volume `MY_EXTERNAL_VOL` (example: `s3://jh-iceberg/tt`)

## Quickstart
```bash
snow sql -c default -f sql/setup/00_environment.sql
snow sql -c default -f sql/setup/10_raw_landing.sql
snow dbt deploy finance_de_demo --source dbt/finance_de_demo --database FINANCE_DE_DEMO --schema PUBLIC -c default
snow dbt execute -c default --database FINANCE_DE_DEMO --schema PUBLIC finance_de_demo build
snow sql -c default -f sql/semantic/customer_360_semantic_view.sql
```
See `DEMO_RUNBOOK.md` for the full narrated flow.
