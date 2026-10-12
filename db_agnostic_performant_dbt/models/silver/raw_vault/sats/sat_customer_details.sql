{{ config(meta={'perf': {'indexes': [['customer_hk', 'load_dts']], 'cluster_by': ['load_dts']}}) }}
{{ sat(source_model='stg_shop__customers', parent_hk='customer_hk', hashdiff='customer_details_hashdiff',
       payload=['customer_segment', 'country_code', 'created_at']) }}
