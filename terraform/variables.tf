variable "project_id" {
  type    = string
  default = "cybertranspay-prod"
}

variable "region" {
  type    = string
  default = "europe-west1"
}

variable "github_app_installation_id" {
  description = "GitHub App Installation ID for Developer Connect"
  type        = number
  default     = 0
}

variable "routing_engine_image_tag" {
  description = "Docker image tag for routing-engine on Cloud Run"
  type        = string
  default     = "latest"
}

variable "allow_public_routing_api" {
  description = "Allow unauthenticated Cloud Run invoke (dev/MVP only)"
  type        = bool
  default     = false
}

variable "auth_required" {
  description = "Require X-API-Key header on /v1/* routes"
  type        = bool
  default     = true
}

variable "auth_api_keys" {
  description = "Comma-separated API keys stored in Secret Manager"
  type        = string
  sensitive   = true
  default     = ""
}

variable "create_auth_secret" {
  description = "Create Secret Manager secret for AUTH_API_KEYS"
  type        = bool
  default     = true
}

# ── Marketplace ───────────────────────────────────────────────────────────────

variable "marketplace_db_instance_name" {
  description = "Cloud SQL instance name for the marketplace PostgreSQL database"
  type        = string
  default     = "marketplace-db"
}

variable "marketplace_db_tier" {
  description = "Cloud SQL machine type for the marketplace database"
  type        = string
  default     = "db-f1-micro"
}

variable "marketplace_db_ha" {
  description = "Enable high-availability (REGIONAL) for the marketplace database"
  type        = bool
  default     = false
}

variable "marketplace_db_backup" {
  description = "Enable automated backups for the marketplace database"
  type        = bool
  default     = true
}

variable "marketplace_cdn_enabled" {
  description = "Enable Cloud CDN for the marketplace product images bucket"
  type        = bool
  default     = true
}

variable "marketplace_image_tag" {
  description = "Docker image tag for the marketplace service on Cloud Run"
  type        = string
  default     = "latest"
}
