with src as (
    select * from {{ source('shop', 'orders') }}
),

typed as (
    select
        cast(order_id as {{ t_string(20) }}) as order_id,
        cast(customer_id as {{ t_string(20) }}) as customer_id,
        cast(order_ts as {{ t_ts() }}) as order_ts,
        cast(upper(order_status) as {{ t_string(20) }}) as order_status,
        cast(upper(channel) as {{ t_string(20) }}) as channel,
        cast(currency as {{ t_string(3) }}) as currency_code,
        cast(shipping_amount as {{ t_decimal(18, 2) }}) as shipping_amount,
        cast(updated_at as {{ t_ts() }}) as updated_at,
        cast(loaded_at as {{ t_ts() }}) as load_dts,
        cast('{{ var("record_source_prefix") }}.ORDERS' as {{ t_string(50) }}) as record_source
    from src
)

select
    t.*,
    {{ hash_key(['t.order_id']) }} as order_hk,
    {{ hash_key(['t.customer_id']) }} as customer_hk,
    {{ hash_key(['t.order_id', 't.customer_id']) }} as order_customer_hk,
    {{ hash_diff(['t.order_ts', 't.order_status', 't.channel', 't.currency_code', 't.shipping_amount']) }} as order_hashdiff
from typed t
