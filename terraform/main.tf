####################################
# VPC Lattice Lab - Main Configuration
####################################

# This Terraform configuration demonstrates:
# - Traditional microservices networking (ALB-based)
# - Modern service networking (VPC Lattice)
# 
# Deploy scenarios:
# - "traditional" = Frontend -> ALB -> Backend
# - "lattice"     = Frontend -> Service Network -> Backend
# - "both"        = Deploy both for side-by-side comparison

####################################
# Data Sources
####################################

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

####################################
# Local Variables
####################################

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  common_tags = {
    Project     = var.project_name
    Environment = "Demo"
    ManagedBy   = "Terraform"
    Blog        = "VPC-Lattice-Before-After"
    Scenario    = var.deploy_scenario
  }
}

####################################
# Deployment Information
####################################

resource "null_resource" "deployment_info" {
  provisioner "local-exec" {
    when    = create
    command = <<-EOT
      echo "======================================"
      echo "VPC Lattice Lab Deployment Starting"
      echo "======================================"
      echo "Scenario: ${var.deploy_scenario}"
      echo "Region: ${var.aws_region}"
      echo "Account: ${local.account_id}"
      echo ""
      echo "This will deploy:"
      ${var.deploy_scenario == "traditional" ? "echo '  - VPC + Subnets + NAT Gateways'" : ""}
      ${var.deploy_scenario == "traditional" ? "echo '  - ECS Cluster + 2 Services (Frontend, Backend)'" : ""}
      ${var.deploy_scenario == "traditional" ? "echo '  - Application Load Balancer'" : ""}
      ${var.deploy_scenario == "traditional" ? "echo '  - Target Group + Listener'" : ""}
      ${var.deploy_scenario == "traditional" ? "echo '  - 3 Security Groups (Frontend, ALB, Backend)'" : ""}
      ${var.deploy_scenario == "lattice" ? "echo '  - VPC + Subnets + NAT Gateways'" : ""}
      ${var.deploy_scenario == "lattice" ? "echo '  - ECS Cluster + 2 Services (Frontend, Backend)'" : ""}
      ${var.deploy_scenario == "lattice" ? "echo '  - VPC Lattice Service Network'" : ""}
      ${var.deploy_scenario == "lattice" ? "echo '  - VPC Lattice Service (Backend)'" : ""}
      ${var.deploy_scenario == "lattice" ? "echo '  - IAM-based Auth Policy'" : ""}
      ${var.deploy_scenario == "lattice" ? "echo '  - 2 Security Groups (Frontend, Backend)'" : ""}
      echo ""
      echo "Estimated deployment time: 5-7 minutes"
      echo "======================================"
    EOT
  }
}

####################################
# Module Organization
####################################

# The infrastructure is organized into these files:
# - versions.tf    → Terraform and provider versions
# - variables.tf   → Input variables
# - outputs.tf     → Output values (what to test)
# - vpc.tf         → VPC, subnets, routing (both scenarios)
# - iam.tf         → IAM roles for ECS tasks
# - ecs.tf         → ECS cluster and task definitions
# - traditional.tf → ALB-based setup (Part A)
# - lattice.tf     → VPC Lattice setup (Part B)
# - main.tf        → This file (orchestration)

