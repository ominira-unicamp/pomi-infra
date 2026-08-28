output "api_url" {
  value = module.pomi_exchange.api_url
}

output "api_hostname" {
  value = module.pomi_exchange.api_hostname
}

output "frontend_url" {
  value = module.pomi_exchange.frontend_url
}

output "lightsail_instance_name" {
  value = module.platform.instance_name
}

output "lightsail_static_ip" {
  value = module.platform.static_ip_address
}

output "lightsail_ssh_user" {
  value = module.platform.ssh_user
}

output "vercel_project_id" {
  value = module.pomi_exchange.vercel_project_id
}

output "aws_resource_group_name" {
  value = module.platform.resource_group_name
}

output "deployment_target" {
  value = module.platform.deployment_target
}

output "pomi_data_api_url" {
  value = module.pomi.data_api_url
}

output "pomi_frontend_url" {
  value = module.pomi.frontend_url
}

output "pomi_vercel_project_id" {
  value = module.pomi.vercel_project_id
}

output "pomi_data_api_hostname" {
  value = module.pomi.data_api_hostname
}

output "pomi_app_api_url" {
  value = module.pomi.app_api_url
}

output "pomi_app_api_hostname" {
  value = module.pomi.app_api_hostname
}

output "pomi_keycloak_url" {
  value = module.pomi.keycloak_url
}

output "pomi_keycloak_hostname" {
  value = module.pomi.keycloak_hostname
}

output "pomi_backup_bucket" {
  value = module.pomi.backup_bucket
}

output "exchange_backend_repository_url" {
  value = module.pomi_exchange.backend_repository_url
}

output "pomi_backend_repository_url" {
  value = module.pomi.backend_repository_url
}

output "pomi_injection_repository_url" {
  value = module.pomi.injection_repository_url
}

output "aws_region" {
  value = var.aws_region
}

output "pomi_keycloak_admin_password_parameter_name" {
  value = var.pomi_keycloak_admin_password_parameter_name
}

output "pomi_postgres_password_parameter_name" {
  value = var.pomi_postgres_password_parameter_name
}

output "pomi_data_admin_token_parameter_name" {
  value = var.pomi_data_admin_token_parameter_name
}

output "exchange_jwt_parameter_name" {
  value = var.jwt_parameter_name
}

output "exchange_admin_api_key_parameter_name" {
  value = var.admin_api_key_parameter_name
}

output "exchange_smtp_password_parameter_name" {
  value = var.smtp_password_parameter_name
}

output "exchange_openobserve_auth_parameter_name" {
  value = var.openobserve_auth_parameter_name
}

output "exchange_smtp_host" {
  value = var.smtp_host
}

output "exchange_smtp_port" {
  value = var.smtp_port
}

output "exchange_smtp_user" {
  value = var.smtp_user
}

output "exchange_smtp_from" {
  value = var.smtp_from
}

output "exchange_openobserve_url" {
  value = var.openobserve_url
}

output "exchange_log_level" {
  value = var.log_level
}

output "exchange_vercel_project_name" {
  value = var.vercel_project_name
}

output "exchange_vercel_team_id" {
  value = var.vercel_team_id
}
