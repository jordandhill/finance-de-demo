{{
  config(
    materialized = 'table',
    table_format = 'iceberg',
    external_volume = 'MY_EXTERNAL_VOL',
    base_location = 'finance_de_demo/customer_360'
  )
}}

-- Gold: Customer 360 / relationship value.
-- Combines all three sources:
--   customers (profile) + transactions (cash & trades) + instrument_prices (valuation)

with tx as (
    select * from {{ ref('stg_transactions') }}
),

cash as (
    select
        customer_id,
        count(*)                                                          as txn_count,
        sum(case when txn_type = 'DEPOSIT'  then amount else 0 end)        as total_deposits,
        sum(case when txn_type = 'WITHDRAWAL' then amount else 0 end)      as total_withdrawals,
        sum(case when txn_type = 'FEE' then amount else 0 end)            as total_fees,
        max(txn_ts)                                                       as last_activity_ts
    from tx
    group by 1
),

-- current cash balance = balance_after of the most recent transaction
latest_balance as (
    select customer_id, balance_after as current_cash_balance
    from (
        select customer_id, balance_after,
               row_number() over (partition by customer_id order by txn_ts desc) as rn
        from tx
    )
    where rn = 1
),

-- net position per symbol from buys (+qty) and sells (-qty)
positions as (
    select
        customer_id,
        symbol,
        sum(case when txn_type = 'TRADE_BUY'  then quantity
                 when txn_type = 'TRADE_SELL' then -quantity else 0 end) as net_quantity
    from tx
    where txn_type in ('TRADE_BUY','TRADE_SELL') and symbol is not null
    group by 1, 2
),

holdings as (
    select
        p.customer_id,
        sum(p.net_quantity * pr.price)              as holdings_value,
        count(distinct case when p.net_quantity <> 0 then p.symbol end) as instruments_held
    from positions p
    join {{ ref('stg_instrument_prices') }} pr on pr.symbol = p.symbol
    group by 1
)

select
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email,
    c.segment,
    c.kyc_status,
    c.risk_rating,
    c.country,
    c.onboarded_date,
    c.tenure_days,
    coalesce(cash.txn_count, 0)                              as txn_count,
    coalesce(cash.total_deposits, 0)                         as total_deposits,
    coalesce(cash.total_withdrawals, 0)                      as total_withdrawals,
    coalesce(cash.total_fees, 0)                             as total_fees,
    coalesce(lb.current_cash_balance, 0)                     as current_cash_balance,
    coalesce(h.holdings_value, 0)                            as holdings_value,
    coalesce(h.instruments_held, 0)                          as instruments_held,
    coalesce(lb.current_cash_balance, 0)
      + coalesce(h.holdings_value, 0)                        as total_relationship_value,
    cash.last_activity_ts::timestamp_ntz(6)                 as last_activity_ts,
    current_timestamp()::timestamp_ntz(6)                   as _built_at
from {{ ref('stg_customers') }} c
left join cash        on cash.customer_id = c.customer_id
left join latest_balance lb on lb.customer_id = c.customer_id
left join holdings h  on h.customer_id = c.customer_id
