{{ config(meta={'perf': {'indexes': [['product_hk', 'load_dts']]}}) }}
{{ sat(source_model='stg_shop__products', parent_hk='product_hk', hashdiff='product_hashdiff',
       payload=['sku', 'product_name', 'category', 'brand', 'list_price', 'unit_cost', 'is_active']) }}
