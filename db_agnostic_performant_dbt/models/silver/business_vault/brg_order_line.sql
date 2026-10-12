{#- Bridge: order line grain with the hub keys needed by facts (customer resolved via the active effectivity row). -#}
{{ config(meta={'perf': {'indexes': [['order_line_hk'], ['order_hk']]}}) }}

with active_customer as (
    select
        e.order_hk,
        e.customer_hk
    from (
        select
            f.order_hk,
            f.customer_hk,
            f.is_active,
            row_number() over (partition by f.order_hk order by f.load_dts desc, f.is_active desc) as rn
        from {{ ref('efs_order_customer') }} f
    ) e
    where e.rn = 1 and e.is_active = 1
)

select
    l.order_line_hk,
    l.order_hk,
    l.product_hk,
    coalesce(c.customer_hk, {{ zero_key() }}) as customer_hk,
    l.line_number,
    l.load_dts
from {{ ref('lnk_order_product') }} l
left join active_customer c
    on l.order_hk = c.order_hk
