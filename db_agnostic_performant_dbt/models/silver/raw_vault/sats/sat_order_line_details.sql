{{ config(meta={'perf': {'indexes': [['order_line_hk', 'load_dts']], 'cluster_by': ['load_dts']}}) }}
{{ sat(source_model='stg_shop__order_lines', parent_hk='order_line_hk', hashdiff='order_line_hashdiff',
       payload=['quantity', 'unit_price', 'discount_amount']) }}
