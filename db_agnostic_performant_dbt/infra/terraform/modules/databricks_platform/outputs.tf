output "catalog" { value = databricks_catalog.analytics.name }
output "http_path" { value = databricks_sql_endpoint.transform.odbc_params[0].path }
output "service_principal_application_id" { value = databricks_service_principal.dbt.application_id }
output "pii_reader_group" { value = databricks_group.group["pii_readers"].display_name }
