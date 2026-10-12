{#- Canonical data types. Models cast through these so DDL is portable. -#}

{% macro t_string(n=255) %}{{ return(adapter.dispatch('t_string', 'db_agnostic_performant_dbt')(n)) }}{% endmacro %}
{% macro default__t_string(n) %}varchar({{ n }}){% endmacro %}
{% macro sqlserver__t_string(n) %}nvarchar({{ n }}){% endmacro %}
{% macro oracle__t_string(n) %}varchar2({{ n }} char){% endmacro %}
{% macro databricks__t_string(n) %}string{% endmacro %}

{% macro t_int() %}{{ return(adapter.dispatch('t_int', 'db_agnostic_performant_dbt')()) }}{% endmacro %}
{% macro default__t_int() %}integer{% endmacro %}
{% macro oracle__t_int() %}number(10){% endmacro %}

{% macro t_bigint() %}{{ return(adapter.dispatch('t_bigint', 'db_agnostic_performant_dbt')()) }}{% endmacro %}
{% macro default__t_bigint() %}bigint{% endmacro %}
{% macro oracle__t_bigint() %}number(19){% endmacro %}

{% macro t_decimal(p=18, s=2) %}{{ return(adapter.dispatch('t_decimal', 'db_agnostic_performant_dbt')(p, s)) }}{% endmacro %}
{% macro default__t_decimal(p, s) %}decimal({{ p }}, {{ s }}){% endmacro %}
{% macro oracle__t_decimal(p, s) %}number({{ p }}, {{ s }}){% endmacro %}
{% macro snowflake__t_decimal(p, s) %}number({{ p }}, {{ s }}){% endmacro %}

{% macro t_ts() %}{{ return(adapter.dispatch('t_ts', 'db_agnostic_performant_dbt')()) }}{% endmacro %}
{% macro default__t_ts() %}timestamp{% endmacro %}
{% macro sqlserver__t_ts() %}datetime2(6){% endmacro %}
{% macro oracle__t_ts() %}timestamp(6){% endmacro %}
{% macro snowflake__t_ts() %}timestamp_ntz{% endmacro %}

{% macro t_date() %}date{% endmacro %}

{#- Booleans are modelled as 0/1 integer flags: Oracle (<23ai) and SQL Server have no boolean column type. -#}
{% macro t_flag() %}{{ return(adapter.dispatch('t_flag', 'db_agnostic_performant_dbt')()) }}{% endmacro %}
{% macro default__t_flag() %}smallint{% endmacro %}
{% macro oracle__t_flag() %}number(1){% endmacro %}
{% macro databricks__t_flag() %}tinyint{% endmacro %}

{% macro t_hash() %}{{ return(adapter.dispatch('t_hash', 'db_agnostic_performant_dbt')()) }}{% endmacro %}
{% macro default__t_hash() %}char(64){% endmacro %}
{% macro snowflake__t_hash() %}varchar(64){% endmacro %}
{% macro databricks__t_hash() %}string{% endmacro %}
