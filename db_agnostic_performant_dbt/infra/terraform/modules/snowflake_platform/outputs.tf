output "database" { value = snowflake_database.analytics.name }
output "warehouse" { value = snowflake_warehouse.transform.name }
output "transformer_role" { value = snowflake_account_role.role["TRANSFORMER"].name }
output "pii_reader_role" { value = snowflake_account_role.role["PII_READER"].name }
output "pii_tag" { value = "${snowflake_database.analytics.name}.GOVERNANCE.PII_CLASS" }
output "service_user" { value = snowflake_service_user.dbt.name }
