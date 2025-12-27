#!/bin/bash

#############################################
# VPC Lattice Lab - Setup Script
# Demonstrates: Before and After VPC Lattice
#############################################

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================="
echo "VPC Lattice Lab - Setup"
echo "=========================================="
echo ""

#############################################
# Step 1: Choose Scenario
#############################################

echo -e "${YELLOW}Which scenario do you want to deploy?${NC}"
echo ""
echo "  1. Traditional (ALB-based) - Frontend -> ALB -> Backend"
echo "  2. VPC Lattice - Frontend -> Service Network -> Backend"
echo "  3. Both (for comparison)"
echo ""
read -p "Enter choice (1/2/3): " CHOICE

case $CHOICE in
  1)
    SCENARIO="traditional"
    ;;
  2)
    SCENARIO="lattice"
    ;;
  3)
    SCENARIO="both"
    ;;
  *)
    echo -e "${RED}Invalid choice${NC}"
    exit 1
    ;;
esac

echo ""
echo -e "${GREEN}Selected scenario: $SCENARIO${NC}"
echo ""

#############################################
# Step 2: Verify Terraform
#############################################

echo -e "${BLUE}Step 2: Verifying Terraform...${NC}"
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}ERROR: Terraform not found${NC}"
    echo "Install from: https://www.terraform.io/downloads"
    exit 1
fi

TF_VERSION=$(terraform version | head -1)
echo -e "${GREEN}✓ Terraform found: $TF_VERSION${NC}"
echo ""

#############################################
# Step 3: Verify AWS Credentials
#############################################

echo -e "${BLUE}Step 3: Verifying AWS credentials...${NC}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
if [ -z "$ACCOUNT_ID" ]; then
    echo -e "${RED}ERROR: AWS credentials not configured${NC}"
    echo "Run: aws configure"
    exit 1
fi

echo -e "${GREEN}✓ AWS Account ID: $ACCOUNT_ID${NC}"
echo ""

#############################################
# Step 4: Initialize Terraform
#############################################

echo -e "${BLUE}Step 4: Initializing Terraform...${NC}"
terraform init

if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: Terraform init failed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Terraform initialized${NC}"
echo ""

#############################################
# Step 5: Plan Deployment
#############################################

echo -e "${BLUE}Step 5: Planning deployment...${NC}"
terraform plan -var="deploy_scenario=$SCENARIO" -out=tfplan

if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: Terraform plan failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ Plan created${NC}"
echo ""

#############################################
# Step 6: Confirm Deployment
#############################################

echo -e "${YELLOW}Ready to deploy. This will create:${NC}"
echo ""
if [ "$SCENARIO" == "traditional" ]; then
    echo "  • VPC + Subnets + NAT Gateways"
    echo "  • ECS Cluster + 2 Services"
    echo "  • Application Load Balancer"
    echo "  • Target Group + Listener"
    echo "  • 3 Security Groups"
elif [ "$SCENARIO" == "lattice" ]; then
    echo "  • VPC + Subnets + NAT Gateways"
    echo "  • ECS Cluster + 2 Services"
    echo "  • VPC Lattice Service Network"
    echo "  • VPC Lattice Service"
    echo "  • IAM Auth Policy"
    echo "  • 2 Security Groups"
else
    echo "  • All components from both scenarios"
fi
echo ""
echo -e "${YELLOW}Estimated cost: ~\$0.50/hour${NC}"
echo -e "${YELLOW}Deployment time: ~5-7 minutes${NC}"
echo ""

read -p "Continue? (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ]; then
    echo "Cancelled."
    exit 0
fi

#############################################
# Step 7: Apply Terraform
#############################################

echo ""
echo -e "${BLUE}Step 7: Deploying infrastructure...${NC}"
echo ""

terraform apply tfplan

if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: Terraform apply failed${NC}"
    exit 1
fi

echo ""
echo "=========================================="
echo -e "${GREEN}DEPLOYMENT COMPLETE!${NC}"
echo "=========================================="
echo ""

#############################################
# Step 8: Display Outputs
#############################################

echo -e "${BLUE}Deployment Summary:${NC}"
echo ""
terraform output -json | jq -r 'to_entries[] | "\(.key): \(.value.value)"' 2>/dev/null || terraform output

echo ""
echo "=========================================="
echo "NEXT STEPS"
echo "=========================================="

if [ "$SCENARIO" == "traditional" ]; then
    echo ""
    echo "1. Test the traditional setup:"
    ALB_DNS=$(terraform output -raw traditional_alb_dns 2>/dev/null || echo "")
    if [ -n "$ALB_DNS" ]; then
        echo "   curl http://$ALB_DNS"
    fi
    echo ""
    echo "2. Observe in AWS Console:"
    echo "   - EC2 > Load Balancers (ALB)"
    echo "   - EC2 > Target Groups"
    echo "   - VPC > Security Groups (3 groups with chained rules)"
    echo ""
    echo "3. Ask: Is access explicit or implicit?"
elif [ "$SCENARIO" == "lattice" ]; then
    echo ""
    echo "1. Test VPC Lattice setup:"
    echo "   - Frontend can call backend via service DNS"
    echo "   - No ALB needed"
    echo ""
    echo "2. Observe in AWS Console:"
    echo "   - VPC > Lattice > Service Networks"
    echo "   - VPC > Lattice > Services"
    echo "   - VPC > Lattice > Access (IAM policy)"
    echo ""
    echo "3. Ask: Who is allowed to call whom?"
fi

echo ""
echo "=========================================="
echo "TO CLEAN UP (IMPORTANT):"
echo "=========================================="
echo ""
echo "  ./cleanup.sh"
echo ""
echo "Or manually:"
echo "  terraform destroy -var=\"deploy_scenario=$SCENARIO\""
echo ""
echo "=========================================="

