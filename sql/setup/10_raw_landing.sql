-- ============================================================================
-- Apollo Bank :: RAW / Bronze landing  (represents Openflow CDC output)
-- These tables mirror exactly what the Openflow PostgreSQL connector lands,
-- including CDC metadata columns. For a live runtime the connector populates
-- them; here we load representative data so the pipeline runs end-to-end.
-- Run with: snow sql -c default -f sql/setup/10_raw_landing.sql
-- ============================================================================
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE APOLLO_WH;
USE DATABASE APOLLO_FIN;
USE SCHEMA RAW;

-- ---------------------------------------------------------------------------
-- Source 2: Customer / CRM master
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE RAW.CUSTOMERS (
    CUSTOMER_ID     NUMBER,
    FIRST_NAME      STRING,
    LAST_NAME       STRING,
    EMAIL           STRING,
    SEGMENT         STRING,
    KYC_STATUS      STRING,
    RISK_RATING     STRING,
    COUNTRY         STRING,
    ONBOARDED_DATE  DATE,
    UPDATED_AT      TIMESTAMP_NTZ,
    _SNOWFLAKE_INSERTED_AT TIMESTAMP_NTZ,
    _SNOWFLAKE_DELETED     BOOLEAN
);

INSERT INTO RAW.CUSTOMERS
SELECT
    seq4()+1 AS customer_id,
    'First'||(seq4()+1),
    'Last'||(seq4()+1),
    'cust'||(seq4()+1)||'@apollobank.com',
    ARRAY_CONSTRUCT('RETAIL','PREMIER','PRIVATE','BUSINESS')[UNIFORM(0,3,RANDOM())]::STRING,
    ARRAY_CONSTRUCT('VERIFIED','VERIFIED','VERIFIED','PENDING','REVIEW')[UNIFORM(0,4,RANDOM())]::STRING,
    ARRAY_CONSTRUCT('LOW','LOW','MEDIUM','HIGH')[UNIFORM(0,3,RANDOM())]::STRING,
    ARRAY_CONSTRUCT('US','US','GB','CA','DE','SG')[UNIFORM(0,5,RANDOM())]::STRING,
    DATEADD(day, -UNIFORM(0,2200,RANDOM()), CURRENT_DATE),
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP,
    FALSE
FROM TABLE(GENERATOR(ROWCOUNT => 1000));

-- ---------------------------------------------------------------------------
-- Source 3: Market / reference data (instrument prices)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE RAW.INSTRUMENT_PRICES (
    SYMBOL       STRING,
    ASSET_CLASS  STRING,
    PRICE        NUMBER(18,4),
    CURRENCY     STRING,
    AS_OF_DATE   DATE,
    UPDATED_AT   TIMESTAMP_NTZ,
    _SNOWFLAKE_INSERTED_AT TIMESTAMP_NTZ,
    _SNOWFLAKE_DELETED     BOOLEAN
);

INSERT INTO RAW.INSTRUMENT_PRICES
SELECT
    'SYM'||LPAD((seq4()+1)::STRING,3,'0'),
    ARRAY_CONSTRUCT('EQUITY','EQUITY','ETF','BOND','FX','CRYPTO')[UNIFORM(0,5,RANDOM())]::STRING,
    ROUND(UNIFORM(10,1000,RANDOM()) + RANDOM()/100000000000000000, 4),
    'USD',
    CURRENT_DATE,
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP,
    FALSE
FROM TABLE(GENERATOR(ROWCOUNT => 50));

-- ---------------------------------------------------------------------------
-- Source 1: Core banking transactions (trades reference a symbol)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE RAW.TRANSACTIONS (
    TXN_ID         NUMBER,
    ACCOUNT_ID     NUMBER,
    CUSTOMER_ID    NUMBER,
    TXN_TS         TIMESTAMP_NTZ,
    TXN_TYPE       STRING,
    SYMBOL         STRING,
    QUANTITY       NUMBER(18,4),
    AMOUNT         NUMBER(18,2),
    CURRENCY       STRING,
    BALANCE_AFTER  NUMBER(18,2),
    UPDATED_AT     TIMESTAMP_NTZ,
    _SNOWFLAKE_INSERTED_AT TIMESTAMP_NTZ,
    _SNOWFLAKE_DELETED     BOOLEAN
);

INSERT INTO RAW.TRANSACTIONS
SELECT
    rn AS txn_id,
    100000 + MOD(rn, 1000),
    1 + MOD(rn, 1000),
    DATEADD(day, -UNIFORM(0,365,RANDOM()), CURRENT_TIMESTAMP),
    ttype,
    CASE WHEN ttype IN ('TRADE_BUY','TRADE_SELL')
         THEN 'SYM'||LPAD(UNIFORM(1,50,RANDOM())::STRING,3,'0') END,
    CASE WHEN ttype IN ('TRADE_BUY','TRADE_SELL')
         THEN ROUND(UNIFORM(1,100,RANDOM()) + RANDOM()/100000000000000000, 4) END,
    ROUND(UNIFORM(-3000,7000,RANDOM()) + RANDOM()/100000000000000000, 2),
    'USD',
    ROUND(UNIFORM(0,50000,RANDOM()) + RANDOM()/100000000000000000, 2),
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP,
    FALSE
FROM (
    SELECT seq4()+1 AS rn,
           ARRAY_CONSTRUCT('DEPOSIT','WITHDRAWAL','TRADE_BUY','TRADE_SELL','FEE')[UNIFORM(0,4,RANDOM())]::STRING AS ttype
    FROM TABLE(GENERATOR(ROWCOUNT => 50000))
);

SELECT 'CUSTOMERS' t, COUNT(*) n FROM RAW.CUSTOMERS
UNION ALL SELECT 'INSTRUMENT_PRICES', COUNT(*) FROM RAW.INSTRUMENT_PRICES
UNION ALL SELECT 'TRANSACTIONS', COUNT(*) FROM RAW.TRANSACTIONS;
