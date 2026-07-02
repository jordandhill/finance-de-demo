-- Silver: latest non-deleted customer record per customer_id
with src as (
    select *,
           row_number() over (partition by customer_id order by updated_at desc) as rn
    from {{ source('raw', 'CUSTOMERS') }}
    where coalesce(_snowflake_deleted, false) = false
)
select
    customer_id,
    initcap(first_name)                    as first_name,
    initcap(last_name)                     as last_name,
    lower(email)                           as email,
    upper(segment)                         as segment,
    upper(kyc_status)                      as kyc_status,
    upper(risk_rating)                     as risk_rating,
    upper(country)                         as country,
    onboarded_date,
    datediff('day', onboarded_date, current_date) as tenure_days
from src
where rn = 1
