resource "aws_ecr_repository" "backend" {
  name                 = "pomi-exchange-${var.environment}/backend"
  image_tag_mutability = "IMMUTABLE"

  encryption_configuration {
    encryption_type = "AES256"
  }

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(var.tags, {
    Component = "exchange-backend-registry"
  })
}

resource "aws_ecr_lifecycle_policy" "backend" {
  repository = aws_ecr_repository.backend.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Preserva as imagens mais recentes do backend"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.registry_image_retention
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
