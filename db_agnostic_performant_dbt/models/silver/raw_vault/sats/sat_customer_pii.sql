{#- PII is isolated in its own satellite: access can be restricted and erasure requests handled in one place. -#}
{{ config(meta={'perf': {'indexes': [['customer_hk', 'load_dts']]}}, tags=['pii']) }}
{{ sat(source_model='stg_shop__customers', parent_hk='customer_hk', hashdiff='customer_pii_hashdiff',
       payload=['first_name', 'last_name', 'email', 'phone', 'date_of_birth', 'address_line1', 'city', 'state_code', 'postal_code']) }}
