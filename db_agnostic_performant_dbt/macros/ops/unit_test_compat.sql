{#- Oracle rejects identifiers starting with "_", which dbt-core's default unit-test SQL uses as subquery aliases. -#}
{% macro oracle__get_unit_test_sql(main_sql, expected_fixture_sql, expected_column_names) -%}
with dbt_internal_unit_test_actual as (
  select
    {% for c in expected_column_names %}{{ c }}{% if not loop.last %}, {% endif %}{% endfor %}, {{ dbt.string_literal("actual") }} as {{ adapter.quote("actual_or_expected") }}
  from (
    {{ main_sql }}
  ) dbt_ut_actual
),
dbt_internal_unit_test_expected as (
  select
    {% for c in expected_column_names %}{{ c }}{% if not loop.last %}, {% endif %}{% endfor %}, {{ dbt.string_literal("expected") }} as {{ adapter.quote("actual_or_expected") }}
  from (
    {{ expected_fixture_sql }}
  ) dbt_ut_expected
)
select * from dbt_internal_unit_test_actual
union all
select * from dbt_internal_unit_test_expected
{%- endmacro %}
