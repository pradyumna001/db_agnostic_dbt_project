{#-
  Effectivity satellite (driving key), insert-only.
  When the link active for a driving key changes, insert the new link as active (is_active = 1)
  and the previous link as ended (is_active = 0) at the same load_dts.
-#}
{% macro eff_sat(source_model, link_hk, driving_key, secondary_fks, ldts='load_dts', rsrc='record_source') -%}
{%- set fks = [driving_key] + secondary_fks -%}
with src as (
    select d.{{ link_hk }}, {{ dv_cols(fks, 'd') }}, d.{{ ldts }}, d.{{ rsrc }}
    from (
        select
            s.{{ link_hk }}, {{ dv_cols(fks, 's') }}, s.{{ ldts }}, s.{{ rsrc }},
            row_number() over (partition by s.{{ driving_key }}, s.{{ ldts }} order by s.{{ link_hk }}) as rn
        from {{ ref(source_model) }} s
        where s.{{ link_hk }} is not null
        {%- if is_incremental() %}
          and s.{{ ldts }} > {{ dv_watermark(ldts) }}
        {%- endif %}
    ) d
    where d.rn = 1
),

{%- if is_incremental() %}

latest_active as (
    select a.{{ link_hk }}, {{ dv_cols(fks, 'a') }}, a.{{ ldts }}, a.{{ rsrc }}
    from (
        select
            t.{{ link_hk }}, {{ dv_cols(fks, 't') }}, t.{{ ldts }}, t.{{ rsrc }}, t.is_active,
            row_number() over (partition by t.{{ driving_key }} order by t.{{ ldts }} desc, t.is_active desc) as rn
        from {{ this }} t
        inner join (select distinct {{ driving_key }} from src) k
            on t.{{ driving_key }} = k.{{ driving_key }}
    ) a
    where a.rn = 1 and a.is_active = 1
),
{%- endif %}

combined as (
    select {{ link_hk }}, {{ dv_cols(fks) }}, {{ ldts }}, {{ rsrc }}, 1 as is_new from src
    {%- if is_incremental() %}
    union all
    select {{ link_hk }}, {{ dv_cols(fks) }}, {{ ldts }}, {{ rsrc }}, 0 as is_new from latest_active
    {%- endif %}
),

sequenced as (
    select
        c.*,
        lag(c.{{ link_hk }}) over (partition by c.{{ driving_key }} order by c.{{ ldts }}) as prev_link_hk
        {%- for f in secondary_fks %},
        lag(c.{{ f }}) over (partition by c.{{ driving_key }} order by c.{{ ldts }}) as prev_{{ f }}
        {%- endfor %}
    from combined c
),

changes as (
    select q.*
    from sequenced q
    where q.is_new = 1
      and (q.prev_link_hk is null or q.prev_link_hk <> q.{{ link_hk }})
)

select
    ch.{{ link_hk }}, {{ dv_cols(fks, 'ch') }},
    cast(1 as {{ t_flag() }}) as is_active,
    ch.{{ ldts }}, ch.{{ rsrc }}
from changes ch
union all
select
    ch.prev_link_hk, ch.{{ driving_key }}{% for f in secondary_fks %}, ch.prev_{{ f }}{% endfor %},
    cast(0 as {{ t_flag() }}) as is_active,
    ch.{{ ldts }}, ch.{{ rsrc }}
from changes ch
where ch.prev_link_hk is not null
{%- endmacro %}
