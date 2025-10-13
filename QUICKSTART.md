# 🚀 Banking K8s Infrastructure - Quick Start Guide

Este documento te guiará para desplegar rápidamente la aplicación bancaria en Minikube.

## ⚡ Inicio Rápido (5 minutos)

### 1. Preparar el Entorno

```bash
# Clonar el repositorio
git clone <repository-url>
cd banking-k8s-infrastructure

# Configurar el entorno automáticamente
make setup-dev
```

### 2. Acceder a la Aplicación

```bash
# Obtener URLs de acceso
make show-urls

# O acceder directamente
minikube service banking-frontend -n banking-app
```

## 🛠️ Comandos Principales

### Gestión del Entorno

```bash
make setup-dev          # Configurar entorno completo
make deploy-all          # Desplegar toda la aplicación
make clean-all           # Limpiar todos los recursos
make show-urls           # Mostrar URLs de acceso
```

### Desarrollo y Debug

```bash
make logs               # Ver logs del backend
make logs-frontend      # Ver logs del frontend
make shell-backend      # Acceder al contenedor backend
make test-connectivity  # Probar conectividad
```

### Gestión de Minikube

```bash
make minikube-start     # Iniciar Minikube
make minikube-stop      # Detener Minikube
make minikube-dashboard # Abrir dashboard de Kubernetes
```

## 🏗️ Arquitectura

```
┌─────────────────────────────────────────────────────────┐
│                    Minikube Cluster                     │
│  ┌──────────────┐ ┌──────────────┐ ┌────────────────┐  │
│  │   Frontend   │ │   Backend    │ │   Databases    │  │
│  │   (Nginx)    │ │   (FastAPI)  │ │ PostgreSQL+Redis│  │
│  │   Port: 80   │ │  Port: 8000  │ │ Ports: 5432+6379│  │
│  └──────────────┘ └──────────────┘ └────────────────┘  │
│         │                 │                │           │
│         └─────────────────┴────────────────┘           │
└─────────────────────────────────────────────────────────┘
                          │
                   Ingress Controller
                          │
                    http://minikube-ip
```

## 📂 Estructura del Proyecto

```
banking-k8s-infrastructure/
├── app/
│   ├── backend/           # FastAPI application
│   └── frontend/          # HTML/CSS/JS application
├── k8s/                   # Kubernetes manifests
├── scripts/               # Automation scripts
├── terraform/             # Infrastructure as Code
├── Makefile              # Automation commands
├── docker-compose.yml    # Local development
└── README.md             # Main documentation
```

## 🔧 Requisitos del Sistema

- **macOS** (optimizado para macOS)
- **Docker Desktop**
- **Homebrew** (se instala automáticamente)
- **4GB RAM disponible** para Minikube
- **10GB espacio en disco**

## 🐳 Desarrollo Local con Docker Compose

```bash
# Alternativa rápida para desarrollo
make docker-up           # Iniciar con Docker Compose
make docker-logs         # Ver logs
make docker-down         # Detener servicios
```

## 🔐 Credenciales Demo

- **Usuario:** `demo_user`
- **Contraseña:** `demo_password`

## 🚨 Solución de Problemas

### Minikube no inicia

```bash
minikube delete
make minikube-start
```

### Imágenes no se encuentran

```bash
eval $(minikube docker-env)
make deploy-all
```

### Puerto ocupado

```bash
make clean-all
make deploy-all
```

### Ver estado de pods

```bash
kubectl get pods -n banking-app
kubectl describe pod <pod-name> -n banking-app
```

## 📊 Monitoreo

- **Kubernetes Dashboard:** `make minikube-dashboard`
- **Application Logs:** `make logs`
- **Resource Usage:** `kubectl top pods -n banking-app`

## 🆘 Ayuda

```bash
make help               # Ver todos los comandos disponibles
```

## 🎯 Próximos Pasos

1. ✅ Aplicación desplegada en Minikube
2. 🔄 Configurar CI/CD pipeline
3. ☁️ Migrar a AWS EKS
4. 📈 Añadir monitoreo avanzado
5. 🔒 Implementar autenticación OAuth

---

**¡Listo!** Tu aplicación bancaria está funcionando en Kubernetes. 🎉
