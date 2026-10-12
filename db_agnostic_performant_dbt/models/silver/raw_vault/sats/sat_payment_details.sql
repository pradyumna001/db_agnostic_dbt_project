{{ config(meta={'perf': {'indexes': [['payment_hk', 'load_dts']]}}) }}
{{ sat(source_model='stg_shop__payments', parent_hk='payment_hk', hashdiff='payment_hashdiff',
       payload=['payment_method', 'card_last4', 'payment_amount', 'paid_ts', 'payment_status']) }}
