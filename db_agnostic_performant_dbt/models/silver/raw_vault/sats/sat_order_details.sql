{{ config(meta={'perf': {'indexes': [['order_hk', 'load_dts']], 'cluster_by': ['load_dts']}}) }}
{{ sat(source_model='stg_shop__orders', parent_hk='order_hk', hashdiff='order_hashdiff',
       payload=['order_ts', 'order_status', 'channel', 'currency_code', 'shipping_amount']) }}
