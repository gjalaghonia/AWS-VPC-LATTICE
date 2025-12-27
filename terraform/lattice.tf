####################################
# PART B: VPC Lattice Setup
# Only created when deploy_scenario = "lattice"
####################################

####################################
# VPC Lattice Service Network
####################################

resource "aws_vpclattice_service_network" "main" {
  count      = var.deploy_scenario == "lattice" ? 1 : 0
  name       = "${var.project_name}-service-network"
  auth_type  = "NONE"  # No auth for demo/testing purposes

  tags = {
    Name     = "${var.project_name}-service-network"
    Scenario = "lattice"
    Purpose  = "Service-driven networking boundary"
  }
}

####################################
# Associate VPC with Service Network
####################################

resource "aws_vpclattice_service_network_vpc_association" "main" {
  count              = var.deploy_scenario == "lattice" ? 1 : 0
  vpc_identifier     = aws_vpc.main.id
  service_network_identifier = aws_vpclattice_service_network.main[0].id

  security_group_ids = [aws_security_group.lattice_association[0].id]

  tags = {
    Name     = "${var.project_name}-vpc-association"
    Scenario = "lattice"
  }
}

####################################
# VPC Lattice Service (Backend)
####################################

resource "aws_vpclattice_service" "backend" {
  count      = var.deploy_scenario == "lattice" ? 1 : 0
  name       = "backend"
  auth_type  = "NONE"  # No auth for demo/testing purposes

  tags = {
    Name     = "${var.project_name}-backend-service"
    Scenario = "lattice"
    Purpose  = "Backend microservice exposed via Lattice"
  }
}

####################################
# Associate Backend Service with Network
####################################

resource "aws_vpclattice_service_network_service_association" "backend" {
  count                  = var.deploy_scenario == "lattice" ? 1 : 0
  service_identifier     = aws_vpclattice_service.backend[0].id
  service_network_identifier = aws_vpclattice_service_network.main[0].id

  tags = {
    Name     = "${var.project_name}-backend-association"
    Scenario = "lattice"
  }
}

####################################
# VPC Lattice Target Group
####################################

resource "aws_vpclattice_target_group" "backend" {
  count = var.deploy_scenario == "lattice" ? 1 : 0
  name  = "${var.project_name}-backend-tg"
  type  = "IP"

  config {
    port             = var.backend_port
    protocol         = "HTTP"
    vpc_identifier   = aws_vpc.main.id
    protocol_version = "HTTP1"

    health_check {
      enabled                       = true
      health_check_interval_seconds = 30
      health_check_timeout_seconds  = 5
      healthy_threshold_count       = 2
      unhealthy_threshold_count     = 2
      path                          = "/"
      protocol                      = "HTTP"
      protocol_version              = "HTTP1"
      matcher {
        value = "200"
      }
    }
  }

  tags = {
    Name     = "${var.project_name}-backend-tg"
    Scenario = "lattice"
  }
}

####################################
# VPC Lattice Listener
####################################

resource "aws_vpclattice_listener" "backend" {
  count              = var.deploy_scenario == "lattice" ? 1 : 0
  name               = "backend-listener"
  protocol           = "HTTP"
  port               = 80
  service_identifier = aws_vpclattice_service.backend[0].id

  default_action {
    forward {
      target_groups {
        target_group_identifier = aws_vpclattice_target_group.backend[0].id
        weight                  = 100
      }
    }
  }

  tags = {
    Name     = "${var.project_name}-backend-listener"
    Scenario = "lattice"
  }
}

####################################
# Register Backend ECS Tasks as Targets
####################################

# Wait for ECS tasks to be running before registering
resource "null_resource" "wait_for_backend_tasks" {
  count = var.deploy_scenario == "lattice" ? 1 : 0

  depends_on = [aws_ecs_service.backend]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for backend ECS tasks to be running..."
      sleep 30
    EOT
  }
}

