{#-
  dev/ci : <target.schema>_<layer>   e.g. dbt_alice_silver, pr_123_gold
  prod   : <layer>                   e.g. silver
  oracle : schemas are users, so by default everything is built in the connecting user's schema.
-#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema | trim }}
    {%- elif target.type == 'oracle' and var('oracle_single_schema', true) -%}
        {{ target.schema | trim }}
    {%- elif var('env', 'dev') == 'prod' -%}
        {{ custom_schema_name | trim }}
    {%- else -%}
        {{ target.schema | trim }}_{{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}

{% macro ops_schema() -%}
{%- if target.type == 'oracle' -%}{{ target.schema }}{%- else -%}{{ generate_schema_name('ops', none) }}{%- endif -%}
{%- endmacro %}
