variable "env" {
  description = "dev | prod"
  type        = string
}

variable "database_name" {
  type    = string
  default = "ANALYTICS"
}

variable "warehouse_size" {
  type    = string
  default = "XSMALL"
}

variable "monthly_credit_quota" {
  type    = number
  default = 100
}

variable "dbt_service_user_public_key" {
  description = "RSA public key (PEM body, no header) for the dbt service user's key-pair auth."
  type        = string
  sensitive   = true
}

variable "data_retention_days" {
  type    = number
  default = 7
}
