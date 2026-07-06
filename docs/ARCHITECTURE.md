# Architecture

End-to-end data flow for the Finance DE Demo. Structured **trades & risk** and core
banking / CRM / market data arrive via Openflow **PostgreSQL CDC**; **earnings-call
transcripts** arrive via a non-Postgres Openflow **document connector** and are parsed
with Cortex. dbt transforms Bronze -> Silver -> Gold, landing two open Snowflake-managed
Iceberg data products (`CUSTOMER_360`, `PORTFOLIO_RISK`), exposed to AI via semantic
views, a Cortex Search service, and Horizon lineage — all version-controlled with
GitHub and CI/CD.

```mermaid
flowchart TD
  subgraph pg [Postgres CDC - Openflow PostgreSQL connector]
    S1[Core banking transactions]
    S2[Customer / CRM master]
    S3[Market / reference prices]
    S4[Trades - executions]
    S5[Risk metrics - exposure / VaR / limits]
  end
  subgraph docs [Unstructured - Openflow document connector]
    D1[Earnings call transcripts]
  end
  S1 --> OFPG[Openflow PostgreSQL CDC]
  S2 --> OFPG
  S3 --> OFPG
  S4 --> OFPG
  S5 --> OFPG
  D1 --> OFDOC[Openflow document connector]
  OFPG --> RAW[(RAW - Bronze)]
  OFDOC --> STG_DOC[Stage + directory table]
  STG_DOC --> PARSE[Cortex AI_PARSE_DOCUMENT + AI_SENTIMENT/AI_COMPLETE]
  PARSE --> RAW
  RAW --> SILVER[(Silver - dbt views)]
  SILVER --> G1[(CUSTOMER_360 - Iceberg)]
  SILVER --> G2[(PORTFOLIO_RISK - Iceberg)]
  SILVER --> G3[(CUSTOMER_RISK - Iceberg)]
  PARSE --> SEARCH[Cortex Search over transcripts]
  G1 --> SV1[CUSTOMER_360_SV]
  G2 --> SV2[PORTFOLIO_RISK_SV]
  SV1 --> AI[Cortex Analyst / Snowflake Intelligence]
  SV2 --> AI
  SEARCH --> AI
  subgraph cicd [Version Control and CI-CD]
    GH[GitHub repo] --> GHA[GitHub Actions: dbt build/test + snow deploy]
    GH --> GITREPO[Snowflake GIT REPOSITORY object]
  end
  GHA -.deploys.-> SILVER
  GHA -.deploys.-> G2
```

## Sources
| # | Source | Openflow connector | Lands as |
|---|--------|--------------------|----------|
| 1 | Core banking transactions | PostgreSQL CDC | `RAW.TRANSACTIONS` |
| 2 | Customer / CRM master | PostgreSQL CDC | `RAW.CUSTOMERS` |
| 3 | Market / reference prices | PostgreSQL CDC | `RAW.INSTRUMENT_PRICES` |
| 4 | Trades (executions) | PostgreSQL CDC | `RAW.TRADES` |
| 5 | Risk metrics (exposure/VaR) | PostgreSQL CDC | `RAW.RISK_METRICS` |
| 6 | Earnings call transcripts | Document connector | `RAW.DOC_STAGE` -> `RAW.EARNINGS_TRANSCRIPTS_RAW` |

## Gold data products (Snowflake-managed Iceberg)
- `MARTS.CUSTOMER_360` — relationship value per customer
- `MARTS.PORTFOLIO_RISK` — customer x instrument positions, exposure, P&L + earnings sentiment
- `MARTS.CUSTOMER_RISK` — customer-level exposure, VaR, limit breaches

## AI serving
- `SEMANTIC.CUSTOMER_360_SV`, `SEMANTIC.PORTFOLIO_RISK_SV` — semantic views for Cortex Analyst
- `SEMANTIC.EARNINGS_SEARCH` — Cortex Search service over transcript text
- Horizon lineage from every gold table back to its RAW sources
