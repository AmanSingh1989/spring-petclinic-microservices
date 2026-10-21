# Fetch latest official Amazon Linux 2023 ECS-Optimized AMI ID dynamically
data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id"
}

# ECS Cluster definition
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.project_name}-cluster"
  }
}

# Direct EC2 micro instances registered directly into the ECS cluster (No Auto Scaling)
resource "aws_instance" "ecs_nodes" {
  count                = var.ec2_instance_count
  ami                  = data.aws_ssm_parameter.ecs_ami.value
  instance_type        = var.ec2_instance_type
  subnet_id            = aws_subnet.public[count.index % 2].id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile = aws_iam_instance_profile.ecs_instance_profile.name

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    delete_on_termination = true
  }

  # Cloud-init: Sets up 4GB swap space and joins the ECS cluster
  user_data = <<-EOF
    #!/bin/bash
    # Set up 4GB swapfile to provide memory headroom for Spring Boot JVMs
    dd if=/dev/zero of=/swapfile bs=1M count=4096
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab

    # Tell the ECS agent to join our cluster
    echo "ECS_CLUSTER=${aws_ecs_cluster.main.name}" >> /etc/ecs/ecs.config
    echo "ECS_ENABLE_CONTAINER_METADATA=true" >> /etc/ecs/ecs.config
  EOF

  tags = {
    Name = "${var.project_name}-ecs-node-${count.index + 1}"
  }
}
