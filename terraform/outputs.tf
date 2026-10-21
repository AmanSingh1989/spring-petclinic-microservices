output "application_url" {
  description = "Public URL to access the Spring PetClinic web application through the ALB"
  value       = "http://${aws_lb.main.dns_name}"
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "ecs_cluster_name" {
  description = "Name of the ECS Cluster"
  value       = aws_ecs_cluster.main.name
}

output "rds_mysql_endpoint" {
  description = "Internal endpoint of the MySQL database"
  value       = aws_db_instance.mysql.endpoint
}

output "ecr_repository_urls" {
  description = "Map of ECR repository URLs for pushing container images"
  value = {
    for k, v in aws_ecr_repository.services : k => v.repository_url
  }
}

output "db_password_ssm_parameter" {
  description = "AWS SSM Parameter Store path where the generated database password is encrypted and stored"
  value       = aws_ssm_parameter.db_password.name
}

output "database_password" {
  description = "Auto-generated database password (sensitive - view using: terraform output -raw database_password)"
  value       = local.db_password
  sensitive   = true
}

output "ec2_node_public_ips" {
  description = "Public IP addresses of the 4 ECS cluster EC2 nodes"
  value       = aws_instance.ecs_nodes[*].public_ip
}
