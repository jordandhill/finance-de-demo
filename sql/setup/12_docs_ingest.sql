-- ============================================================================
-- Finance DE Demo :: Unstructured earnings-transcript ingest (non-Postgres)
-- Represents an Openflow document connector landing transcript files to a stage,
-- then parsing them with Cortex AI_PARSE_DOCUMENT.
-- Run order:
--   1) snow sql -c default -f sql/setup/12_docs_ingest.sql        (DDL only, up to PUT note)
--   2) PUT the PDFs (see openflow/earnings_docs_connector.md)
--   3) re-run the parse INSERT at the bottom
-- ============================================================================
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE FINANCE_DE_DEMO_WH;
USE DATABASE FINANCE_DE_DEMO;
USE SCHEMA RAW;

-- Server-side encryption (SNOWFLAKE_SSE) is required for AI_PARSE_DOCUMENT / TO_FILE.
CREATE STAGE IF NOT EXISTS RAW.DOC_STAGE
  DIRECTORY = (ENABLE = TRUE)
  ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
  COMMENT = 'Landing stage for Openflow document connector (earnings transcripts)';

CREATE TABLE IF NOT EXISTS RAW.EARNINGS_TRANSCRIPTS_RAW (
    FILE_NAME      STRING,
    SYMBOL         STRING,
    FISCAL_PERIOD  STRING,
    PARSED_TEXT    STRING,
    LOADED_AT      TIMESTAMP_NTZ
);

-- After PUT + REFRESH, (re)load parsed text:
--   PUT file://openflow/sample_docs/*.pdf @RAW.DOC_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
ALTER STAGE RAW.DOC_STAGE REFRESH;

TRUNCATE TABLE IF EXISTS RAW.EARNINGS_TRANSCRIPTS_RAW;
INSERT INTO RAW.EARNINGS_TRANSCRIPTS_RAW
SELECT
    RELATIVE_PATH,
    REGEXP_SUBSTR(RELATIVE_PATH, 'SYM[0-9]{3}')      AS symbol,
    REGEXP_SUBSTR(RELATIVE_PATH, '20[0-9]{2}Q[1-4]') AS fiscal_period,
    AI_PARSE_DOCUMENT(
        TO_FILE('@RAW.DOC_STAGE', RELATIVE_PATH),
        {'mode': 'LAYOUT'}
    ):content::STRING                                AS parsed_text,
    CURRENT_TIMESTAMP::TIMESTAMP_NTZ(6)
FROM DIRECTORY(@RAW.DOC_STAGE)
WHERE RELATIVE_PATH ILIKE '%.pdf';

SELECT SYMBOL, FISCAL_PERIOD, LEFT(PARSED_TEXT, 80) AS preview FROM RAW.EARNINGS_TRANSCRIPTS_RAW;
