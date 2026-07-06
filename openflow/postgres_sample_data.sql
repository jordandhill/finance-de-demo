-- ============================================================================
-- the bank :: Openflow CDC SOURCE definition (PostgreSQL)
-- Run this against the source Postgres instance (RDS/EC2) that the Openflow
-- PostgreSQL connector reads from.  Requires wal_level=logical (RDS: set in
-- the parameter group and reboot).
--
-- 3 financial sources modeled here:
--   1. core_banking.transactions      - account debits/credits + trades
--   2. customer_crm.customers          - customer master / KYC / segment
--   3. market_ref.instrument_prices    - instrument prices & FX (reference)
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS core_banking;
CREATE SCHEMA IF NOT EXISTS customer_crm;
CREATE SCHEMA IF NOT EXISTS market_ref;

-- ---------------------------------------------------------------------------
-- 2. Customer / CRM master
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS customer_crm.customers CASCADE;
CREATE TABLE customer_crm.customers (
    customer_id     INTEGER PRIMARY KEY,
    first_name      VARCHAR(60),
    last_name       VARCHAR(60),
    email           VARCHAR(160),
    segment         VARCHAR(20),          -- RETAIL / PREMIER / PRIVATE / BUSINESS
    kyc_status      VARCHAR(20),          -- VERIFIED / PENDING / REVIEW
    risk_rating     VARCHAR(10),          -- LOW / MEDIUM / HIGH
    country         VARCHAR(2),
    onboarded_date  DATE,
    updated_at      TIMESTAMP DEFAULT now()
);

INSERT INTO customer_crm.customers
SELECT g,
       'First'  || g,
       'Last'   || g,
       'cust' || g || '@finance_de_demobank.com',
       (ARRAY['RETAIL','PREMIER','PRIVATE','BUSINESS'])[1 + floor(random()*4)],
       (ARRAY['VERIFIED','VERIFIED','VERIFIED','PENDING','REVIEW'])[1 + floor(random()*5)],
       (ARRAY['LOW','LOW','MEDIUM','HIGH'])[1 + floor(random()*4)],
       (ARRAY['US','US','GB','CA','DE','SG'])[1 + floor(random()*6)],
       DATE '2019-01-01' + (floor(random()*2200))::int,
       now()
FROM generate_series(1, 1000) g;

-- ---------------------------------------------------------------------------
-- 3. Market / reference data (instrument prices & FX)
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS market_ref.instrument_prices CASCADE;
CREATE TABLE market_ref.instrument_prices (
    symbol        VARCHAR(12) PRIMARY KEY,
    asset_class   VARCHAR(20),            -- EQUITY / ETF / BOND / FX / CRYPTO
    price         NUMERIC(18,4),
    currency      VARCHAR(3),
    as_of_date    DATE,
    updated_at    TIMESTAMP DEFAULT now()
);

INSERT INTO market_ref.instrument_prices
SELECT 'SYM' || lpad(g::text, 3, '0'),
       (ARRAY['EQUITY','EQUITY','ETF','BOND','FX','CRYPTO'])[1 + floor(random()*6)],
       round((10 + random()*990)::numeric, 4),
       'USD',
       CURRENT_DATE,
       now()
FROM generate_series(1, 50) g;

-- ---------------------------------------------------------------------------
-- 1. Core banking transactions (fact source; trades reference a symbol)
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS core_banking.transactions CASCADE;
CREATE TABLE core_banking.transactions (
    txn_id         BIGINT PRIMARY KEY,
    account_id     INTEGER,
    customer_id    INTEGER,
    txn_ts         TIMESTAMP,
    txn_type       VARCHAR(20),           -- DEPOSIT / WITHDRAWAL / TRADE_BUY / TRADE_SELL / FEE
    symbol         VARCHAR(12),           -- populated for TRADE_* rows
    quantity       NUMERIC(18,4),         -- populated for TRADE_* rows
    amount         NUMERIC(18,2),         -- signed: +credit / -debit
    currency       VARCHAR(3),
    balance_after  NUMERIC(18,2),
    updated_at     TIMESTAMP DEFAULT now()
);

