variable "static_ip_address" {
  type = string
}

variable "environment" {
  type = string
}

variable "api_domain_name" {
  type     = string
  nullable = true
}

variable "hosted_zone_name" {
  type     = string
  nullable = true
}

variable "vercel_team_id" {
  type     = string
  nullable = true
}

variable "vercel_project_name" {
  type = string
}

variable "frontend_git_repository" {
  type = string
}

variable "frontend_root_directory" {
  type     = string
  nullable = true
}

variable "frontend_url" {
  type     = string
  nullable = true
}

variable "registry_image_retention" {
  type = number
}

variable "tags" {
  type = map(string)
}
