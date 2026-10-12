output "airflow_bucket" { value = aws_s3_bucket.airflow.bucket }
output "airflow_bucket_arn" { value = aws_s3_bucket.airflow.arn }
output "webserver_url" { value = aws_mwaa_environment.this.webserver_url }
output "execution_role_arn" { value = aws_iam_role.execution.arn }
output "security_group_id" { value = aws_security_group.mwaa.id }
