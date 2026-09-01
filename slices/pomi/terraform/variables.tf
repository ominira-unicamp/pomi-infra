variable "environment" {
  type = string
}

variable "vercel_team_id" {
  type     = string
  nullable = true
}

variable "frontend_project_name" {
  type    = string
  default = "pomi-frontend"
}

variable "frontend_git_repository" {
  type = string
}

variable "frontend_root_directory" {
  type     = string
  default  = null
  nullable = true
}

variable "frontend_url" {
  type     = string
  default  = null
  nullable = true
}

variable "data_api_domain_name" {
  type     = string
  default  = null
  nullable = true
}

variable "app_api_domain_name" {
  type     = string
  default  = null
  nullable = true
}

variable "keycloak_domain_name" {
  type     = string
  default  = null
  nullable = true
}

variable "keycloak_realm" {
  type    = string
  default = "pomi"
}

variable "keycloak_client_id" {
  type    = string
  default = "pomi-frontend"
}

variable "static_ip_address" {
  type = string
}

variable "backup_bucket_name" {
  type     = string
  nullable = true
}

variable "backup_retention" {
  type = number
}

variable "registry_image_retention" {
  type = number
}

variable "tags" {
  type = map(string)
}
