# Common JVM and network environment variables for all microservices
locals {
  common_env = [
    # Direct internal connection to Node 1 where Config Server & Eureka run
    {
      name  = "SPRING_CONFIG_IMPORT"
      value = "configserver:http://${aws_instance.ecs_nodes[0].private_ip}:8888/"
    },
    {
      name  = "EUREKA_CLIENT_SERVICEURL_DEFAULTZONE"
      value = "http://${aws_instance.ecs_nodes[0].private_ip}:8761/eureka"
    },
    {
      name  = "CONFIG_SERVER_URL"
      value = "http://${aws_instance.ecs_nodes[0].private_ip}:8888/"
    },
    {
      name  = "EUREKA_SERVER_URL"
      value = "http://${aws_instance.ecs_nodes[0].private_ip}:8761/eureka"
    },
    {
      name  = "JAVA_TOOL_OPTIONS"
      value = "-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:+ExitOnOutOfMemoryError"
    }
  ]

  db_env = [
    {
      name  = "SPRING_PROFILES_ACTIVE"
      value = "docker,mysql"
    },
    {
      name  = "SPRING_DATASOURCE_URL"
      value = "jdbc:mysql://${aws_db_instance.mysql.endpoint}/${var.db_name}?useUnicode=true&characterEncoding=utf8&useSSL=false"
    },
    {
      name  = "SPRING_DATASOURCE_USERNAME"
      value = var.db_username
    },
    {
      name  = "SPRING_DATASOURCE_PASSWORD"
      value = local.db_password
    }
  ]

  # Map config-server and discovery-server hostnames directly to Node 1 private IP inside containers
  extra_hosts = [
    {
      hostname  = "config-server"
      ipAddress = aws_instance.ecs_nodes[0].private_ip
    },
    {
      hostname  = "discovery-server"
      ipAddress = aws_instance.ecs_nodes[0].private_ip
    }
  ]
}

# -------------------------------------------------------------
# 1. Config Server
# -------------------------------------------------------------
resource "aws_ecs_task_definition" "config_server" {
  family                   = "${var.project_name}-config-server"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "config-server"
      image     = "${aws_ecr_repository.services["config-server"].repository_url}:latest"
      cpu               = 256
      memory            = 450
      memoryReservation = 280
      essential         = true

      portMappings = [
        {
          containerPort = 8888
          hostPort      = 8888
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "JAVA_TOOL_OPTIONS"
          value = "-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs["config-server"].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "config-server"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "config_server" {
  name                               = "${var.project_name}-config-server"
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.config_server.arn
  desired_count                      = 1
  deployment_maximum_percent         = 100
  deployment_minimum_healthy_percent = 0

  # Run on Node 1 where config-server DNS points
  placement_constraints {
    type       = "memberOf"
    expression = "ec2InstanceId == ${aws_instance.ecs_nodes[0].id}"
  }
}

# -------------------------------------------------------------
# 2. Discovery Server (Eureka)
# -------------------------------------------------------------
resource "aws_ecs_task_definition" "discovery_server" {
  family                   = "${var.project_name}-discovery-server"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "discovery-server"
      image     = "${aws_ecr_repository.services["discovery-server"].repository_url}:latest"
      cpu               = 256
      memory            = 450
      memoryReservation = 280
      essential         = true

      portMappings = [
        {
          containerPort = 8761
          hostPort      = 8761
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "SPRING_CONFIG_IMPORT"
          value = "configserver:http://${aws_instance.ecs_nodes[0].private_ip}:8888/"
        },
        {
          name  = "CONFIG_SERVER_URL"
          value = "http://${aws_instance.ecs_nodes[0].private_ip}:8888/"
        },
        {
          name  = "JAVA_TOOL_OPTIONS"
          value = "-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs["discovery-server"].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "discovery-server"
        }
      }

      extraHosts = local.extra_hosts
    }
  ])
}

resource "aws_ecs_service" "discovery_server" {
  name                               = "${var.project_name}-discovery-server"
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.discovery_server.arn
  desired_count                      = 1
  deployment_maximum_percent         = 100
  deployment_minimum_healthy_percent = 0

  # Run on Node 1 where discovery-server DNS points
  placement_constraints {
    type       = "memberOf"
    expression = "ec2InstanceId == ${aws_instance.ecs_nodes[0].id}"
  }

  depends_on = [aws_ecs_service.config_server]
}

# -------------------------------------------------------------
# 3. API Gateway (Attached to Application Load Balancer)
# -------------------------------------------------------------
resource "aws_ecs_task_definition" "api_gateway" {
  family                   = "${var.project_name}-api-gateway"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "api-gateway"
      image     = "${aws_ecr_repository.services["api-gateway"].repository_url}:latest"
      cpu               = 256
      memory            = 450
      memoryReservation = 280
      essential         = true

      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]

      environment = local.common_env

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs["api-gateway"].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "api-gateway"
        }
      }

      extraHosts = local.extra_hosts
    }
  ])
}

resource "aws_ecs_service" "api_gateway" {
  name                               = "${var.project_name}-api-gateway"
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.api_gateway.arn
  desired_count                      = 1
  deployment_maximum_percent         = 100
  deployment_minimum_healthy_percent = 0

  load_balancer {
    target_group_arn = aws_lb_target_group.api_gateway.arn
    container_name   = "api-gateway"
    container_port   = 8080
  }

  depends_on = [aws_ecs_service.discovery_server]
}

