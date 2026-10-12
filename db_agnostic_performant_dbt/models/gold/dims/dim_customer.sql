{#- SCD2 customer dimension derived from the daily PIT. One version per change of either satellite. -#}
{{ config(meta={'perf': {'indexes': [['customer_hk', 'effective_from']]}}) }}

with pit as (
    select
        p.customer_hk,
        p.as_of_date,
        p.sat_customer_details_ldts,
        p.sat_customer_pii_ldts,
        lag(p.sat_customer_details_ldts) over (partition by p.customer_hk order by p.as_of_date) as prev_details_ldts,
        lag(p.sat_customer_pii_ldts) over (partition by p.customer_hk order by p.as_of_date) as prev_pii_ldts
    from {{ ref('pit_customer') }} p
),

changes as (
    select c.*
    from pit c
    where
        c.prev_details_ldts is null
        or c.prev_details_ldts <> c.sat_customer_details_ldts
        or c.prev_pii_ldts <> c.sat_customer_pii_ldts
),

versions as (
    select
        v.*,
        lead(v.as_of_date) over (partition by v.customer_hk order by v.as_of_date) as next_as_of_date
    from changes v
)

select
    {{ hash_key(['v.customer_hk', date_key('v.as_of_date')]) }} as customer_sk,
    v.customer_hk,
    h.customer_id,
    d.customer_segment,
    d.country_code,
    pii.first_name,
    pii.last_name,
    pii.email,
    pii.phone,
    pii.date_of_birth,
    pii.address_line1,
    pii.city,
    pii.state_code,
    pii.postal_code,
    v.as_of_date as effective_from,
    coalesce(v.next_as_of_date, {{ end_of_time_date() }}) as effective_to,
    cast(case when v.next_as_of_date is null then 1 else 0 end as {{ t_flag() }}) as is_current
from versions v
inner join {{ ref('hub_customer') }} h
    on v.customer_hk = h.customer_hk
left join {{ ref('sat_customer_details') }} d
    on
        v.customer_hk = d.customer_hk
        and v.sat_customer_details_ldts = d.load_dts
left join {{ ref('sat_customer_pii') }} pii
    on
        v.customer_hk = pii.customer_hk
        and v.sat_customer_pii_ldts = pii.load_dts

union all

select
    {{ zero_key() }} as customer_sk,
    {{ zero_key() }} as customer_hk,
    cast('UNKNOWN' as {{ t_string(20) }}) as customer_id,
    cast('UNKNOWN' as {{ t_string(30) }}) as customer_segment,
    cast(null as {{ t_string(2) }}) as country_code,
    cast(null as {{ t_string(100) }}) as first_name,
    cast(null as {{ t_string(100) }}) as last_name,
    cast(null as {{ t_string(255) }}) as email,
    cast(null as {{ t_string(30) }}) as phone,
    cast(null as {{ t_date() }}) as date_of_birth,
    cast(null as {{ t_string(255) }}) as address_line1,
    cast(null as {{ t_string(100) }}) as city,
    cast(null as {{ t_string(10) }}) as state_code,
    cast(null as {{ t_string(20) }}) as postal_code,
    {{ date_literal('1900-01-01') }} as effective_from,
    {{ end_of_time_date() }} as effective_to,
    cast(1 as {{ t_flag() }}) as is_current
{{ from_dual() }}
