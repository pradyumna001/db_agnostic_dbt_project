variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "azs" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

variable "github_repository" {
  type    = string
  default = "pradyumna001/db_agnostic_dbt_project"
}

variable "rds_engines" {
  description = "Which RDS engines to provision for this environment."
  type        = set(string)
}

variable "enable_mwaa" {
  type    = bool
  default = true
}

variable "enable_snowflake" {
  type    = bool
  default = true
}

variable "enable_databricks" {
  type    = bool
  default = true
}

variable "snowflake_dbt_public_key" {
  type      = string
  sensitive = true
  default   = ""
}
