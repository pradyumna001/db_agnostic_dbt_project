{#- Masked view of dim_customer for general consumers (works on every platform). -#}
select
    c.customer_sk,
    c.customer_hk,
    {{ tokenize('c.customer_id') }} as customer_token,
    c.customer_segment,
    c.country_code,
    {{ mask_name('c.first_name') }} as first_name,
    {{ mask_name('c.last_name') }} as last_name,
    {{ mask_email('c.email') }} as email,
    {{ mask_phone('c.phone') }} as phone,
    {{ date_part_int('year', 'c.date_of_birth') }} as birth_year,
    c.city,
    c.state_code,
    {{ mask_postal_code('c.postal_code') }} as postal_code,
    c.effective_from,
    c.effective_to,
    c.is_current
from {{ ref('dim_customer') }} c
