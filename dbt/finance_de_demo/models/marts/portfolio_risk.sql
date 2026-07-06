{{
  config(
    materialized = 'table',
    table_format = 'iceberg',
    external_volume = 'MY_EXTERNAL_VOL',
    base_location = 'finance_de_demo/portfolio_risk'
  )
}}

-- Gold: Portfolio risk at customer x instrument grain.
-- Net positions from trade executions, valued at latest market price, enriched
-- with the instrument's latest earnings-call sentiment/summary.

with trades as (
    select * from {{ ref('stg_trades') }}
    where status <> 'CANCELLED'
),

positions as (
    select
        customer_id,
        symbol,
        sum(case when side = 'BUY' then quantity else -quantity end) as net_quantity,
        sum(case when side = 'BUY' then notional else -notional end) as net_cost,
        count(*)                                                     as trade_count
    from trades
    group by 1, 2
),

prices as (
    select symbol, price, asset_class from {{ ref('stg_instrument_prices') }}
),

-- one earnings record per symbol (latest fiscal period)
earnings as (
    select symbol, sentiment, summary,
           row_number() over (partition by symbol order by fiscal_period desc) as rn
    from {{ ref('stg_earnings_transcripts') }}
    qualify rn = 1
)

select
    p.customer_id                                   as investor_id,
    c.segment                                       as investor_segment,
    c.risk_rating,
    p.symbol,
    pr.asset_class,
    p.net_quantity,
    p.trade_count,
    pr.price                                        as last_price,
    round(p.net_quantity * pr.price, 2)             as market_value,
    round(abs(p.net_quantity * pr.price), 2)        as gross_exposure,
    round(p.net_quantity * pr.price - p.net_cost, 2) as unrealized_pnl,
    e.sentiment::string                             as earnings_sentiment,
    e.summary::string                               as earnings_summary,
    current_timestamp()::timestamp_ntz(6)           as _built_at
from positions p
join prices pr             on pr.symbol = p.symbol
join {{ ref('stg_customers') }} c on c.customer_id = p.customer_id
left join earnings e       on e.symbol = p.symbol
where p.net_quantity <> 0
