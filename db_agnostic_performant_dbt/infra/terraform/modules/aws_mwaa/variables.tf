variable "name" { type = string }
variable "vpc_id" { type = string }

variable "private_subnet_ids" {
  description = "Exactly two private subnets in different AZs."
  type        = list(string)
}

variable "kms_key_arn" { type = string }

variable "airflow_version" {
  type    = string
  default = "2.10.3"
}

variable "environment_class" {
  type    = string
  default = "mw1.small"
}

variable "max_workers" {
  type    = number
  default = 5
}

variable "secret_name_prefix" {
  description = "Secrets Manager prefix the Airflow secrets backend may read (e.g. dbt-agnostic-prod)."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
