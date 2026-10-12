{#- Small cross-database expression helpers. -#}

{#- `from dual` where the dialect needs a FROM clause for constant selects. -#}
{% macro from_dual() %}{{ return(adapter.dispatch('from_dual', 'db_agnostic_performant_dbt')()) }}{% endmacro %}
{% macro default__from_dual() %}{% endmacro %}
{% macro oracle__from_dual() %}from dual{% endmacro %}

{% macro concat_strings(exprs) %}{{ return(adapter.dispatch('concat_strings', 'db_agnostic_performant_dbt')(exprs)) }}{% endmacro %}
{% macro default__concat_strings(exprs) %}({{ exprs | join(' || ') }}){% endmacro %}
{% macro sqlserver__concat_strings(exprs) %}{% if exprs | length == 1 %}({{ exprs[0] }}){% else %}concat({{ exprs | join(', ') }}){% endif %}{% endmacro %}

{% macro ts_literal(value) %}{{ return(adapter.dispatch('ts_literal', 'db_agnostic_performant_dbt')(value)) }}{% endmacro %}
{% macro default__ts_literal(value) %}timestamp '{{ value }}'{% endmacro %}
{% macro sqlserver__ts_literal(value) %}cast('{{ value }}' as datetime2(6)){% endmacro %}
{% macro snowflake__ts_literal(value) %}'{{ value }}'::timestamp_ntz{% endmacro %}

{% macro date_literal(value) %}{{ return(adapter.dispatch('date_literal', 'db_agnostic_performant_dbt')(value)) }}{% endmacro %}
{% macro default__date_literal(value) %}date '{{ value }}'{% endmacro %}
{% macro sqlserver__date_literal(value) %}cast('{{ value }}' as date){% endmacro %}

{% macro ghost_ts() %}{{ ts_literal('1900-01-01 00:00:00') }}{% endmacro %}
{% macro end_of_time_date() %}{{ date_literal('9999-12-31') }}{% endmacro %}

{#- Truncate a timestamp to a date (Oracle DATE keeps time, so trunc() is required). -#}
{% macro to_date_day(expr) %}{{ return(adapter.dispatch('to_date_day', 'db_agnostic_performant_dbt')(expr)) }}{% endmacro %}
{% macro default__to_date_day(expr) %}cast({{ expr }} as date){% endmacro %}
{% macro oracle__to_date_day(expr) %}trunc({{ expr }}){% endmacro %}

{% macro add_days(date_expr, n_expr) %}{{ return(adapter.dispatch('add_days', 'db_agnostic_performant_dbt')(date_expr, n_expr)) }}{% endmacro %}
{% macro default__add_days(date_expr, n_expr) %}cast({{ date_expr }} + ({{ n_expr }}) * interval '1 day' as date){% endmacro %}
{% macro sqlserver__add_days(date_expr, n_expr) %}dateadd(day, {{ n_expr }}, {{ date_expr }}){% endmacro %}
{% macro oracle__add_days(date_expr, n_expr) %}({{ date_expr }} + ({{ n_expr }})){% endmacro %}
{% macro snowflake__add_days(date_expr, n_expr) %}dateadd(day, {{ n_expr }}, {{ date_expr }}){% endmacro %}
{% macro databricks__add_days(date_expr, n_expr) %}date_add({{ date_expr }}, {{ n_expr }}){% endmacro %}

{% macro add_hours(ts_expr, n) %}{{ return(adapter.dispatch('add_hours', 'db_agnostic_performant_dbt')(ts_expr, n)) }}{% endmacro %}
{% macro default__add_hours(ts_expr, n) %}({{ ts_expr }} + interval '{{ n }}' hour){% endmacro %}
{% macro postgres__add_hours(ts_expr, n) %}({{ ts_expr }} + interval '{{ n }} hours'){% endmacro %}
{% macro sqlserver__add_hours(ts_expr, n) %}dateadd(hour, {{ n }}, {{ ts_expr }}){% endmacro %}
{% macro snowflake__add_hours(ts_expr, n) %}dateadd(hour, {{ n }}, {{ ts_expr }}){% endmacro %}

{#- Date part as integer. part in: year, quarter, month, day -#}
{% macro date_part_int(part, expr) %}{{ return(adapter.dispatch('date_part_int', 'db_agnostic_performant_dbt')(part, expr)) }}{% endmacro %}
{% macro default__date_part_int(part, expr) %}cast(extract({{ part }} from {{ expr }}) as {{ t_int() }}){% endmacro %}
{% macro sqlserver__date_part_int(part, expr) %}datepart({{ part }}, {{ expr }}){% endmacro %}
{% macro oracle__date_part_int(part, expr) %}{% if part == 'quarter' %}cast(to_char({{ expr }}, 'Q') as number(10)){% else %}extract({{ part }} from {{ expr }}){% endif %}{% endmacro %}
{% macro databricks__date_part_int(part, expr) %}{{ part }}({{ expr }}){% endmacro %}

{#- ISO day of week: 1 = Monday ... 7 = Sunday, independent of session settings. -#}
{% macro iso_day_of_week(expr) %}{{ return(adapter.dispatch('iso_day_of_week', 'db_agnostic_performant_dbt')(expr)) }}{% endmacro %}
{% macro default__iso_day_of_week(expr) %}cast(extract(isodow from {{ expr }}) as integer){% endmacro %}
{% macro sqlserver__iso_day_of_week(expr) %}(((datepart(weekday, {{ expr }}) + @@datefirst - 2) % 7) + 1){% endmacro %}
{% macro oracle__iso_day_of_week(expr) %}(trunc({{ expr }}) - trunc({{ expr }}, 'IW') + 1){% endmacro %}
{% macro snowflake__iso_day_of_week(expr) %}dayofweekiso({{ expr }}){% endmacro %}
{% macro databricks__iso_day_of_week(expr) %}(weekday({{ expr }}) + 1){% endmacro %}

{#- yyyymmdd integer surrogate key for dates. -#}
{% macro date_key(expr) %}({{ date_part_int('year', expr) }} * 10000 + {{ date_part_int('month', expr) }} * 100 + {{ date_part_int('day', expr) }}){% endmacro %}

{% macro str_position(substring, string) %}{{ return(adapter.dispatch('str_position', 'db_agnostic_performant_dbt')(substring, string)) }}{% endmacro %}
{% macro default__str_position(substring, string) %}position({{ substring }} in {{ string }}){% endmacro %}
{% macro sqlserver__str_position(substring, string) %}charindex({{ substring }}, {{ string }}){% endmacro %}
{% macro oracle__str_position(substring, string) %}instr({{ string }}, {{ substring }}){% endmacro %}
{% macro databricks__str_position(substring, string) %}instr({{ string }}, {{ substring }}){% endmacro %}

{% macro substr(string, start, length=none) %}{{ return(adapter.dispatch('substr', 'db_agnostic_performant_dbt')(string, start, length)) }}{% endmacro %}
{% macro default__substr(string, start, length) %}substr({{ string }}, {{ start }}{% if length is not none %}, {{ length }}{% endif %}){% endmacro %}
{% macro sqlserver__substr(string, start, length) %}substring({{ string }}, {{ start }}, {{ length if length is not none else 4000 }}){% endmacro %}
{% macro postgres__substr(string, start, length) %}substring({{ string }} from {{ start }}{% if length is not none %} for {{ length }}{% endif %}){% endmacro %}

{% macro str_length(string) %}{{ return(adapter.dispatch('str_length', 'db_agnostic_performant_dbt')(string)) }}{% endmacro %}
{% macro default__str_length(string) %}length({{ string }}){% endmacro %}
{% macro sqlserver__str_length(string) %}len({{ string }}){% endmacro %}

{% macro right_chars(string, n) %}{{ substr(string, str_length(string) ~ ' - ' ~ (n - 1)) }}{% endmacro %}

{#- Keep the first row per partition (no QUALIFY outside Snowflake/Databricks). -#}
{% macro dedupe(relation_sql, partition_by, order_by, alias='d') %}
select * from (
    select {{ alias }}_src.*, row_number() over (partition by {{ partition_by | join(', ') }} order by {{ order_by }}) as dedupe_rn
    from ({{ relation_sql }}) {{ alias }}_src
) {{ alias }}
where {{ alias }}.dedupe_rn = 1
{% endmacro %}

{#- Incremental strategy that upserts on unique_key on each platform. -#}
{% macro upsert_strategy() %}{{ return(adapter.dispatch('upsert_strategy', 'db_agnostic_performant_dbt')()) }}{% endmacro %}
{% macro default__upsert_strategy() %}{{ return('merge') }}{% endmacro %}
{% macro postgres__upsert_strategy() %}{{ return('delete+insert') }}{% endmacro %}
