# Makefile for Banking K8s Infrastructure

# Variables
ENVIRONMENT ?= dev
AWS_REGION ?= us-west-2
TAG ?= latest
REGISTRY ?= ""
NAMESPACE = banking-app

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

# Help target
.PHONY: help
help: ## Show this help message
	@echo "$(BLUE)Banking K8s Infrastructure - Available Commands$(NC)"
	@echo "=================================================="
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "$(GREEN)%-20s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Prerequisites
.PHONY: check-prereqs
check-prereqs: ## Check if required tools are installed
	@echo "$(BLUE)Checking prerequisites...$(NC)"
	@command -v kubectl >/dev/null 2>&1 || (echo "$(RED)kubectl not found$(NC)" && exit 1)
	@command -v docker >/dev/null 2>&1 || (echo "$(RED)Docker not found$(NC)" && exit 1)
	@command -v minikube >/dev/null 2>&1 || (echo "$(RED)Minikube not found$(NC)" && exit 1)
	@echo "$(GREEN)All prerequisites satisfied$(NC)"

# Infrastructure targets
.PHONY: infra-init
infra-init: check-prereqs ## Initialize Terraform
	@./scripts/deploy-infrastructure.sh $(ENVIRONMENT) init

.PHONY: infra-plan
infra-plan: check-prereqs ## Plan Terraform changes
	@./scripts/deploy-infrastructure.sh $(ENVIRONMENT) plan

.PHONY: infra-apply
infra-apply: check-prereqs ## Apply Terraform changes
	@./scripts/deploy-infrastructure.sh $(ENVIRONMENT) apply

.PHONY: infra-destroy
infra-destroy: check-prereqs ## Destroy infrastructure
	@./scripts/deploy-infrastructure.sh $(ENVIRONMENT) destroy

# Docker targets
.PHONY: build
build: check-prereqs ## Build Docker images
	@./scripts/build-images.sh $(TAG) $(REGISTRY)

.PHONY: build-push
build-push: check-prereqs ## Build and push Docker images
	@./scripts/build-images.sh $(TAG) $(REGISTRY)

# Kubernetes targets  
.PHONY: kubeconfig
kubeconfig: ## Update kubeconfig for EKS cluster
	@./scripts/deploy-infrastructure.sh $(ENVIRONMENT) kubeconfig

.PHONY: deploy
deploy: check-prereqs ## Deploy application to Kubernetes
	@./scripts/deploy.sh $(ENVIRONMENT) $(AWS_REGION)

.PHONY: status
status: ## Show Kubernetes deployment status
	@./scripts/deploy.sh status

# Application management
.PHONY: scale-up
scale-up: ## Scale up application (backend=5, frontend=5)
	@echo "$(BLUE)Scaling up applications...$(NC)"
	@kubectl scale deployment banking-backend --replicas=5 -n $(NAMESPACE)
	@kubectl scale deployment banking-frontend --replicas=5 -n $(NAMESPACE)
	@echo "$(GREEN)Scaling completed$(NC)"

.PHONY: restart
restart: ## Restart all applications
	@echo "$(BLUE)Restarting applications...$(NC)"
	@kubectl rollout restart deployment/banking-backend -n $(NAMESPACE)
	@kubectl rollout restart deployment/banking-frontend -n $(NAMESPACE)
	@echo "$(GREEN)Restart completed$(NC)"

# Development targets
.PHONY: dev-setup
dev-setup: infra-init infra-apply kubeconfig build deploy ## Full development setup
	@echo "$(GREEN)🎉 Development environment ready!$(NC)"

.PHONY: docs
docs: ## Show application URLs and credentials
	@echo "$(BLUE)Banking Application Information$(NC)"
	@echo "=============================="
	@echo "$(GREEN)Demo Credentials:$(NC)"
	@echo "Username: demo_user"  
	@echo "Password: demo_password"

# Minikube specific targets
.PHONY: minikube-start
minikube-start: ## Start Minikube with proper configuration
	@echo "$(BLUE)Starting Minikube...$(NC)"
	@minikube start --driver=docker --memory=4096 --cpus=2
	@minikube addons enable ingress
	@minikube addons enable dashboard
	@minikube addons enable metrics-server
	@echo "$(GREEN)Minikube started and configured$(NC)"

.PHONY: minikube-stop
minikube-stop: ## Stop Minikube
	@echo "$(BLUE)Stopping Minikube...$(NC)"
	@minikube stop
	@echo "$(GREEN)Minikube stopped$(NC)"

.PHONY: minikube-delete
minikube-delete: ## Delete Minikube cluster
	@echo "$(YELLOW)Deleting Minikube cluster...$(NC)"
	@minikube delete
	@echo "$(GREEN)Minikube cluster deleted$(NC)"

.PHONY: minikube-dashboard
minikube-dashboard: ## Open Kubernetes dashboard
	@minikube dashboard

.PHONY: minikube-tunnel
minikube-tunnel: ## Start minikube tunnel for LoadBalancer services
	@echo "$(BLUE)Starting Minikube tunnel...$(NC)"
	@sudo minikube tunnel

.PHONY: minikube-ip
minikube-ip: ## Show Minikube IP
	@echo "$(BLUE)Minikube IP:$(NC) $(shell minikube ip)"

