provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.tags
  }
}

provider "vercel" {
  team = var.vercel_team_id
}
