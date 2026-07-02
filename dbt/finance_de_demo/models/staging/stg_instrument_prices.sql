-- Silver: latest price per instrument symbol
with src as (
    select *,
           row_number() over (partition by symbol order by as_of_date desc, updated_at desc) as rn
    from {{ source('raw', 'INSTRUMENT_PRICES') }}
    where coalesce(_snowflake_deleted, false) = false
)
select
    symbol,
    upper(asset_class) as asset_class,
    price,
    upper(currency)    as currency,
    as_of_date
from src
where rn = 1
