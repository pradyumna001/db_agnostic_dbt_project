{#- Portable run audit: every invocation writes node results to <ops schema>.dbt_run_audit. -#}

{% macro audit_relation() -%}
{%- if target.type in ['snowflake', 'databricks', 'sqlserver'] -%}
{{ target.database }}.{{ ops_schema() }}.dbt_run_audit
{%- else -%}
{{ ops_schema() }}.dbt_run_audit
{%- endif -%}
{%- endmacro %}

{% macro audit_columns_ddl() -%}
invocation_id {{ t_string(64) }},
run_started_at {{ t_ts() }},
node_id {{ t_string(512) }},
resource_type {{ t_string(32) }},
status {{ t_string(32) }},
execution_seconds {{ t_decimal(12, 3) }},
rows_affected {{ t_bigint() }},
target_name {{ t_string(64) }},
env_name {{ t_string(16) }},
git_sha {{ t_string(64) }}
{%- endmacro %}

{% macro create_ops_objects() %}
    {%- if execute and flags.WHICH in ['run', 'build', 'seed', 'snapshot', 'test'] -%}
        {{ return(adapter.dispatch('create_ops_objects', 'db_agnostic_performant_dbt')()) }}
    {%- endif -%}
{% endmacro %}

{% macro default__create_ops_objects() %}
    {% do run_query('create schema if not exists ' ~ ops_schema()) %}
    {% do run_query('create table if not exists ' ~ audit_relation() ~ ' (' ~ audit_columns_ddl() ~ ')') %}
{% endmacro %}

{% macro sqlserver__create_ops_objects() %}
    {% do run_query("if schema_id('" ~ ops_schema() ~ "') is null exec('create schema " ~ ops_schema() ~ "')") %}
    {% do run_query("if object_id('" ~ ops_schema() ~ ".dbt_run_audit') is null create table " ~ ops_schema() ~ ".dbt_run_audit (" ~ audit_columns_ddl() ~ ")") %}
{% endmacro %}

{% macro oracle__create_ops_objects() %}
    {% set ddl %}
begin
    execute immediate 'create table {{ audit_relation() }} ({{ audit_columns_ddl() }})';
exception
    when others then
        if sqlcode != -955 then raise; end if;
end;
    {% endset %}
    {% do run_query(ddl) %}
{% endmacro %}

{% macro log_run_results(results) %}
    {%- if not execute or results is none or results | length == 0 -%}{{ return('') }}{%- endif -%}
    {%- set git_sha = env_var('GIT_SHA', env_var('GITHUB_SHA', 'local')) -%}
    {%- set rows = [] -%}
    {%- for r in results if r.node is defined and r.node -%}
        {%- set rows_affected = (r.adapter_response or {}).get('rows_affected') -%}
        {%- set row -%}
select
    '{{ invocation_id }}',
    {{ ts_literal(run_started_at.strftime('%Y-%m-%d %H:%M:%S')) }},
    '{{ r.node.unique_id | replace("'", "''") }}',
    '{{ r.node.resource_type }}',
    '{{ r.status }}',
    cast({{ (r.execution_time or 0) | round(3) }} as {{ t_decimal(18, 3) }}),
    cast({{ rows_affected if rows_affected is number and rows_affected >= 0 else 'null' }} as {{ t_bigint() }}),
    '{{ target.name }}',
    '{{ var("env", "dev") }}',
    '{{ git_sha }}'
{{ from_dual() }}
        {%- endset -%}
        {%- do rows.append(row) -%}
    {%- endfor -%}
    {%- if rows | length == 0 -%}{{ return('') }}{%- endif -%}
    {%- set sql -%}
insert into {{ audit_relation() }}
    (invocation_id, run_started_at, node_id, resource_type, status, execution_seconds, rows_affected, target_name, env_name, git_sha)
{{ rows | join('\nunion all\n') }}
    {%- endset -%}
    {% do run_query(sql) %}
    {% if target.type in ['postgres', 'oracle'] %}{% do run_query('commit') %}{% endif %}
    {{ return('') }}
{% endmacro %}

{#- Drop all schemas built for a CI run (used on PR close). -#}
{% macro drop_ci_schemas(prefix) %}
    {%- set layers = ['bronze', 'silver', 'gold', 'ops'] -%}
    {%- for layer in layers -%}
        {%- set schema = prefix ~ '_' ~ layer -%}
        {%- if target.type == 'oracle' -%}
            {{ log('oracle builds into the user schema; drop the CI user instead', info=True) }}
        {%- else -%}
            {% do adapter.drop_schema(api.Relation.create(database=target.database, schema=schema)) %}
            {{ log('dropped schema ' ~ schema, info=True) }}
        {%- endif -%}
    {%- endfor -%}
{% endmacro %}
