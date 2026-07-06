# BUILD — Finance DE Demo (AI-Driven Data Engineering for an Asset Manager)

Authoritative, end-to-end build guide for this project. It consolidates the setup,
ingestion, transformation, AI, serving, and CI/CD steps into one reproducible document.

- Customer-facing narrative / talk track: [CUSTOMER_WALKTHROUGH.md](CUSTOMER_WALKTHROUGH.md)
- Architecture diagram: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- Short overview: [README.md](README.md)

---

## 0. What this builds

An asset-management data platform built conversationally with **Cortex Code (CoCo)** —
AI writes the pipeline, AI processes data inside it, and the outputs are AI-ready.

```
6 sources ─ Openflow ─> RAW (Bronze) ─ dbt (AI-authored) ─> STAGING (Silver)
   ─> MARTS: INVESTOR_360 (AUM), PORTFOLIO_RISK, INVESTOR_RISK  (Snowflake-managed Iceberg)
   ─> Semantic views + Cortex Search ─> Cortex Analyst / Snowflake Intelligence
   GitHub + GitHub Actions CI/CD + Snowflake GIT REPOSITORY
```

## 1. Environment / prerequisites

| Item | Value |
|------|-------|
| Account | `SFSENORTHAMERICA-DEMO_JHILL` (PBB04236), AWS us-east-1 |
| snow CLI connection | `default` (role `ACCOUNTADMIN`, key-pair `SNOWFLAKE_JWT`) |
| Database / warehouse | `FINANCE_DE_DEMO` / `FINANCE_DE_DEMO_WH` (XS) |
| Schemas | `RAW`, `STAGING`, `MARTS`, `SEMANTIC`, `GOVERNANCE` |
| Iceberg storage | external volume `MY_EXTERNAL_VOL` -> `s3://jh-iceberg/tt` (pre-verified) |
| Git | GitHub `jordandhill/finance-de-demo` (public); Snowflake `FINANCE_DE_DEMO.PUBLIC.FINANCE_DE_DEMO_REPO` via `GITHUB_API_INTEGRATION` |
| Tools | `snow` CLI, `gh` CLI, `cupsfilter` (macOS, for sample PDFs) — no local `dbt` needed (native `snow dbt`) |

Verify the Iceberg volume before any Iceberg DDL:
```sql
SELECT SYSTEM$VERIFY_EXTERNAL_VOLUME('MY_EXTERNAL_VOL');   -- expect all PASSED
```

## 2. Build sequence

Each phase shows the **CoCo prompt** (what the engineer types) and the resulting
artifacts / commands. Run from repo root with the `default` connection.

### Phase 1 — Environment
> CoCo: "Set up the FINANCE_DE_DEMO database with RAW, STAGING, MARTS and SEMANTIC schemas
> and an XSMALL warehouse, and verify the MY_EXTERNAL_VOL external volume."

```bash
snow sql -c default -f sql/setup/00_environment.sql
```

### Phase 2 — Version control
> CoCo: "Create a GitHub repo for this project and register it as a Snowflake GIT REPOSITORY."

- GitHub repo created via `gh` (public); Snowflake git object `FINANCE_DE_DEMO_REPO` created
  against `GITHUB_API_INTEGRATION` (public repo -> no credentials needed).

### Phase 3 — Ingestion (Openflow, 6 sources)
> CoCo: "Build an Openflow PostgreSQL CDC pipeline landing OMS cash flows, investor CRM,
> market prices, trades and risk metrics into RAW; plus an Openflow document connector for
> earnings-call transcripts parsed with Cortex."

Config-as-code lives in `openflow/`. Because there is **no live Openflow runtime** on the
account (runtime is Control-Plane-UI only), representative CDC output is loaded so the rest
runs live; the RAW contract matches the connector output.

```bash
snow sql -c default -f sql/setup/10_raw_landing.sql        # customers, prices, cash flows
snow sql -c default -f sql/setup/11_raw_trades_risk.sql    # trades, risk metrics
# Documents: stage (SNOWFLAKE_SSE required for AI_PARSE_DOCUMENT), upload PDFs, parse
snow sql -c default -q "CREATE STAGE IF NOT EXISTS FINANCE_DE_DEMO.RAW.DOC_STAGE DIRECTORY=(ENABLE=TRUE) ENCRYPTION=(TYPE='SNOWFLAKE_SSE');"
snow sql -c default -q "PUT file://openflow/sample_docs/*.pdf @FINANCE_DE_DEMO.RAW.DOC_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;"
snow sql -c default -f sql/setup/12_docs_ingest.sql        # AI_PARSE_DOCUMENT -> RAW
```
Sample transcript PDFs were generated from text with `cupsfilter` (see `openflow/sample_docs/`).

