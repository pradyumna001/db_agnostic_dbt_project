{{ config(meta={'perf': {'indexes': [['order_customer_hk'], ['order_hk']]}}, as_columnstore=false) }}
{{ link(source_models=['stg_shop__orders'], link_hk='order_customer_hk', fk=['order_hk', 'customer_hk']) }}
