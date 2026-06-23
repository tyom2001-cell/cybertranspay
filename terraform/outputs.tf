output "routing_engine_url" {
  description = "Cloud Run URL for the routing engine API"
  value       = module.cloud_run.service_url
}

output "artifact_registry_docker" {
  description = "Docker repository prefix for images"
  value       = module.artifact_registry.docker_repository
}

output "service_account_email" {
  description = "Runtime service account for CyberTransPay workloads"
  value       = module.iam.service_account_email
}

output "marketplace_db_connection_name" {
  description = "Cloud SQL connection name for the marketplace database (use with Cloud SQL Auth Proxy)"
  value       = module.cloud_sql.connection_name
}

output "marketplace_db_private_ip" {
  description = "Private IP of the marketplace Cloud SQL instance"
  value       = module.cloud_sql.private_ip
}

output "marketplace_images_bucket" {
  description = "GCS bucket for marketplace product images"
  value       = module.cloud_storage.bucket_name
}

output "marketplace_images_bucket_url" {
  description = "GCS bucket URL for marketplace product images"
  value       = module.cloud_storage.bucket_url
}

output "marketplace_cdn_backend" {
  description = "Cloud CDN backend bucket name for marketplace images"
  value       = module.cloud_storage.cdn_backend_name
}
