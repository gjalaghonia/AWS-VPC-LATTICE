#!/bin/bash

#############################################
# VPC Lattice Lab - Cleanup Script
#############################################

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "=========================================="
echo "VPC Lattice Lab - Cleanup"
echo "=========================================="
echo ""

#############################################
# Check Terraform State
#############################################

if [ ! -f "terraform.tfstate" ]; then
    echo -e "${YELLOW}No terraform state found.${NC}"
    echo "Nothing to clean up."
    exit 0
fi

#############################################
# Detect Scenario
#############################################

SCENARIO=$(terraform output -raw scenario_deployed 2>/dev/null || echo "unknown")

echo -e "${YELLOW}Detected scenario: $SCENARIO${NC}"
echo ""

#############################################
# Confirm Destruction
#############################################

echo -e "${RED}WARNING: This will destroy all resources!${NC}"
echo ""
echo "Resources to be destroyed:"
echo "  • VPC and all networking components"
echo "  • ECS Cluster and services"

if [ "$SCENARIO" == "traditional" ]; then
    echo "  • Application Load Balancer"
    echo "  • Target Groups"
elif [ "$SCENARIO" == "lattice" ]; then
    echo "  • VPC Lattice Service Network"
    echo "  • VPC Lattice Services"
fi

echo "  • Security Groups"
echo "  • CloudWatch Log Groups"
echo "  • NAT Gateways and Elastic IPs"
echo ""

read -p "Are you sure? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Cancelled."
    exit 0
fi

#############################################
# Destroy Infrastructure
#############################################

echo ""
echo -e "${YELLOW}Destroying infrastructure...${NC}"
echo ""

if [ "$SCENARIO" != "unknown" ]; then
    terraform destroy -var="deploy_scenario=$SCENARIO" -auto-approve
else
    # Try to destroy without knowing scenario
    terraform destroy -auto-approve
fi

if [ $? -ne 0 ]; then
    echo ""
    echo -e "${RED}ERROR: Terraform destroy failed${NC}"
    echo ""
    echo "Common issues:"
    echo "  1. ENIs still attached (wait 1-2 minutes, retry)"
    echo "  2. Load balancers not deleted (check AWS Console)"
    echo "  3. VPC Lattice associations still active"
    echo ""
    echo "Manual cleanup:"
    echo "  1. Check AWS Console for remaining resources"
    echo "  2. Delete manually if needed"
    echo "  3. Run: terraform destroy -var=\"deploy_scenario=$SCENARIO\" again"
    exit 1
fi

echo ""
echo "=========================================="
echo -e "${GREEN}CLEANUP COMPLETE!${NC}"
echo "=========================================="
echo ""
echo "All resources have been destroyed."
echo "No ongoing charges."
echo ""

#############################################
# Clean Up Terraform Files
#############################################

read -p "Remove Terraform state files? (y/n): " CLEAN_STATE

if [ "$CLEAN_STATE" == "y" ]; then
    rm -f terraform.tfstate*
    rm -f tfplan
    rm -rf .terraform
    echo -e "${GREEN}✓ Terraform files removed${NC}"
fi

echo ""
echo "=========================================="
echo "Lab complete. Thank you!"
echo "=========================================="

