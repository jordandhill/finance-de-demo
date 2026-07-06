# Openflow — Document connector configuration (Earnings call transcripts)

Config-as-code for the **non-Postgres** Openflow source: an unstructured **document
connector** that lands earnings-call transcript files into a Snowflake stage, where
Cortex `AI_PARSE_DOCUMENT` extracts the text.

> Like the PostgreSQL connector, the Openflow runtime is provisioned once via the
> Control Plane UI. This file is the connector configuration; in environments without
> a runtime, `sql/setup/12_docs_ingest.sql` + the sample files under
> `openflow/sample_docs/` reproduce the landed-and-parsed result so the pipeline runs live.

## Connector parameters

| Parameter | Value |
|-----------|-------|
| Connector type | Document source (cloud storage / Google Drive / SharePoint / Box) |
| Source location | `earnings-transcripts/` folder in the document source |
| File types | `pdf` (also docx, pptx, images supported by AI_PARSE_DOCUMENT) |
| Sync mode | incremental (new/changed files) |
| Destination | Snowflake internal stage `FINANCE_DE_DEMO.RAW.DOC_STAGE` (directory table enabled, `SNOWFLAKE_SSE`) |
| Post-land processing | `AI_PARSE_DOCUMENT(TO_FILE('@RAW.DOC_STAGE', relative_path), {'mode':'LAYOUT'})` |
| Snowflake auth | `SNOWFLAKE_MANAGED` (SPCS runtime) |

## Flow

```
Document source (folder of transcript PDFs)
   -> Openflow document connector (incremental file sync)
   -> FINANCE_DE_DEMO.RAW.DOC_STAGE  (internal stage + directory table, SNOWFLAKE_SSE)
   -> AI_PARSE_DOCUMENT -> RAW.EARNINGS_TRANSCRIPTS_RAW (file_name, symbol, fiscal_period, parsed_text)
   -> dbt stg_earnings_transcripts (adds sentiment + summary via Cortex)
   -> MARTS.PORTFOLIO_RISK (sentiment joined to held instruments) + Cortex Search service
```

## Reproduce locally (no runtime)

```bash
# Sample transcripts (5 issuers) already under openflow/sample_docs/*.pdf
snow sql -c default -q "CREATE STAGE IF NOT EXISTS FINANCE_DE_DEMO.RAW.DOC_STAGE \
  DIRECTORY=(ENABLE=TRUE) ENCRYPTION=(TYPE='SNOWFLAKE_SSE');"
snow sql -c default -q "PUT file://openflow/sample_docs/*.pdf @FINANCE_DE_DEMO.RAW.DOC_STAGE \
  AUTO_COMPRESS=FALSE OVERWRITE=TRUE;"
snow sql -c default -f sql/setup/12_docs_ingest.sql
```

## Filename convention
`EARNINGS_<SYMBOL>_<FISCALPERIOD>.pdf` (e.g. `EARNINGS_SYM023_2026Q1.pdf`) so the
loader can derive `symbol` and `fiscal_period` from the file name.
