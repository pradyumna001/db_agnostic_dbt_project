{{ config(meta={'perf': {'cluster_by': ['order_date_key']}}) }}

select
    f.order_date_key,
    f.channel,
    count(*) as orders,
    count(distinct f.customer_sk) as customers,
    sum(f.units) as units,
    sum(f.order_total) as revenue,
    sum(f.paid_amount) as paid_revenue
from {{ ref('fct_order') }} f
where f.order_status not in ('CANCELLED', 'RETURNED')
group by f.order_date_key, f.channel
