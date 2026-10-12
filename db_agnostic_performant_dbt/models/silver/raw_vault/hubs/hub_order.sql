{{ config(meta={'perf': {'indexes': [['order_hk']]}}, as_columnstore=false) }}
{{ hub(source_models=['stg_shop__orders', 'stg_shop__order_lines', 'stg_shop__payments'], hk='order_hk', bk=['order_id']) }}
