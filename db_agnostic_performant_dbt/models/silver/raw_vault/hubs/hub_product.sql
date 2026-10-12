{{ config(meta={'perf': {'indexes': [['product_hk']]}}, as_columnstore=false) }}
{{ hub(source_models=['stg_shop__products', 'stg_shop__order_lines'], hk='product_hk', bk=['product_id']) }}
