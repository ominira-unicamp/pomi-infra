output "api_url" {
  value = local.api_url
}

output "api_hostname" {
  value = local.api_hostname
}

output "frontend_url" {
  value = local.frontend_url
}

output "vercel_project_id" {
  value = vercel_project.frontend.id
}

output "backend_repository_url" {
  value = aws_ecr_repository.backend.repository_url
}
