with src as (
    select * from {{ source('shop', 'order_lines') }}
),

typed as (
    select
        cast(order_line_id as {{ t_string(40) }}) as order_line_id,
        cast(order_id as {{ t_string(20) }}) as order_id,
        cast(line_number as {{ t_int() }}) as line_number,
        cast(product_id as {{ t_string(20) }}) as product_id,
        cast(quantity as {{ t_int() }}) as quantity,
        cast(unit_price as {{ t_decimal(18, 2) }}) as unit_price,
        cast(discount_amount as {{ t_decimal(18, 2) }}) as discount_amount,
        cast(loaded_at as {{ t_ts() }}) as load_dts,
        cast('{{ var("record_source_prefix") }}.ORDER_LINES' as {{ t_string(50) }}) as record_source
    from src
)

select
    t.*,
    {{ hash_key(['t.order_id']) }} as order_hk,
    {{ hash_key(['t.product_id']) }} as product_hk,
    {{ hash_key(['t.order_id', 't.product_id', 't.line_number']) }} as order_line_hk,
    {{ hash_diff(['t.quantity', 't.unit_price', 't.discount_amount']) }} as order_line_hashdiff
from typed t
