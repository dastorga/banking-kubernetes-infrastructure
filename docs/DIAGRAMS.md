# 🎯 Diagramas Interactivos - Banking Kubernetes Infrastructure

## 📊 Visualización Interactiva

### 🌐 Diagrama HTML Interactivo

Abre el archivo [`interactive-architecture.html`](./interactive-architecture.html) en tu navegador para una experiencia completamente interactiva.

**Características:**

- ✨ **Componentes clicables** con información detallada
- 🔄 **Flujos animados** de datos
- 📊 **Métricas en tiempo real**
- 🎨 **Diseño responsive** y moderno

### 🔥 Flujos Disponibles:

1. **👤 Flujo de Login** - Autenticación completa paso a paso
2. **💰 Consulta de Balance** - Verificación de cuentas bancarias
3. **💸 Nueva Transacción** - Transferencia entre cuentas
4. **🏥 Health Check** - Monitoreo del sistema

---

## 📋 Diagrama Mermaid - Flujo de Datos

```mermaid
graph TD
    User[👤 Usuario<br/>banking.local<br/>Port: 80]

    subgraph "🔧 Minikube Cluster"
        Ingress[🚪 Nginx Ingress<br/>Controller<br/>Routes: /, /api]

        subgraph "🎯 Application Layer"
            Frontend[🌐 Frontend<br/>Nginx + HTML/JS<br/>Port: 80<br/>Replicas: 2]
            Backend[⚡ Backend<br/>FastAPI + Python<br/>Port: 8000<br/>Replicas: 2]
        end

        subgraph "💾 Data Layer"
            Database[(🗃️ PostgreSQL<br/>banking_db<br/>Port: 5432<br/>Users, Accounts, Transactions)]
            Cache[(🚀 Redis<br/>Cache & Sessions<br/>Port: 6379<br/>256MB Memory)]
        end
    end

    User -->|HTTP Request| Ingress
    Ingress -->|Route: /| Frontend
    Ingress -->|Route: /api| Backend
    Frontend -.->|API Calls| Backend
    Backend -->|SQL Queries| Database
    Backend -->|Cache Operations| Cache

    classDef userStyle fill:#667eea,stroke:#333,stroke-width:3px,color:#fff
    classDef ingressStyle fill:#6c5ce7,stroke:#333,stroke-width:2px,color:#fff
    classDef frontendStyle fill:#ff6b6b,stroke:#333,stroke-width:2px,color:#fff
    classDef backendStyle fill:#4ecdc4,stroke:#333,stroke-width:2px,color:#fff
    classDef databaseStyle fill:#45b7d1,stroke:#333,stroke-width:2px,color:#fff
    classDef cacheStyle fill:#f9ca24,stroke:#333,stroke-width:2px,color:#000

    class User userStyle
    class Ingress ingressStyle
    class Frontend frontendStyle
    class Backend backendStyle
    class Database databaseStyle
    class Cache cacheStyle
```

---

## 🔄 Secuencia de Login de Usuario

```mermaid
sequenceDiagram
    participant U as 👤 Usuario
    participant I as 🚪 Ingress
    participant F as 🌐 Frontend
    participant B as ⚡ Backend
    participant D as 🗃️ PostgreSQL
    participant R as 🚀 Redis

    U->>+I: GET banking.local/login
    I->>+F: Route / → Frontend:80
    F->>-U: Serve login.html

    U->>+F: POST credentials
    F->>+I: POST /api/auth/login
    I->>+B: Route /api → Backend:8000

    B->>+D: SELECT user WHERE username=?
    D->>-B: Return user data

    Note over B: Validate password hash

    B->>+R: SET session:username (JWT, TTL 30min)
    R->>-B: Session stored

    B->>-I: Return JWT token
    I->>-F: Response with token
    F->>-U: Redirect to dashboard

    Note over U,R: Login Complete - User Authenticated
```

---

## 💰 Secuencia de Consulta de Balance

