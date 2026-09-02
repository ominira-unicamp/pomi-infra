resource "aws_ecr_repository" "backend" {
  name                 = "${local.name}/backend"
  image_tag_mutability = "IMMUTABLE"

  encryption_configuration {
    encryption_type = "AES256"
  }

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(var.tags, {
    Component = "planner-backend-registry"
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

resource "aws_ecr_repository" "injection" {
  name                 = "${local.name}/injection"
  image_tag_mutability = "IMMUTABLE"

  encryption_configuration {
    encryption_type = "AES256"
  }

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(var.tags, {
    Component = "planner-injection-registry"
  })
}

resource "aws_ecr_lifecycle_policy" "injection" {
  repository = aws_ecr_repository.injection.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Preserva as imagens mais recentes da injection"
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

resource "aws_ecr_repository" "notifier" {
  name                 = "${local.name}/notifier"
  image_tag_mutability = "IMMUTABLE"

  encryption_configuration {
    encryption_type = "AES256"
  }

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(var.tags, {
    Component = "planner-notifier-registry"
  })
}

resource "aws_ecr_lifecycle_policy" "notifier" {
  repository = aws_ecr_repository.notifier.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Preserva as imagens mais recentes do notifier"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = var.registry_image_retention
      }
      action = { type = "expire" }
    }]
  })
}
