{#-
  Platform-neutral performance hints, declared once per model:

    config(meta={'perf': {
        'cluster_by': ['order_date_key'],         -- physical clustering / pruning key
        'indexes': [['customer_hk'], ['product_hk']],  -- secondary lookup indexes
        'stats': true                              -- refresh optimizer statistics (default true)
    }})

  Translation per platform:
    snowflake  : cluster_by -> ALTER TABLE .. CLUSTER BY (only for large tables), indexes ignored
    databricks : cluster_by -> liquid clustering (ALTER TABLE .. CLUSTER BY), optional OPTIMIZE
    postgres   : cluster_by -> BRIN index, indexes -> b-tree, ANALYZE
    sqlserver  : indexes -> nonclustered indexes (tables are clustered columnstore by default), UPDATE STATISTICS
    oracle     : indexes -> b-tree indexes, DBMS_STATS (compression/parallel via table configs)
-#}

{% macro perf_hints() -%}
    {%- set meta = config.get('meta') or {} -%}
    {{- return(meta.get('perf', {})) -}}
{%- endmacro %}

{% macro perf_index_name(prefix, cols) -%}
{{ prefix }}_{{ local_md5(this.schema ~ '.' ~ this.identifier ~ ':' ~ (cols | join(','))) [:24] }}
{%- endmacro %}

{% macro apply_performance() %}
    {%- if not execute or config.get('materialized') not in ['table', 'incremental'] -%}{{ return('') }}{%- endif -%}
    {%- set hints = perf_hints() -%}
    {{- return(adapter.dispatch('apply_performance', 'db_agnostic_performant_dbt')(hints)) -}}
{% endmacro %}

{% macro default__apply_performance(hints) %}{{ return('') }}{% endmacro %}

{% macro postgres__apply_performance(hints) %}
    {%- for cols in hints.get('indexes', []) -%}
        {% do run_query('create index if not exists ' ~ perf_index_name('ix', cols) ~ ' on ' ~ this ~ ' (' ~ cols | join(', ') ~ ')') %}
    {%- endfor -%}
    {%- if hints.get('cluster_by') -%}
        {% do run_query('create index if not exists ' ~ perf_index_name('brin', hints.cluster_by) ~ ' on ' ~ this ~ ' using brin (' ~ hints.cluster_by | join(', ') ~ ')') %}
    {%- endif -%}
    {%- if hints.get('stats', true) -%}{{ return('analyze ' ~ this) }}{%- endif -%}
    {{ return('') }}
{% endmacro %}

{% macro sqlserver__apply_performance(hints) %}
    {%- set rel = this.include(database=False) -%}
    {%- for cols in hints.get('indexes', []) -%}
        {%- set ix = perf_index_name('ix', cols) -%}
        {% do run_query("if not exists (select 1 from sys.indexes where name = '" ~ ix ~ "' and object_id = object_id('" ~ rel ~ "')) create nonclustered index " ~ ix ~ " on " ~ rel ~ " (" ~ cols | join(', ') ~ ")") %}
    {%- endfor -%}
    {%- if hints.get('stats', true) -%}{{ return('update statistics ' ~ rel) }}{%- endif -%}
    {{ return('') }}
{% endmacro %}

{% macro oracle__apply_performance(hints) %}
    {%- for cols in hints.get('indexes', []) -%}
        {%- set ix = perf_index_name('ix', cols) | upper -%}
        {% set ddl %}
begin
    execute immediate 'create index {{ ix }} on {{ this }} ({{ cols | join(", ") }})';
exception
    when others then
        if sqlcode not in (-955, -1408) then raise; end if;
end;
        {% endset %}
        {% do run_query(ddl) %}
    {%- endfor -%}
    {%- if hints.get('stats', true) -%}
        {{ return("begin dbms_stats.gather_table_stats(ownname => '" ~ this.schema | upper ~ "', tabname => '" ~ this.identifier | upper ~ "', degree => dbms_stats.auto_degree); end;") }}
    {%- endif -%}
    {{ return('') }}
{% endmacro %}

{% macro snowflake__apply_performance(hints) %}
    {%- if hints.get('cluster_by') -%}
        {{ return('alter table ' ~ this ~ ' cluster by (' ~ hints.cluster_by | join(', ') ~ ')') }}
    {%- endif -%}
    {{ return('') }}
{% endmacro %}

{% macro databricks__apply_performance(hints) %}
    {%- if hints.get('cluster_by') -%}
        {% do run_query('alter table ' ~ this ~ ' cluster by (' ~ hints.cluster_by | join(', ') ~ ')') %}
    {%- endif -%}
    {%- if var('databricks_optimize', false) -%}{{ return('optimize ' ~ this) }}{%- endif -%}
    {{ return('') }}
{% endmacro %}
