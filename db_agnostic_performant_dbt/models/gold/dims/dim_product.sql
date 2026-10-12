{#- SCD1 product dimension: latest satellite state per product. -#}
{{ config(meta={'perf': {'indexes': [['product_hk']]}}) }}

with latest as (
    select l.*
    from (
        select
            s.product_hk,
            s.sku,
            s.product_name,
            s.category,
            s.brand,
            s.list_price,
            s.unit_cost,
            s.is_active,
            s.load_dts,
            row_number() over (partition by s.product_hk order by s.load_dts desc) as rn
        from {{ ref('sat_product_details') }} s
    ) l
    where l.rn = 1
)

select
    h.product_hk,
    h.product_id,
    l.sku,
    l.product_name,
    l.category,
    l.brand,
    l.list_price,
    l.unit_cost,
    l.is_active,
    l.load_dts as last_changed_at
from {{ ref('hub_product') }} h
left join latest l
    on h.product_hk = l.product_hk
