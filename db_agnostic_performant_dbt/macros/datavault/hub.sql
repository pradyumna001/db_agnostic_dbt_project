{#-
  Hub: one row per business key, insert-only.
  source_models: list of staging models exposing the same hk / bk / ldts / rsrc column names.
-#}
{% macro hub(source_models, hk, bk, ldts='load_dts', rsrc='record_source') -%}
{%- if bk is string %}{% set bk = [bk] %}{% endif -%}
{%- set cols = [hk] + bk + [ldts, rsrc] -%}
with src as (
{%- for m in source_models %}
    select {{ dv_cols(cols) }}
    from {{ ref(m) }}
    where {{ hk }} is not null
    {%- if is_incremental() %}
      and {{ ldts }} > {{ dv_watermark(ldts) }}
    {%- endif %}
    {% if not loop.last %}union all{% endif %}
{%- endfor %}
),

ranked as (
    select
        s.*,
        row_number() over (partition by s.{{ hk }} order by s.{{ ldts }}, s.{{ rsrc }}) as rn
    from src s
)

select {{ dv_cols(cols, 'r') }}
from ranked r
{%- if is_incremental() %}
left join {{ this }} t
    on r.{{ hk }} = t.{{ hk }}
{%- endif %}
where r.rn = 1
{%- if is_incremental() %}
  and t.{{ hk }} is null
{%- endif %}
{%- endmacro %}
