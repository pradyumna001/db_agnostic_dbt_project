{{ config(meta={'perf': {'indexes': [['customer_hk']]}}, as_columnstore=false) }}
{{ hub(source_models=['stg_shop__customers', 'stg_shop__orders'], hk='customer_hk', bk=['customer_id']) }}
