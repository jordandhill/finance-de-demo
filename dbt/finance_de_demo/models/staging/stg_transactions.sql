-- Silver: cleansed core banking transactions (non-deleted)
select
    txn_id,
    account_id,
    customer_id,
    txn_ts,
    upper(txn_type) as txn_type,
    symbol,
    quantity,
    amount,
    upper(currency) as currency,
    balance_after
from {{ source('raw', 'TRANSACTIONS') }}
where coalesce(_snowflake_deleted, false) = false
