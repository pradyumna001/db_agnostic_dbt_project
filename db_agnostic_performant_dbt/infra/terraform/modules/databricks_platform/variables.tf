variable "env" { type = string }

variable "catalog_name" {
  type    = string
  default = "analytics"
}

variable "catalog_storage_root" {
  description = "Optional managed storage location (s3://...) for the catalog."
  type        = string
  default     = null
}

variable "warehouse_size" {
  type    = string
  default = "2X-Small"
}

variable "max_clusters" {
  type    = number
  default = 2
}
