# 🏦 Banking K8s Infrastructure - Complete DevOps Solution

[![Infrastructure](https://img.shields.io/badge/Infrastructure-Terraform-purple)](https://terraform.io)
[![Container](https://img.shields.io/badge/Container-Docker-blue)](https://docker.com)
[![Orchestration](https://img.shields.io/badge/Orchestration-Kubernetes-blue)](https://kubernetes.io)
[![Cloud](https://img.shields.io/badge/Cloud-AWS%20EKS-orange)](https://aws.amazon.com/eks/)
[![Backend](https://img.shields.io/badge/Backend-FastAPI-green)](https://fastapi.tiangolo.com)
[![Frontend](https://img.shields.io/badge/Frontend-HTML%2FJS-red)](https://developer.mozilla.org/en-US/docs/Web/HTML)

## 📋 Descripción del Proyecto

Este proyecto implementa una **infraestructura completa de banca digital** utilizando las mejores prácticas de DevOps e Infraestructura como Código. Incluye:

- **Infraestructura AWS EKS** con Terraform
- **Aplicación bancaria** con FastAPI backend y frontend web
- **Despliegue automático** en Kubernetes
- **Servicios críticos** para aplicaciones bancarias
- **Seguridad y monitoreo** incorporados

## 🏗️ Arquitectura

```
┌─────────────────────────────────────────────────────────────────┐
│                           Internet                              │
└─────────────────────┬───────────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────────┐
│                 Application Load Balancer                      │
└─────────────────────┬───────────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────────┐
│                   EKS Cluster (VPC)                           │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────────────┐│
│  │   Frontend   │ │   Backend    │ │       Databases          ││
│  │   (Nginx)    │ │   (FastAPI)  │ │  ┌─────────┐ ┌────────┐  ││
│  │              │ │              │ │  │PostgreSQL│ │ Redis  │  ││
│  │   Port: 80   │ │  Port: 8000  │ │  │Port:5432│ │Port:6379│  ││
│  └──────────────┘ └──────────────┘ │  └─────────┘ └────────┘  ││
│         │                 │        └──────────────────────────┘│
│         └─────────────────┘                                    │
└─────────────────────────────────────────────────────────────────┘
```

## 📁 Estructura del Proyecto

```
banking-k8s-infrastructure/
├── terraform/                 # Infraestructura como Código
├── app/backend/              # Aplicación FastAPI
├── app/frontend/             # Aplicación web
├── k8s/                      # Manifiestos de Kubernetes
├── scripts/                  # Scripts de automatización
├── Makefile                  # Comandos simplificados
└── README.md                # Esta documentación
```

## 🚀 Guía de Despliegue

### Prerrequisitos

```bash
# AWS CLI
aws --version

# Terraform
terraform --version

# kubectl
kubectl version --client

# Helm
helm version

# Docker
docker --version
```

### Comandos Rápidos

```bash
# 1. Configurar credenciales AWS
aws configure

# 2. Hacer ejecutables los scripts
chmod +x scripts/*.sh

# 3. Despliegue completo de desarrollo
make dev-setup

# 4. Ver información de la aplicación
make docs
```

## 🛡️ Seguridad Implementada

- ✅ **VPC privada** con subnets públicas y privadas
- ✅ **Security Groups** restrictivos por servicio
- ✅ **IAM Roles** con permisos mínimos (IRSA)
- ✅ **Encriptación** en tránsito y en reposo
- ✅ **KMS** para gestión de claves
- ✅ **Network Policies** de Kubernetes

## 🔧 Operaciones Comunes

### Actualizar la Aplicación

```bash
# Construir nueva versión
./scripts/build-images.sh v1.1.0 <registry>

# Actualizar deployment
kubectl set image deployment/banking-backend \
  banking-api=<registry>/banking-backend:v1.1.0 \
  -n banking-app
```

### Escalar Manualmente

```bash
# Escalar backend
kubectl scale deployment banking-backend --replicas=5 -n banking-app
```

### Ver Logs

```bash
# Logs del backend
kubectl logs -f deployment/banking-backend -n banking-app
```

## 🧪 Testing

### Credenciales de Demo

- **Usuario**: demo_user
- **Contraseña**: demo_password

### Tests en Cluster

```bash
# Port forward para testing local
kubectl port-forward service/banking-backend 8000:8000 -n banking-app
kubectl port-forward service/banking-frontend 8080:80 -n banking-app
```

## 📞 Soporte

Para dudas o problemas:

1. **Revisa los logs** con los comandos de troubleshooting
2. **Consulta la documentación** de cada componente
3. **Verifica la configuración** de networking y security groups

---

**⚠️ IMPORTANTE**: Este es un ejemplo educativo. Para uso en producción:

- Cambia todas las contraseñas y secrets
- Configura certificados SSL válidos
- Ajusta los security groups a tu red
- Implementa backups y disaster recovery
- Configura monitoreo y alertas completos
- Realiza pruebas de penetración y auditorías de seguridad
