variable "name" {
  description = "Name prefix for all resources, e.g. dbt-agnostic-dev."
  type        = string
}

variable "vpc_cidr" {
  type    = string
  default = "10.40.0.0/16"
}

variable "azs" {
  description = "Two or more availability zones (MWAA and Multi-AZ RDS need two)."
  type        = list(string)
}

variable "github_repository" {
  description = "owner/repo allowed to assume the CI role via OIDC."
  type        = string
}

variable "github_oidc_subjects" {
  description = "Allowed OIDC sub claims, e.g. pull requests and the main branch."
  type        = list(string)
  default     = ["pull_request", "ref:refs/heads/main", "environment:prod"]
}

variable "create_github_oidc_provider" {
  description = "Set false if the account already has the GitHub OIDC provider."
  type        = bool
  default     = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
