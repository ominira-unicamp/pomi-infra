locals {
  frontend_url      = coalesce(var.frontend_url, "https://${var.vercel_project_name}.vercel.app")
  custom_api_domain = try(trimspace(var.api_domain_name), "") != ""
  api_hostname      = local.custom_api_domain ? trimspace(var.api_domain_name) : "${var.static_ip_address}.sslip.io"
  api_url           = "https://${local.api_hostname}"
  frontend_environment_variables = {
    VITE_API_URL = {
      value   = local.api_url
      target  = ["production", "preview", "development"]
      comment = "URL pública da API do POMI Intercâmbio"
    }
  }
}

data "aws_route53_zone" "main" {
  count = local.custom_api_domain ? 1 : 0

  name         = try(trimspace(var.hosted_zone_name), "")
  private_zone = false
}

resource "aws_route53_record" "api" {
  count = local.custom_api_domain ? 1 : 0

  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = local.api_hostname
  type    = "A"
  ttl     = 60
  records = [var.static_ip_address]
}

resource "vercel_project" "frontend" {
  name           = var.vercel_project_name
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
