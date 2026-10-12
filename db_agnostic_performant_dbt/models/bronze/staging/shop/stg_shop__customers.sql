with src as (
    select * from {{ source('shop', 'customers') }}
),

typed as (
    select
        cast(customer_id as {{ t_string(20) }}) as customer_id,
        cast(trim(first_name) as {{ t_string(100) }}) as first_name,
        cast(trim(last_name) as {{ t_string(100) }}) as last_name,
        cast(lower(trim(email)) as {{ t_string(255) }}) as email,
        cast(phone as {{ t_string(30) }}) as phone,
        cast(date_of_birth as {{ t_date() }}) as date_of_birth,
        cast(address_line1 as {{ t_string(255) }}) as address_line1,
        cast(city as {{ t_string(100) }}) as city,
        cast(state as {{ t_string(10) }}) as state_code,
        cast(postal_code as {{ t_string(20) }}) as postal_code,
        cast(country as {{ t_string(2) }}) as country_code,
        cast(upper(customer_segment) as {{ t_string(30) }}) as customer_segment,
        cast(created_at as {{ t_ts() }}) as created_at,
        cast(updated_at as {{ t_ts() }}) as updated_at,
        cast(loaded_at as {{ t_ts() }}) as load_dts,
        cast('{{ var("record_source_prefix") }}.CUSTOMERS' as {{ t_string(50) }}) as record_source
    from src
)

select
    t.*,
    {{ hash_key(['t.customer_id']) }} as customer_hk,
    {{ hash_diff(['t.customer_segment', 't.country_code', 't.created_at']) }} as customer_details_hashdiff,
    {{ hash_diff(['t.first_name', 't.last_name', 't.email', 't.phone', 't.date_of_birth', 't.address_line1', 't.city', 't.state_code', 't.postal_code']) }} as customer_pii_hashdiff
from typed t
