output "bucket_name" {
  description = "GCS bucket name for marketplace product images"
  value       = google_storage_bucket.marketplace_images.name
}

output "bucket_url" {
  description = "GCS bucket URL"
  value       = google_storage_bucket.marketplace_images.url
}

output "cdn_backend_name" {
  description = "Cloud CDN backend bucket name (empty if CDN disabled)"
  value       = var.cdn_enabled ? google_compute_backend_bucket.marketplace_cdn[0].name : ""
}