```mermaid
sequenceDiagram
    participant U as 👤 Usuario
    participant F as 🌐 Frontend
    participant B as ⚡ Backend
    participant R as 🚀 Redis
    participant D as 🗃️ PostgreSQL

    U->>+F: Click "Ver Balance"
    F->>+B: GET /api/accounts (JWT Header)

    Note over B: Verify JWT Token

    B->>+R: GET session:username
    R->>-B: Validate session active

    B->>+D: SELECT * FROM accounts WHERE user_id=?
    D->>-B: Return accounts data

    Note over B: Calculate total balance

    B->>-F: JSON response with accounts
    F->>-U: Display balance in UI

    Note over U,D: Balance Retrieved Successfully
```

---

## 💸 Secuencia de Nueva Transacción

```mermaid
sequenceDiagram
    participant U as 👤 Usuario
    participant F as 🌐 Frontend
    participant B as ⚡ Backend
    participant D as 🗃️ PostgreSQL
    participant R as 🚀 Redis

    U->>+F: Submit transfer form
    F->>+B: POST /api/transactions (amount, from_account, to_account)

    Note over B: Validate JWT & amount

    B->>+D: BEGIN TRANSACTION
    D->>-B: Transaction started

    B->>+D: UPDATE accounts SET balance = balance - amount WHERE id = from_account
    D->>-B: Balance updated

    B->>+D: UPDATE accounts SET balance = balance + amount WHERE id = to_account
    D->>-B: Balance updated

    B->>+D: INSERT INTO transactions (from_account, to_account, amount, timestamp)
    D->>-B: Transaction logged

    B->>+D: COMMIT TRANSACTION
    D->>-B: Transaction committed

    B->>+R: DEL cache:accounts:user_id (Invalidate cache)
    R->>-B: Cache cleared

    B->>-F: Success response
    F->>-U: Show "Transfer Successful"

    Note over U,R: ACID Transaction Complete
```

---

## 🏥 Health Check Flow

```mermaid
sequenceDiagram
    participant K as ☸️ Kubernetes
    participant B as ⚡ Backend
    participant D as 🗃️ PostgreSQL
    participant R as 🚀 Redis

    K->>+B: GET /health (Liveness Probe)

    par Database Check
        B->>+D: SELECT 1
        D->>-B: ✅ Connection OK
    and Cache Check
        B->>+R: PING
        R->>-B: ✅ PONG Response
    end

    Note over B: All systems healthy

    B->>-K: HTTP 200 {"status": "healthy", "database": "connected", "cache": "connected"}

    Note over K,R: Pod Marked as Ready
```

---

## 🔧 Configuración de Servicios

### Service Discovery interno (DNS)

```
postgres.banking-app.svc.cluster.local:5432
redis.banking-app.svc.cluster.local:6379
banking-backend.banking-app.svc.cluster.local:8000
banking-frontend.banking-app.svc.cluster.local:80
```

### Variables de Entorno (ConfigMap)

```yaml
DATABASE_URL: "postgresql://banking_user:***@postgres:5432/banking_db"
REDIS_URL: "redis://redis:6379/0"
JWT_SECRET: "super-secret-jwt-key"
ENVIRONMENT: "development"
LOG_LEVEL: "INFO"
```

### Resource Limits

| Componente | CPU Request | CPU Limit | Memory Request | Memory Limit |
| ---------- | ----------- | --------- | -------------- | ------------ |
| Frontend   | 100m        | 200m      | 128Mi          | 256Mi        |
| Backend    | 200m        | 500m      | 256Mi          | 512Mi        |
| PostgreSQL | 250m        | 500m      | 256Mi          | 512Mi        |
| Redis      | 100m        | 300m      | 128Mi          | 256Mi        |

---

## 🚀 Cómo usar los diagramas

### 1. **Diagrama HTML Interactivo**

```bash
# Abrir en navegador
open docs/interactive-architecture.html
# o
python -m http.server 8080
# Luego ir a: http://localhost:8080/docs/interactive-architecture.html
```

### 2. **Mermaid en GitHub**

Los diagramas Mermaid se renderizan automáticamente en GitHub. Solo ve el archivo en tu repositorio.

### 3. **Exportar como imagen**

```bash
# Instalar mermaid-cli
npm install -g @mermaid-js/mermaid-cli

# Generar PNG
mmdc -i DIAGRAMS.md -o architecture.png
```

¡Estos diagramas te dan una visualización completa e interactiva de todo el flujo de datos en tu aplicación bancaria! 🎯
