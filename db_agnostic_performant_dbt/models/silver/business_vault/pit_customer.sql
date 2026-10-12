{{ config(
    materialized='incremental',
    incremental_strategy='append',
    meta={'perf': {'indexes': [['customer_hk', 'as_of_date']], 'cluster_by': ['as_of_date']}}
) }}
{{ pit(hub_model='hub_customer', hk='customer_hk', satellites=['sat_customer_details', 'sat_customer_pii'], as_of_model='as_of_dates') }}
