{{ config(
    materialized='incremental',
    incremental_strategy=upsert_strategy(),
    unique_key='order_line_hk',
    on_schema_change='append_new_columns',
    meta={'perf': {'cluster_by': ['order_date_key'], 'indexes': [['order_line_hk'], ['customer_sk'], ['product_hk']]}}
) }}

with line_details as (
    select l.*
    from (
        select
            s.order_line_hk,
            s.quantity,
            s.unit_price,
            s.discount_amount,
            s.load_dts,
            row_number() over (partition by s.order_line_hk order by s.load_dts desc) as rn
        from {{ ref('sat_order_line_details') }} s
        {%- if is_incremental() %}
            where s.order_line_hk in (
                select x.order_line_hk from {{ ref('sat_order_line_details') }} x
                where x.load_dts > (select max(t.source_load_dts) from {{ this }} t)
            )
        {%- endif %}
    ) l
    where l.rn = 1
),

order_details as (
    select
        o.order_hk,
        o.order_ts,
        o.channel
    from (
        select
            s.order_hk,
            s.order_ts,
            s.channel,
            row_number() over (partition by s.order_hk order by s.load_dts desc) as rn
        from {{ ref('sat_order_details') }} s
    ) o
    where o.rn = 1
)

select
    b.order_line_hk,
    b.order_hk,
    b.product_hk,
    coalesce(c.customer_sk, {{ zero_key() }}) as customer_sk,
    cast({{ date_key('o.order_ts') }} as {{ t_int() }}) as order_date_key,
    o.channel,
    ld.quantity,
    ld.unit_price,
    ld.discount_amount,
    cast(ld.quantity * ld.unit_price as {{ t_decimal(18, 2) }}) as gross_amount,
    cast(ld.quantity * ld.unit_price - ld.discount_amount as {{ t_decimal(18, 2) }}) as net_amount,
    ld.load_dts as source_load_dts
from line_details ld
inner join {{ ref('brg_order_line') }} b
    on ld.order_line_hk = b.order_line_hk
inner join order_details o
    on b.order_hk = o.order_hk
left join {{ ref('dim_customer') }} c
    on
        b.customer_hk = c.customer_hk
        and {{ to_date_day('o.order_ts') }} >= c.effective_from
        and {{ to_date_day('o.order_ts') }} < c.effective_to