### Phase 4 — Transformation (dbt on Snowflake)
> CoCo: "Create a dbt project: Silver staging over RAW; Gold INVESTOR_360 (AUM = cash +
> holdings valued at market) and PORTFOLIO_RISK at investor x instrument grain; add tests."

```bash
snow dbt deploy finance_de_demo --source dbt/finance_de_demo --database FINANCE_DE_DEMO --schema PUBLIC -c default
snow dbt execute -c default --database FINANCE_DE_DEMO --schema PUBLIC finance_de_demo build
```
41 nodes (6 staging views, 3 Iceberg gold tables, 32 tests). AI is a transformation step
here: `stg_earnings_transcripts` adds `AI_SENTIMENT` + `AI_COMPLETE` summary.

### Phase 5 — Gold as Snowflake-managed Iceberg
The gold models carry `table_format='iceberg'`, `external_volume='MY_EXTERNAL_VOL'`. Verify:
```sql
SHOW ICEBERG TABLES IN SCHEMA FINANCE_DE_DEMO.MARTS;  -- INVESTOR_360, PORTFOLIO_RISK, INVESTOR_RISK (MANAGED)
```

### Phase 6 — AI serving (semantic views + Cortex Search)
> CoCo: "Create semantic views over the gold tables and a Cortex Search service over the
> transcripts."

```bash
snow sql -c default -f sql/semantic/investor_360_semantic_view.sql
snow sql -c default -f sql/semantic/portfolio_risk_semantic_view.sql
snow sql -c default -f sql/semantic/earnings_search.sql
```

### Phase 7 — CI/CD
> CoCo: "Add a GitHub Actions workflow that builds and tests the dbt project on every PR
> and deploys the semantic views on merge to main."

`.github/workflows/finance-de-cicd.yml`. Requires repo secrets `SNOWFLAKE_ACCOUNT`,
`SNOWFLAKE_USER`, `SNOWFLAKE_PRIVATE_KEY` (key-pair PEM). CI uses `snow --temporary-connection`.

## 3. Verification

```sql
-- Bronze row counts (6 sources)
SELECT 'CUSTOMERS' t, COUNT(*) FROM FINANCE_DE_DEMO.RAW.CUSTOMERS
UNION ALL SELECT 'INSTRUMENT_PRICES', COUNT(*) FROM FINANCE_DE_DEMO.RAW.INSTRUMENT_PRICES
UNION ALL SELECT 'TRANSACTIONS', COUNT(*) FROM FINANCE_DE_DEMO.RAW.TRANSACTIONS
UNION ALL SELECT 'TRADES', COUNT(*) FROM FINANCE_DE_DEMO.RAW.TRADES
UNION ALL SELECT 'RISK_METRICS', COUNT(*) FROM FINANCE_DE_DEMO.RAW.RISK_METRICS
UNION ALL SELECT 'EARNINGS_TRANSCRIPTS', COUNT(*) FROM FINANCE_DE_DEMO.RAW.EARNINGS_TRANSCRIPTS_RAW;

-- AUM by investor segment (semantic view / Cortex Analyst)
SELECT * FROM SEMANTIC_VIEW(FINANCE_DE_DEMO.SEMANTIC.INVESTOR_360_SV
  DIMENSIONS investors.investor_segment
  METRICS investors.investor_count, investors.total_aum) ORDER BY total_aum DESC;

-- Lineage: gold Iceberg back to raw sources (structured + unstructured)
SELECT source_object_name, target_object_name, distance
FROM TABLE(SNOWFLAKE.CORE.GET_LINEAGE('FINANCE_DE_DEMO.MARTS.PORTFOLIO_RISK','TABLE','UPSTREAM',3))
ORDER BY distance;
```

## 4. File inventory

