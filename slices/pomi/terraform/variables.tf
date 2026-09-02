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

variable "smtp_password_parameter_name" { type = string }
variable "smtp_host" { type = string }
variable "smtp_port" { type = number }
variable "smtp_user" { type = string }
variable "smtp_from" { type = string }
variable "log_level" { type = string }

variable "openobserve_s3_bucket_name" {
  type = string
}

variable "openobserve_s3_access_key_parameter_name" { type = string }
variable "openobserve_s3_secret_key_parameter_name" { type = string }
variable "openobserve_root_password_parameter_name" { type = string }

variable "registry_image_retention" {
  type = number
}

variable "tags" {
  type = map(string)
}
