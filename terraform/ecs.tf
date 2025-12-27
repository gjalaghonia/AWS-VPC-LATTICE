####################################
# ECS Cluster (Used by Both Scenarios)
####################################

resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = var.enable_detailed_logs ? "enabled" : "disabled"
  }

  tags = {
    Name = "${var.project_name}-cluster"
  }
}

####################################
# CloudWatch Log Groups
####################################

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${var.project_name}/backend"
  retention_in_days = 1 # Keep short for demo

  tags = {
    Name    = "${var.project_name}-backend-logs"
    Service = "backend"
  }
}

resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/ecs/${var.project_name}/frontend"
  retention_in_days = 1

  tags = {
    Name    = "${var.project_name}-frontend-logs"
    Service = "frontend"
  }
}

####################################
# Backend Task Definition
####################################

resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.project_name}-backend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "backend"
      image = var.backend_container_image
      
      # http-echo container configuration
      command = [
        "-text=Hello from Backend Service! This is the response you requested."
      ]
      
      portMappings = [
        {
          containerPort = var.backend_port
          protocol      = "tcp"
        }
      ]
      
      environment = [
        {
          name  = "SERVICE_NAME"
          value = "backend"
        },
        {
          name  = "SCENARIO"
          value = var.deploy_scenario
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.backend.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "backend"
        }
      }
      
      healthCheck = {
        command     = ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:${var.backend_port}/ || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name    = "${var.project_name}-backend-task"
    Service = "backend"
  }
}

####################################
# Frontend Task Definition
####################################

resource "aws_ecs_task_definition" "frontend" {
  family                   = "${var.project_name}-frontend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "frontend"
      image = var.frontend_container_image
      
      portMappings = [
        {
          containerPort = var.frontend_port
          protocol      = "tcp"
        }
      ]
      
      environment = [
        {
          name  = "SERVICE_NAME"
          value = "frontend"
        },
        {
          name  = "BACKEND_URL"
          value = var.deploy_scenario == "lattice" ? "http://backend.${var.project_name}.svc" : "http://backend-alb"
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.frontend.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "frontend"
        }
      }
      
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost/ || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name    = "${var.project_name}-frontend-task"
    Service = "frontend"
  }
}

####################################
# Backend ECS Service
####################################

resource "aws_ecs_service" "backend" {
  name            = "${var.project_name}-backend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  # Force new deployment on service updates
  force_new_deployment = true

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.backend.id]
    assign_public_ip = false
  }

  # Load balancer configuration (only for traditional setup)
  dynamic "load_balancer" {
    for_each = var.deploy_scenario == "traditional" ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.backend[0].arn
      container_name   = "backend"
      container_port   = var.backend_port
    }
  }

  # VPC Lattice targets are registered via null_resource in lattice.tf

  tags = {
    Name     = "${var.project_name}-backend-service"
    Service  = "backend"
    Scenario = var.deploy_scenario
  }

  depends_on = [
    aws_iam_role.ecs_execution,
    aws_iam_role.ecs_task,
    aws_lb_listener.main,
    aws_lb_target_group.backend
  ]
  
  # Ignore desired count changes from external sources
  lifecycle {
    ignore_changes = []
  }
}

####################################
# Frontend ECS Service
####################################

resource "aws_ecs_service" "frontend" {
  count           = var.deploy_scenario == "traditional" ? 1 : 0
  name            = "${var.project_name}-frontend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.frontend[0].id]
    assign_public_ip = false
  }

  tags = {
    Name     = "${var.project_name}-frontend-service"
    Service  = "frontend"
    Scenario = "traditional"
  }

  depends_on = [
    aws_lb.main,
    aws_lb_listener.main
  ]
}

# Frontend for VPC Lattice scenario
resource "aws_ecs_service" "frontend_lattice" {
  count           = var.deploy_scenario == "lattice" ? 1 : 0
  name            = "${var.project_name}-frontend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.frontend_lattice[0].id]
    assign_public_ip = false
  }

  tags = {
    Name     = "${var.project_name}-frontend-service"
    Service  = "frontend"
    Scenario = "lattice"
  }

  depends_on = [
    aws_vpclattice_service.backend,
    aws_vpclattice_service_network_vpc_association.main
  ]
}

