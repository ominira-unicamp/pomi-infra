variable "environment" {
  description = "Ambiente físico legado da plataforma POMI; mantido para preservar o nome da instância."
  type        = string
  default     = "production"
}

variable "target_environment" {
  description = "Ambiente lógico selecionado para este state."
  type        = string
  default     = "homolog"

  validation {
    condition     = contains(["homolog", "develop"], var.target_environment)
    error_message = "target_environment deve ser homolog ou develop."
  }
}

variable "platform_resource_name" {
  description = "Nome físico da plataforma Lightsail, separado do ambiente lógico."
  type        = string
  default     = "pomi-exchange-production"
}

variable "aws_region" {
  description = "Região AWS da plataforma compartilhada."
  type        = string
  default     = "sa-east-1"
}

variable "lightsail_availability_zone" {
  type    = string
  default = "sa-east-1a"
}

variable "lightsail_blueprint_id" {
  type    = string
  default = "ubuntu_24_04"
}

variable "lightsail_bundle_id" {
  type    = string
  default = "micro_3_1"
}

variable "lightsail_snapshot_time" {
  type    = string
  default = "06:00"

  validation {
    condition     = can(regex("^([01][0-9]|2[0-3]):00$", var.lightsail_snapshot_time))
    error_message = "lightsail_snapshot_time deve usar uma hora cheia no formato HH:00 em UTC."
  }
}

variable "lightsail_ssh_public_key" {
  type = string
}

variable "ssh_allowed_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "pomi_smtp_password_parameter_name" {
  type    = string
  default = "/pomi/smtp-password"
}

variable "pomi_smtp_host" {
  type = string
}

variable "pomi_smtp_port" {
  type    = number
  default = 587
}

variable "pomi_smtp_user" {
  type = string
}

variable "pomi_smtp_from" {
  type = string
}

variable "pomi_log_level" {
  type    = string
  default = "info"
}

variable "pomi_openobserve_url" {
  type = string

  validation {
    condition     = startswith(var.pomi_openobserve_url, "https://") && !endswith(var.pomi_openobserve_url, "/")
    error_message = "pomi_openobserve_url deve usar HTTPS e não pode terminar com barra."
  }
}

variable "pomi_openobserve_auth_parameter_name" {
  type    = string
  default = "/pomi/openobserve-auth"
}

variable "vercel_team_id" {
  type     = string
  default  = null
  nullable = true
}

variable "pomi_environment" {
  description = "Ambiente sob demanda do planejador POMI."
  type        = string
  default     = "test"
}

variable "pomi_frontend_project_name" {
  type    = string
  default = "pomi-frontend"
}

variable "pomi_frontend_git_repository" {
  type = string
}

variable "pomi_frontend_root_directory" {
  type     = string
  default  = null
  nullable = true
}

variable "pomi_frontend_url" {
  type     = string
  default  = null
  nullable = true
}

variable "pomi_data_api_domain_name" {
  description = "Domínio público da API Data do POMI."
  type        = string
  default     = null
  nullable    = true
}

variable "pomi_app_api_domain_name" {
  description = "Domínio público da API App do POMI."
  type        = string
  default     = null
  nullable    = true
}

variable "pomi_keycloak_domain_name" {
  description = "Domínio público do Keycloak do POMI."
  type        = string
  default     = null
  nullable    = true
}

variable "pomi_keycloak_realm" {
  type    = string
  default = "pomi"
}

variable "pomi_keycloak_client_id" {
  type    = string
  default = "pomi-frontend"
}

variable "pomi_backup_bucket_name" {
  description = "Nome opcional do bucket de backups do PostgreSQL do POMI."
  type        = string
  default     = null
  nullable    = true
}

variable "pomi_backup_retention_days" {
  type    = number
  default = 30

  validation {
    condition     = var.pomi_backup_retention_days >= 1
    error_message = "pomi_backup_retention_days deve ser maior que zero."
  }
}

variable "registry_image_retention" {
  description = "Quantidade de imagens mais recentes preservadas em cada repositório ECR."
  type        = number
  default     = 20

  validation {
    condition     = var.registry_image_retention >= 2
    error_message = "registry_image_retention deve ser pelo menos 2 para permitir rollback."
  }
}

variable "pomi_keycloak_admin_password_parameter_name" {
  type    = string
  default = "/pomi/planner/test/keycloak-admin-password"
}

variable "pomi_postgres_password_parameter_name" {
  type    = string
  default = "/pomi/planner/test/postgres-password"
}

variable "pomi_data_admin_token_parameter_name" {
  type    = string
  default = "/pomi/planner/test/data-admin-token"
}

variable "pomi_notifier_unsubscribe_secret_parameter_name" {
  type    = string
  default = "/pomi/planner/test/notifier-unsubscribe-secret"
}

variable "tags" {
  type    = map(string)
  default = {}
}
