locals {
  platform_name = "pomi-exchange-${var.environment}"
  tags = merge({
    Application = "pomi-exchange"
    Environment = var.environment
    ManagedBy   = "OpenTofu"
    Platform    = "pomi"
  }, var.tags)
}

module "platform" {
  source = "../slices/platform/terraform"

  name                        = local.platform_name
  aws_region                  = var.aws_region
  lightsail_availability_zone = var.lightsail_availability_zone
  lightsail_blueprint_id      = var.lightsail_blueprint_id
  lightsail_bundle_id         = var.lightsail_bundle_id
  lightsail_snapshot_time     = var.lightsail_snapshot_time
  lightsail_ssh_public_key    = var.lightsail_ssh_public_key
  ssh_allowed_cidrs           = var.ssh_allowed_cidrs
  exchange_api_domain_name    = var.api_domain_name
  exchange_hosted_zone_name   = var.hosted_zone_name
  tags                        = local.tags
}

module "pomi_exchange" {
  source = "../slices/pomi-exchange/terraform"

  static_ip_address        = module.platform.static_ip_address
  environment              = var.environment
  api_domain_name          = var.api_domain_name
  hosted_zone_name         = var.hosted_zone_name
  vercel_team_id           = var.vercel_team_id
  vercel_project_name      = var.vercel_project_name
  frontend_git_repository  = var.frontend_git_repository
  frontend_root_directory  = var.frontend_root_directory
  frontend_url             = var.frontend_url
  registry_image_retention = var.registry_image_retention
  tags                     = local.tags
}

module "pomi" {
  source = "../slices/pomi/terraform"

  environment              = var.pomi_environment
  static_ip_address        = module.platform.static_ip_address
  backup_bucket_name       = var.pomi_backup_bucket_name
  backup_retention         = var.pomi_backup_retention_days
  registry_image_retention = var.registry_image_retention
  vercel_team_id           = var.vercel_team_id
  frontend_project_name    = var.pomi_frontend_project_name
  frontend_git_repository  = var.pomi_frontend_git_repository
  frontend_root_directory  = var.pomi_frontend_root_directory
  frontend_url             = var.pomi_frontend_url
  data_api_domain_name     = var.pomi_data_api_domain_name
  app_api_domain_name      = var.pomi_app_api_domain_name
  keycloak_domain_name     = var.pomi_keycloak_domain_name
  keycloak_realm           = var.pomi_keycloak_realm
  keycloak_client_id       = var.pomi_keycloak_client_id
  tags                     = local.tags
}
