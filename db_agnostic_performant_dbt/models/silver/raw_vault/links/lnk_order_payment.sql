{{ config(meta={'perf': {'indexes': [['order_payment_hk'], ['order_hk']]}}, as_columnstore=false) }}
{{ link(source_models=['stg_shop__payments'], link_hk='order_payment_hk', fk=['order_hk', 'payment_hk']) }}
