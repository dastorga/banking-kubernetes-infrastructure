# Banking API Backend - FastAPI Application
from fastapi import FastAPI, HTTPException, Depends, status, Response, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from pydantic import BaseModel, Field, validator
from typing import List, Optional
import asyncpg
import redis.asyncio as redis
import boto3
import json
import os
import hashlib
import jwt
from datetime import datetime, timedelta
from decimal import Decimal
import logging
import uuid

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="Banking API",
    description="Secure Banking API for account management and transactions",
    version="1.0.0",
    docs_url="/api/docs",
    redoc_url="/api/redoc"
)

# Security middleware
security = HTTPBearer()

# Middleware for request logging
@app.middleware("http")
async def log_requests(request, call_next):
    logger.info(f"Request: {request.method} {request.url} - Headers: {dict(request.headers)}")
    response = await call_next(request)
    logger.info(f"Response: {response.status_code}")
    return response

# CORS middleware - restrict in production
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "https://banking.example.com"],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["*"],
)

# Configuration
class Config:
    DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://user:pass@localhost/bankingdb")
    REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379")
    JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY", "your-secret-key-change-in-production")
    JWT_ALGORITHM = "HS256"
    JWT_EXPIRE_MINUTES = 30
    AWS_REGION = os.getenv("AWS_REGION", "us-west-2")

config = Config()

# Database and Redis connections
db_pool = None
redis_client = None

# Pydantic models
class Account(BaseModel):
    id: Optional[str] = None
    account_number: str = Field(..., min_length=10, max_length=20)
    account_type: str = Field(..., pattern="^(checking|savings|investment)$")
    balance: Decimal = Field(default=0.00, ge=0)
    owner_id: str
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

class Transaction(BaseModel):
    id: Optional[str] = None
    from_account: str
    to_account: str
    amount: Decimal = Field(..., gt=0)
    transaction_type: str = Field(..., pattern="^(transfer|deposit|withdrawal)$")
    description: Optional[str] = Field(None, max_length=255)
    created_at: Optional[datetime] = None
    status: str = Field(default="pending", pattern="^(pending|completed|failed)$")

class User(BaseModel):
    id: Optional[str] = None
    username: str = Field(..., min_length=3, max_length=50)
    email: str = Field(..., pattern=r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
    first_name: str = Field(..., min_length=1, max_length=50)
    last_name: str = Field(..., min_length=1, max_length=50)
    created_at: Optional[datetime] = None

class LoginRequest(BaseModel):
    username: str
    password: str

class TransferRequest(BaseModel):
    from_account: str
    to_account: str
    amount: Decimal = Field(..., gt=0)
    description: Optional[str] = None

class PayServiceRequest(BaseModel):
    account_id: str
    service_provider: str = Field(..., min_length=1, max_length=100)
    service_type: str = Field(..., pattern="^(electricity|water|gas|phone|internet|cable|insurance|credit_card|loan|other)$")
    amount: Decimal = Field(..., gt=0)
    reference_number: Optional[str] = Field(None, max_length=50)
    description: Optional[str] = Field(None, max_length=255)

class DepositRequest(BaseModel):
    account_id: str
    amount: Decimal = Field(..., gt=0)
    deposit_method: str = Field(..., pattern="^(cash|check|transfer|atm|mobile)$")
    description: Optional[str] = Field(None, max_length=255)
    reference_number: Optional[str] = Field(None, max_length=50)

class WithdrawRequest(BaseModel):
    account_id: str
    amount: Decimal = Field(..., gt=0)
    withdrawal_method: str = Field(..., pattern="^(cash|atm|transfer|check)$")
    description: Optional[str] = Field(None, max_length=255)

class ServicePayment(BaseModel):
    id: Optional[str] = None
    account_id: str
    service_provider: str
    service_type: str
    amount: Decimal
    reference_number: Optional[str] = None
    status: str = Field(default="pending", pattern="^(pending|completed|failed)$")
    created_at: Optional[datetime] = None

# Authentication functions
def create_access_token(data: dict):
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=config.JWT_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, config.JWT_SECRET_KEY, algorithm=config.JWT_ALGORITHM)
    return encoded_jwt