# -------------------------------------------------------------
# 4. Customers Service
# -------------------------------------------------------------
resource "aws_ecs_task_definition" "customers_service" {
  family                   = "${var.project_name}-customers-service"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "customers-service"
      image     = "${aws_ecr_repository.services["customers-service"].repository_url}:latest"
      cpu               = 256
      memory            = 450
      memoryReservation = 280
      essential         = true

      portMappings = [
        {
          containerPort = 8081
          hostPort      = 8081
          protocol      = "tcp"
        }
      ]

      environment = concat(local.common_env, local.db_env)

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs["customers-service"].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "customers-service"
        }
      }

      extraHosts = local.extra_hosts
    }
  ])
}

resource "aws_ecs_service" "customers_service" {
  name                               = "${var.project_name}-customers-service"
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.customers_service.arn
  desired_count                      = 1
  deployment_maximum_percent         = 100
  deployment_minimum_healthy_percent = 0

  depends_on = [aws_ecs_service.discovery_server]
}

# -------------------------------------------------------------
# 5. Visits Service
# -------------------------------------------------------------
resource "aws_ecs_task_definition" "visits_service" {
  family                   = "${var.project_name}-visits-service"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "visits-service"
      image     = "${aws_ecr_repository.services["visits-service"].repository_url}:latest"
      cpu               = 256
      memory            = 450
      memoryReservation = 280
      essential         = true

      portMappings = [
        {
          containerPort = 8082
          hostPort      = 8082
          protocol      = "tcp"
        }
      ]

      environment = concat(local.common_env, local.db_env)

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs["visits-service"].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "visits-service"
        }
      }

      extraHosts = local.extra_hosts
    }
  ])
}

resource "aws_ecs_service" "visits_service" {
  name                               = "${var.project_name}-visits-service"
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.visits_service.arn
  desired_count                      = 1
  deployment_maximum_percent         = 100
  deployment_minimum_healthy_percent = 0

  depends_on = [aws_ecs_service.discovery_server]
}

# -------------------------------------------------------------
# 6. Vets Service
# -------------------------------------------------------------
resource "aws_ecs_task_definition" "vets_service" {
  family                   = "${var.project_name}-vets-service"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "vets-service"
      image     = "${aws_ecr_repository.services["vets-service"].repository_url}:latest"
      cpu               = 256
      memory            = 450
      memoryReservation = 280
      essential         = true

      portMappings = [
        {
          containerPort = 8083
          hostPort      = 8083
          protocol      = "tcp"
        }
      ]

      environment = concat(local.common_env, local.db_env)

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs["vets-service"].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "vets-service"
        }
      }

      extraHosts = local.extra_hosts
    }
  ])
}

resource "aws_ecs_service" "vets_service" {
  name                               = "${var.project_name}-vets-service"
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.vets_service.arn
  desired_count                      = 1
  deployment_maximum_percent         = 100
  deployment_minimum_healthy_percent = 0

  depends_on = [aws_ecs_service.discovery_server]
}

# -------------------------------------------------------------
# 7. Admin Server (Spring Boot Admin Dashboard)
# -------------------------------------------------------------
resource "aws_ecs_task_definition" "admin_server" {
  family                   = "${var.project_name}-admin-server"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "admin-server"
      image     = "${aws_ecr_repository.services["admin-server"].repository_url}:latest"
      cpu               = 256
      memory            = 450
      memoryReservation = 280
      essential         = true

      portMappings = [
        {
          containerPort = 9090
          hostPort      = 9090
          protocol      = "tcp"
        }
      ]

      environment = local.common_env

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs["admin-server"].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "admin-server"
        }
      }

      extraHosts = local.extra_hosts
    }
  ])
}

resource "aws_ecs_service" "admin_server" {
  name                               = "${var.project_name}-admin-server"
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.admin_server.arn
  desired_count                      = 1
  deployment_maximum_percent         = 100
  deployment_minimum_healthy_percent = 0

  depends_on = [aws_ecs_service.discovery_server]
}

# -------------------------------------------------------------
# 8. GenAI Service (OPTIONAL / TOGGLEABLE)
# -------------------------------------------------------------
resource "aws_ecs_task_definition" "genai_service" {
  count                    = var.enable_genai ? 1 : 0
  family                   = "${var.project_name}-genai-service"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "genai-service"
      image     = "${aws_ecr_repository.services["genai-service"].repository_url}:latest"
      cpu               = 256
      memory            = 450
      memoryReservation = 280
      essential         = true

      portMappings = [
        {
          containerPort = 8084
          hostPort      = 8084
          protocol      = "tcp"
        }
      ]

      environment = concat(local.common_env, [
        {
          name  = "OPENAI_API_KEY"
          value = var.openai_api_key
        }
      ])

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs["genai-service"].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "genai-service"
        }
      }

      extraHosts = local.extra_hosts
    }
  ])
}

resource "aws_ecs_service" "genai_service" {
  count                              = var.enable_genai ? 1 : 0
  name                               = "${var.project_name}-genai-service"
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.genai_service[0].arn
  desired_count                      = 1
  deployment_maximum_percent         = 100
  deployment_minimum_healthy_percent = 0

  depends_on = [aws_ecs_service.discovery_server]
}