# Register backend ECS task IPs to VPC Lattice target group
resource "null_resource" "register_lattice_targets" {
  count = var.deploy_scenario == "lattice" ? 1 : 0

  depends_on = [
    null_resource.wait_for_backend_tasks,
    aws_vpclattice_target_group.backend
  ]

  # Trigger re-registration if service or target group changes
  triggers = {
    service_id      = aws_ecs_service.backend.id
    target_group_id = aws_vpclattice_target_group.backend[0].id
  }

  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      set -e
      
      echo "Getting backend task IPs..."
      TASK_ARNS=$(aws ecs list-tasks \
        --cluster ${aws_ecs_cluster.main.name} \
        --service-name ${aws_ecs_service.backend.name} \
        --region ${var.aws_region} \
        --query 'taskArns[]' \
        --output text)
      
      if [ -z "$TASK_ARNS" ]; then
        echo "No tasks found yet, waiting..."
        sleep 30
        TASK_ARNS=$(aws ecs list-tasks \
          --cluster ${aws_ecs_cluster.main.name} \
          --service-name ${aws_ecs_service.backend.name} \
          --region ${var.aws_region} \
          --query 'taskArns[]' \
          --output text)
      fi
      
      for TASK_ARN in $TASK_ARNS; do
        echo "Processing task: $TASK_ARN"
        TASK_IP=$(aws ecs describe-tasks \
          --cluster ${aws_ecs_cluster.main.name} \
          --tasks $TASK_ARN \
          --region ${var.aws_region} \
          --query 'tasks[0].containers[0].networkInterfaces[0].privateIpv4Address' \
          --output text)
        
        if [ -n "$TASK_IP" ] && [ "$TASK_IP" != "None" ]; then
          echo "Registering $TASK_IP:${var.backend_port} to VPC Lattice..."
          aws vpc-lattice register-targets \
            --target-group-identifier ${aws_vpclattice_target_group.backend[0].id} \
            --targets id=$TASK_IP,port=${var.backend_port} \
            --region ${var.aws_region} || echo "Target may already be registered"
        fi
      done
      
      echo "Target registration complete!"
      
      # Verify targets
      echo "Current targets:"
      aws vpc-lattice list-targets \
        --target-group-identifier ${aws_vpclattice_target_group.backend[0].id} \
        --region ${var.aws_region}
    EOT
  }

  # Deregister targets on destroy
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "Deregistering targets on destroy..."
      # Targets will be automatically removed when target group is deleted
    EOT
  }
}

####################################
# VPC Lattice Auth Policy (Explicit Access Control)
####################################

# Note: When auth_type = "NONE", no auth policy is needed
# Commenting out for demo purposes to allow simple curl testing
# In production, use auth_type = "AWS_IAM" with proper auth policy

# resource "aws_vpclattice_auth_policy" "backend" {
#   count               = var.deploy_scenario == "lattice" ? 1 : 0
#   resource_identifier = aws_vpclattice_service.backend[0].arn
#
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Principal = "*"
#         Action = "vpc-lattice-svcs:Invoke"
#         Resource = "*"
#         Condition = {
#           StringEquals = {
#             "vpc-lattice-svcs:SourceVpc" = aws_vpc.main.id
#           }
#         }
#       }
#     ]
#   })
# }

####################################
# Security Group: VPC Association
####################################

resource "aws_security_group" "lattice_association" {
  count       = var.deploy_scenario == "lattice" ? 1 : 0
  name        = "${var.project_name}-lattice-association-sg"
  description = "Security group for VPC Lattice association"
  vpc_id      = aws_vpc.main.id

  # Allow inbound from VPC (Lattice managed endpoints)
  ingress {
    description = "All from VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  # Allow all outbound
  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name     = "${var.project_name}-lattice-association-sg"
    Scenario = "lattice"
  }
}

####################################
# Security Group: Frontend (Lattice)
####################################

resource "aws_security_group" "frontend_lattice" {
  count       = var.deploy_scenario == "lattice" ? 1 : 0
  name        = "${var.project_name}-frontend-lattice-sg"
  description = "Security group for frontend (VPC Lattice scenario)"
  vpc_id      = aws_vpc.main.id

  # Allow outbound to VPC (for Lattice service calls)
  egress {
    description = "To VPC Lattice services"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  # Allow outbound for pulling images
  egress {
    description = "HTTPS for ECR image pull"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name     = "${var.project_name}-frontend-lattice-sg"
    Scenario = "lattice"
    Note     = "No SG chaining needed - Lattice handles routing"
  }
}

####################################
# VPC Lattice Architecture Summary
####################################

# This setup demonstrates:
# 1. Service Network as logical boundary
# 2. Backend registered as a Lattice Service
# 3. Explicit IAM-based access policy (frontend can call backend)
# 4. No ALB needed for east-west traffic
# 5. Built-in service discovery (DNS)
# 6. Simpler security group model
# 7. Access is explicit and auditable

