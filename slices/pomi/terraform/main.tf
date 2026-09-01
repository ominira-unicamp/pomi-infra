locals {
  name = "pomi-${var.environment}"
  data_api_hostname = coalesce(
    var.data_api_domain_name,
    "data.pomi.${var.static_ip_address}.sslip.io",
  )
  data_api_url = "https://${local.data_api_hostname}"
  app_api_hostname = coalesce(
    var.app_api_domain_name,
    "app.pomi.${var.static_ip_address}.sslip.io",
  )
  app_api_url = "https://${local.app_api_hostname}"
  keycloak_hostname = coalesce(
    var.keycloak_domain_name,
    "auth.pomi.${var.static_ip_address}.sslip.io",
  )
  keycloak_url = "https://${local.keycloak_hostname}"
  frontend_url = coalesce(var.frontend_url, "https://${var.frontend_project_name}.vercel.app")
  frontend_environment_variables = {
    VITE_DATA_API_URL = {
      value   = local.data_api_url
      target  = ["production", "preview"]
      comment = "URL pública da API de dados acadêmicos do POMI"
    }
    VITE_APP_API_URL = {
      value   = local.app_api_url
      target  = ["production", "preview"]
      comment = "URL pública da API de estudante e planejamento do POMI"
    }
    VITE_KEYCLOAK_URL = {
      value   = local.keycloak_url
      target  = ["production", "preview", "development"]
      comment = "URL pública do Keycloak do planejador POMI"
    }
    VITE_KEYCLOAK_REALM = {
      value   = var.keycloak_realm
      target  = ["production", "preview", "development"]
      comment = "Realm OIDC do planejador POMI"
    }
    VITE_KEYCLOAK_CLIENT_ID = {
      value   = var.keycloak_client_id
      target  = ["production", "preview", "development"]
      comment = "Client público OIDC do frontend POMI"
    }
  }
}

resource "vercel_project" "frontend" {
  name           = var.frontend_project_name
  framework      = "vite"
  root_directory = var.frontend_root_directory
  team_id        = var.vercel_team_id

  git_repository = {
    type = "github"
    repo = var.frontend_git_repository
  }

  lifecycle {
    ignore_changes = [
      environment,
      oidc_token_config,
      protection_bypass_for_automation_secret,
      vercel_authentication,
    ]
  }
}

resource "vercel_project_environment_variable" "frontend" {
  for_each = local.frontend_environment_variables

  project_id = vercel_project.frontend.id
  key        = each.key
  value      = each.value.value
  target     = each.value.target
  sensitive  = false
  comment    = each.value.comment
}

resource "aws_s3_bucket" "backups" {
  bucket        = var.backup_bucket_name
  bucket_prefix = var.backup_bucket_name == null ? "${local.name}-postgres-backups-" : null

  tags = merge(var.tags, {
    Component = "planner-postgres-backups"
  })
}

resource "aws_s3_bucket_public_access_block" "backups" {
  bucket = aws_s3_bucket.backups.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "backups" {
  bucket = aws_s3_bucket.backups.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id

  rule {
    id     = "expire-postgres-backups"
    status = "Enabled"

    filter {}

    expiration {
      days = var.backup_retention
    }

    noncurrent_version_expiration {
      noncurrent_days = var.backup_retention
    }
  }

  depends_on = [aws_s3_bucket_versioning.backups]
}
