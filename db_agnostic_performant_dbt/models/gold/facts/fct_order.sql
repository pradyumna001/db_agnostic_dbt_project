{{ config(meta={'perf': {'cluster_by': ['order_date_key'], 'indexes': [['order_hk'], ['customer_sk']]}}) }}

with orders as (
    select o.*
    from (
        select
            s.order_hk,
            s.order_ts,
            s.order_status,
            s.channel,
            s.currency_code,
            s.shipping_amount,
            row_number() over (partition by s.order_hk order by s.load_dts desc) as rn
        from {{ ref('sat_order_details') }} s
    ) o
    where o.rn = 1
),

lines as (
    select
        f.order_hk,
        max(f.customer_sk) as customer_sk,
        count(*) as line_count,
        sum(f.quantity) as units,
        sum(f.gross_amount) as gross_amount,
        sum(f.discount_amount) as discount_amount,
        sum(f.net_amount) as net_line_amount
    from {{ ref('fct_order_line') }} f
    group by f.order_hk
),

payments as (
    select
        lp.order_hk,
        sum(p.payment_amount) as paid_amount
    from {{ ref('lnk_order_payment') }} lp
    inner join (
        select
            pd.payment_hk,
            pd.payment_amount,
            row_number() over (partition by pd.payment_hk order by pd.load_dts desc) as rn
        from {{ ref('sat_payment_details') }} pd
    ) p
        on lp.payment_hk = p.payment_hk and p.rn = 1
    group by lp.order_hk
)

select
    o.order_hk,
    h.order_id,
    coalesce(l.customer_sk, {{ zero_key() }}) as customer_sk,
    cast({{ date_key('o.order_ts') }} as {{ t_int() }}) as order_date_key,
    o.order_ts,
    o.order_status,
    o.channel,
    o.currency_code,
    coalesce(l.line_count, 0) as line_count,
    coalesce(l.units, 0) as units,
    coalesce(l.gross_amount, 0) as gross_amount,
    coalesce(l.discount_amount, 0) as discount_amount,
    o.shipping_amount,
    cast(coalesce(l.net_line_amount, 0) + o.shipping_amount as {{ t_decimal(18, 2) }}) as order_total,
    coalesce(p.paid_amount, 0) as paid_amount
from orders o
inner join {{ ref('hub_order') }} h
    on o.order_hk = h.order_hk
left join lines l
    on o.order_hk = l.order_hk
left join payments p
    on o.order_hk = p.order_hk
