#!/bin/bash

# Banking K8s Infrastructure - Minikube Deployment Script
# This script deploys the banking application to Minikube

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

ENVIRONMENT=${1:-dev}
ACTION=${2:-deploy}

echo -e "${BLUE}🏦 Banking Infrastructure Deployment for Minikube${NC}"
echo "Environment: $ENVIRONMENT"
echo "Action: $ACTION"
echo "=================================================="

# Ensure we're using minikube context
kubectl config use-context minikube

case $ACTION in
    "init")
        echo -e "${BLUE}Initializing infrastructure...${NC}"
        
        # Check if minikube is running
        if ! minikube status >/dev/null 2>&1; then
            echo -e "${RED}Minikube is not running. Please run 'minikube start' first.${NC}"
            exit 1
        fi
        
        # Enable Docker daemon
        eval $(minikube docker-env)
        
        echo -e "${GREEN}✓ Infrastructure initialized${NC}"
        ;;
        
    "plan")
        echo -e "${BLUE}Planning Kubernetes deployment...${NC}"
        
        # Validate Kubernetes manifests
        echo -e "${YELLOW}Validating Kubernetes manifests...${NC}"
        kubectl apply --dry-run=client -f k8s/ || {
            echo -e "${RED}Kubernetes manifest validation failed${NC}"
            exit 1
        }
        
        echo -e "${GREEN}✓ All manifests are valid${NC}"
        ;;
        
    "deploy"|"apply")
        echo -e "${BLUE}Deploying to Minikube...${NC}"
        
        # Set Docker environment to minikube
        eval $(minikube docker-env)
        
        # Build Docker images in minikube
        echo -e "${YELLOW}Building Docker images...${NC}"
        
        # Build backend image
        cd app/backend
        docker build -t banking-backend:latest .
        cd ../..
        
        # Build frontend image
        cd app/frontend  
        docker build -t banking-frontend:latest .
        cd ../..
        
        echo -e "${GREEN}✓ Docker images built${NC}"
        
        # Deploy to Kubernetes
        echo -e "${YELLOW}Deploying to Kubernetes...${NC}"
        
        # Create namespace
        kubectl apply -f k8s/namespace.yaml
        
        # Deploy applications in order
        kubectl apply -f k8s/postgres-deployment.yaml
        kubectl apply -f k8s/redis-deployment.yaml
        
        # Wait for databases to be ready
        echo -e "${YELLOW}Waiting for databases to be ready...${NC}"
        kubectl wait --for=condition=ready pod -l app=postgres -n banking-app --timeout=300s
        kubectl wait --for=condition=ready pod -l app=redis -n banking-app --timeout=300s
        
        # Deploy applications
        kubectl apply -f k8s/backend-deployment.yaml
        kubectl apply -f k8s/frontend-deployment.yaml
        
        # Deploy services and ingress
        kubectl apply -f k8s/services.yaml
        kubectl apply -f k8s/ingress.yaml
        
        # Wait for deployments
        echo -e "${YELLOW}Waiting for applications to be ready...${NC}"
        kubectl wait --for=condition=available deployment/banking-backend -n banking-app --timeout=300s
        kubectl wait --for=condition=available deployment/banking-frontend -n banking-app --timeout=300s
        
        echo -e "${GREEN}✓ Deployment completed successfully${NC}"
        
        # Show access information
        echo ""
        echo -e "${BLUE}Access Information:${NC}"
        echo "==================="
        
        # Get Minikube IP
        MINIKUBE_IP=$(minikube ip)
        echo -e "Frontend URL: ${YELLOW}http://$MINIKUBE_IP${NC}"
        echo -e "Backend API: ${YELLOW}http://$MINIKUBE_IP/api${NC}"
        echo -e "API Docs: ${YELLOW}http://$MINIKUBE_IP/api/docs${NC}"
        
        echo ""
        echo -e "${BLUE}Useful Commands:${NC}"
        echo "• View pods: ${YELLOW}kubectl get pods -n banking-app${NC}"
        echo "• View services: ${YELLOW}kubectl get svc -n banking-app${NC}"
        echo "• Open in browser: ${YELLOW}minikube service banking-frontend -n banking-app${NC}"
        echo "• View dashboard: ${YELLOW}minikube dashboard${NC}"
        ;;
        
    "destroy")
        echo -e "${BLUE}Destroying infrastructure...${NC}"
        
        # Delete all resources
        kubectl delete -f k8s/ --ignore-not-found=true
        
        # Clean up Docker images
        eval $(minikube docker-env)
        docker rmi banking-backend:latest banking-frontend:latest 2>/dev/null || true
        
        echo -e "${GREEN}✓ Infrastructure destroyed${NC}"
        ;;
        
    *)
        echo -e "${RED}Invalid action: $ACTION${NC}"
        echo "Usage: $0 [environment] [init|plan|deploy|destroy]"
        exit 1
        ;;
esac