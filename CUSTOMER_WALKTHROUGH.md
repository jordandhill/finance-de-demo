# Customer Walkthrough — Building a Governed Financial Data Product on Snowflake with Cortex Code

**Audience:** data engineering, platform, and analytics leaders at a financial services institution
**Duration:** ~20 minutes
**What you'll see:** a data engineer build a complete, governed pipeline — from three
operational source systems to an AI-ready data product — conversationally with Cortex
Code (CoCo), entirely on Snowflake, with open Iceberg storage, lineage, and CI/CD.

---

## 1. The business problem

Relationship managers and risk teams need a single, trustworthy view of each customer:
their profile, their cash activity, what they trade and hold, the risk they carry, and
what the market is saying. Today that data lives in separate systems:

| Source system | What it holds |
|---------------|---------------|
| Core banking | Account transactions, deposits, withdrawals |
| CRM | Customer profile, segment, KYC and risk rating |
| Market data | Instrument prices and FX rates |
| Trading & risk | Trade executions, positions, exposure, VaR, limit breaches |
| Earnings transcripts (unstructured) | What management said on the earnings call |

The goal: governed, open **Customer 360** and **Portfolio Risk** data products that
combine structured and unstructured data, answer natural-language questions, and let
risk teams search what was actually said — built by a small team without stitching
together five different tools.

## 2. The approach

One platform, one governed copy of the data, built conversationally:

```
Core banking ┐
CRM          ├─ Openflow CDC ─> Bronze ─ dbt ─> Silver ─ dbt ─> Gold (open Iceberg)
Market data  ┘                                                      │
                                       Semantic view + lineage ─> Cortex Analyst / AI
                              GitHub + CI/CD  +  Snowflake Git version control
```

Every stage below was created by describing the intent to Cortex Code in plain
English. The engineer stays in the flow of the business problem; CoCo writes the SQL,
the dbt models, the connector config, and the automation.

## 3. The walkthrough

### Act 1 — Ingest three sources with Openflow (Bronze)
**Say:** "Land core banking transactions, customer CRM, and market reference data into
Snowflake with an Openflow PostgreSQL CDC pipeline."

**Show:** the generated connector configuration and source definitions in `openflow/`.
Data lands continuously into the `RAW` layer as change-data-capture — no bulk reloads,
no data leaving the Snowflake trust boundary.

**Point to make:** 200+ managed connectors, credentials and data stay inside Snowflake.
```sql
SELECT 'CUSTOMERS' t, COUNT(*) FROM FINANCE_DE_DEMO.RAW.CUSTOMERS
UNION ALL SELECT 'INSTRUMENT_PRICES', COUNT(*) FROM FINANCE_DE_DEMO.RAW.INSTRUMENT_PRICES
UNION ALL SELECT 'TRANSACTIONS', COUNT(*) FROM FINANCE_DE_DEMO.RAW.TRANSACTIONS;
```
1,000 customers, 50 instruments, 50,000 transactions landed and ready.

### Act 2 — Transform with dbt, on Snowflake (Silver -> Gold)
**Say:** "Build a dbt project: cleanse each source in a Silver layer, then join them into
a Gold Customer 360 model with cash, holdings valued at market price, and total
relationship value. Add tests."

**Show:** the dbt models, then run them natively:
```bash
snow dbt execute -c default --database FINANCE_DE_DEMO --schema PUBLIC finance_de_demo build
```
19 models and tests run **on Snowflake compute** — no separate orchestration server, no
data movement. Tests (uniqueness, not-null, referential integrity) gate the build.

**Point to make:** governed, tested, version-controlled transformations — the same dbt
your teams know, running inside the platform.

### Act 3 — An open Gold data product (Iceberg)
**Say:** "Materialize the Gold table as a Snowflake-managed Iceberg table."

**Show:**
```sql
SHOW ICEBERG TABLES IN SCHEMA FINANCE_DE_DEMO.MARTS;   -- catalog = SNOWFLAKE, MANAGED
```
The Customer 360 data product is stored in **open Apache Iceberg format on your own
cloud storage** — readable by other engines, one copy, fully managed by Snowflake.

**Point to make:** open format, no lock-in, no duplication; Snowflake handles metadata,
compaction, and performance.

### Act 3b — More sources through Openflow: trades, risk & unstructured earnings
**Say:** "Add a trades and risk source, and bring in earnings-call transcripts as an
unstructured source."

**Show:**
- **Trades & risk** land through the same Openflow **PostgreSQL CDC** connector (trade
  executions + a per-customer risk snapshot with exposure, VaR, and limit breaches).
  You can narrate how the same connector also supports **streaming** for real-time trades.
- **Earnings call transcripts** (PDFs) arrive through a **non-Postgres Openflow document
  connector**, land in a Snowflake stage, and are parsed with **Cortex `AI_PARSE_DOCUMENT`**,
  then scored for sentiment and summarized — no external OCR or NLP tooling.

