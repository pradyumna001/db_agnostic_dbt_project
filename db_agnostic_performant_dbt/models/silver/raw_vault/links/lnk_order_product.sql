{{ config(meta={'perf': {'indexes': [['order_line_hk'], ['order_hk']]}}, as_columnstore=false) }}
{{ link(source_models=['stg_shop__order_lines'], link_hk='order_line_hk', fk=['order_hk', 'product_hk'], dependent_child_keys=['line_number']) }}
