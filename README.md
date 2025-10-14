# 🏦 Banking K8s Infrastructure - Complete DevOps Solution

[![Infrastructure](https://img.shields.io/badge/Infrastructure-Terraform-purple)](https://terraform.io)
[![Container](https://img.shields.io/badge/Container-Docker-blue)](https://docker.com)
[![Orchestration](https://img.shields.io/badge/Orchestration-Kubernetes-blue)](https://kubernetes.io)
[![Development](https://img.shields.io/badge/Development-Minikube-green)](https://minikube.sigs.k8s.io/)
[![Backend](https://img.shields.io/badge/Backend-FastAPI-green)](https://fastapi.tiangolo.com)
[![Frontend](https://img.shields.io/badge/Frontend-HTML%2FJS-red)](https://developer.mozilla.org/en-US/docs/Web/HTML)

## 📋 Descripción del Proyecto

Este proyecto implementa una **infraestructura completa de banca digital** utilizando las mejores prácticas de DevOps e Infraestructura como Código. Incluye:

- **Entorno de desarrollo** con Minikube (preparado para AWS EKS)
- **Aplicación bancaria** con FastAPI backend y frontend web
- **Despliegue automático** en Kubernetes
- **Servicios críticos** para aplicaciones bancarias
- **Infraestructura como Código** con Terraform (listo para producción)

## 🏗️ Arquitectura

### Entorno de Desarrollo (Minikube)

```
┌─────────────────────────────────────────────────────────────────┐
│                      localhost / minikube                      │
└─────────────────────┬───────────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────────┐
│                  Nginx Ingress Controller                     │
│                    (banking.local)                            │
└─────────────────────┬───────────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────────┐
│                 Minikube Cluster                              │
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

### Producción (AWS EKS - Configuración disponible)

_La infraestructura de Terraform está lista para despliegue en AWS EKS cuando sea necesario._

## 📁 Estructura del Proyecto

```
banking-k8s-infrastructure/
├── terraform/                 # Infraestructura como Código (AWS EKS)
├── app/
│   ├── backend/              # Aplicación FastAPI
│   └── frontend/             # Aplicación web Nginx
├── k8s/                      # Manifiestos de Kubernetes
├── scripts/                  # Scripts de automatización
├── Makefile                  # Comandos simplificados
├── QUICKSTART.md             # Guía de inicio rápido
└── README.md                # Esta documentación
```

## 🎯 Estado Actual del Proyecto

**✅ COMPLETADO - Entorno de Desarrollo:**

- Aplicación bancaria completa funcionando en Minikube
- Frontend accesible en `http://banking.local`
- Backend API con endpoints de salud y transacciones
- Base de datos PostgreSQL configurada
- Redis para caché y sesiones
- Ingress controller configurado
- Todos los manifiestos de Kubernetes operativos

**⚙️ DISPONIBLE - Infraestructura AWS:**

- Configuración de Terraform para AWS EKS
- Scripts preparados para despliegue en la nube
- VPC, subnets, security groups definidos
- Configuración IAM y networking lista

## 🚀 Guía de Despliegue

### Prerrequisitos

**Para desarrollo local (Minikube):**

```bash
# Minikube
minikube version

# kubectl
kubectl version --client

# Docker Desktop
docker --version

# Make
make --version
```

**Para producción (AWS EKS) - Opcional:**

```bash
# AWS CLI
aws --version

# Terraform
terraform --version

# Helm
helm version
```

### Comandos Rápidos

**Despliegue en Minikube (Desarrollo):**

```bash
# 1. Hacer ejecutables los scripts
chmod +x scripts/*.sh

# 2. Despliegue completo de desarrollo
make setup-dev

# 3. Acceder a la aplicación
# Frontend: http://banking.local
# API: http://banking.local/api

# 4. Ver estado de los pods
kubectl get pods -n banking-app
```

**Para AWS EKS (Producción) - Futuro:**

```bash
# 1. Configurar credenciales AWS
aws configure

# 2. Despliegue de infraestructura
make setup-aws

# 3. Despliegue de aplicación
make deploy-app
```

## 🛡️ Seguridad Implementada

**Entorno de Desarrollo:**

- ✅ **Network Policies** de Kubernetes
- ✅ **Ingress Controller** con configuración segura
- ✅ **Contenedores** con usuarios no privilegiados
- ✅ **Health Checks** y startup probes

**Preparado para Producción (AWS):**

- ⚙️ **VPC privada** con subnets públicas y privadas
- ⚙️ **Security Groups** restrictivos por servicio
- ⚙️ **IAM Roles** con permisos mínimos (IRSA)
- ⚙️ **Encriptación** en tránsito y en reposo
- ⚙️ **KMS** para gestión de claves

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

### Acceso a la Aplicación

**Método Principal (Ingress):**

```bash
# Iniciar túnel de minikube (si no está activo)
minikube tunnel

# Acceder via navegador
open http://banking.local
```

**Método Alternativo (Port Forward):**

```bash
# Port forward para testing directo
kubectl port-forward service/banking-backend 8000:8000 -n banking-app
kubectl port-forward service/banking-frontend 8080:80 -n banking-app

# Acceder vía localhost
open http://localhost:8080
```

**Método NodePort:**

```bash
# Obtener URL del servicio
minikube service banking-frontend -n banking-app --url
```

## 📞 Soporte

Para dudas o problemas:

1. **Revisa los logs** con los comandos de troubleshooting
2. **Consulta la documentación** de cada componente
3. **Verifica la configuración** de networking y security groups

---

**⚠️ IMPORTANTE**: Este es un ejemplo practico/desafio SRE. Para uso en producción:

- Cambia todas las contraseñas y secrets
- Configura certificados SSL válidos
- Ajusta los security groups a tu red
- Implementa backups y disaster recovery
- Configura monitoreo y alertas completos
- Realiza pruebas de penetración y auditorías de seguridad