```sql
SELECT symbol, sentiment, LEFT(summary, 90) AS outlook
FROM FINANCE_DE_DEMO.STAGING.STG_EARNINGS_TRANSCRIPTS ORDER BY symbol;
```
**Point to make:** one platform ingests structured *and* unstructured data, and AI reads
the documents in place.

### Act 3c — Portfolio risk data product + document AI
**Say:** "Build a portfolio risk view that values every position and blends in the
earnings sentiment for each holding."

**Show:** the second Iceberg gold product, `PORTFOLIO_RISK`, and how sentiment lines up
with performance:
```sql
SELECT * FROM SEMANTIC_VIEW(
  FINANCE_DE_DEMO.SEMANTIC.PORTFOLIO_RISK_SV
  DIMENSIONS positions.earnings_sentiment
  METRICS positions.position_count, positions.total_gross_exposure, positions.total_unrealized_pnl
) ORDER BY total_unrealized_pnl DESC;
```
Positions in **positive-sentiment** names carry materially higher unrealized P&L than
**negative/neutral** ones — a structured + unstructured signal in one governed table.

**And natural-language document search** via Cortex Search:
```sql
SELECT f.value:symbol::string AS symbol, f.value:sentiment::string AS sentiment
FROM TABLE(FLATTEN(input => PARSE_JSON(SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
  'FINANCE_DE_DEMO.SEMANTIC.EARNINGS_SEARCH',
  '{"query":"which companies are cutting guidance or facing weak demand","columns":["symbol","sentiment"],"limit":3}'
)):results)) f;
```
**Point to make:** risk officers query positions *and* search what management actually
said — all governed, all in Snowflake.

### Act 4 — Make it answer questions (Semantic view + AI)
**Say:** "Create a semantic view over Customer 360 with segment, risk, and country
dimensions and relationship-value metrics."

**Show:** a business question answered through the semantic layer:
```sql
SELECT * FROM SEMANTIC_VIEW(
  FINANCE_DE_DEMO.SEMANTIC.CUSTOMER_360_SV
  DIMENSIONS customers.segment
  METRICS customers.customer_count, customers.total_book_value
) ORDER BY total_book_value DESC;
```

| Segment | Customers | Total relationship value |
|---------|-----------|--------------------------|
| PREMIER | 247 | ~$9.6M |
| RETAIL | 247 | ~$9.0M |
| PRIVATE | 263 | ~$7.4M |
| BUSINESS | 243 | net negative — a risk signal to investigate |

**Point to make:** point Cortex Analyst / Snowflake Intelligence at this semantic view
and business users ask questions in plain English — grounded in governed, defined
metrics, not ad-hoc SQL.

### Act 5 — Trust and governance (Lineage)
**Say:** "Show me where this data product comes from."

**Show:**
```sql
SELECT source_object_name, target_object_name, distance
FROM TABLE(SNOWFLAKE.CORE.GET_LINEAGE('FINANCE_DE_DEMO.MARTS.CUSTOMER_360','TABLE','UPSTREAM',3))
ORDER BY distance;
```
Lineage traces the Gold Iceberg product back through the Silver views to all three RAW
sources — automatically, no manual documentation.

**Point to make:** built-in Horizon lineage answers "where did this number come from?"
and "what breaks if I change this?" — essential for audit and regulatory confidence.

### Act 6 — Production discipline (Version control + CI/CD)
**Say:** "Version everything in Git and add CI/CD."

**Show:** the GitHub repo and `.github/workflows/finance-de-cicd.yml`. Every change opens
a pull request; CI deploys and builds the dbt project and runs the tests before merge;
merging to `main` promotes the semantic view. The repo is also mirrored into Snowflake
as a Git repository object.

**Point to make:** the whole data product is code — reviewed, tested, and promoted like
software, with a full audit trail.

## 4. Why it matters

| Stakeholder | Takeaway |
|-------------|----------|
| Data engineering | One platform, conversational build, native dbt + CI/CD — less tooling to run |
| Architecture | Open Iceberg on your storage, one governed copy, automatic lineage |
| Risk & compliance | End-to-end lineage and tested, version-controlled pipelines for audit |
| Analytics / AI | Governed semantic layer powering natural-language questions over trusted data |

## 5. What was built (recap)
- **6 sources** ingested via Openflow — 5 structured (PostgreSQL CDC) + 1 unstructured
  (earnings transcripts via a document connector, parsed with Cortex)
- **dbt** Silver + Gold transformations, tested, running on Snowflake compute
- **Two Iceberg data products**: `CUSTOMER_360` (relationship value) and `PORTFOLIO_RISK`
  (positions, exposure, P&L + earnings sentiment), plus a `CUSTOMER_RISK` summary
- **Semantic views** + a **Cortex Search** service enabling AI / natural-language analytics
- **Horizon lineage** from Gold back to every structured and unstructured source
- **GitHub + CI/CD** and Snowflake Git for full version control

All of it built by describing the outcome to Cortex Code — the engineer focused on the
business problem, not the plumbing.
