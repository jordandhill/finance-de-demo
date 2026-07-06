{{
  config(
    materialized = 'table',
    table_format = 'iceberg',
    external_volume = 'MY_EXTERNAL_VOL',
    base_location = 'finance_de_demo/investor_risk'
  )
}}

-- Gold: investor-level risk summary (from the risk system + derived positions).
-- Non-additive risk measures (VaR, limits) kept at investor grain.

with risk as (
    select * from {{ ref('stg_risk_metrics') }}
),

pos as (
    select investor_id as customer_id,
           sum(gross_exposure)   as derived_gross_exposure,
           count(*)              as instruments_held
    from {{ ref('portfolio_risk') }}
    group by 1
)

select
    c.customer_id       as investor_id,
    c.segment           as investor_segment,
    c.risk_rating,
    c.country,
    r.as_of_date,
    r.gross_exposure,
    r.net_exposure,
    r.var_95,
    r.risk_limit,
    r.limit_breach_flag,
    coalesce(pos.derived_gross_exposure, 0) as portfolio_gross_exposure,
    coalesce(pos.instruments_held, 0)       as instruments_held
from {{ ref('stg_customers') }} c
left join risk r  on r.customer_id = c.customer_id
left join pos     on pos.customer_id = c.customer_id
