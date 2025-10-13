#!/bin/bash

# Banking Application Deployment Script for Minikube
# This script handles application-specific deployment tasks

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

NAMESPACE="banking-app"
ACTION=${1:-deploy}

echo -e "${BLUE}🚀 Banking Application Deployment${NC}"
echo "Action: $ACTION"
echo "=================================================="

# Set minikube docker env
eval $(minikube docker-env)

case $ACTION in
    "build")
        echo -e "${BLUE}Building application images...${NC}"
        
        # Build backend
        echo -e "${YELLOW}Building backend image...${NC}"
        cd app/backend
        docker build -t banking-backend:latest -f Dockerfile .
        cd ../..
        
        # Build frontend
        echo -e "${YELLOW}Building frontend image...${NC}"
        cd app/frontend
        docker build -t banking-frontend:latest -f Dockerfile .
        cd ../..
        
        echo -e "${GREEN}✓ Images built successfully${NC}"
        ;;
        
    "deploy")
        echo -e "${BLUE}Deploying banking application...${NC}"
        
        # First build images
        ./scripts/deploy-application.sh build
        
        # Deploy to Kubernetes
        kubectl apply -f k8s/
        
        echo -e "${YELLOW}Waiting for deployment to be ready...${NC}"
        kubectl wait --for=condition=available deployment/banking-backend -n $NAMESPACE --timeout=300s
        kubectl wait --for=condition=available deployment/banking-frontend -n $NAMESPACE --timeout=300s
        
        echo -e "${GREEN}✓ Application deployed successfully${NC}"
        
        # Show status
        echo ""
        echo -e "${BLUE}Deployment Status:${NC}"
        kubectl get pods -n $NAMESPACE
        echo ""
        kubectl get svc -n $NAMESPACE
        ;;
        
    "status")
        echo -e "${BLUE}Application Status:${NC}"
        echo "==================="
        
        echo -e "${YELLOW}Pods:${NC}"
        kubectl get pods -n $NAMESPACE
        
        echo ""
        echo -e "${YELLOW}Services:${NC}"
        kubectl get svc -n $NAMESPACE
        
        echo ""
        echo -e "${YELLOW}Ingress:${NC}"
        kubectl get ingress -n $NAMESPACE
        
        echo ""
        echo -e "${YELLOW}Deployments:${NC}"
        kubectl get deployments -n $NAMESPACE
        ;;
        
    "logs")
        SERVICE=${2:-backend}
        
        echo -e "${BLUE}Showing logs for: $SERVICE${NC}"
        kubectl logs -f deployment/banking-$SERVICE -n $NAMESPACE
        ;;
        
    "restart")
        SERVICE=${2:-all}
        
        if [ "$SERVICE" = "all" ]; then
            echo -e "${BLUE}Restarting all services...${NC}"
            kubectl rollout restart deployment/banking-backend -n $NAMESPACE
            kubectl rollout restart deployment/banking-frontend -n $NAMESPACE
        else
            echo -e "${BLUE}Restarting $SERVICE...${NC}"
            kubectl rollout restart deployment/banking-$SERVICE -n $NAMESPACE
        fi
        
        echo -e "${GREEN}✓ Restart initiated${NC}"
        ;;
        
    "scale")
        SERVICE=${2:-backend}
        REPLICAS=${3:-2}
        
        echo -e "${BLUE}Scaling $SERVICE to $REPLICAS replicas...${NC}"
        kubectl scale deployment banking-$SERVICE --replicas=$REPLICAS -n $NAMESPACE
        
        echo -e "${GREEN}✓ Scaling completed${NC}"
        ;;
        
    "port-forward")
        SERVICE=${2:-frontend}
        
        case $SERVICE in
            "frontend")
                echo -e "${BLUE}Port forwarding frontend (localhost:3000 -> pod:80)${NC}"
                kubectl port-forward svc/banking-frontend 3000:80 -n $NAMESPACE
                ;;
            "backend")
                echo -e "${BLUE}Port forwarding backend (localhost:8000 -> pod:8000)${NC}"
                kubectl port-forward svc/banking-backend 8000:8000 -n $NAMESPACE
                ;;
            "postgres")
                echo -e "${BLUE}Port forwarding postgres (localhost:5432 -> pod:5432)${NC}"
                kubectl port-forward svc/postgres 5432:5432 -n $NAMESPACE
                ;;
            "redis")
                echo -e "${BLUE}Port forwarding redis (localhost:6379 -> pod:6379)${NC}"
                kubectl port-forward svc/redis 6379:6379 -n $NAMESPACE
                ;;
            *)
                echo -e "${RED}Invalid service: $SERVICE${NC}"
                echo "Available services: frontend, backend, postgres, redis"
                exit 1
                ;;
        esac
        ;;
        
    "shell")
        SERVICE=${2:-backend}
        
        echo -e "${BLUE}Opening shell in $SERVICE pod...${NC}"
        POD=$(kubectl get pods -n $NAMESPACE -l app=banking-$SERVICE -o jsonpath='{.items[0].metadata.name}')
        kubectl exec -it $POD -n $NAMESPACE -- /bin/bash
        ;;
        
    "test")
        echo -e "${BLUE}Running application tests...${NC}"
        
        # Get service URL
        MINIKUBE_IP=$(minikube ip)
        FRONTEND_URL="http://$MINIKUBE_IP"
        BACKEND_URL="http://$MINIKUBE_IP/api"
        
        echo -e "${YELLOW}Testing frontend connectivity...${NC}"
        if curl -s "$FRONTEND_URL" > /dev/null; then
            echo -e "${GREEN}✓ Frontend is accessible${NC}"
        else
            echo -e "${RED}✗ Frontend is not accessible${NC}"
        fi
        
        echo -e "${YELLOW}Testing backend API...${NC}"
        if curl -s "$BACKEND_URL/health" > /dev/null; then
            echo -e "${GREEN}✓ Backend API is accessible${NC}"
        else
            echo -e "${RED}✗ Backend API is not accessible${NC}"
        fi
        
        echo -e "${YELLOW}Testing API docs...${NC}"
        if curl -s "$BACKEND_URL/docs" > /dev/null; then
            echo -e "${GREEN}✓ API documentation is accessible${NC}"
        else
            echo -e "${RED}✗ API documentation is not accessible${NC}"
        fi
        ;;
        
    "clean")
        echo -e "${BLUE}Cleaning up application resources...${NC}"
        
        # Delete application resources
        kubectl delete -f k8s/ --ignore-not-found=true
        
        # Clean Docker images
        docker rmi banking-backend:latest banking-frontend:latest 2>/dev/null || true
        
        echo -e "${GREEN}✓ Cleanup completed${NC}"
        ;;
        
    *)
        echo -e "${RED}Invalid action: $ACTION${NC}"
        echo ""
        echo "Usage: $0 [ACTION] [OPTIONS]"
        echo ""
        echo "Actions:"
        echo "  build                     - Build Docker images"
        echo "  deploy                    - Deploy application to Kubernetes"
        echo "  status                    - Show application status"
        echo "  logs [SERVICE]            - Show logs (backend|frontend)"
        echo "  restart [SERVICE]         - Restart service (all|backend|frontend)"
        echo "  scale SERVICE REPLICAS    - Scale service"
        echo "  port-forward SERVICE      - Port forward to service"
        echo "  shell SERVICE             - Open shell in service pod"
        echo "  test                      - Test connectivity"
        echo "  clean                     - Clean up resources"
        exit 1
        ;;
esac