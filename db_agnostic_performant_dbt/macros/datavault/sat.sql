{#-
  Satellite: insert-only history of descriptive attributes, a new row only when the hashdiff changes.
  Handles several batches per run (change detection with lag over the target's latest row + new rows).
-#}
{% macro sat(source_model, parent_hk, hashdiff, payload, ldts='load_dts', rsrc='record_source') -%}
{%- set cols = [parent_hk, hashdiff] + payload + [ldts, rsrc] -%}
with src as (
    select {{ dv_cols(cols) }}
    from {{ ref(source_model) }}
    where {{ parent_hk }} is not null
    {%- if is_incremental() %}
      and {{ ldts }} > {{ dv_watermark(ldts) }}
    {%- endif %}
),

src_dedup as (
    select d.*
    from (
        select
            s.*,
            row_number() over (partition by s.{{ parent_hk }}, s.{{ ldts }} order by s.{{ hashdiff }}) as rn
        from src s
    ) d
    where d.rn = 1
),

{%- if is_incremental() %}

latest as (
    select l.{{ parent_hk }}, l.{{ hashdiff }}, l.{{ ldts }}
    from (
        select
            t.{{ parent_hk }},
            t.{{ hashdiff }},
            t.{{ ldts }},
            row_number() over (partition by t.{{ parent_hk }} order by t.{{ ldts }} desc) as rn
        from {{ this }} t
        inner join (select distinct {{ parent_hk }} from src_dedup) k
            on t.{{ parent_hk }} = k.{{ parent_hk }}
    ) l
    where l.rn = 1
),
{%- endif %}

combined as (
    select {{ parent_hk }}, {{ hashdiff }}, {{ ldts }}, 1 as is_new from src_dedup
    {%- if is_incremental() %}
    union all
    select {{ parent_hk }}, {{ hashdiff }}, {{ ldts }}, 0 as is_new from latest
    {%- endif %}
),

changes as (
    select
        c.{{ parent_hk }},
        c.{{ ldts }},
        c.is_new,
        c.{{ hashdiff }},
        lag(c.{{ hashdiff }}) over (partition by c.{{ parent_hk }} order by c.{{ ldts }}) as prev_hashdiff
    from combined c
)

select {{ dv_cols(cols, 's') }}
from src_dedup s
inner join changes ch
    on s.{{ parent_hk }} = ch.{{ parent_hk }}
   and s.{{ ldts }} = ch.{{ ldts }}
where ch.is_new = 1
  and (ch.prev_hashdiff is null or ch.prev_hashdiff <> ch.{{ hashdiff }})
{%- endmacro %}
