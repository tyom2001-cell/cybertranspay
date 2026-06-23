resource "google_sql_database_instance" "marketplace" {
  name             = var.instance_name
  project          = var.project_id
  region           = var.region
  database_version = var.database_version
  deletion_protection = var.deletion_protection

  settings {
    tier              = var.tier
    availability_type = var.availability_type

    backup_configuration {
      enabled    = var.backup_enabled
      start_time = var.backup_start_time
      backup_retention_settings {
        retained_backups = 7
      }
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = "projects/${var.project_id}/global/networks/default"
    }

    database_flags {
      name  = "max_connections"
      value = "100"
    }

    insights_config {
      query_insights_enabled  = true
      query_string_length     = 1024
      record_application_tags = true
      record_client_address   = false
    }
  }
}

resource "google_sql_database" "marketplace" {
  name     = var.database_name
  instance = google_sql_database_instance.marketplace.name
  project  = var.project_id
}

resource "google_sql_user" "app_user" {
  name     = var.database_user
  instance = google_sql_database_instance.marketplace.name
  project  = var.project_id
  # Password is managed via Secret Manager — set to empty here so Terraform
  # does not manage or expose it in state.
  password = null
}
