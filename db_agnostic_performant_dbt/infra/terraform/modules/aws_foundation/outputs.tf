output "vpc_id" { value = module.vpc.vpc_id }
output "vpc_cidr" { value = module.vpc.vpc_cidr_block }
output "private_subnet_ids" { value = module.vpc.private_subnets }
output "kms_key_arn" { value = aws_kms_key.this.arn }
output "artifacts_bucket" { value = aws_s3_bucket.artifacts.bucket }
output "artifacts_bucket_arn" { value = aws_s3_bucket.artifacts.arn }
output "github_ci_role_arn" { value = aws_iam_role.github_ci.arn }
output "github_ci_role_name" { value = aws_iam_role.github_ci.name }
output "pii_salt_secret_arn" { value = aws_secretsmanager_secret.pii_salt.arn }
output "warehouse_secret_arns" { value = { for k, s in aws_secretsmanager_secret.warehouse : k => s.arn } }
