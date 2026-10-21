# CloudWatch Log Groups for each microservice with 7-day retention
resource "aws_cloudwatch_log_group" "ecs_logs" {
  for_each          = toset(local.services)
  name              = "/ecs/${var.project_name}/${each.key}"
  retention_in_days = 7

  tags = {
    Service = each.key
  }
}
