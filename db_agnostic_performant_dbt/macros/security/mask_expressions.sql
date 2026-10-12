{#- Portable masking expressions used by gold/secure views (works on every platform). -#}

{% macro mask_email(col) -%}
case when {{ col }} is null then null else
{{ concat_strings([substr(col, 1, 1), "'***@'", substr(col, str_position("'@'", col) ~ ' + 1', 255)]) }}
end
{%- endmacro %}

{% macro mask_phone(col) -%}
case when {{ col }} is null then null else {{ concat_strings(["'***-***-'", right_chars(col, 4)]) }} end
{%- endmacro %}

{% macro mask_name(col) -%}
case when {{ col }} is null then null else {{ concat_strings([substr(col, 1, 1), "'****'"]) }} end
{%- endmacro %}

{% macro mask_postal_code(col) -%}
case when {{ col }} is null then null else {{ concat_strings([substr(col, 1, 2), "'***'"]) }} end
{%- endmacro %}

{% macro mask_redact(col) -%}
case when {{ col }} is null then null else '*****' end
{%- endmacro %}
