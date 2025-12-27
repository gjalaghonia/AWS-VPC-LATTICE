####################################
# Bastion Host for Testing Internal Resources
# Optional - only created when needed
####################################

####################################
# Get Latest Amazon Linux 2023 AMI
####################################

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

####################################
# IAM Role for Bastion (Session Manager)
####################################

resource "aws_iam_role" "bastion" {
  count = var.deploy_bastion ? 1 : 0
  name  = "${var.project_name}-bastion-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-bastion-role"
  }
}

# Attach Session Manager policy
resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  count      = var.deploy_bastion ? 1 : 0
  role       = aws_iam_role.bastion[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Allow bastion to invoke VPC Lattice services
resource "aws_iam_role_policy" "bastion_lattice_invoke" {
  count = var.deploy_bastion ? 1 : 0
  name  = "${var.project_name}-bastion-lattice-invoke"
  role  = aws_iam_role.bastion[0].id

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

# Instance profile
resource "aws_iam_instance_profile" "bastion" {
  count = var.deploy_bastion ? 1 : 0
  name  = "${var.project_name}-bastion-profile"
  role  = aws_iam_role.bastion[0].name

  tags = {
    Name = "${var.project_name}-bastion-profile"
  }
}

####################################
# Security Group for Bastion
####################################

resource "aws_security_group" "bastion" {
  count       = var.deploy_bastion ? 1 : 0
  name        = "${var.project_name}-bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = aws_vpc.main.id

  # Allow outbound to everywhere (for yum updates, curl, etc.)
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-bastion-sg"
    Note = "No inbound needed - using Session Manager"
  }
}

####################################
# Bastion EC2 Instance
####################################

resource "aws_instance" "bastion" {
  count                  = var.deploy_bastion ? 1 : 0
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.bastion[0].id]
  iam_instance_profile   = aws_iam_instance_profile.bastion[0].name

  # User data to install tools
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y curl wget jq
              
              # Create helpful aliases
              echo "alias alb='curl http://${var.deploy_scenario == "traditional" ? try(aws_lb.main[0].dns_name, "ALB-NOT-DEPLOYED") : "N/A"}'" >> /home/ec2-user/.bashrc
              
              # Create welcome message
              cat > /etc/motd << 'MOTD'
              ========================================
              VPC Lattice Lab - Bastion Host
              ========================================
              
              This bastion is inside the VPC and can reach internal resources.
              
              Quick Commands:
              ---------------
              # Test Traditional ALB
              curl http://${var.deploy_scenario == "traditional" ? try(aws_lb.main[0].dns_name, "ALB-NOT-DEPLOYED") : "N/A"}
              
              # Check VPC Lattice (if deployed)
              # (VPC Lattice DNS will be shown in outputs)
              
              Helpful Aliases:
              ---------------
              alb    - curl the ALB endpoint
              
              ========================================
              MOTD
              EOF

  tags = {
    Name     = "${var.project_name}-bastion"
    Purpose  = "Testing internal ALB and VPC Lattice"
    Scenario = var.deploy_scenario
  }

  # Enable detailed monitoring (optional)
  monitoring = false

  # Enable metadata service v2 (security best practice)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
}

####################################
# Outputs for Bastion
####################################

output "bastion_instance_id" {
  description = "Bastion instance ID (use with Session Manager)"
  value       = var.deploy_bastion ? aws_instance.bastion[0].id : null
}

output "bastion_connect_command" {
  description = "Command to connect to bastion via Session Manager"
  value = var.deploy_bastion ? {
    aws_console = "EC2 > Instances > ${aws_instance.bastion[0].id} > Connect > Session Manager"
    aws_cli     = "aws ssm start-session --target ${aws_instance.bastion[0].id} --region ${var.aws_region}"
  } : null
}

output "bastion_test_commands" {
  description = "Commands to run on bastion to test"
  value = var.deploy_bastion ? {
    traditional_alb = var.deploy_scenario == "traditional" ? "curl http://${aws_lb.main[0].dns_name}" : "Not deployed"
    lattice_service = var.deploy_scenario == "lattice" ? "curl http://${try(aws_vpclattice_service.backend[0].dns_entry[0].domain_name, "N/A")}" : "Not deployed"
  } : null
}

