-- Silver: latest risk snapshot per customer (non-deleted)
with src as (
    select *,
           row_number() over (partition by customer_id order by as_of_date desc, updated_at desc) as rn
    from {{ source('raw', 'RISK_METRICS') }}
    where coalesce(_snowflake_deleted, false) = false
)
select
    customer_id,
    as_of_date,
    gross_exposure,
    net_exposure,
    var_95,
    risk_limit,
    limit_breach_flag
from src
where rn = 1
