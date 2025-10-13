# Backend Dockerfile for Banking FastAPI Application
FROM python:3.11-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PYTHONPATH=/app

# Set work directory
WORKDIR /app

# Install system dependencies
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
  gcc \
  postgresql-client \
  curl \
  netcat-openbsd \
  && rm -rf /var/lib/apt/lists/*

# Create non-root user for security
RUN addgroup --system --gid 1001 appgroup \
  && adduser --system --uid 1001 --gid 1001 --no-create-home appuser

# Copy requirements first for better Docker layer caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade pip \
  && pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create necessary directories
RUN mkdir -p /app/logs && chown -R appuser:appgroup /app

# Health check script
RUN echo '#!/bin/bash\ncurl -f http://localhost:8000/health || exit 1' > /usr/local/bin/health-check.sh \
  && chmod +x /usr/local/bin/health-check.sh

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD /usr/local/bin/health-check.sh

# Expose port
EXPOSE 8000

# Labels for better container management
LABEL maintainer="DevOps Team <devops@banking.com>"
LABEL version="1.0"
LABEL description="Banking Application Backend - FastAPI with PostgreSQL and Redis"

# Switch to non-root user
USER appuser

# Command to run the application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]