# Banking EKS Infrastructure - Terraform Makefile
# Facilita las operaciones comunes de Terraform

.PHONY: help init plan apply destroy validate fmt lint clean check-tools setup

# Variables
TF_VAR_FILE ?= terraform.tfvars
ENVIRONMENT ?= dev
AWS_REGION ?= us-west-2

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

# Default target
help: ## Show this help message
	@echo "$(BLUE)Banking EKS Infrastructure - Terraform Commands$(NC)"
	@echo ""
	@echo "$(GREEN)Available commands:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(YELLOW)%-15s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(GREEN)Usage examples:$(NC)"
	@echo "  make setup              # Initial setup and validation"
	@echo "  make plan ENV=prod      # Plan for production environment"
	@echo "  make apply ENV=staging  # Apply for staging environment"
	@echo ""

check-tools: ## Check if required tools are installed
	@echo "$(BLUE)Checking required tools...$(NC)"
	@which terraform >/dev/null 2>&1 || (echo "$(RED)Error: terraform not found$(NC)" && exit 1)
	@which aws >/dev/null 2>&1 || (echo "$(RED)Error: aws cli not found$(NC)" && exit 1)
	@which kubectl >/dev/null 2>&1 || (echo "$(RED)Error: kubectl not found$(NC)" && exit 1)
	@echo "$(GREEN)✓ All required tools are installed$(NC)"

check-aws: ## Check AWS credentials and configuration
	@echo "$(BLUE)Checking AWS configuration...$(NC)"
	@aws sts get-caller-identity >/dev/null 2>&1 || (echo "$(RED)Error: AWS credentials not configured$(NC)" && exit 1)
	@echo "$(GREEN)✓ AWS credentials are configured$(NC)"
	@aws sts get-caller-identity

check-tfvars: ## Check if terraform.tfvars exists
	@if [ ! -f $(TF_VAR_FILE) ]; then \
		echo "$(YELLOW)Warning: $(TF_VAR_FILE) not found$(NC)"; \
		echo "$(BLUE)Creating from template...$(NC)"; \
		cp terraform.tfvars.example $(TF_VAR_FILE); \
		echo "$(GREEN)✓ Created $(TF_VAR_FILE) from template$(NC)"; \
		echo "$(YELLOW)Please edit $(TF_VAR_FILE) with your values before proceeding$(NC)"; \
	else \
		echo "$(GREEN)✓ $(TF_VAR_FILE) found$(NC)"; \
	fi

setup: check-tools check-aws check-tfvars ## Complete setup and validation
	@echo "$(GREEN)✓ Setup completed successfully$(NC)"
	@echo ""
	@echo "$(BLUE)Next steps:$(NC)"
	@echo "1. Edit $(TF_VAR_FILE) with your configuration"
	@echo "2. Run 'make init' to initialize Terraform"
	@echo "3. Run 'make plan' to see planned changes"
	@echo "4. Run 'make apply' to create infrastructure"

init: ## Initialize Terraform
	@echo "$(BLUE)Initializing Terraform...$(NC)"
	terraform init
	@echo "$(GREEN)✓ Terraform initialized$(NC)"

validate: ## Validate Terraform configuration
	@echo "$(BLUE)Validating Terraform configuration...$(NC)"
	terraform validate
	@echo "$(GREEN)✓ Configuration is valid$(NC)"

fmt: ## Format Terraform files
	@echo "$(BLUE)Formatting Terraform files...$(NC)"
	terraform fmt -recursive
	@echo "$(GREEN)✓ Files formatted$(NC)"

lint: fmt validate ## Run linting and validation
	@echo "$(GREEN)✓ Linting completed$(NC)"

plan: check-tfvars ## Plan Terraform changes
	@echo "$(BLUE)Planning Terraform changes...$(NC)"
	terraform plan -var-file=$(TF_VAR_FILE) -out=tfplan
	@echo "$(GREEN)✓ Plan completed$(NC)"

plan-destroy: check-tfvars ## Plan Terraform destroy
	@echo "$(BLUE)Planning Terraform destroy...$(NC)"
	terraform plan -destroy -var-file=$(TF_VAR_FILE) -out=tfplan-destroy
	@echo "$(YELLOW)⚠ Destroy plan completed$(NC)"

apply: ## Apply Terraform changes
	@if [ ! -f tfplan ]; then \
		echo "$(RED)Error: No plan file found. Run 'make plan' first$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Applying Terraform changes...$(NC)"
	terraform apply tfplan
	@echo "$(GREEN)✓ Infrastructure deployed successfully$(NC)"
	@$(MAKE) show-outputs

apply-auto: check-tfvars ## Apply changes automatically (skip plan file)
	@echo "$(YELLOW)⚠ Auto-applying Terraform changes...$(NC)"
	@read -p "Are you sure you want to proceed? [y/N] " -n 1 -r; \
	echo ""; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		terraform apply -var-file=$(TF_VAR_FILE) -auto-approve; \
		echo "$(GREEN)✓ Infrastructure deployed successfully$(NC)"; \
		$(MAKE) show-outputs; \
	else \
		echo "$(BLUE)Operation cancelled$(NC)"; \
	fi

destroy: ## Destroy Terraform infrastructure
	@echo "$(RED)⚠ WARNING: This will destroy ALL infrastructure!$(NC)"
	@read -p "Type 'destroy' to confirm: " -r; \
	if [ "$$REPLY" = "destroy" ]; then \
		terraform destroy -var-file=$(TF_VAR_FILE) -auto-approve; \
		echo "$(RED)✓ Infrastructure destroyed$(NC)"; \
	else \
		echo "$(BLUE)Operation cancelled$(NC)"; \
	fi

