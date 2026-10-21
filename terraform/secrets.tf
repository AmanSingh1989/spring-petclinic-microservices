# Generate a secure 16-character database password automatically
# Avoids punctuation characters that can break JDBC connection strings (/ @ " ' \)
resource "random_password" "generated_db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

locals {
  # Use provided password if explicitly given, otherwise use the auto-generated random password
  db_password = var.db_password != "" ? var.db_password : random_password.generated_db_password.result
}

# Store database password securely in AWS Systems Manager Parameter Store
resource "aws_ssm_parameter" "db_password" {
  name        = "/${var.project_name}/database/password"
  description = "Master password for PetClinic RDS MySQL database"
  type        = "SecureString"
  value       = local.db_password

  tags = {
    Name = "${var.project_name}-db-password"
  }
}

# Store database username in SSM Parameter Store
resource "aws_ssm_parameter" "db_username" {
  name        = "/${var.project_name}/database/username"
  description = "Master username for PetClinic RDS MySQL database"
  type        = "String"
  value       = var.db_username

  tags = {
    Name = "${var.project_name}-db-username"
  }
}
