####################################
# PART A: Traditional Setup (ALB-based)
# Only created when deploy_scenario = "traditional"
####################################

####################################
# Application Load Balancer
####################################

resource "aws_lb" "main" {
  count              = var.deploy_scenario == "traditional" ? 1 : 0
  name               = "${var.project_name}-alb"
  internal           = true  # Internal ALB for service-to-service communication
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb[0].id]
  subnets            = aws_subnet.private[*].id

  enable_deletion_protection = false
  enable_http2              = true

  tags = {
    Name     = "${var.project_name}-alb"
    Scenario = "traditional"
    Purpose  = "Frontend to ALB to Backend"
  }
}

####################################
# ALB Target Group (for Backend)
####################################

resource "aws_lb_target_group" "backend" {
  count       = var.deploy_scenario == "traditional" ? 1 : 0
  name        = "${var.project_name}-backend-tg"
  port        = var.backend_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name     = "${var.project_name}-backend-tg"
    Scenario = "traditional"
  }
}

####################################
# ALB Listener
####################################

resource "aws_lb_listener" "main" {
  count             = var.deploy_scenario == "traditional" ? 1 : 0
  load_balancer_arn = aws_lb.main[0].arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend[0].arn
  }

  tags = {
    Name     = "${var.project_name}-listener"
    Scenario = "traditional"
  }
}

####################################
# Security Group: Frontend (Traditional)
####################################

resource "aws_security_group" "frontend" {
  count       = var.deploy_scenario == "traditional" ? 1 : 0
  name        = "${var.project_name}-frontend-sg"
  description = "Security group for frontend service (traditional)"
  vpc_id      = aws_vpc.main.id

  # Allow outbound for pulling images
  egress {
    description = "HTTPS for ECR image pull"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name     = "${var.project_name}-frontend-sg"
    Scenario = "traditional"
    Note     = "Outbound to ALB (added via separate rule)"
  }
}

####################################
# Security Group: ALB
####################################

resource "aws_security_group" "alb" {
  count       = var.deploy_scenario == "traditional" ? 1 : 0
  name        = "${var.project_name}-alb-sg"
  description = "Security group for ALB (traditional setup)"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name     = "${var.project_name}-alb-sg"
    Scenario = "traditional"
    Note     = "SG chaining: Frontend -> ALB -> Backend"
  }
}

####################################
# Security Group: Backend (Traditional)
####################################

resource "aws_security_group" "backend" {
  name        = "${var.project_name}-backend-sg"
  description = "Security group for backend service"
  vpc_id      = aws_vpc.main.id

  # VPC Lattice: Allow from VPC CIDR (VPC Lattice uses VPC IP space + link-local)
  dynamic "ingress" {
    for_each = var.deploy_scenario == "lattice" ? [1] : []
    content {
      description = "HTTP from VPC (VPC Lattice)"
      from_port   = var.backend_port
      to_port     = var.backend_port
      protocol    = "tcp"
      cidr_blocks = [var.vpc_cidr]
    }
  }

  # VPC Lattice: Also allow from link-local range (169.254.0.0/16) for health checks
  dynamic "ingress" {
    for_each = var.deploy_scenario == "lattice" ? [1] : []
    content {
      description = "HTTP from VPC Lattice link-local (health checks)"
      from_port   = var.backend_port
      to_port     = var.backend_port
      protocol    = "tcp"
      cidr_blocks = ["169.254.0.0/16"]
    }
  }

  # Allow outbound for responses
  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name     = "${var.project_name}-backend-sg"
    Scenario = var.deploy_scenario
    Note     = var.deploy_scenario == "traditional" ? "Accepts from ALB only" : "Accepts from VPC + link-local (Lattice)"
  }
}

####################################
# Security Group Rules (Separate to avoid cycles)
####################################

# Frontend -> ALB
resource "aws_security_group_rule" "frontend_to_alb" {
  count                    = var.deploy_scenario == "traditional" ? 1 : 0
  type                     = "egress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = aws_security_group.frontend[0].id
  source_security_group_id = aws_security_group.alb[0].id
  description              = "Frontend to ALB"
}

# ALB <- Frontend
resource "aws_security_group_rule" "alb_from_frontend" {
  count                    = var.deploy_scenario == "traditional" ? 1 : 0
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = aws_security_group.alb[0].id
  source_security_group_id = aws_security_group.frontend[0].id
  description              = "ALB from Frontend"
}

# ALB -> Backend
resource "aws_security_group_rule" "alb_to_backend" {
  count                    = var.deploy_scenario == "traditional" ? 1 : 0
  type                     = "egress"
  from_port                = var.backend_port
  to_port                  = var.backend_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.alb[0].id
  source_security_group_id = aws_security_group.backend.id
  description              = "ALB to Backend"
}

# Backend <- ALB
resource "aws_security_group_rule" "backend_from_alb" {
  count                    = var.deploy_scenario == "traditional" ? 1 : 0
  type                     = "ingress"
  from_port                = var.backend_port
  to_port                  = var.backend_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.backend.id
  source_security_group_id = aws_security_group.alb[0].id
  description              = "Backend from ALB"
}

# ALB <- Bastion (for testing)
resource "aws_security_group_rule" "alb_from_bastion" {
  count                    = var.deploy_scenario == "traditional" && var.deploy_bastion ? 1 : 0
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = aws_security_group.alb[0].id
  source_security_group_id = aws_security_group.bastion[0].id
  description              = "ALB from Bastion (testing)"
}

####################################
# Traditional Architecture Summary
####################################

# This setup demonstrates:
# 1. Frontend needs to know ALB DNS name
# 2. ALB fronts the backend
# 3. Three security groups with chained rules
# 4. Access is implicit (if SG allows, it works)
# 5. More components to manage

