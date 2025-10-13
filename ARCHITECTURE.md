# 🏗️ Banking Kubernetes Infrastructure - Arquitectura Detallada

## 📊 Diagrama de Arquitectura Completa

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                    🌐 INTERNET / LOCAL NETWORK                                             │
└─────────────────────────────────────┬───────────────────────────────────────────────────────────────────┘
                                      │
                    ┌─────────────────▼─────────────────┐
                    │         💻 USER BROWSER           │
                    │     http://banking.local          │
                    └─────────────────┬─────────────────┘
                                      │ HTTP Requests
                                      │ (Port 80/443)
┌─────────────────────────────────────▼─────────────────────────────────────────────────────────────────────┐
│                                   🔧 MINIKUBE CLUSTER                                                      │
│                                                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │                                🚪 INGRESS LAYER                                                      │  │
│  │                                                                                                     │  │
│  │    ┌─────────────────────────────────────────────────────────────────────────────────────────┐    │  │
│  │    │                          📡 Nginx Ingress Controller                                     │    │  │
│  │    │                              banking.local                                              │    │  │
│  │    │                                                                                         │    │  │
│  │    │  Routes:                                                                                │    │  │
│  │    │  • / → banking-frontend:80 (Frontend)                                                  │    │  │
│  │    │  • /api → banking-backend:8000 (Backend API)                                          │    │  │
│  │    └─────────────────────────────────────────────────────────────────────────────────────────┘    │  │
│  └─────────────────────────────────┬───────────────────┬───────────────────────────────────────────────┘  │
│                                    │                   │                                                   │
│                                    ▼                   ▼                                                   │
│  ┌─────────────────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │                                🎯 APPLICATION LAYER                                                  │  │
│  │                                                                                                     │  │
│  │  ┌─────────────────────────────┐                   ┌─────────────────────────────┐                │  │
│  │  │        🌐 FRONTEND          │                   │        ⚡ BACKEND            │                │  │
│  │  │      (Nginx + HTML/JS)      │                   │      (FastAPI Python)       │                │  │
│  │  │                             │                   │                             │                │  │
│  │  │ Service: banking-frontend   │◄──────────────────┤ Service: banking-backend    │                │  │
│  │  │ Port: 80                    │   API Calls       │ Port: 8000                  │                │  │
│  │  │ Replicas: 2                 │   /api/*          │ Replicas: 2                 │                │  │
│  │  │                             │                   │                             │                │  │
│  │  │ Features:                   │                   │ Endpoints:                  │                │  │
│  │  │ • Banking UI                │                   │ • /health (Health Check)   │                │  │
│  │  │ • Responsive Design         │                   │ • /ready (Startup Probe)   │                │  │
│  │  │ • Mock Data Support         │                   │ • /ping (Basic Check)      │                │  │
│  │  │ • API Integration Ready     │                   │ • /api/auth/login           │                │  │
│  │  │                             │                   │ • /api/users/me             │                │  │
│  │  │ Health: /nginx-health       │                   │ • /api/accounts             │                │  │
│  │  └─────────────────────────────┘                   │ • /api/transactions         │                │  │
│  │                                                     └─────────────┬───────────────┘                │  │
│  └─────────────────────────────────────────────────────────────────┼─────────────────────────────────┘  │
│                                                                      │                                     │
│                                                                      ▼                                     │
│  ┌─────────────────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │                                💾 DATA LAYER                                                        │  │
│  │                                                                                                     │  │
│  │  ┌─────────────────────────────┐                   ┌─────────────────────────────┐                │  │
│  │  │      🗃️ POSTGRESQL          │                   │        🚀 REDIS             │                │  │
│  │  │     (Primary Database)      │                   │      (Cache & Sessions)     │                │  │
│  │  │                             │                   │                             │                │  │
│  │  │ Service: postgres           │                   │ Service: redis              │                │  │
│  │  │ Port: 5432                  │                   │ Port: 6379                  │                │  │
│  │  │ Replicas: 1                 │                   │ Replicas: 1                 │                │  │
│  │  │                             │                   │                             │                │  │
│  │  │ Database: banking_db        │                   │ Memory: 256MB               │                │  │
│  │  │ User: banking_user          │                   │ Policy: allkeys-lru         │                │  │
│  │  │                             │                   │                             │                │  │
│  │  │ Tables:                     │                   │ Uses:                       │                │  │
│  │  │ • users (Authentication)    │◄──────────────────┤ • User Sessions             │                │  │
│  │  │ • accounts (Bank Accounts)  │   Database Ops    │ • API Response Cache        │                │  │
│  │  │ • transactions (History)    │                   │ • Temporary Data            │                │  │
│  │  │                             │                   │                             │                │  │
│  │  │ Health: pg_isready          │                   │ Health: redis-cli ping      │                │  │
│  │  └─────────────────────────────┘                   └─────────────────────────────┘                │  │
│  └─────────────────────────────────┬───────────────────┬───────────────────────────────────────────────┘  │
│                                    ▲                   ▲                                                   │
│                    ┌───────────────┘                   └───────────────┐                                   │
│                    │                                                   │                                   │
│                    │ DB Queries:                                       │ Cache Operations:                 │
│                    │ • User Authentication                             │ • SET session:username            │
│                    │ • Account Balance                                 │ • GET session:username            │
│                    │ • Transaction History                             │ • PING health check               │
│                    │ • Balance Updates                                 │                                   │
└────────────────────┼───────────────────────────────────────────────────┼───────────────────────────────────┘
                     │                                                   │
                     └───────────────────────────────────────────────────┘
                                             ▲
                          ┌──────────────────┴──────────────────┐
                          │         🔗 CONNECTION FLOW          │
                          │                                     │
                          │ 1. User → Ingress (Port 80)        │
                          │ 2. Ingress → Frontend (Port 80)    │
                          │ 3. Frontend → Backend (/api)       │
                          │ 4. Backend → PostgreSQL (Port 5432)│
                          │ 5. Backend → Redis (Port 6379)     │
                          └─────────────────────────────────────┘
```

## 🌐 Flujo de Comunicación Detallado

### 1. 📥 Entrada de Usuario
```
User Browser → http://banking.local
     ↓
Nginx Ingress Controller (Port 80)
     ↓
Routing Decision:
├─ Path: / → banking-frontend:80
└─ Path: /api → banking-backend:8000
```

### 2. 🎨 Frontend (Nginx + HTML/JS)
```
Container: banking-frontend
├─ Image: nginx:1.25-alpine
├─ Port: 80
├─ Replicas: 2
├─ Features:
│  ├─ Banking Dashboard UI
│  ├─ Account Management
│  ├─ Transaction History
│  ├─ Responsive Design
│  └─ API Integration Ready
├─ Health Check: /nginx-health
└─ Communication:
   └─ API Calls → backend:8000/api/*
```

### 3. ⚡ Backend (FastAPI)
```
Container: banking-backend  
├─ Image: python:3.11-slim
├─ Port: 8000
├─ Replicas: 2
├─ Framework: FastAPI + Uvicorn
├─ Endpoints:
│  ├─ GET /health (Health Check)
│  ├─ GET /ready (Kubernetes Startup Probe)
│  ├─ GET /ping (Basic Connectivity)
│  ├─ POST /api/auth/login
│  ├─ GET /api/users/me
│  ├─ GET /api/accounts
│  └─ POST /api/transactions
├─ Health Checks:
│  ├─ Startup Probe: /ping
│  ├─ Readiness Probe: /health
│  └─ Liveness Probe: /health
├─ Authentication: JWT Tokens
├─ CORS: Enabled for frontend
└─ Communication:
   ├─ Database → postgres:5432
   └─ Cache → redis:6379
```

### 4. 🗃️ PostgreSQL Database
```
Container: postgres
├─ Image: postgres:15-alpine
├─ Port: 5432
├─ Database: banking_db
├─ User: banking_user
├─ Tables:
│  ├─ users (id, username, password_hash, email, created_at)
│  ├─ accounts (id, user_id, account_number, balance, type)
│  └─ transactions (id, from_account, to_account, amount, timestamp)
├─ Connection: AsyncPG Pool
├─ Health Check: pg_isready
└─ Usage:
   ├─ User Authentication
   ├─ Account Management
   └─ Transaction Storage
```

### 5. 🚀 Redis Cache
```
Container: redis
├─ Image: redis:7-alpine
├─ Port: 6379
├─ Memory Limit: 256MB
├─ Policy: allkeys-lru
├─ Persistence: AOF enabled
├─ Health Check: redis-cli ping
└─ Usage:
   ├─ User Session Storage (30 min TTL)
   ├─ API Response Caching
   └─ Temporary Data Storage
```

## 🔄 Tipos de Comunicación

### HTTP/REST API
```
Frontend (JavaScript) ←→ Backend (FastAPI)
├─ Protocol: HTTP/1.1
├─ Format: JSON
├─ Authentication: JWT Bearer Token
├─ CORS: Configured
└─ Endpoints: RESTful API design
```

### Database Operations  
```
Backend ←→ PostgreSQL
├─ Protocol: PostgreSQL Wire Protocol
├─ Connection: AsyncPG Connection Pool
├─ Transactions: ACID Compliant
├─ Queries: Parameterized (SQL Injection Safe)
└─ Connection Pooling: Enabled
```

### Cache Operations
```
Backend ←→ Redis
├─ Protocol: RESP (Redis Serialization Protocol)
├─ Connection: redis.asyncio client
├─ Operations: GET, SET, DELETE, PING
├─ TTL: Configurable per key
└─ Serialization: JSON for complex objects
```

## 🏷️ Service Discovery & Networking

### Kubernetes Services
```
banking-frontend (NodePort)
├─ Selector: app=banking-frontend
├─ Port: 80 → targetPort: 80
└─ External Access: minikube service

banking-backend (ClusterIP)
├─ Selector: app=banking-backend  
├─ Port: 8000 → targetPort: 8000
└─ Internal Access Only

postgres (ClusterIP)
├─ Selector: app=postgres
├─ Port: 5432 → targetPort: 5432
└─ Internal Access Only

redis (ClusterIP)
├─ Selector: app=redis
├─ Port: 6379 → targetPort: 6379
└─ Internal Access Only
```

### DNS Resolution
```
Within Kubernetes Cluster:
├─ postgres.banking-app.svc.cluster.local:5432
├─ redis.banking-app.svc.cluster.local:6379
├─ banking-backend.banking-app.svc.cluster.local:8000
└─ banking-frontend.banking-app.svc.cluster.local:80

ConfigMap References (Backend):
├─ DATABASE_URL: postgresql://banking_user:***@postgres:5432/banking_db
└─ REDIS_URL: redis://redis:6379/0
```

## 🛡️ Seguridad y Configuración

### Variables de Entorno (ConfigMap)
```yaml
backend-config:
├─ DATABASE_URL: Connection string
├─ REDIS_URL: Redis connection
├─ JWT_SECRET: Token signing key  
├─ ENVIRONMENT: development
└─ LOG_LEVEL: INFO
```

### Health Checks
```
Frontend: HTTP GET /nginx-health
Backend: HTTP GET /health (checks DB + Redis)
PostgreSQL: pg_isready command
Redis: redis-cli ping command
```

### Resource Limits
```
Backend:
├─ CPU: 200m request, 500m limit
└─ Memory: 256Mi request, 512Mi limit

Frontend:
├─ CPU: 100m request, 200m limit  
└─ Memory: 128Mi request, 256Mi limit
```

## 🔍 Monitoreo y Debugging

### Acceso a Logs
```bash
# Backend logs
kubectl logs -f deployment/banking-backend -n banking-app

# Frontend logs  
kubectl logs -f deployment/banking-frontend -n banking-app

# Database logs
kubectl logs -f deployment/postgres -n banking-app
```

### Port Forwarding para Debug
```bash
# Frontend directo
kubectl port-forward svc/banking-frontend 3000:80 -n banking-app

# Backend API directo
kubectl port-forward svc/banking-backend 8000:8000 -n banking-app

# Base de datos
kubectl port-forward svc/postgres 5432:5432 -n banking-app

# Redis
kubectl port-forward svc/redis 6379:6379 -n banking-app
```

## 🎯 Flujo de Datos Completo

### Ejemplo: Login de Usuario
```
1. User → Browser: banking.local/login
2. Browser → Ingress: GET /
3. Ingress → Frontend: Serve login.html
4. User → Frontend: Submit credentials
5. Frontend → Backend: POST /api/auth/login
6. Backend → PostgreSQL: SELECT user WHERE username=?
7. Backend → Redis: SET session:username (JWT token)
8. Backend → Frontend: Return JWT token
9. Frontend → Browser: Store token, redirect to dashboard
```

### Ejemplo: Ver Balance de Cuenta
```
1. Frontend → Backend: GET /api/accounts (with JWT)
2. Backend: Verify JWT token
3. Backend → Redis: GET session:username
4. Backend → PostgreSQL: SELECT accounts WHERE user_id=?
5. PostgreSQL → Backend: Return account data
6. Backend → Frontend: JSON response with accounts
7. Frontend → Browser: Display account balances
```

Esta arquitectura proporciona:
- ✅ **Escalabilidad**: Múltiples replicas de frontend/backend
- ✅ **Resilencia**: Health checks y reinicio automático
- ✅ **Seguridad**: JWT tokens, network isolation
- ✅ **Performance**: Redis caching, connection pooling
- ✅ **Observabilidad**: Structured logging, health endpoints
- ✅ **Mantenibilidad**: Clear separation of concerns