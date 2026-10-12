{{ config(meta={'perf': {'indexes': [['date_key']]}}) }}

with digits as (
    {%- for d in range(10) %}
        select {{ d }} as n {{ from_dual() }}
        {% if not loop.last %}union all{% endif %}
    {%- endfor %}
),

numbers as (
    select d1.n + d2.n * 10 + d3.n * 100 + d4.n * 1000 as n
    from digits d1
    cross join digits d2
    cross join digits d3
    cross join digits d4
),

days as (
    select {{ add_days(date_literal(var('dim_date_start')), 'n') }} as date_day
    from numbers
    where n < {{ var('dim_date_days') }}
)

select
    cast({{ date_key('date_day') }} as {{ t_int() }}) as date_key,
    cast(date_day as {{ t_date() }}) as date_day,
    {{ date_part_int('year', 'date_day') }} as year_number,
    {{ date_part_int('quarter', 'date_day') }} as quarter_number,
    {{ date_part_int('month', 'date_day') }} as month_number,
    {{ date_part_int('day', 'date_day') }} as day_of_month,
    {{ iso_day_of_week('date_day') }} as iso_day_of_week,
    cast(case when {{ iso_day_of_week('date_day') }} in (6, 7) then 1 else 0 end as {{ t_flag() }}) as is_weekend
from days
