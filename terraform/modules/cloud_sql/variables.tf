variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "instance_name" {
  type    = string
  default = "marketplace-db"
}

variable "database_version" {
  type    = string
  default = "POSTGRES_15"
}

variable "tier" {
  description = "Cloud SQL machine type"
  type        = string
  default     = "db-f1-micro"
}

variable "database_name" {
  type    = string
  default = "marketplace"
}

variable "database_user" {
  type    = string
  default = "marketplace_app"
}

variable "deletion_protection" {
  type    = bool
  default = true
}

variable "availability_type" {
  description = "ZONAL or REGIONAL (HA)"
  type        = string
  default     = "ZONAL"
}

variable "backup_enabled" {
  type    = bool
  default = true
}

variable "backup_start_time" {
  description = "HH:MM format in UTC"
  type        = string
  default     = "03:00"
}
