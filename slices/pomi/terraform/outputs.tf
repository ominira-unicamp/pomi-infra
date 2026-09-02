output "data_api_url" {
  value = local.data_api_url
}

output "frontend_url" {
  value = local.frontend_url
}

output "vercel_project_id" {
  value = vercel_project.frontend.id
}

output "data_api_hostname" {
  value = local.data_api_hostname
}

output "app_api_url" {
  value = local.app_api_url
}

output "app_api_hostname" {
  value = local.app_api_hostname
}

output "keycloak_url" {
  value = local.keycloak_url
}

output "keycloak_hostname" {
  value = local.keycloak_hostname
}

output "backup_bucket" {
  value = aws_s3_bucket.backups.id
}

output "backend_repository_url" {
  value = aws_ecr_repository.backend.repository_url
}

output "injection_repository_url" {
  value = aws_ecr_repository.injection.repository_url
}

output "notifier_repository_url" {
  value = aws_ecr_repository.notifier.repository_url
}

output "smtp_password_parameter_name" { value = var.smtp_password_parameter_name }
output "smtp_host" { value = var.smtp_host }
output "smtp_port" { value = var.smtp_port }
output "smtp_user" { value = var.smtp_user }
output "smtp_from" { value = var.smtp_from }
output "log_level" { value = var.log_level }
output "openobserve_url" { value = var.openobserve_url }
output "openobserve_auth_parameter_name" { value = var.openobserve_auth_parameter_name }
