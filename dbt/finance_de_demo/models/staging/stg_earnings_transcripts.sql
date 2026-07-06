-- Silver: earnings transcripts enriched with Cortex sentiment + one-line summary.
-- One row per (symbol, fiscal_period). Cortex AI functions run on Snowflake.
select
    file_name,
    symbol,
    fiscal_period,
    parsed_text,
    ai_sentiment(parsed_text):categories[0]:sentiment::string as sentiment,
    ai_complete(
        'llama3.1-70b',
        'Summarize the forward outlook of this earnings call in one sentence. '
        || 'Respond with ONLY the sentence, no preamble or labels: '
        || parsed_text
    )::string as summary,
    loaded_at
from {{ source('raw', 'EARNINGS_TRANSCRIPTS_RAW') }}
