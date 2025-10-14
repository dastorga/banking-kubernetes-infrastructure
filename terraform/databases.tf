# Database and Cache Infrastructure for Banking EKS

# Random password for RDS
resource "random_password" "db_password" {
  length  = 16
  special = true
}

# AWS Secrets Manager secret for RDS password
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${local.cluster_name}-rds-password"
  description             = "RDS PostgreSQL password for banking application"
  recovery_window_in_days = 7

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-rds-password"
  })
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
  })
}

# RDS Parameter Group
resource "aws_db_parameter_group" "banking" {
  family = "postgres15"
  name   = "${local.cluster_name}-postgres-params"

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
  }

  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  parameter {
    name  = "log_checkpoints"
    value = "1"
  }

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-postgres-params"
  })
}

# RDS Option Group
resource "aws_db_option_group" "banking" {
  name                     = "${local.cluster_name}-postgres-options"
  option_group_description = "Option group for banking PostgreSQL"
  engine_name              = "postgres"
  major_engine_version     = "15"

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-postgres-options"
  })
}

# RDS Instance
resource "aws_db_instance" "banking" {
  identifier = "${local.cluster_name}-postgres"

  # Engine configuration
  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  # Storage configuration
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.rds.arn

  # Database configuration
  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_password.result

  # Network configuration
  db_subnet_group_name   = aws_db_subnet_group.banking.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  port                   = 5432

  # Parameter and option groups
  parameter_group_name = aws_db_parameter_group.banking.name
  option_group_name    = aws_db_option_group.banking.name

  # Backup configuration
  backup_retention_period   = 7
  backup_window             = "03:00-04:00"
  maintenance_window        = "sun:04:00-sun:05:00"
  copy_tags_to_snapshot     = true
  skip_final_snapshot       = false
  final_snapshot_identifier = "${local.cluster_name}-postgres-final-snapshot"

  # Monitoring and logging
  monitoring_interval             = 60
  monitoring_role_arn             = aws_iam_role.rds_monitoring.arn
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  performance_insights_enabled    = true
  performance_insights_kms_key_id = aws_kms_key.rds.arn

  # Security
  deletion_protection = true

  depends_on = [
    aws_cloudwatch_log_group.rds_postgresql,
    aws_cloudwatch_log_group.rds_upgrade
  ]

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-postgres"
  })
}

# RDS Read Replica (for production workloads)
resource "aws_db_instance" "banking_replica" {
  count = var.environment == "prod" ? 1 : 0

  identifier = "${local.cluster_name}-postgres-replica"

  # Replica configuration
  replicate_source_db = aws_db_instance.banking.id
  instance_class      = var.db_instance_class

  # Network configuration
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  # Monitoring
  monitoring_interval             = 60
  monitoring_role_arn             = aws_iam_role.rds_monitoring.arn
  performance_insights_enabled    = true
  performance_insights_kms_key_id = aws_kms_key.rds.arn

  skip_final_snapshot = true
  deletion_protection = true

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-postgres-replica"
  })
}

# CloudWatch Log Groups for RDS
resource "aws_cloudwatch_log_group" "rds_postgresql" {
  name              = "/aws/rds/instance/${local.cluster_name}-postgres/postgresql"
  retention_in_days = 7
  kms_key_id        = aws_kms_key.rds.arn

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-rds-postgresql-logs"
  })
}

resource "aws_cloudwatch_log_group" "rds_upgrade" {
  name              = "/aws/rds/instance/${local.cluster_name}-postgres/upgrade"
  retention_in_days = 7
  kms_key_id        = aws_kms_key.rds.arn

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-rds-upgrade-logs"
  })
}

# KMS Key for RDS encryption
resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-rds-kms-key"
  })
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${local.cluster_name}-rds-key"
  target_key_id = aws_kms_key.rds.key_id
}

# IAM Role for RDS Enhanced Monitoring
resource "aws_iam_role" "rds_monitoring" {
  name = "${local.cluster_name}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-rds-monitoring-role"
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
  role       = aws_iam_role.rds_monitoring.name
}

# ElastiCache Parameter Group
resource "aws_elasticache_parameter_group" "banking" {
  family = "redis7.x"
  name   = "${local.cluster_name}-redis-params"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  parameter {
    name  = "timeout"
    value = "300"
  }

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-redis-params"
  })
}

# ElastiCache Replication Group
resource "aws_elasticache_replication_group" "banking" {
  replication_group_id = "${local.cluster_name}-redis"
  description          = "Redis cluster for banking application"

  # Engine configuration
  engine               = "redis"
  engine_version       = var.redis_engine_version
  node_type            = var.redis_node_type
  parameter_group_name = aws_elasticache_parameter_group.banking.name
  port                 = 6379

  # Cluster configuration
  num_cache_clusters = var.redis_num_cache_nodes

  # Network configuration
  subnet_group_name  = aws_elasticache_subnet_group.banking.name
  security_group_ids = [aws_security_group.elasticache.id]

  # Security
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = random_password.redis_auth_token.result
  kms_key_id                 = aws_kms_key.elasticache.arn

  # Backup configuration
  snapshot_retention_limit = 3
  snapshot_window          = "03:00-05:00"
  maintenance_window       = "sun:05:00-sun:07:00"

  # Logging
  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.elasticache_slow.name
    destination_type = "cloudwatch-logs"
    log_format       = "text"
    log_type         = "slow-log"
  }

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-redis"
  })
}

# Random auth token for Redis
resource "random_password" "redis_auth_token" {
  length  = 32
  special = false
}

# AWS Secrets Manager secret for Redis auth token
resource "aws_secretsmanager_secret" "redis_auth_token" {
  name                    = "${local.cluster_name}-redis-auth-token"
  description             = "Redis auth token for banking application"
  recovery_window_in_days = 7

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-redis-auth-token"
  })
}

resource "aws_secretsmanager_secret_version" "redis_auth_token" {
  secret_id = aws_secretsmanager_secret.redis_auth_token.id
  secret_string = jsonencode({
    auth_token = random_password.redis_auth_token.result
  })
}

# CloudWatch Log Group for ElastiCache
resource "aws_cloudwatch_log_group" "elasticache_slow" {
  name              = "/aws/elasticache/${local.cluster_name}-redis/slow-log"
  retention_in_days = 7
  kms_key_id        = aws_kms_key.elasticache.arn

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-elasticache-slow-logs"
  })
}

# KMS Key for ElastiCache encryption
resource "aws_kms_key" "elasticache" {
  description             = "KMS key for ElastiCache encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-elasticache-kms-key"
  })
}

resource "aws_kms_alias" "elasticache" {
  name          = "alias/${local.cluster_name}-elasticache-key"
  target_key_id = aws_kms_key.elasticache.key_id
}
