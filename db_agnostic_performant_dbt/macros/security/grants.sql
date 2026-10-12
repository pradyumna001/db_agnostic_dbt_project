{#- Roles granted SELECT on a layer; returns {} unless grants are enabled (roles are created by Terraform). -#}
{% macro layer_grants(roles_var) -%}
    {%- if var('enable_grants', false) and var(roles_var, []) | length > 0 -%}
        {{ return({'select': var(roles_var)}) }}
    {%- endif -%}
    {{ return({}) }}
{%- endmacro %}
