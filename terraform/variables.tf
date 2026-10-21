variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name prefix used for resource naming"
  type        = string
  default     = "petclinic"
}

variable "environment" {
  description = "Deployment environment (e.g. sandbox, dev, prod)"
  type        = string
  default     = "sandbox"
}

variable "ec2_instance_type" {
  description = "EC2 instance type for the ECS cluster nodes"
  type        = string
  default     = "t3.micro"
}

variable "ec2_instance_count" {
  description = "Number of micro EC2 instances to launch in the ECS cluster"
  type        = number
  default     = 4
}

variable "enable_genai" {
  description = "Toggle to include or skip the spring-petclinic-genai-service"
  type        = bool
  default     = false
}

variable "db_name" {
  description = "Database name for RDS MySQL"
  type        = string
  default     = "petclinic"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "petclinic"
}

variable "db_password" {
  description = "Database master password. If left empty (default), a secure random password is automatically generated and stored in AWS SSM."
  type        = string
  sensitive   = true
  default     = ""
}

variable "openai_api_key" {
  description = "OpenAI API Key for genai-service (optional when genai is disabled)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "allowed_ssh_cidr" {
  description = "CIDR block permitted to SSH into EC2 instances for debugging"
  type        = string
  default     = "0.0.0.0/0"
}
