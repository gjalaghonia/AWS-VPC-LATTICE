####################################
# Outputs - What to Test
####################################

output "scenario_deployed" {
  description = "Which scenario was deployed"
  value       = var.deploy_scenario
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

####################################
# Traditional Scenario Outputs
####################################

output "traditional_alb_dns" {
  description = "ALB DNS name for traditional setup"
  value       = var.deploy_scenario == "traditional" || var.deploy_scenario == "both" ? aws_lb.main[0].dns_name : null
}

output "traditional_backend_url" {
  description = "Backend URL via ALB (traditional)"
  value       = var.deploy_scenario == "traditional" || var.deploy_scenario == "both" ? "http://${aws_lb.main[0].dns_name}" : null
}

output "traditional_frontend_task_id" {
  description = "Frontend ECS task ID (traditional)"
  value       = var.deploy_scenario == "traditional" || var.deploy_scenario == "both" ? aws_ecs_service.frontend[0].id : null
}

output "traditional_components_created" {
  description = "Components created in traditional setup"
  value = var.deploy_scenario == "traditional" || var.deploy_scenario == "both" ? [
    "Application Load Balancer",
    "Target Group",
    "3 Security Groups (Frontend, ALB, Backend)",
    "Security Group Rules (6+)",
    "ECS Services (2)",
    "CloudWatch Log Groups"
  ] : []
}

####################################
# VPC Lattice Scenario Outputs
####################################

output "lattice_service_network_id" {
  description = "VPC Lattice Service Network ID"
  value       = var.deploy_scenario == "lattice" || var.deploy_scenario == "both" ? aws_vpclattice_service_network.main[0].id : null
}

output "lattice_service_network_arn" {
  description = "VPC Lattice Service Network ARN"
  value       = var.deploy_scenario == "lattice" || var.deploy_scenario == "both" ? aws_vpclattice_service_network.main[0].arn : null
}

output "lattice_backend_service_dns" {
  description = "VPC Lattice backend service DNS name"
  value       = var.deploy_scenario == "lattice" || var.deploy_scenario == "both" ? aws_vpclattice_service.backend[0].dns_entry[0].domain_name : null
}

output "lattice_backend_service_url" {
  description = "Backend URL via VPC Lattice"
  value       = var.deploy_scenario == "lattice" || var.deploy_scenario == "both" ? "http://${aws_vpclattice_service.backend[0].dns_entry[0].domain_name}" : null
}

output "lattice_components_created" {
  description = "Components created in VPC Lattice setup"
  value = var.deploy_scenario == "lattice" || var.deploy_scenario == "both" ? [
    "VPC Lattice Service Network",
    "VPC Lattice Service (backend)",
    "VPC Lattice Target Group",
    "VPC Association",
    "Auth Policy (explicit allow)",
    "2 Security Groups (Frontend, Backend)",
    "ECS Services (2)"
  ] : []
}

####################################
# Comparison
####################################

output "key_difference" {
  description = "Key architectural difference"
  value = {
    traditional = "Frontend -> ALB -> Backend (implicit trust via SG)"
    lattice     = "Frontend -> Service Network -> Backend (explicit policy)"
  }
}

output "components_eliminated" {
  description = "What VPC Lattice eliminates"
  value = var.deploy_scenario == "lattice" || var.deploy_scenario == "both" ? [
    "Application Load Balancer (for east-west traffic)",
    "Target Group management",
    "Security Group chaining",
    "Manual DNS/discovery setup"
  ] : []
}

####################################
# Testing Instructions
####################################

output "test_instructions_traditional" {
  description = "How to test traditional setup"
  value = var.deploy_scenario == "traditional" || var.deploy_scenario == "both" ? {
    step_1 = "Get ALB DNS: ${try(aws_lb.main[0].dns_name, "N/A")}"
    step_2 = "curl http://${try(aws_lb.main[0].dns_name, "N/A")}"
    step_3 = "Observe: Traffic goes Frontend -> ALB -> Backend"
    step_4 = "Check AWS Console: See ALB, Target Group, Security Groups"
  } : null
}

output "test_instructions_lattice" {
  description = "How to test VPC Lattice setup"
  value = var.deploy_scenario == "lattice" || var.deploy_scenario == "both" ? {
    step_1 = "VPC Lattice Service DNS: ${try(aws_vpclattice_service.backend[0].dns_entry[0].domain_name, "N/A")}"
    step_2 = "From frontend container, call backend directly via service name"
    step_3 = "Observe: No ALB needed, direct service-to-service"
    step_4 = "Check AWS Console: See Service Network, explicit auth policy"
  } : null
}

####################################
# Cost Estimate
####################################

output "estimated_hourly_cost" {
  description = "Estimated cost per hour"
  value = {
    traditional = "$0.50/hour (ALB $0.025/hour + 2 ECS tasks ~$0.48/hour)"
    lattice     = "$0.30/hour (VPC Lattice ~$0.025/hour + 2 ECS tasks ~$0.28/hour, no ALB)"
    note        = "Destroy immediately after testing to minimize cost"
  }
}

####################################
# Cleanup
####################################

output "cleanup_command" {
  description = "How to clean up resources"
  value       = "terraform destroy -auto-approve"
}

