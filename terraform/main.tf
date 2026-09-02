locals {
  platform_name = "pomi-exchange-${var.environment}"
  tags = merge({
    Application = "pomi"
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
  tags                        = local.tags
}

module "pomi" {
  source = "../slices/pomi/terraform"

  environment                     = var.pomi_environment
  static_ip_address               = module.platform.static_ip_address
  backup_bucket_name              = var.pomi_backup_bucket_name
  backup_retention                = var.pomi_backup_retention_days
  registry_image_retention        = var.registry_image_retention
  vercel_team_id                  = var.vercel_team_id
  frontend_project_name           = var.pomi_frontend_project_name
  frontend_git_repository         = var.pomi_frontend_git_repository
  frontend_root_directory         = var.pomi_frontend_root_directory
  frontend_url                    = var.pomi_frontend_url
  data_api_domain_name            = var.pomi_data_api_domain_name
  app_api_domain_name             = var.pomi_app_api_domain_name
  keycloak_domain_name            = var.pomi_keycloak_domain_name
  keycloak_realm                  = var.pomi_keycloak_realm
  keycloak_client_id              = var.pomi_keycloak_client_id
  smtp_password_parameter_name    = var.pomi_smtp_password_parameter_name
  smtp_host                       = var.pomi_smtp_host
  smtp_port                       = var.pomi_smtp_port
  smtp_user                       = var.pomi_smtp_user
  smtp_from                       = var.pomi_smtp_from
  log_level                       = var.pomi_log_level
  openobserve_url                 = var.pomi_openobserve_url
  openobserve_auth_parameter_name = var.pomi_openobserve_auth_parameter_name
  tags                            = local.tags
}
