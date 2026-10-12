variable "name" { type = string }

variable "engine" {
  description = "postgres | sqlserver | oracle (license-included editions; no paid security options)."
  type        = string
  validation {
    condition     = contains(["postgres", "sqlserver", "oracle"], var.engine)
    error_message = "engine must be postgres, sqlserver or oracle."
  }
}

variable "instance_class" {
  type    = string
  default = "db.m6i.large"
}

variable "allocated_storage_gb" {
  type    = number
  default = 100
}

variable "max_allocated_storage_gb" {
  type    = number
  default = 500
}

variable "multi_az" {
  type    = bool
  default = false
}

variable "deletion_protection" {
  type    = bool
  default = true
}

variable "backup_retention_days" {
  type    = number
  default = 7
}

variable "vpc_id" { type = string }
variable "subnet_ids" { type = list(string) }

variable "allowed_cidr_blocks" {
  description = "CIDRs allowed to connect (e.g. the VPC, for MWAA workers)."
  type        = list(string)
}

variable "kms_key_arn" { type = string }

variable "tags" {
  type    = map(string)
  default = {}
}
