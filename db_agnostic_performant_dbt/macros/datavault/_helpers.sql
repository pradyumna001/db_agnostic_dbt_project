{#- Lower bound for incremental loads: max(load_dts) already in the target, minus an optional lookback. -#}
{% macro dv_watermark(ldts='load_dts') -%}
{%- set lookback = var('watermark_lookback_hours', 0) | int -%}
{%- if lookback > 0 -%}
(select {{ add_hours('coalesce(max(' ~ ldts ~ '), ' ~ ghost_ts() ~ ')', -lookback) }} from {{ this }})
{%- else -%}
(select coalesce(max({{ ldts }}), {{ ghost_ts() }}) from {{ this }})
{%- endif -%}
{%- endmacro %}

{% macro dv_cols(cols, prefix=none) -%}
{%- for c in cols -%}{% if prefix %}{{ prefix }}.{% endif %}{{ c }}{% if not loop.last %}, {% endif %}{%- endfor -%}
{%- endmacro %}
