with src as (
    select * from {{ source('shop', 'payments') }}
),

typed as (
    select
        cast(payment_id as {{ t_string(20) }}) as payment_id,
        cast(order_id as {{ t_string(20) }}) as order_id,
        cast(upper(payment_method) as {{ t_string(20) }}) as payment_method,
        cast(card_last4 as {{ t_string(4) }}) as card_last4,
        cast(amount as {{ t_decimal(18, 2) }}) as payment_amount,
        cast(paid_ts as {{ t_ts() }}) as paid_ts,
        cast(upper(payment_status) as {{ t_string(20) }}) as payment_status,
        cast(loaded_at as {{ t_ts() }}) as load_dts,
        cast('{{ var("record_source_prefix") }}.PAYMENTS' as {{ t_string(50) }}) as record_source
    from src
)

select
    t.*,
    {{ hash_key(['t.payment_id']) }} as payment_hk,
    {{ hash_key(['t.order_id']) }} as order_hk,
    {{ hash_key(['t.order_id', 't.payment_id']) }} as order_payment_hk,
    {{ hash_diff(['t.payment_method', 't.card_last4', 't.payment_amount', 't.paid_ts', 't.payment_status']) }} as payment_hashdiff
from typed t
