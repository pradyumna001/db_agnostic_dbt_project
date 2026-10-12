{#-
  Link: one row per unique combination of hub keys, insert-only.
  fk: list of hub hash key columns; dependent_child_keys: optional degenerate keys (e.g. line number).
-#}
{% macro link(source_models, link_hk, fk, dependent_child_keys=[], ldts='load_dts', rsrc='record_source') -%}
{%- set cols = [link_hk] + fk + dependent_child_keys + [ldts, rsrc] -%}
with src as (
{%- for m in source_models %}
    select {{ dv_cols(cols) }}
    from {{ ref(m) }}
    where {{ link_hk }} is not null
    {%- if is_incremental() %}
      and {{ ldts }} > {{ dv_watermark(ldts) }}
    {%- endif %}
    {% if not loop.last %}union all{% endif %}
{%- endfor %}
),

ranked as (
    select
        s.*,
        row_number() over (partition by s.{{ link_hk }} order by s.{{ ldts }}, s.{{ rsrc }}) as rn
    from src s
)

select {{ dv_cols(cols, 'r') }}
from ranked r
{%- if is_incremental() %}
left join {{ this }} t
    on r.{{ link_hk }} = t.{{ link_hk }}
{%- endif %}
where r.rn = 1
{%- if is_incremental() %}
  and t.{{ link_hk }} is null
{%- endif %}
{%- endmacro %}
