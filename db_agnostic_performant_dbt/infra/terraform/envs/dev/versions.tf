terraform {
  required_version = ">= 1.6"
  # Partial config: bucket/key/region/dynamodb_table are passed with -backend-config in CI.
  backend "s3" {}
  required_providers {
    aws        = { source = "hashicorp/aws", version = "~> 5.70" }
    random     = { source = "hashicorp/random", version = "~> 3.6" }
    snowflake  = { source = "snowflakedb/snowflake", version = "~> 1.0" }
    databricks = { source = "databricks/databricks", version = "~> 1.58" }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags { tags = local.tags }
}

# Snowflake / Databricks providers read credentials from SNOWFLAKE_* / DATABRICKS_* env vars.
provider "snowflake" {}
provider "databricks" {}