INSERT INTO core_banking.transactions
SELECT g,
       100000 + (g % 1000),
       1 + (g % 1000),
       now() - (floor(random()*365) || ' days')::interval,
       (ARRAY['DEPOSIT','WITHDRAWAL','TRADE_BUY','TRADE_SELL','FEE'])[1 + floor(random()*5)] AS ttype,
       CASE WHEN random() < 0.4 THEN 'SYM' || lpad((1+floor(random()*50))::int::text,3,'0') END,
       CASE WHEN random() < 0.4 THEN round((random()*100)::numeric,4) END,
       round((random()*10000 - 3000)::numeric, 2),
       'USD',
       round((random()*50000)::numeric, 2),
       now()
FROM generate_series(1, 50000) g;

-- ---------------------------------------------------------------------------
-- 4. Trades (trade executions) - dedicated trading source
-- ---------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS trading;

DROP TABLE IF EXISTS trading.trades CASCADE;
CREATE TABLE trading.trades (
    trade_id       BIGINT PRIMARY KEY,
    customer_id    INTEGER,
    symbol         VARCHAR(12),
    side           VARCHAR(4),            -- BUY / SELL
    quantity       NUMERIC(18,4),
    price          NUMERIC(18,4),
    notional       NUMERIC(18,2),
    book           VARCHAR(16),           -- EQUITY / FIXED_INCOME / FX / DERIVATIVES
    status         VARCHAR(12),           -- FILLED / PARTIAL / CANCELLED
    trade_ts       TIMESTAMP,
    updated_at     TIMESTAMP DEFAULT now()
);

INSERT INTO trading.trades
SELECT g,
       1 + (g % 1000),
       'SYM' || lpad((1 + floor(random()*50))::int::text, 3, '0'),
       (ARRAY['BUY','SELL'])[1 + floor(random()*2)],
       q,
       p,
       round((q * p)::numeric, 2),
       (ARRAY['EQUITY','FIXED_INCOME','FX','DERIVATIVES'])[1 + floor(random()*4)],
       (ARRAY['FILLED','FILLED','FILLED','PARTIAL','CANCELLED'])[1 + floor(random()*5)],
       now() - (floor(random()*365) || ' days')::interval,
       now()
FROM (
    SELECT g,
           round((1 + random()*500)::numeric, 4)  AS q,
           round((10 + random()*990)::numeric, 4) AS p
    FROM generate_series(1, 20000) g
) s;

-- ---------------------------------------------------------------------------
-- 5. Risk metrics (per-customer risk snapshot from the risk system)
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS trading.risk_metrics CASCADE;
CREATE TABLE trading.risk_metrics (
    customer_id       INTEGER,
    as_of_date        DATE,
    gross_exposure    NUMERIC(18,2),
    net_exposure      NUMERIC(18,2),
    var_95            NUMERIC(18,2),      -- 95% 1-day Value at Risk
    risk_limit        NUMERIC(18,2),
    limit_breach_flag BOOLEAN,
    updated_at        TIMESTAMP DEFAULT now(),
    PRIMARY KEY (customer_id, as_of_date)
);

INSERT INTO trading.risk_metrics
SELECT c AS customer_id,
       CURRENT_DATE,
       gross,
       round((gross * (0.2 + random()*0.6))::numeric, 2)  AS net,
       v,
       lim,
       (v > lim)                                          AS breach,
       now()
FROM (
    SELECT c,
           round((10000 + random()*990000)::numeric, 2)  AS gross,
           round((5000 + random()*200000)::numeric, 2)   AS v,
           round((50000 + random()*200000)::numeric, 2)  AS lim
    FROM generate_series(1, 1000) c
) s;

-- ---------------------------------------------------------------------------
-- CDC enablement: logical replication publication for the Openflow connector
-- ---------------------------------------------------------------------------
CREATE PUBLICATION finance_cdc_pub FOR TABLE
    customer_crm.customers,
    market_ref.instrument_prices,
    core_banking.transactions,
    trading.trades,
    trading.risk_metrics;

-- Openflow connector uses a replication slot; grant replication to the connector user.
-- GRANT rds_replication TO <connector_user>;   -- RDS
