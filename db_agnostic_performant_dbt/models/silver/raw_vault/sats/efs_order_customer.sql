{{ config(meta={'perf': {'indexes': [['order_hk', 'load_dts']]}}) }}
{{ eff_sat(source_model='stg_shop__orders', link_hk='order_customer_hk', driving_key='order_hk', secondary_fks=['customer_hk']) }}
