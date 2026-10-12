{#-
  PII classification lives in model YAML (single source of truth):

    columns:
      - name: email
        meta: {pii: true, pii_class: email}

  pii_class in: name, email, phone, date, address, postal_code, card, free_text
  apply_masking() turns that into the native control of each platform:
    snowflake  : column tag  -> tag-based masking policy (policies + tag created by Terraform)
    databricks : Unity Catalog column mask functions + column tags
    sqlserver  : Dynamic Data Masking (UNMASK granted to the pii reader role)
    postgres / oracle : no native masking here -> gold/secure views + grants
-#}

{% macro pii_columns() -%}
    {%- set out = {} -%}
    {%- for name, col in model.columns.items() -%}
        {%- set meta = col.meta or {} -%}
        {%- if meta.get('pii') -%}{% do out.update({name: meta.get('pii_class', 'free_text')}) %}{%- endif -%}
    {%- endfor -%}
    {{- return(out) -}}
{%- endmacro %}

{% macro apply_masking() %}
    {%- if not execute or not var('enable_native_masking', true) or config.get('materialized') not in ['table', 'incremental'] -%}{{ return('') }}{%- endif -%}
    {%- set cols = pii_columns() -%}
    {%- if cols | length == 0 -%}{{ return('') }}{%- endif -%}
    {{- return(adapter.dispatch('apply_masking', 'db_agnostic_performant_dbt')(cols)) -}}
{% endmacro %}

{% macro default__apply_masking(cols) %}{{ return('') }}{% endmacro %}

{% macro snowflake__apply_masking(cols) %}
    {%- for col, cls in cols.items() -%}
        {% do run_query('alter table ' ~ this ~ ' modify column ' ~ col ~ ' set tag ' ~ var('snowflake_pii_tag') ~ " = '" ~ cls ~ "'") %}
    {%- endfor -%}
    {{ return('') }}
{% endmacro %}

{% macro databricks_mask_function(cls) -%}
{{ target.database }}.{{ var('databricks_mask_schema') }}.mask_{{ 'date' if cls == 'date' else 'string_' ~ cls }}
{%- endmacro %}

{% macro databricks__apply_masking(cols) %}
    {%- for col, cls in cols.items() -%}
        {% do run_query('alter table ' ~ this ~ ' alter column ' ~ col ~ ' set mask ' ~ databricks_mask_function(cls)) %}
        {% do run_query('alter table ' ~ this ~ " alter column " ~ col ~ " set tags ('pii_class' = '" ~ cls ~ "')") %}
    {%- endfor -%}
    {{ return('') }}
{% endmacro %}

{% macro sqlserver_mask_function(cls) -%}
{%- set fns = {
    'email': 'email()',
    'phone': 'partial(0,"XXX-XXX-",4)',
    'card': 'partial(0,"XXXX-XXXX-XXXX-",4)',
    'name': 'partial(1,"****",0)',
    'postal_code': 'partial(2,"***",0)',
} -%}
{{- fns.get(cls, 'default()') -}}
{%- endmacro %}

{% macro sqlserver__apply_masking(cols) %}
    {%- set rel = this.include(database=False) -%}
    {%- for col, cls in cols.items() -%}
        {% do run_query("if not exists (select 1 from sys.masked_columns where object_id = object_id('" ~ rel ~ "') and name = '" ~ col ~ "') alter table " ~ rel ~ " alter column " ~ col ~ " add masked with (function = '" ~ sqlserver_mask_function(cls) ~ "')") %}
    {%- endfor -%}
    {{ return('') }}
{% endmacro %}

{#- on-run-start: create Databricks mask functions (other platforms: no-op). -#}
{% macro create_mask_functions() %}
    {%- if execute and target.type == 'databricks' and var('enable_native_masking', true) and flags.WHICH in ['run', 'build'] -%}
        {%- set schema = target.database ~ '.' ~ var('databricks_mask_schema') -%}
        {%- set grp = var('pii_reader_role') -%}
        {% do run_query('create schema if not exists ' ~ schema) %}
        {%- set string_masks = {
            'email': "concat(left(v, 1), '***@', split_part(v, '@', 2))",
            'phone': "concat('***-***-', right(v, 4))",
            'card': "concat('****-****-****-', right(v, 4))",
            'name': "concat(left(v, 1), '****')",
            'postal_code': "concat(left(v, 2), '***')",
            'address': "'*****'",
            'free_text': "'*****'",
        } -%}
        {%- for cls, expr in string_masks.items() -%}
            {% do run_query("create or replace function " ~ schema ~ ".mask_string_" ~ cls ~ "(v string) returns string return case when is_account_group_member('" ~ grp ~ "') then v else " ~ expr ~ " end") %}
        {%- endfor -%}
        {% do run_query("create or replace function " ~ schema ~ ".mask_date(v date) returns date return case when is_account_group_member('" ~ grp ~ "') then v else date_trunc('year', v) end") %}
    {%- endif -%}
    {{ return('') }}
{% endmacro %}