show-outputs: ## Show Terraform outputs
	@echo "$(BLUE)Terraform Outputs:$(NC)"
	@terraform output

show-resources: ## Show all Terraform resources
	@echo "$(BLUE)Terraform Resources:$(NC)"
	@terraform state list

refresh: ## Refresh Terraform state
	@echo "$(BLUE)Refreshing Terraform state...$(NC)"
	terraform refresh -var-file=$(TF_VAR_FILE)
	@echo "$(GREEN)✓ State refreshed$(NC)"

import: ## Import existing resource (usage: make import RESOURCE=aws_instance.example ID=i-1234567890abcdef0)
	@if [ -z "$(RESOURCE)" ] || [ -z "$(ID)" ]; then \
		echo "$(RED)Error: Missing RESOURCE or ID$(NC)"; \
		echo "Usage: make import RESOURCE=aws_instance.example ID=i-1234567890abcdef0"; \
		exit 1; \
	fi
	terraform import $(RESOURCE) $(ID)

clean: ## Clean temporary files
	@echo "$(BLUE)Cleaning temporary files...$(NC)"
	rm -f tfplan tfplan-destroy
	rm -f terraform.tfplan
	rm -f .terraform.lock.hcl
	@echo "$(GREEN)✓ Temporary files cleaned$(NC)"

clean-all: clean ## Clean all Terraform files (including state)
	@echo "$(RED)⚠ WARNING: This will remove ALL Terraform state!$(NC)"
	@read -p "Type 'clean-all' to confirm: " -r; \
	if [ "$$REPLY" = "clean-all" ]; then \
		rm -rf .terraform; \
		rm -f terraform.tfstate*; \
		echo "$(RED)✓ All Terraform files cleaned$(NC)"; \
	else \
		echo "$(BLUE)Operation cancelled$(NC)"; \
	fi

# EKS specific commands
configure-kubectl: ## Configure kubectl for EKS cluster
	@echo "$(BLUE)Configuring kubectl for EKS cluster...$(NC)"
	@CLUSTER_NAME=$$(terraform output -raw cluster_id 2>/dev/null || echo "$(ENVIRONMENT)-banking-eks"); \
	aws eks update-kubeconfig --region $(AWS_REGION) --name $$CLUSTER_NAME
	@echo "$(GREEN)✓ kubectl configured$(NC)"

test-connection: configure-kubectl ## Test connection to EKS cluster
	@echo "$(BLUE)Testing connection to EKS cluster...$(NC)"
	kubectl get nodes
	kubectl get pods --all-namespaces
	@echo "$(GREEN)✓ Connection test completed$(NC)"

deploy-addons: ## Deploy essential EKS add-ons
	@echo "$(BLUE)Deploying EKS add-ons...$(NC)"
	@# Add commands to deploy AWS Load Balancer Controller, Cluster Autoscaler, etc.
	@echo "$(YELLOW)⚠ Add-on deployment not implemented yet$(NC)"

# Monitoring and debugging
logs: ## Show recent Terraform logs
	@echo "$(BLUE)Recent Terraform operations:$(NC)"
	@ls -la .terraform/ 2>/dev/null || echo "No Terraform state found"

check-costs: ## Estimate infrastructure costs
	@echo "$(BLUE)Infrastructure Cost Estimation:$(NC)"
	@echo "$(YELLOW)Use AWS Pricing Calculator or tools like Infracost for detailed estimates$(NC)"
	@echo "Basic estimation for $(ENVIRONMENT) environment:"
	@echo "- EKS Control Plane: ~$$73/month"
	@echo "- EC2 Instances (3x t3.medium): ~$$100/month"
	@echo "- RDS (db.t3.micro): ~$$15/month"
	@echo "- ElastiCache (cache.t3.micro): ~$$15/month"
	@echo "- Data transfer and storage: ~$$20/month"
	@echo "$(GREEN)Total estimated: ~$$223/month$(NC)"

security-check: ## Run basic security checks
	@echo "$(BLUE)Running basic security checks...$(NC)"
	@terraform show -json | jq -r '.values.root_module.resources[] | select(.type == "aws_security_group") | .values.name' || echo "No security groups found"
	@echo "$(GREEN)✓ Security check completed$(NC)"

# Environment-specific shortcuts
dev: ## Deploy to development environment
	$(MAKE) apply TF_VAR_FILE=terraform.tfvars ENVIRONMENT=dev

staging: ## Deploy to staging environment
	$(MAKE) apply TF_VAR_FILE=terraform-staging.tfvars ENVIRONMENT=staging

prod: ## Deploy to production environment
	$(MAKE) apply TF_VAR_FILE=terraform-prod.tfvars ENVIRONMENT=prod

# Backup and restore
backup-state: ## Backup Terraform state
	@echo "$(BLUE)Backing up Terraform state...$(NC)"
	@mkdir -p backups
	@cp terraform.tfstate backups/terraform.tfstate.$(shell date +%Y%m%d_%H%M%S) 2>/dev/null || echo "No local state file found"
	@echo "$(GREEN)✓ State backed up$(NC)"

# Documentation
docs: ## Generate documentation
	@echo "$(BLUE)Terraform Documentation:$(NC)"
	@echo "See README.md for detailed documentation"
	@echo ""
	@echo "$(GREEN)Quick Reference:$(NC)"
	@echo "- Configuration: $(TF_VAR_FILE)"
	@echo "- AWS Region: $(AWS_REGION)"
	@echo "- Environment: $(ENVIRONMENT)"