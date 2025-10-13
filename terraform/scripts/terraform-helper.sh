#!/bin/bash

# Terraform Helper Script for Banking Infrastructure
# This script provides common Terraform operations with proper error handling

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$(dirname "$SCRIPT_DIR")"

# Default values
ENVIRONMENT=${1:-dev}
ACTION=${2:-plan}
AUTO_APPROVE=${3:-false}

echo -e "${BLUE}🏗️ Banking Infrastructure Terraform Helper${NC}"
echo "Directory: $TERRAFORM_DIR"
echo "Environment: $ENVIRONMENT"
echo "Action: $ACTION"
echo "=================================================="

# Change to terraform directory
cd "$TERRAFORM_DIR"

# Function to check prerequisites
check_prerequisites() {
    echo -e "${BLUE}Checking prerequisites...${NC}"
    
    # Check if terraform is installed
    if ! command -v terraform &> /dev/null; then
        echo -e "${RED}Terraform is not installed or not in PATH${NC}"
        exit 1
    fi
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}AWS CLI is not installed or not in PATH${NC}"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        echo -e "${RED}AWS credentials not configured or invalid${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Prerequisites satisfied${NC}"
}

# Function to initialize Terraform
terraform_init() {
    echo -e "${BLUE}Initializing Terraform...${NC}"
    
    terraform init \
        -upgrade \
        -input=false \
        -backend-config="bucket=banking-terraform-state-${ENVIRONMENT}" \
        -backend-config="key=eks/terraform.tfstate" \
        -backend-config="region=us-west-2"
    
    echo -e "${GREEN}✓ Terraform initialized${NC}"
}

# Function to validate Terraform configuration
terraform_validate() {
    echo -e "${BLUE}Validating Terraform configuration...${NC}"
    
    terraform validate
    
    echo -e "${GREEN}✓ Terraform configuration is valid${NC}"
}

# Function to format Terraform files
terraform_format() {
    echo -e "${BLUE}Formatting Terraform files...${NC}"
    
    terraform fmt -recursive
    
    echo -e "${GREEN}✓ Terraform files formatted${NC}"
}

# Function to plan Terraform changes
terraform_plan() {
    echo -e "${BLUE}Planning Terraform changes...${NC}"
    
    terraform plan \
        -var="environment=$ENVIRONMENT" \
        -out="terraform-${ENVIRONMENT}.tfplan" \
        -input=false
    
    echo -e "${GREEN}✓ Terraform plan completed${NC}"
}

# Function to apply Terraform changes
terraform_apply() {
    echo -e "${BLUE}Applying Terraform changes...${NC}"
    
    if [ "$AUTO_APPROVE" = "true" ]; then
        terraform apply \
            -var="environment=$ENVIRONMENT" \
            -auto-approve \
            -input=false
    else
        terraform apply \
            -var="environment=$ENVIRONMENT" \
            -input=false
    fi
    
    echo -e "${GREEN}✓ Terraform apply completed${NC}"
}

# Function to destroy infrastructure
terraform_destroy() {
    echo -e "${YELLOW}⚠️  WARNING: This will destroy all infrastructure!${NC}"
    
    if [ "$AUTO_APPROVE" = "true" ]; then
        terraform destroy \
            -var="environment=$ENVIRONMENT" \
            -auto-approve \
            -input=false
    else
        echo -e "${YELLOW}Please confirm by typing 'yes':${NC}"
        read -r confirmation
        if [ "$confirmation" = "yes" ]; then
            terraform destroy \
                -var="environment=$ENVIRONMENT" \
                -input=false
        else
            echo -e "${YELLOW}Destroy cancelled${NC}"
            exit 0
        fi
    fi
    
    echo -e "${GREEN}✓ Infrastructure destroyed${NC}"
}

# Function to show Terraform outputs
terraform_output() {
    echo -e "${BLUE}Terraform outputs:${NC}"
    
    terraform output -json | jq '.'
    
    echo -e "${GREEN}✓ Outputs displayed${NC}"
}

# Function to generate kubeconfig
generate_kubeconfig() {
    echo -e "${BLUE}Generating kubeconfig...${NC}"
    
    CLUSTER_NAME=$(terraform output -raw cluster_id 2>/dev/null || echo "banking-eks-${ENVIRONMENT}")
    AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-west-2")
    
    aws eks update-kubeconfig \
        --region "$AWS_REGION" \
        --name "$CLUSTER_NAME" \
        --kubeconfig ~/.kube/config-banking-$ENVIRONMENT
    
    echo -e "${GREEN}✓ Kubeconfig generated: ~/.kube/config-banking-$ENVIRONMENT${NC}"
    echo -e "${BLUE}To use: export KUBECONFIG=~/.kube/config-banking-$ENVIRONMENT${NC}"
}

# Function to check cluster health
check_cluster_health() {
    echo -e "${BLUE}Checking EKS cluster health...${NC}"
    
    CLUSTER_NAME=$(terraform output -raw cluster_id 2>/dev/null || echo "banking-eks-${ENVIRONMENT}")
    AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-west-2")
    
    # Check cluster status
    CLUSTER_STATUS=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" --query 'cluster.status' --output text)
    echo "Cluster Status: $CLUSTER_STATUS"
    
    # Check node group status
    NODE_GROUPS=$(aws eks list-nodegroups --cluster-name "$CLUSTER_NAME" --region "$AWS_REGION" --query 'nodegroups' --output text)
    for ng in $NODE_GROUPS; do
        NG_STATUS=$(aws eks describe-nodegroup --cluster-name "$CLUSTER_NAME" --nodegroup-name "$ng" --region "$AWS_REGION" --query 'nodegroup.status' --output text)
        echo "Node Group $ng Status: $NG_STATUS"
    done
    
    echo -e "${GREEN}✓ Cluster health check completed${NC}"
}

# Main script logic
case $ACTION in
    "init")
        check_prerequisites
        terraform_init
        terraform_validate
        ;;
    "validate")
        terraform_validate
        ;;
    "fmt"|"format")
        terraform_format
        ;;
    "plan")
        check_prerequisites
        terraform_plan
        ;;
    "apply")
        check_prerequisites
        terraform_apply
        ;;
    "destroy")
        check_prerequisites
        terraform_destroy
        ;;
    "output")
        terraform_output
        ;;
    "kubeconfig")
        generate_kubeconfig
        ;;
    "health")
        check_cluster_health
        ;;
    "all")
        check_prerequisites
        terraform_init
        terraform_validate
        terraform_format
        terraform_plan
        terraform_apply
        terraform_output
        generate_kubeconfig
        ;;
    *)
        echo -e "${RED}Invalid action: $ACTION${NC}"
        echo ""
        echo "Usage: $0 [environment] [action] [auto_approve]"
        echo ""
        echo "Actions:"
        echo "  init       - Initialize Terraform"
        echo "  validate   - Validate configuration"
        echo "  fmt        - Format Terraform files"
        echo "  plan       - Plan changes"
        echo "  apply      - Apply changes"
        echo "  destroy    - Destroy infrastructure"
        echo "  output     - Show outputs"
        echo "  kubeconfig - Generate kubeconfig"
        echo "  health     - Check cluster health"
        echo "  all        - Run complete deployment"
        echo ""
        echo "Environments: dev, staging, prod"
        echo "Auto approve: true, false (default: false)"
        exit 1
        ;;
esac

echo -e "${GREEN}🎉 Operation completed successfully!${NC}"