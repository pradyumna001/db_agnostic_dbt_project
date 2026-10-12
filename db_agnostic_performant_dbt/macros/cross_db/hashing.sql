{#-
  Deterministic SHA-256 hashing, identical on every platform for string / integer inputs:
    UPPER(TRIM(value)) -> NULL/'' becomes '^^' -> joined with '||' -> SHA-256 -> 64 char upper-case hex (UTF-8 bytes).
  Hash *keys* are therefore portable across platforms. Hashdiffs over dates/decimals are only
  compared within one platform, so their string formatting may differ between platforms.
-#}

{% macro hash_standardize(expr) -%}
coalesce(nullif(upper(trim(cast({{ expr }} as {{ t_string(4000) }}))), ''), '^^')
{%- endmacro %}

{% macro sha256_hex(expr) %}{{ return(adapter.dispatch('sha256_hex', 'db_agnostic_performant_dbt')(expr)) }}{% endmacro %}
{% macro default__sha256_hex(expr) %}upper(encode(sha256(convert_to({{ expr }}, 'UTF8')), 'hex')){% endmacro %}
{% macro sqlserver__sha256_hex(expr) %}convert(char(64), hashbytes('SHA2_256', cast(({{ expr }}) collate Latin1_General_100_BIN2_UTF8 as varchar(max))), 2){% endmacro %}
{% macro oracle__sha256_hex(expr) %}rawtohex(standard_hash({{ expr }}, 'SHA256')){% endmacro %}
{% macro snowflake__sha256_hex(expr) %}upper(sha2({{ expr }}, 256)){% endmacro %}
{% macro databricks__sha256_hex(expr) %}upper(sha2({{ expr }}, 256)){% endmacro %}

{% macro hash_key(columns) -%}
{%- if columns is string %}{% set columns = [columns] %}{% endif -%}
{%- set parts = [] -%}
{%- for c in columns -%}
  {%- do parts.append(hash_standardize(c)) -%}
  {%- if not loop.last %}{% do parts.append("'||'") %}{% endif -%}
{%- endfor -%}
cast({{ sha256_hex(concat_strings(parts)) }} as {{ t_hash() }})
{%- endmacro %}

{#- Hashdiff: same algorithm, columns sorted so ordering in YAML/SQL does not matter. -#}
{% macro hash_diff(columns) -%}
{{ hash_key(columns | sort) }}
{%- endmacro %}

{% macro zero_key() %}cast('{{ "0" * 64 }}' as {{ t_hash() }}){% endmacro %}

{#- Deterministic tokenization of PII: salted hash, joinable but not reversible without the salt. -#}
{% macro tokenize(expr) -%}
{{ hash_key(["'" ~ env_var('DBT_PII_SALT', 'local-dev-only-salt') ~ "'", expr]) }}
{%- endmacro %}
