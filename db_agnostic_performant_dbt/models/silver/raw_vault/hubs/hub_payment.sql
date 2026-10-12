{{ config(meta={'perf': {'indexes': [['payment_hk']]}}, as_columnstore=false) }}
{{ hub(source_models=['stg_shop__payments'], hk='payment_hk', bk=['payment_id']) }}
