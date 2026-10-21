resource "aws_db_subnet_group" "rds" {
  name        = "${var.project_name}-rds-subnet-group"
  description = "Subnet group for PetClinic MySQL RDS instance across private subnets"
  subnet_ids  = aws_subnet.private[*].id

  tags = {
    Name = "${var.project_name}-rds-subnet-group"
  }
}

resource "aws_db_instance" "mysql" {
  identifier             = "${var.project_name}-mysql"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  max_allocated_storage  = 20
  storage_type           = "gp3"
  db_name                = var.db_name
  username               = var.db_username
  password               = local.db_password
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.rds.name

  publicly_accessible = false
  multi_az            = false

  # Crucial for sandbox and testing environments to allow immediate clean teardown
  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name = "${var.project_name}-mysql"
  }
}
