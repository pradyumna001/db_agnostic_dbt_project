locals {
  env  = "dev"
  name = "dbt-agnostic-${local.env}"
  tags = { project = "db_agnostic_performant_dbt", env = local.env, managed_by = "terraform" }
}

module "foundation" {
  source            = "../../modules/aws_foundation"
  name              = local.name
  azs               = var.azs
  github_repository = var.github_repository
  tags              = local.tags
}

module "rds" {
  source   = "../../modules/aws_rds"
  for_each = var.rds_engines

  name                = "${local.name}-${each.key}"
  engine              = each.key
  instance_class      = "db.t3.medium"
  multi_az            = false
  deletion_protection = false
  vpc_id              = module.foundation.vpc_id
  subnet_ids          = module.foundation.private_subnet_ids
  allowed_cidr_blocks = [module.foundation.vpc_cidr]
  kms_key_arn         = module.foundation.kms_key_arn
  tags                = local.tags
}

module "mwaa" {
  source = "../../modules/aws_mwaa"
  count  = var.enable_mwaa ? 1 : 0

  name               = local.name
  vpc_id             = module.foundation.vpc_id
  private_subnet_ids = module.foundation.private_subnet_ids
  kms_key_arn        = module.foundation.kms_key_arn
  secret_name_prefix = local.name
  environment_class  = "mw1.small"
  max_workers        = 2
  tags               = local.tags
}

module "snowflake" {
  source = "../../modules/snowflake_platform"
  count  = var.enable_snowflake ? 1 : 0

  env                         = local.env
  warehouse_size              = "XSMALL"
  monthly_credit_quota        = 50
  data_retention_days         = 1
  dbt_service_user_public_key = var.snowflake_dbt_public_key
}

module "databricks" {
  source = "../../modules/databricks_platform"
  count  = var.enable_databricks ? 1 : 0

  env            = local.env
  warehouse_size = "2X-Small"
  max_clusters   = 1
}