# Complete deployment targets
.PHONY: deploy-all
deploy-all: check-prereqs ## Complete deployment (Minikube + App)
	@echo "$(BLUE)🚀 Starting complete deployment...$(NC)"
	@./scripts/setup-environment.sh
	@./scripts/deploy-infrastructure.sh dev deploy
	@echo "$(GREEN)🎉 Deployment completed!$(NC)"
	@make show-urls

.PHONY: clean-all
clean-all: ## Clean all resources and stop Minikube
	@echo "$(BLUE)Cleaning all resources...$(NC)"
	@./scripts/deploy-infrastructure.sh dev destroy || true
	@make minikube-stop || true
	@docker system prune -f || true
	@echo "$(GREEN)Cleanup completed$(NC)"

.PHONY: show-urls
show-urls: ## Show application access URLs
	@echo ""
	@echo "$(BLUE)🌐 Application Access URLs$(NC)"
	@echo "================================="
	@echo "$(GREEN)Frontend (NodePort):$(NC) http://$(shell minikube ip):$(shell kubectl get service banking-frontend -n $(NAMESPACE) -o jsonpath='{.spec.ports[0].nodePort}')"
	@echo "$(GREEN)Backend (NodePort):$(NC) http://$(shell minikube ip):$(shell kubectl get service backend-loadbalancer -n $(NAMESPACE) -o jsonpath='{.spec.ports[0].nodePort}')"
	@echo "$(GREEN)Kubernetes Dashboard:$(NC) Run 'make minikube-dashboard'"
	@echo ""
	@echo "$(BLUE)Alternative Access (minikube service):$(NC)"
	@echo "• Frontend: $(YELLOW)minikube service banking-frontend -n $(NAMESPACE)$(NC)"
	@echo "• Backend: $(YELLOW)minikube service backend-loadbalancer -n $(NAMESPACE)$(NC)"
	@echo ""
	@echo "$(BLUE)Quick Commands:$(NC)"
	@echo "• View pods: $(YELLOW)kubectl get pods -n $(NAMESPACE)$(NC)"
	@echo "• View services: $(YELLOW)kubectl get svc -n $(NAMESPACE)$(NC)"
	@echo "• View logs: $(YELLOW)kubectl logs -f deployment/banking-backend -n $(NAMESPACE)$(NC)"
	@echo "• Scale app: $(YELLOW)make scale-up$(NC)"

.PHONY: logs
logs: ## Show application logs
	@echo "$(BLUE)Application Logs:$(NC)"
	@echo "Backend logs:"
	@kubectl logs -f deployment/banking-backend -n $(NAMESPACE) --tail=50

.PHONY: logs-frontend  
logs-frontend: ## Show frontend logs
	@echo "$(BLUE)Frontend Logs:$(NC)"
	@kubectl logs -f deployment/banking-frontend -n $(NAMESPACE) --tail=50

.PHONY: shell-backend
shell-backend: ## Open shell in backend pod
	@kubectl exec -it deployment/banking-backend -n $(NAMESPACE) -- /bin/bash

.PHONY: shell-postgres
shell-postgres: ## Open PostgreSQL shell
	@kubectl exec -it deployment/postgres -n $(NAMESPACE) -- psql -U banking_user -d banking_db

.PHONY: port-forward
port-forward: ## Port forward services to localhost
	@echo "$(BLUE)Starting port forwarding...$(NC)"
	@echo "Frontend: http://localhost:3000"
	@echo "Backend: http://localhost:8000"
	@echo "Press Ctrl+C to stop"
	@kubectl port-forward svc/banking-frontend 3000:80 -n $(NAMESPACE) &
	@kubectl port-forward svc/banking-backend 8000:8000 -n $(NAMESPACE) &
	@wait

# Testing targets
.PHONY: test-connectivity
test-connectivity: ## Test application connectivity
	@echo "$(BLUE)Testing application connectivity...$(NC)"
	@./scripts/deploy-application.sh test

.PHONY: test-api
test-api: ## Test backend API endpoints
	@echo "$(BLUE)Testing API endpoints...$(NC)"
	@MINIKUBE_IP=$$(minikube ip) && \
	curl -f "http://$$MINIKUBE_IP/api/health" && echo "✓ Health check passed" || echo "✗ Health check failed"

# Environment management
.PHONY: setup-dev
setup-dev: ## Setup complete development environment
	@echo "$(BLUE)🔧 Setting up development environment...$(NC)"
	@./scripts/setup-environment.sh
	@make deploy-all
	@make show-urls

.PHONY: backup-db
backup-db: ## Backup PostgreSQL database
	@echo "$(BLUE)Creating database backup...$(NC)"
	@kubectl exec deployment/postgres -n $(NAMESPACE) -- pg_dump -U banking_user banking_db > backup_$(shell date +%Y%m%d_%H%M%S).sql
	@echo "$(GREEN)Database backup created$(NC)"

# Docker Compose targets (for local development)
.PHONY: docker-up
docker-up: ## Start services with Docker Compose
	@echo "$(BLUE)Starting services with Docker Compose...$(NC)"
	@docker-compose up -d
	@echo "$(GREEN)Services started$(NC)"

.PHONY: docker-down
docker-down: ## Stop Docker Compose services
	@echo "$(BLUE)Stopping Docker Compose services...$(NC)"
	@docker-compose down
	@echo "$(GREEN)Services stopped$(NC)"

.PHONY: docker-logs
docker-logs: ## Show Docker Compose logs
	@docker-compose logs -f

# Default target
.DEFAULT_GOAL := help