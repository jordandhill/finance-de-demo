# Architecture

End-to-end data flow for the Finance DE Demo: three financial sources ingested via
Openflow CDC, transformed with dbt through Bronze/Silver/Gold, landed as an open
Snowflake-managed Iceberg gold table, and exposed to AI via a semantic view with
Horizon lineage — all version-controlled with GitHub and CI/CD.

```mermaid
flowchart TD
  subgraph sources [Synthetic Financial Sources - Postgres CDC]
    S1[Core banking transactions]
    S2[Customer / CRM master]
    S3[Market / reference data]
  end
  S1 --> OF[Openflow CDC Connector]
  S2 --> OF
  S3 --> OF
  OF --> BRONZE[(RAW / Bronze landing tables)]
  BRONZE --> SILVER[(Silver - dbt cleansed & conformed)]
  SILVER --> GOLD[(Gold - CUSTOMER_360 Snowflake-managed Iceberg)]
  GOLD --> SV[Semantic View for Cortex Analyst / AI]
  GOLD --> LIN[Horizon column-level lineage]
  SV --> AI[Snowflake Intelligence / AI]
  subgraph cicd [Version Control and CI-CD]
    GH[GitHub repo] --> GHA[GitHub Actions: dbt build/test + snow deploy]
    GH --> GITREPO[Snowflake GIT REPOSITORY object]
  end
  GHA -.deploys.-> SILVER
  GHA -.deploys.-> GOLD
```
