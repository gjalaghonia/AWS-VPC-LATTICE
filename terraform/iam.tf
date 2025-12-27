####################################
# IAM Roles for ECS Tasks
####################################

####################################
# ECS Task Execution Role
# (Used by ECS to pull images and write logs)
####################################

resource "aws_iam_role" "ecs_execution" {
  name = "${var.project_name}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-ecs-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

####################################
# ECS Task Role
# (Used by the application running in the container)
####################################

resource "aws_iam_role" "ecs_task" {
  name = "${var.project_name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-ecs-task-role"
  }
}

####################################
# VPC Lattice Invoke Policy
# (Allows frontend to invoke backend via Lattice)
####################################

resource "aws_iam_role_policy" "lattice_invoke" {
  count = var.deploy_scenario == "lattice" ? 1 : 0
  name  = "${var.project_name}-lattice-invoke-policy"
  role  = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "vpc-lattice-svcs:Invoke"
        ]
        Resource = "*"
      }
    ]
  })
}

####################################
# CloudWatch Logs Policy
####################################

resource "aws_iam_role_policy" "ecs_logs" {
  name = "${var.project_name}-ecs-logs-policy"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "${aws_cloudwatch_log_group.backend.arn}:*",
          "${aws_cloudwatch_log_group.frontend.arn}:*"
        ]
      }
    ]
  })
}

####################################
# Service-to-Service Communication Policy
####################################

# Traditional: No special policy needed (SG-based)
# VPC Lattice: IAM-based access (handled by auth policy in lattice.tf)

# This demonstrates the shift from network-based to identity-based access control

