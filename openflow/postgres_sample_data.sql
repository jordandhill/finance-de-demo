-- ============================================================================
-- Apollo Bank :: Openflow CDC SOURCE definition (PostgreSQL)
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
       'cust' || g || '@apollobank.com',
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
-- CDC enablement: logical replication publication for the Openflow connector
-- ---------------------------------------------------------------------------
CREATE PUBLICATION apollo_cdc_pub FOR TABLE
    customer_crm.customers,
    market_ref.instrument_prices,
    core_banking.transactions;

-- Openflow connector uses a replication slot; grant replication to the connector user.
-- GRANT rds_replication TO <connector_user>;   -- RDS
