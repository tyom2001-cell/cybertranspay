output "instance_name" {
  description = "Cloud SQL instance name"
  value       = google_sql_database_instance.marketplace.name
}

output "connection_name" {
  description = "Cloud SQL connection name (for Cloud SQL Auth Proxy)"
  value       = google_sql_database_instance.marketplace.connection_name
}

output "database_name" {
  description = "PostgreSQL database name"
  value       = google_sql_database.marketplace.name
}

output "private_ip" {
  description = "Private IP address of the Cloud SQL instance"
  value       = google_sql_database_instance.marketplace.private_ip_address
}
