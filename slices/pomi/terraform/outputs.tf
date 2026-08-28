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
