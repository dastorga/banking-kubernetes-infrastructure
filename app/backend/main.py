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

# Trusted host middleware - disabled for development/Kubernetes
# Note: TrustedHostMiddleware doesn't support IP wildcards like "10.*"
# In production, configure with specific domains or disable for internal services
# app.add_middleware(
#     TrustedHostMiddleware,
#     allowed_hosts=["localhost", "*.banking.example.com"]
# )

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

# Root endpoint
@app.get("/", tags=["Root"])
async def root():
    return {
        "message": "Banking API",
        "version": "1.0.0",
        "docs": "/api/docs",
        "health": "/health"
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)