locals {
  # Base microservices always needed
  base_services = [
    "config-server",
    "discovery-server",
    "api-gateway",
    "customers-service",
    "visits-service",
    "vets-service",
    "admin-server"
  ]

  # Include genai-service repository if enable_genai is true
  services = var.enable_genai ? concat(local.base_services, ["genai-service"]) : local.base_services
}

resource "aws_ecr_repository" "services" {
  for_each             = toset(local.services)
  name                 = "${var.project_name}/${each.key}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Service = each.key
  }
}

# Lifecycle policy: retain only the last 5 tagged images to avoid storage clutter and stay within sandbox quotas
resource "aws_ecr_lifecycle_policy" "cleanup_policy" {
  for_each   = aws_ecr_repository.services
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only last 5 images"
        selection = {
          tagStatus   = "any"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 14
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
