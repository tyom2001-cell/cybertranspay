locals {
  bucket_name = var.bucket_name != "" ? var.bucket_name : "${var.project_id}-marketplace-images"
}

resource "google_storage_bucket" "marketplace_images" {
  name                        = local.bucket_name
  project                     = var.project_id
  location                    = var.region
  uniform_bucket_level_access = var.uniform_bucket_level_access
  force_destroy               = false

  cors {
    origin          = var.cors_origins
    method          = ["GET", "HEAD"]
    response_header = ["Content-Type", "Content-Length", "ETag"]
    max_age_seconds = 3600
  }

  versioning {
    enabled = var.versioning_enabled
  }

  dynamic "lifecycle_rule" {
    for_each = var.object_lifecycle_days > 0 ? [1] : []
    content {
      action {
        type = "Delete"
      }
      condition {
        age = var.object_lifecycle_days
      }
    }
  }
}

# Make bucket publicly readable so CDN and the Flutter app can load images.
resource "google_storage_bucket_iam_member" "public_reader" {
  bucket = google_storage_bucket.marketplace_images.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

# Backend bucket for Cloud CDN
resource "google_compute_backend_bucket" "marketplace_cdn" {
  count       = var.cdn_enabled ? 1 : 0
  name        = "${local.bucket_name}-cdn"
  project     = var.project_id
  bucket_name = google_storage_bucket.marketplace_images.name
  enable_cdn  = true

  cdn_policy {
    cache_mode        = "CACHE_ALL_STATIC"
    default_ttl       = 3600
    max_ttl           = 86400
    client_ttl        = 3600
    negative_caching  = true
    serve_while_stale = 86400
  }
}
