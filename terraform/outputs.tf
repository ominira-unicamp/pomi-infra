output "lightsail_instance_name" {
  value = module.platform.instance_name
}

output "target_environment" {
  value = var.target_environment
}

output "lightsail_static_ip" {
  value = module.platform.static_ip_address
}

output "lightsail_ssh_user" {
  value = module.platform.ssh_user
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

output "pomi_backend_repository_url" {
  value = module.pomi.backend_repository_url
}

output "pomi_injection_repository_url" {
  value = module.pomi.injection_repository_url
}

output "pomi_notifier_repository_url" {
  value = module.pomi.notifier_repository_url
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

output "pomi_notifier_unsubscribe_secret_parameter_name" {
  value = var.pomi_notifier_unsubscribe_secret_parameter_name
}

output "pomi_smtp_password_parameter_name" { value = module.pomi.smtp_password_parameter_name }
output "pomi_openobserve_auth_parameter_name" { value = module.pomi.openobserve_auth_parameter_name }
output "pomi_smtp_host" { value = module.pomi.smtp_host }
output "pomi_smtp_port" { value = module.pomi.smtp_port }
output "pomi_smtp_user" { value = module.pomi.smtp_user }
output "pomi_smtp_from" { value = module.pomi.smtp_from }
output "pomi_openobserve_url" { value = module.pomi.openobserve_url }
output "pomi_log_level" { value = module.pomi.log_level }