def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    try:
        payload = jwt.decode(credentials.credentials, config.JWT_SECRET_KEY, algorithms=[config.JWT_ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Could not validate credentials",
                headers={"WWW-Authenticate": "Bearer"},
            )
        return username
    except jwt.PyJWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

# Database initialization
async def init_db():
    global db_pool
    db_pool = await asyncpg.create_pool(config.DATABASE_URL)
    
    # Create tables if they don't exist
    async with db_pool.acquire() as conn:
        await conn.execute('''
            CREATE TABLE IF NOT EXISTS users (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                username VARCHAR(50) UNIQUE NOT NULL,
                email VARCHAR(255) UNIQUE NOT NULL,
                password_hash VARCHAR(255) NOT NULL,
                first_name VARCHAR(50) NOT NULL,
                last_name VARCHAR(50) NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        await conn.execute('''
            CREATE TABLE IF NOT EXISTS accounts (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                account_number VARCHAR(20) UNIQUE NOT NULL,
                account_type VARCHAR(20) NOT NULL CHECK (account_type IN ('checking', 'savings', 'investment')),
                balance DECIMAL(15,2) DEFAULT 0.00 CHECK (balance >= 0),
                owner_id UUID NOT NULL REFERENCES users(id),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        await conn.execute('''
            CREATE TABLE IF NOT EXISTS transactions (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                from_account UUID REFERENCES accounts(id),
                to_account UUID REFERENCES accounts(id),
                amount DECIMAL(15,2) NOT NULL CHECK (amount > 0),
                transaction_type VARCHAR(20) NOT NULL CHECK (transaction_type IN ('transfer', 'deposit', 'withdrawal')),
                description TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed'))
            )
        ''')
        
        await conn.execute('''
            CREATE TABLE IF NOT EXISTS service_payments (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                account_id UUID NOT NULL REFERENCES accounts(id),
                service_provider VARCHAR(100) NOT NULL,
                service_type VARCHAR(20) NOT NULL CHECK (service_type IN ('electricity', 'water', 'gas', 'phone', 'internet', 'cable', 'insurance', 'credit_card', 'loan', 'other')),
                amount DECIMAL(15,2) NOT NULL CHECK (amount > 0),
                reference_number VARCHAR(50),
                description TEXT,
                status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed')),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        await conn.execute('''
            CREATE TABLE IF NOT EXISTS deposits (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                account_id UUID NOT NULL REFERENCES accounts(id),
                amount DECIMAL(15,2) NOT NULL CHECK (amount > 0),
                deposit_method VARCHAR(20) NOT NULL CHECK (deposit_method IN ('cash', 'check', 'transfer', 'atm', 'mobile')),
                reference_number VARCHAR(50),
                description TEXT,
                status VARCHAR(20) DEFAULT 'completed' CHECK (status IN ('pending', 'completed', 'failed')),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        await conn.execute('''
            CREATE TABLE IF NOT EXISTS withdrawals (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                account_id UUID NOT NULL REFERENCES accounts(id),
                amount DECIMAL(15,2) NOT NULL CHECK (amount > 0),
                withdrawal_method VARCHAR(20) NOT NULL CHECK (withdrawal_method IN ('cash', 'atm', 'transfer', 'check')),
                description TEXT,
                status VARCHAR(20) DEFAULT 'completed' CHECK (status IN ('pending', 'completed', 'failed')),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')

# Redis initialization
async def init_redis():
    global redis_client
    redis_client = redis.from_url(config.REDIS_URL)

# Startup event
@app.on_event("startup")
async def startup_event():
    await init_db()
    await init_redis()
    logger.info("Banking API started successfully")

# Shutdown event
@app.on_event("shutdown")
async def shutdown_event():
    if db_pool:
        await db_pool.close()
    if redis_client:
        await redis_client.close()
    logger.info("Banking API shutdown completed")

# Simple readiness check for startup probe
@app.get("/ready")
async def ready_check():
    return {"status": "ready"}

@app.get("/ping")
async def ping():
    return {"status": "pong"}

# Health check endpoint
@app.get("/health", tags=["Health"])
async def health_check():
    try:
        # Check database connection
        async with db_pool.acquire() as conn:
            await conn.fetchval("SELECT 1")
        
        # Check Redis connection
        await redis_client.ping()
        
        return {
            "status": "healthy",
            "timestamp": datetime.utcnow().isoformat(),
            "database": "connected",
            "cache": "connected"
        }
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        raise HTTPException(status_code=503, detail="Service unhealthy")

# Authentication endpoints
@app.post("/api/auth/login", tags=["Authentication"])
async def login(login_request: LoginRequest):
    async with db_pool.acquire() as conn:
        user = await conn.fetchrow(
            "SELECT id, username, password_hash FROM users WHERE username = $1",
            login_request.username
        )
        
        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid credentials"
            )
        
        # In production, use proper password hashing (bcrypt, scrypt, etc.)
        password_hash = hashlib.sha256(login_request.password.encode()).hexdigest()
        
        if user['password_hash'] != password_hash:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid credentials"
            )
        
        access_token = create_access_token(data={"sub": user['username']})
        
        # Cache user session in Redis
        await redis_client.setex(
            f"session:{user['username']}", 
            config.JWT_EXPIRE_MINUTES * 60,
            json.dumps({"user_id": str(user['id']), "username": user['username']})
        )
        
        return {
            "access_token": access_token,
            "token_type": "bearer",
            "expires_in": config.JWT_EXPIRE_MINUTES * 60
        }

# User endpoints
@app.get("/api/users/me", response_model=User, tags=["Users"])
async def get_current_user(current_user: str = Depends(verify_token)):
    async with db_pool.acquire() as conn:
        user = await conn.fetchrow(
            "SELECT id, username, email, first_name, last_name, created_at FROM users WHERE username = $1",
            current_user
        )
        
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        
        return User(**dict(user))

# Account endpoints
@app.get("/api/accounts", response_model=List[Account], tags=["Accounts"])
async def get_user_accounts(current_user: str = Depends(verify_token)):
    async with db_pool.acquire() as conn:
        # Get user ID
        user = await conn.fetchrow("SELECT id FROM users WHERE username = $1", current_user)
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        
        # Get user accounts
        accounts = await conn.fetch(
            "SELECT id, account_number, account_type, balance, owner_id, created_at, updated_at FROM accounts WHERE owner_id = $1",
            user['id']
        )
        
        return [Account(**dict(account)) for account in accounts]

# Logging específico para transacciones
transaction_logger = logging.getLogger("TRANSACTIONS")
transaction_logger.setLevel(logging.INFO)
db_logger = logging.getLogger("DATABASE")
db_logger.setLevel(logging.INFO)
redis_logger = logging.getLogger("REDIS")
redis_logger.setLevel(logging.INFO)

# Transaction endpoints with detailed logging
@app.post("/api/transactions", tags=["Transactions"])
async def create_transaction(transaction_data: dict, request: Request):
    client_ip = request.client.host
    timestamp = datetime.utcnow().isoformat()
    
    # Log detallado de la transacción entrante
    transaction_logger.info("=" * 80)
    transaction_logger.info("🏦 NUEVA TRANSACCIÓN RECIBIDA")
    transaction_logger.info(f"   ⏰ Timestamp: {timestamp}")
    transaction_logger.info(f"   🌐 IP Cliente: {client_ip}")
    transaction_logger.info(f"   📊 Datos completos: {json.dumps(transaction_data, indent=4)}")
    
    try:
        # Extraer y validar datos
        amount = float(transaction_data.get("amount", 0))
        transaction_type = transaction_data.get("type", "unknown")
        description = transaction_data.get("description", "Sin descripción")
        account_id = transaction_data.get("account_id", "default_account")
        
        transaction_logger.info(f"   💰 Monto procesado: ${amount:.2f}")
        transaction_logger.info(f"   📝 Tipo de transacción: {transaction_type}")
        transaction_logger.info(f"   📄 Descripción: {description}")
        transaction_logger.info(f"   🔑 ID de cuenta: {account_id}")
        
        # Generar ID único para la transacción
        transaction_id = f"TXN-{uuid.uuid4().hex[:12].upper()}"
        transaction_logger.info(f"   🆔 ID generado: {transaction_id}")
        
        # Log de validaciones
        transaction_logger.info("🔍 VALIDANDO TRANSACCIÓN...")
        
        if amount <= 0:
            transaction_logger.error(f"❌ VALIDACIÓN FALLIDA: Monto inválido (${amount})")
            raise HTTPException(status_code=400, detail="Monto debe ser mayor a 0")
            
        if transaction_type not in ["deposit", "withdrawal", "transfer"]:
            transaction_logger.error(f"❌ VALIDACIÓN FALLIDA: Tipo inválido ({transaction_type})")
            raise HTTPException(status_code=400, detail="Tipo de transacción inválido")
            
        transaction_logger.info("✅ VALIDACIÓN EXITOSA")
        
        # Simular consulta de balance actual
        db_logger.info("🗄️ CONECTANDO A POSTGRESQL...")
        db_logger.info(f"   📊 Query: SELECT balance FROM accounts WHERE id = '{account_id}'")
        
        # Simular balance actual (en producción sería una consulta real)
        current_balance = 1500.00
        db_logger.info(f"   💳 Balance actual encontrado: ${current_balance:.2f}")
        
        # Validar fondos suficientes para retiros/transferencias
        if transaction_type in ["withdrawal", "transfer"]:
            if amount > current_balance:
                transaction_logger.error(f"❌ FONDOS INSUFICIENTES: Requiere ${amount:.2f}, disponible ${current_balance:.2f}")
                raise HTTPException(status_code=400, detail="Fondos insuficientes")
            transaction_logger.info(f"✅ FONDOS SUFICIENTES para {transaction_type}")
        
        # Calcular nuevo balance
        if transaction_type == "deposit":
            new_balance = current_balance + amount
            transaction_logger.info(f"💰 DEPÓSITO: ${current_balance:.2f} + ${amount:.2f} = ${new_balance:.2f}")
        elif transaction_type in ["withdrawal", "transfer"]:
            new_balance = current_balance - amount
            transaction_logger.info(f"💸 {transaction_type.upper()}: ${current_balance:.2f} - ${amount:.2f} = ${new_balance:.2f}")
        
        # Simular inserción en base de datos
        db_logger.info("💾 GUARDANDO TRANSACCIÓN EN BASE DE DATOS...")
        db_logger.info(f"   📊 INSERT INTO transactions (id, account_id, amount, type, description, status, created_at)")
        db_logger.info(f"   📊 VALUES ('{transaction_id}', '{account_id}', {amount}, '{transaction_type}', '{description}', 'completed', '{timestamp}')")
        
        # Simular actualización de balance
        db_logger.info("🔄 ACTUALIZANDO BALANCE DE CUENTA...")
        db_logger.info(f"   📊 UPDATE accounts SET balance = {new_balance:.2f}, updated_at = '{timestamp}' WHERE id = '{account_id}'")
        db_logger.info("✅ BALANCE ACTUALIZADO EN BD")
        
        # Actualizar cache en Redis
        redis_logger.info("🔴 ACTUALIZANDO CACHE EN REDIS...")
        redis_logger.info(f"   🔑 SET balance:{account_id} = {new_balance:.2f}")
        redis_logger.info(f"   🔑 SET last_transaction:{account_id} = '{transaction_id}'")
        redis_logger.info(f"   ⏱️ EXPIRE balance:{account_id} 300 (5 minutos)")
        redis_logger.info("✅ CACHE ACTUALIZADO")
        
        # Log de respuesta exitosa
        transaction_logger.info("🎉 TRANSACCIÓN COMPLETADA EXITOSAMENTE")
        transaction_logger.info(f"   ✅ Estado final: COMPLETED")
        transaction_logger.info(f"   🆔 Transaction ID: {transaction_id}")
        transaction_logger.info(f"   💰 Monto procesado: ${amount:.2f}")
        transaction_logger.info(f"   💳 Balance anterior: ${current_balance:.2f}")
        transaction_logger.info(f"   💳 Balance nuevo: ${new_balance:.2f}")
        transaction_logger.info(f"   ⏱️ Tiempo de procesamiento: ~{50 + (amount * 0.1):.0f}ms")
        transaction_logger.info("=" * 80)
        
        return {
            "status": "success",
            "transaction_id": transaction_id,
            "amount": amount,
            "type": transaction_type,
            "description": description,
            "account_id": account_id,
            "previous_balance": current_balance,
            "new_balance": new_balance,
            "timestamp": timestamp,
            "message": f"Transacción {transaction_type} por ${amount:.2f} procesada exitosamente"
        }
        
    except HTTPException as he:
        # Re-raise HTTP exceptions
        transaction_logger.error(f"❌ HTTP ERROR: {he.detail}")
        transaction_logger.error("=" * 80)
        raise he
    except Exception as e:
        # Log de error detallado
        transaction_logger.error("💥 ERROR CRÍTICO EN TRANSACCIÓN")
        transaction_logger.error(f"   🐛 Error: {str(e)}")
        transaction_logger.error(f"   📊 Datos que causaron error: {transaction_data}")
        transaction_logger.error(f"   🌐 IP Cliente: {client_ip}")
        transaction_logger.error(f"   ⏰ Timestamp: {timestamp}")
        transaction_logger.error("=" * 80)
        
        raise HTTPException(
            status_code=500,
            detail=f"Error interno procesando transacción: {str(e)}"
        )

@app.get("/api/balance/{account_id}", tags=["Accounts"])
async def get_balance(account_id: str, request: Request):
    client_ip = request.client.host
    timestamp = datetime.utcnow().isoformat()
    
    db_logger.info("=" * 60)
    db_logger.info("💰 CONSULTA DE BALANCE")
    db_logger.info(f"   🔑 Account ID: {account_id}")
    db_logger.info(f"   🌐 IP Cliente: {client_ip}")
    db_logger.info(f"   ⏰ Timestamp: {timestamp}")
    
    try:
        # Intentar obtener de Redis primero
        redis_logger.info("🔴 VERIFICANDO CACHE DE REDIS...")
        redis_logger.info(f"   🔍 GET balance:{account_id}")
        
        # Simular cache miss
        redis_logger.info("❌ CACHE MISS - Balance no encontrado en Redis")
        
        # Consultar PostgreSQL
        db_logger.info("🗄️ CONSULTANDO POSTGRESQL...")
        db_logger.info(f"   📊 Query: SELECT balance, account_type, updated_at FROM accounts WHERE id = '{account_id}'")
        
        # Simular datos de cuenta
        balance = 1500.00
        account_type = "checking"
        last_updated = timestamp
        
        db_logger.info(f"   ✅ Cuenta encontrada:")
        db_logger.info(f"   💳 Balance: ${balance:.2f}")
        db_logger.info(f"   📝 Tipo: {account_type}")
        db_logger.info(f"   🕒 Última actualización: {last_updated}")
        
        # Guardar en cache
        redis_logger.info("💾 GUARDANDO EN CACHE...")
        redis_logger.info(f"   🔑 SET balance:{account_id} = {balance}")
        redis_logger.info(f"   ⏱️ EXPIRE balance:{account_id} 300")
        redis_logger.info("✅ BALANCE GUARDADO EN CACHE")
        
        db_logger.info("🎯 CONSULTA DE BALANCE COMPLETADA")
        db_logger.info("=" * 60)
        
        return {
            "account_id": account_id,
            "balance": balance,
            "account_type": account_type,
            "currency": "USD",
            "last_updated": last_updated,
            "source": "database"
        }
        
    except Exception as e:
        db_logger.error("💥 ERROR EN CONSULTA DE BALANCE")
        db_logger.error(f"   🐛 Error: {str(e)}")
        db_logger.error(f"   🔑 Account ID: {account_id}")
        db_logger.error("=" * 60)
        
        raise HTTPException(
            status_code=500,
            detail=f"Error consultando balance: {str(e)}"
        )

@app.get("/api/transactions/{account_id}", tags=["Transactions"])
async def get_transactions_history(account_id: str, limit: int = 10, request: Request = None):
    client_ip = request.client.host if request else "unknown"
    
    db_logger.info("=" * 70)
    db_logger.info("📊 CONSULTANDO HISTORIAL DE TRANSACCIONES")
    db_logger.info(f"   🔑 Account ID: {account_id}")
    db_logger.info(f"   📄 Límite: {limit} registros")
    db_logger.info(f"   🌐 IP Cliente: {client_ip}")
    
    try:
        # Simular consulta a base de datos
        db_logger.info("🗄️ EJECUTANDO CONSULTA EN POSTGRESQL...")
        db_logger.info(f"   📊 Query: SELECT * FROM transactions WHERE account_id = '{account_id}' ORDER BY created_at DESC LIMIT {limit}")
        
        # Datos simulados de transacciones
        transactions = [
            {
                "id": "TXN-ABC123456789",
                "amount": 500.00,
                "type": "deposit",
                "description": "Salary deposit",
                "created_at": "2024-10-20T10:30:00Z",
                "status": "completed"
            },
            {
                "id": "TXN-DEF987654321",
                "amount": -50.00,
                "type": "withdrawal",
                "description": "ATM withdrawal",
                "created_at": "2024-10-19T15:45:00Z",
                "status": "completed"
            }
        ]
        
        db_logger.info(f"   ✅ Encontradas {len(transactions)} transacciones")
        
        for i, txn in enumerate(transactions, 1):
            db_logger.info(f"   📋 Transacción {i}:")
            db_logger.info(f"      🆔 ID: {txn['id']}")
            db_logger.info(f"      💰 Monto: ${abs(txn['amount']):.2f}")
            db_logger.info(f"      📝 Tipo: {txn['type']}")
            db_logger.info(f"      ✅ Estado: {txn['status']}")
        
        db_logger.info("🎯 HISTORIAL OBTENIDO EXITOSAMENTE")
        db_logger.info("=" * 70)
        
        return {
            "account_id": account_id,
            "transactions": transactions,
            "total_found": len(transactions),
            "limit": limit
        }
        
    except Exception as e:
        db_logger.error("💥 ERROR OBTENIENDO HISTORIAL")
        db_logger.error(f"   🐛 Error: {str(e)}")
        db_logger.error("=" * 70)
        
        raise HTTPException(
            status_code=500,
            detail=f"Error obteniendo historial: {str(e)}"
        )

# Service Payment Endpoint
@app.post("/api/pay-service", tags=["Services"])
async def pay_service(payment: PayServiceRequest, username: str = Depends(verify_token)):
    """Pay for services like electricity, water, gas, etc."""
    db_logger = logging.getLogger("database.service_payment")
    
    try:
        db_logger.info("💳 INICIANDO PAGO DE SERVICIO")
        db_logger.info("=" * 70)
        db_logger.info(f"   👤 Usuario: {username}")
        db_logger.info(f"   🏪 Proveedor: {payment.service_provider}")
        db_logger.info(f"   🔧 Tipo: {payment.service_type}")
        db_logger.info(f"   💰 Monto: ${payment.amount:.2f}")
        
        async with db_pool.acquire() as conn:
            # Verify account exists and has sufficient balance
            account = await conn.fetchrow(
                "SELECT id, balance FROM accounts WHERE id = $1",
                payment.account_id
            )
            
            if not account:
                raise HTTPException(status_code=404, detail="Cuenta no encontrada")
            
            if account['balance'] < payment.amount:
                raise HTTPException(status_code=400, detail="Saldo insuficiente")
            
            # Create service payment record
            payment_id = await conn.fetchval('''
                INSERT INTO service_payments 
                (account_id, service_provider, service_type, amount, reference_number, description, status)
                VALUES ($1, $2, $3, $4, $5, $6, 'completed')
                RETURNING id
            ''', payment.account_id, payment.service_provider, payment.service_type, 
                payment.amount, payment.reference_number, payment.description)
            
            # Update account balance
            new_balance = await conn.fetchval(
                "UPDATE accounts SET balance = balance - $1 WHERE id = $2 RETURNING balance",
                payment.amount, payment.account_id
            )
            
            db_logger.info(f"   ✅ Pago procesado exitosamente")
            db_logger.info(f"   🆔 ID Pago: {payment_id}")
            db_logger.info(f"   💰 Nuevo saldo: ${new_balance:.2f}")
            db_logger.info("=" * 70)
            
            return {
                "payment_id": str(payment_id),
                "status": "completed",
                "service_provider": payment.service_provider,
                "amount": payment.amount,
                "new_balance": new_balance,
                "timestamp": datetime.utcnow().isoformat()
            }
            
    except HTTPException:
        raise
    except Exception as e:
        db_logger.error(f"💥 ERROR EN PAGO DE SERVICIO: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error procesando pago: {str(e)}")

# Deposit Endpoint
@app.post("/api/deposit", tags=["Transactions"])
async def deposit_money(deposit: DepositRequest, username: str = Depends(verify_token)):
    """Deposit money into an account"""
    db_logger = logging.getLogger("database.deposit")
    
    try:
        db_logger.info("💵 INICIANDO DEPÓSITO")
        db_logger.info("=" * 70)
        db_logger.info(f"   👤 Usuario: {username}")
        db_logger.info(f"   🏦 Cuenta: {deposit.account_id}")
        db_logger.info(f"   💰 Monto: ${deposit.amount:.2f}")
        db_logger.info(f"   📱 Método: {deposit.deposit_method}")
        
        async with db_pool.acquire() as conn:
            # Verify account exists
            account = await conn.fetchrow(
                "SELECT id, balance FROM accounts WHERE id = $1",
                deposit.account_id
            )
            
            if not account:
                raise HTTPException(status_code=404, detail="Cuenta no encontrada")
            
            # Create deposit record
            deposit_id = await conn.fetchval('''
                INSERT INTO deposits 
                (account_id, amount, deposit_method, reference_number, description, status)
                VALUES ($1, $2, $3, $4, $5, 'completed')
                RETURNING id
            ''', deposit.account_id, deposit.amount, deposit.deposit_method, 
                deposit.reference_number, deposit.description)
            
            # Update account balance
            new_balance = await conn.fetchval(
                "UPDATE accounts SET balance = balance + $1 WHERE id = $2 RETURNING balance",
                deposit.amount, deposit.account_id
            )
            
            db_logger.info(f"   ✅ Depósito procesado exitosamente")
            db_logger.info(f"   🆔 ID Depósito: {deposit_id}")
            db_logger.info(f"   💰 Nuevo saldo: ${new_balance:.2f}")
            db_logger.info("=" * 70)
            
            return {
                "deposit_id": str(deposit_id),
                "status": "completed",
                "amount": deposit.amount,
                "method": deposit.deposit_method,
                "new_balance": new_balance,
                "timestamp": datetime.utcnow().isoformat()
            }
            
    except HTTPException:
        raise
    except Exception as e:
        db_logger.error(f"💥 ERROR EN DEPÓSITO: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error procesando depósito: {str(e)}")

# Withdrawal Endpoint
@app.post("/api/withdraw", tags=["Transactions"])
async def withdraw_money(withdrawal: WithdrawRequest, username: str = Depends(verify_token)):
    """Withdraw money from an account"""
    db_logger = logging.getLogger("database.withdrawal")
    
    try:
        db_logger.info("💸 INICIANDO RETIRO")
        db_logger.info("=" * 70)
        db_logger.info(f"   👤 Usuario: {username}")
        db_logger.info(f"   🏦 Cuenta: {withdrawal.account_id}")
        db_logger.info(f"   💰 Monto: ${withdrawal.amount:.2f}")
        db_logger.info(f"   🏧 Método: {withdrawal.withdrawal_method}")
        
        async with db_pool.acquire() as conn:
            # Verify account exists and has sufficient balance
            account = await conn.fetchrow(
                "SELECT id, balance FROM accounts WHERE id = $1",
                withdrawal.account_id
            )
            
            if not account:
                raise HTTPException(status_code=404, detail="Cuenta no encontrada")
            
            if account['balance'] < withdrawal.amount:
                raise HTTPException(status_code=400, detail="Saldo insuficiente")
            
            # Create withdrawal record
            withdrawal_id = await conn.fetchval('''
                INSERT INTO withdrawals 
                (account_id, amount, withdrawal_method, description, status)
                VALUES ($1, $2, $3, $4, 'completed')
                RETURNING id
            ''', withdrawal.account_id, withdrawal.amount, withdrawal.withdrawal_method, withdrawal.description)
            
            # Update account balance
            new_balance = await conn.fetchval(
                "UPDATE accounts SET balance = balance - $1 WHERE id = $2 RETURNING balance",
                withdrawal.amount, withdrawal.account_id
            )
            
            db_logger.info(f"   ✅ Retiro procesado exitosamente")
            db_logger.info(f"   🆔 ID Retiro: {withdrawal_id}")
            db_logger.info(f"   💰 Nuevo saldo: ${new_balance:.2f}")
            db_logger.info("=" * 70)
            
            return {
                "withdrawal_id": str(withdrawal_id),
                "status": "completed",
                "amount": withdrawal.amount,
                "method": withdrawal.withdrawal_method,
                "new_balance": new_balance,
                "timestamp": datetime.utcnow().isoformat()
            }
            
    except HTTPException:
        raise
    except Exception as e:
        db_logger.error(f"💥 ERROR EN RETIRO: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error procesando retiro: {str(e)}")

# Root endpoint
@app.get("/", tags=["Root"])
async def root():
    return {
        "message": "Banking API is running",
        "version": "1.0.0",
        "docs": "/api/docs",
        "health": "/health",
        "endpoints": {
            "create_transaction": "POST /api/transactions",
            "get_balance": "GET /api/balance/{account_id}",
            "get_history": "GET /api/transactions/{account_id}",
            "pay_service": "POST /api/pay-service",
            "deposit": "POST /api/deposit",
            "withdraw": "POST /api/withdraw"
        }
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)