with src as (
    select * from {{ source('shop', 'products') }}
),

typed as (
    select
        cast(product_id as {{ t_string(20) }}) as product_id,
        cast(sku as {{ t_string(50) }}) as sku,
        cast(product_name as {{ t_string(200) }}) as product_name,
        cast(upper(category) as {{ t_string(50) }}) as category,
        cast(brand as {{ t_string(100) }}) as brand,
        cast(unit_price as {{ t_decimal(18, 2) }}) as list_price,
        cast(unit_cost as {{ t_decimal(18, 2) }}) as unit_cost,
        cast(is_active as {{ t_flag() }}) as is_active,
        cast(updated_at as {{ t_ts() }}) as updated_at,
        cast(loaded_at as {{ t_ts() }}) as load_dts,
        cast('{{ var("record_source_prefix") }}.PRODUCTS' as {{ t_string(50) }}) as record_source
    from src
)

select
    t.*,
    {{ hash_key(['t.product_id']) }} as product_hk,
    {{ hash_diff(['t.sku', 't.product_name', 't.category', 't.brand', 't.list_price', 't.unit_cost', 't.is_active']) }} as product_hashdiff
from typed t
