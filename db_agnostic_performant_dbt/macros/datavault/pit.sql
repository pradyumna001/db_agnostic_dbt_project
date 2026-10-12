{#-
  Point-in-time table: for each hub key and as-of date, the load_dts of the satellite row valid
  at the end of that day (ghost timestamp when none). Incremental by as-of date.
  satellites: list of satellite model names keyed by hk.
-#}
{% macro pit(hub_model, hk, satellites, as_of_model, ldts='load_dts') -%}
with as_of as (
    select a.as_of_date
    from {{ ref(as_of_model) }} a
    {%- if is_incremental() %}
    where a.as_of_date > (select max(as_of_date) from {{ this }})
    {%- endif %}
),

spine as (
    select h.{{ hk }}, a.as_of_date
    from {{ ref(hub_model) }} h
    inner join as_of a
        on {{ to_date_day('h.' ~ ldts) }} <= a.as_of_date
)
{%- for s in satellites %},

{{ s }}_pit as (
    select sp.{{ hk }}, sp.as_of_date, max(s.{{ ldts }}) as {{ s }}_ldts
    from spine sp
    inner join {{ ref(s) }} s
        on s.{{ hk }} = sp.{{ hk }}
       and {{ to_date_day('s.' ~ ldts) }} <= sp.as_of_date
    group by sp.{{ hk }}, sp.as_of_date
)
{%- endfor %}

select
    {{ hash_key(['sp.' ~ hk, date_key('sp.as_of_date')]) }} as pit_hk,
    sp.{{ hk }},
    sp.as_of_date
    {%- for s in satellites %},
    coalesce({{ s }}_pit.{{ s }}_ldts, {{ ghost_ts() }}) as {{ s }}_ldts
    {%- endfor %}
from spine sp
{%- for s in satellites %}
left join {{ s }}_pit
    on {{ s }}_pit.{{ hk }} = sp.{{ hk }}
   and {{ s }}_pit.as_of_date = sp.as_of_date
{%- endfor %}
{%- endmacro %}
