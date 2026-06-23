variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "bucket_name" {
  description = "GCS bucket name for marketplace product images"
  type        = string
  default     = ""
}

variable "cdn_enabled" {
  description = "Enable Cloud CDN for the product images bucket"
  type        = bool
  default     = true
}

variable "cors_origins" {
  description = "Allowed CORS origins for the storage bucket"
  type        = list(string)
  default     = ["*"]
}

variable "uniform_bucket_level_access" {
  type    = bool
  default = true
}

variable "versioning_enabled" {
  type    = bool
  default = false
}

variable "object_lifecycle_days" {
  description = "Delete objects older than this many days (0 = disabled)"
  type        = number
  default     = 0
}
