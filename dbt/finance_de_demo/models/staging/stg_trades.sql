-- Silver: cleansed trade executions (non-deleted)
select
    trade_id,
    customer_id,
    symbol,
    upper(side)   as side,
    quantity,
    price,
    notional,
    upper(book)   as book,
    upper(status) as status,
    trade_ts
from {{ source('raw', 'TRADES') }}
where coalesce(_snowflake_deleted, false) = false
