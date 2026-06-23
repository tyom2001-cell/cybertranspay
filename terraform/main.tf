terraform {
  required_version = ">= 1.9.0"

  backend "gcs" {
    bucket = "cybertranspay-terraform-state"
    prefix = "terraform/state"
  }
}

module "project_apis" {
  source     = "./modules/project_apis"
  project_id = var.project_id
}

module "artifact_registry" {
  source     = "./modules/artifact_registry"
  project_id = var.project_id
  region     = var.region

  depends_on = [module.project_apis]
}

module "iam" {
  source     = "./modules/iam"
  project_id = var.project_id

  depends_on = [module.project_apis]
}

module "secrets" {
  source     = "./modules/secrets"
  project_id = var.project_id

  api_keys              = var.auth_api_keys
  create_api_key_secret = var.create_auth_secret
  service_account_email = module.iam.service_account_email

  depends_on = [module.project_apis, module.iam]
}

module "cloud_run" {
  source     = "./modules/cloud_run"
  project_id = var.project_id
  region     = var.region

  service_account_email = module.iam.service_account_email
  image_tag             = var.routing_engine_image_tag
  allow_unauthenticated = var.allow_public_routing_api
  auth_required         = var.auth_required
  api_keys_secret_id    = module.secrets.api_keys_secret_id

  depends_on = [module.artifact_registry, module.iam, module.project_apis, module.secrets]
}

module "gke" {
  source     = "./modules/gke"
  project_id = var.project_id
  region     = var.region

  depends_on = [module.project_apis]
}

module "cloud_sql" {
  source     = "./modules/cloud_sql"
  project_id = var.project_id
  region     = var.region

  instance_name     = var.marketplace_db_instance_name
  tier              = var.marketplace_db_tier
  availability_type = var.marketplace_db_ha ? "REGIONAL" : "ZONAL"
  backup_enabled    = var.marketplace_db_backup

  depends_on = [module.project_apis]
}

module "cloud_storage" {
  source     = "./modules/cloud_storage"
  project_id = var.project_id
  region     = var.region

  cdn_enabled = var.marketplace_cdn_enabled

  depends_on = [module.project_apis]
}

# Disabled until GitHub App installation ID is configured.
# module "developer_connect" {
#   source                     = "./modules/developer_connect"
#   project_id                 = var.project_id
#   region                     = var.region
#   github_app_installation_id = var.github_app_installation_id
#
#   depends_on = [module.project_apis]
# }