| Path | Purpose |
|------|---------|
| `sql/setup/00_environment.sql` | DB, schemas, warehouse, external-volume verify |
| `sql/setup/10_raw_landing.sql` | RAW: customers, instrument prices, cash flows |
| `sql/setup/11_raw_trades_risk.sql` | RAW: trades, risk metrics |
| `sql/setup/12_docs_ingest.sql` | Doc stage + `AI_PARSE_DOCUMENT` -> RAW transcripts |
| `openflow/postgres_sample_data.sql` | Postgres source DDL + CDC publication (config-as-code) |
| `openflow/connector_config.md` | Openflow PostgreSQL CDC connector reference |
| `openflow/earnings_docs_connector.md` | Openflow document connector reference |
| `openflow/sample_docs/*` | Sample earnings transcripts (txt + generated pdf) |
| `dbt/finance_de_demo/` | dbt project: staging (Silver) + marts (Gold Iceberg) + tests |
| `sql/semantic/investor_360_semantic_view.sql` | INVESTOR_360_SV (AUM) |
| `sql/semantic/portfolio_risk_semantic_view.sql` | PORTFOLIO_RISK_SV |
| `sql/semantic/earnings_search.sql` | Cortex Search over transcripts |
| `.github/workflows/finance-de-cicd.yml` | CI/CD (dbt build/test + semantic deploy) |
| `sql/governance/*` | (in progress) classification, masking, DMFs |

## 5. Rebuild from scratch

```bash
snow sql -c default -f sql/setup/00_environment.sql
snow sql -c default -f sql/setup/10_raw_landing.sql
snow sql -c default -f sql/setup/11_raw_trades_risk.sql
snow sql -c default -q "CREATE STAGE IF NOT EXISTS FINANCE_DE_DEMO.RAW.DOC_STAGE DIRECTORY=(ENABLE=TRUE) ENCRYPTION=(TYPE='SNOWFLAKE_SSE');"
snow sql -c default -q "PUT file://openflow/sample_docs/*.pdf @FINANCE_DE_DEMO.RAW.DOC_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;"
snow sql -c default -f sql/setup/12_docs_ingest.sql
snow dbt deploy finance_de_demo --source dbt/finance_de_demo --database FINANCE_DE_DEMO --schema PUBLIC -c default
snow dbt execute -c default --database FINANCE_DE_DEMO --schema PUBLIC finance_de_demo build
snow sql -c default -f sql/semantic/investor_360_semantic_view.sql
snow sql -c default -f sql/semantic/portfolio_risk_semantic_view.sql
snow sql -c default -f sql/semantic/earnings_search.sql
```

## 6. Known caveats (learned during the build)

- **No live Openflow runtime** on the account (runtime is provisioned via the Control Plane
  UI only). RAW is loaded from representative data with the identical connector contract.
- **Network policy**: the shared account policy `ACCOUNT_VPN_POLICY_SE` periodically drops the
  GitHub Actions rule. Before relying on CI, re-apply:
  `ALTER NETWORK POLICY ACCOUNT_VPN_POLICY_SE SET ALLOWED_NETWORK_RULE_LIST = ('SNOWFLAKE.NETWORK_SECURITY.GITHUBACTIONS_GLOBAL');`
- **Cortex model availability**: `claude-3-5-sonnet` is not available in this region; use
  `llama3.1-70b` for `AI_COMPLETE`.
- **Iceberg type limits**: cast `AI_*` outputs to `::string` (Iceberg rejects VARIANT) and use
  `TIMESTAMP_NTZ(6)` (Iceberg rejects scale 9).
- **dbt on Snowflake**: `profiles.yml` needs `role`; enable `flags: enable_iceberg_materializations: true`;
  `-c <conn>` must precede the project name in `snow dbt execute`.
- **GitHub API integration** restricts allowed secrets; this repo is public so the Snowflake git
  object needs no credential.
- **Tagging Iceberg tables** uses `ALTER ICEBERG TABLE ... MODIFY COLUMN ... SET TAG` (the auto
  classification proc uses `ALTER TABLE` and fails on Iceberg).

## 7. Planned / roadmap (open plans)

- **Governance** (in progress): auto PII classification (`EXTRACT_SEMANTIC_CATEGORIES` +
  `ASSOCIATE_SEMANTIC_CATEGORY_TAGS`), tag-based dynamic masking, and DMFs, with a
  `FINANCE_ANALYST_RL` demo role — see `add-governance-and-iceberg-interop` plan.
- **Iceberg interoperability**: prove the open format (`SYSTEM$GET_ICEBERG_TABLE_INFORMATION`,
  `GET_DDL`) + Spark / PyIceberg / Databricks connection recipes; commented Catalog Integration /
  Open Catalog templates for live external read/write.
