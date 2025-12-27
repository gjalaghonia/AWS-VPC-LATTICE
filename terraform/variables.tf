variable "aws_region" {
  description = "AWS region for the lab"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "vpc-lattice-lab"
}

variable "deploy_scenario" {
  description = "Which scenario to deploy: 'traditional' or 'lattice'"
  type        = string
  default     = "traditional"

  validation {
    condition     = contains(["traditional", "lattice", "both"], var.deploy_scenario)
    error_message = "deploy_scenario must be 'traditional', 'lattice', or 'both'."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones to use"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "frontend_container_image" {
  description = "Docker image for frontend service"
  type        = string
  default     = "public.ecr.aws/nginx/nginx:latest"
}

variable "backend_container_image" {
  description = "Docker image for backend service"
  type        = string
  default     = "hashicorp/http-echo:latest"
}

variable "backend_port" {
  description = "Port for backend service"
  type        = number
  default     = 5678
}

variable "frontend_port" {
  description = "Port for frontend service"
  type        = number
  default     = 80
}

variable "enable_detailed_logs" {
  description = "Enable detailed CloudWatch logs"
  type        = bool
  default     = true
}

variable "deploy_bastion" {
  description = "Deploy a bastion host for testing internal resources"
  type        = bool
  default     = true
}

