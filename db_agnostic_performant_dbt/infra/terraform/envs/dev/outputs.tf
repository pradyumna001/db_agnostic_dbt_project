output "github_ci_role_arn" { value = module.foundation.github_ci_role_arn }
output "artifacts_bucket" { value = module.foundation.artifacts_bucket }
output "rds_endpoints" { value = { for k, m in module.rds : k => m.endpoint } }
output "airflow_bucket" { value = try(module.mwaa[0].airflow_bucket, null) }
output "snowflake_pii_tag" { value = try(module.snowflake[0].pii_tag, null) }
output "databricks_http_path" { value = try(module.databricks[0].http_path, null) }
