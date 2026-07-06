-- ============================================================================
-- Finance DE Demo :: RAW landing for Trades & Risk (Openflow PostgreSQL CDC)
-- Mirrors the connector output for trading.trades and trading.risk_metrics.
-- Run with: snow sql -c default -f sql/setup/11_raw_trades_risk.sql
-- ============================================================================
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE FINANCE_DE_DEMO_WH;
USE DATABASE FINANCE_DE_DEMO;
USE SCHEMA RAW;

-- ---------------------------------------------------------------------------
-- Source 4: Trades (executions)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE RAW.TRADES (
    TRADE_ID       NUMBER,
    CUSTOMER_ID    NUMBER,
    SYMBOL         STRING,
    SIDE           STRING,
    QUANTITY       NUMBER(18,4),
    PRICE          NUMBER(18,4),
    NOTIONAL       NUMBER(18,2),
    BOOK           STRING,
    STATUS         STRING,
    TRADE_TS       TIMESTAMP_NTZ,
    UPDATED_AT     TIMESTAMP_NTZ,
    _SNOWFLAKE_INSERTED_AT TIMESTAMP_NTZ,
    _SNOWFLAKE_DELETED     BOOLEAN
);

INSERT INTO RAW.TRADES
SELECT
    rn AS trade_id,
    1 + MOD(rn, 1000) AS customer_id,
    'SYM'||LPAD(UNIFORM(1,50,RANDOM())::STRING,3,'0'),
    ARRAY_CONSTRUCT('BUY','SELL')[UNIFORM(0,1,RANDOM())]::STRING,
    q,
    p,
    ROUND(q*p, 2),
    ARRAY_CONSTRUCT('EQUITY','FIXED_INCOME','FX','DERIVATIVES')[UNIFORM(0,3,RANDOM())]::STRING,
    ARRAY_CONSTRUCT('FILLED','FILLED','FILLED','PARTIAL','CANCELLED')[UNIFORM(0,4,RANDOM())]::STRING,
    DATEADD(day, -UNIFORM(0,365,RANDOM()), CURRENT_TIMESTAMP)::TIMESTAMP_NTZ(6),
    CURRENT_TIMESTAMP::TIMESTAMP_NTZ(6),
    CURRENT_TIMESTAMP::TIMESTAMP_NTZ(6),
    FALSE
FROM (
    SELECT seq4()+1 AS rn,
           ROUND(UNIFORM(1,500,RANDOM()) + RANDOM()/1e17, 4) AS q,
           ROUND(UNIFORM(10,1000,RANDOM()) + RANDOM()/1e17, 4) AS p
    FROM TABLE(GENERATOR(ROWCOUNT => 20000))
);

-- ---------------------------------------------------------------------------
-- Source 5: Risk metrics (per-customer snapshot)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE RAW.RISK_METRICS (
    CUSTOMER_ID       NUMBER,
    AS_OF_DATE        DATE,
    GROSS_EXPOSURE    NUMBER(18,2),
    NET_EXPOSURE      NUMBER(18,2),
    VAR_95            NUMBER(18,2),
    RISK_LIMIT        NUMBER(18,2),
    LIMIT_BREACH_FLAG BOOLEAN,
    UPDATED_AT        TIMESTAMP_NTZ,
    _SNOWFLAKE_INSERTED_AT TIMESTAMP_NTZ,
    _SNOWFLAKE_DELETED     BOOLEAN
);

INSERT INTO RAW.RISK_METRICS
SELECT
    c AS customer_id,
    CURRENT_DATE,
    gross,
    ROUND(gross * (0.2 + UNIFORM(0,60,RANDOM())/100.0), 2) AS net_exposure,
    v,
    lim,
    (v > lim) AS limit_breach_flag,
    CURRENT_TIMESTAMP::TIMESTAMP_NTZ(6),
    CURRENT_TIMESTAMP::TIMESTAMP_NTZ(6),
    FALSE
FROM (
    SELECT seq4()+1 AS c,
           ROUND(UNIFORM(10000,1000000,RANDOM()) + RANDOM()/1e17, 2) AS gross,
           ROUND(UNIFORM(5000,205000,RANDOM()) + RANDOM()/1e17, 2)   AS v,
           ROUND(UNIFORM(50000,250000,RANDOM()) + RANDOM()/1e17, 2)  AS lim
    FROM TABLE(GENERATOR(ROWCOUNT => 1000))
);

SELECT 'TRADES' t, COUNT(*) n FROM RAW.TRADES
UNION ALL SELECT 'RISK_METRICS', COUNT(*) FROM RAW.RISK_METRICS
UNION ALL SELECT 'RISK_BREACHES', COUNT(*) FROM RAW.RISK_METRICS WHERE LIMIT_BREACH_FLAG;
