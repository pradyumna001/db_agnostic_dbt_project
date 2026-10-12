{#- Daily as-of dates for PITs: every day that received data. -#}
select distinct {{ to_date_day('s.load_dts') }} as as_of_date
from {{ ref('sat_customer_details') }} s
union
select distinct {{ to_date_day('p.load_dts') }} as as_of_date
from {{ ref('sat_customer_pii') }} p
