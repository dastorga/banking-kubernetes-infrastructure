# Monitoring and Logging Infrastructure for Banking EKS

# CloudWatch Log Group for EKS Cluster
resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/${local.cluster_name}/cluster"
  retention_in_days = 7
  kms_key_id        = aws_kms_key.eks.arn

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-cluster-logs"
  })
}

# CloudWatch Log Group for Application Logs
resource "aws_cloudwatch_log_group" "banking_app" {
  name              = "/aws/eks/${local.cluster_name}/banking-app"
  retention_in_days = 14
  kms_key_id        = aws_kms_key.eks.arn

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-banking-app-logs"
  })
}

# CloudWatch Log Group for Ingress Controller
resource "aws_cloudwatch_log_group" "aws_load_balancer_controller" {
  name              = "/aws/eks/${local.cluster_name}/aws-load-balancer-controller"
  retention_in_days = 7
  kms_key_id        = aws_kms_key.eks.arn

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-alb-controller-logs"
  })
}

# CloudWatch Log Group for Cluster Autoscaler
resource "aws_cloudwatch_log_group" "cluster_autoscaler" {
  name              = "/aws/eks/${local.cluster_name}/cluster-autoscaler"
  retention_in_days = 7
  kms_key_id        = aws_kms_key.eks.arn

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-cluster-autoscaler-logs"
  })
}

# SNS Topic for Alerts
resource "aws_sns_topic" "banking_alerts" {
  name         = "${local.cluster_name}-alerts"
  display_name = "Banking EKS Alerts"

  kms_master_key_id = aws_kms_key.sns.arn

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-alerts"
  })
}

# SNS Topic Subscription (add your email here)
resource "aws_sns_topic_subscription" "email_alerts" {
  count = var.alert_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.banking_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# KMS Key for SNS encryption
resource "aws_kms_key" "sns" {
  description             = "KMS key for SNS encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-sns-kms-key"
  })
}

resource "aws_kms_alias" "sns" {
  name          = "alias/${local.cluster_name}-sns-key"
  target_key_id = aws_kms_key.sns.key_id
}

# CloudWatch Alarms

# EKS Cluster CPU Utilization
resource "aws_cloudwatch_metric_alarm" "eks_cpu_high" {
  alarm_name          = "${local.cluster_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EKS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors eks cluster cpu utilization"
  alarm_actions       = [aws_sns_topic.banking_alerts.arn]

  dimensions = {
    ClusterName = aws_eks_cluster.banking_cluster.name
  }

  tags = local.common_tags
}

# EKS Node Group CPU Utilization
resource "aws_cloudwatch_metric_alarm" "node_group_cpu_high" {
  alarm_name          = "${local.cluster_name}-node-group-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors node group cpu utilization"
  alarm_actions       = [aws_sns_topic.banking_alerts.arn]

  tags = local.common_tags
}

# RDS CPU Utilization
resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  alarm_name          = "${local.cluster_name}-rds-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors RDS cpu utilization"
  alarm_actions       = [aws_sns_topic.banking_alerts.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.banking.id
  }

  tags = local.common_tags
}

# RDS Database Connections
resource "aws_cloudwatch_metric_alarm" "rds_connections_high" {
  alarm_name          = "${local.cluster_name}-rds-high-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors RDS database connections"
  alarm_actions       = [aws_sns_topic.banking_alerts.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.banking.id
  }

  tags = local.common_tags
}

# RDS Free Storage Space
resource "aws_cloudwatch_metric_alarm" "rds_free_storage_low" {
  alarm_name          = "${local.cluster_name}-rds-low-storage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "2000000000" # 2GB in bytes
  alarm_description   = "This metric monitors RDS free storage space"
  alarm_actions       = [aws_sns_topic.banking_alerts.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.banking.id
  }

  tags = local.common_tags
}

# ElastiCache CPU Utilization
resource "aws_cloudwatch_metric_alarm" "elasticache_cpu_high" {
  alarm_name          = "${local.cluster_name}-elasticache-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ElastiCache cpu utilization"
  alarm_actions       = [aws_sns_topic.banking_alerts.arn]

  dimensions = {
    CacheClusterId = aws_elasticache_replication_group.banking.id
  }

  tags = local.common_tags
}

# ElastiCache Memory Utilization
resource "aws_cloudwatch_metric_alarm" "elasticache_memory_high" {
  alarm_name          = "${local.cluster_name}-elasticache-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseMemoryUsagePercentage"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ElastiCache memory utilization"
  alarm_actions       = [aws_sns_topic.banking_alerts.arn]

  dimensions = {
    CacheClusterId = aws_elasticache_replication_group.banking.id
  }

  tags = local.common_tags
}

# Application Load Balancer Target Response Time
resource "aws_cloudwatch_metric_alarm" "alb_response_time_high" {
  alarm_name          = "${local.cluster_name}-alb-high-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = "1" # 1 second
  alarm_description   = "This metric monitors ALB target response time"
  alarm_actions       = [aws_sns_topic.banking_alerts.arn]

  tags = local.common_tags
}

# Application Load Balancer 5XX Errors
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors_high" {
  alarm_name          = "${local.cluster_name}-alb-high-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors ALB 5XX errors"
  alarm_actions       = [aws_sns_topic.banking_alerts.arn]

  tags = local.common_tags
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "banking_dashboard" {
  dashboard_name = "${local.cluster_name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/EKS", "cluster_failed_request_count", "ClusterName", aws_eks_cluster.banking_cluster.name],
            ["AWS/EKS", "cluster_request_total", "ClusterName", aws_eks_cluster.banking_cluster.name]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "EKS Cluster Requests"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.banking.id],
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", aws_db_instance.banking.id],
            ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", aws_db_instance.banking.id]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "RDS Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ElastiCache", "CPUUtilization", "CacheClusterId", aws_elasticache_replication_group.banking.id],
            ["AWS/ElastiCache", "DatabaseMemoryUsagePercentage", "CacheClusterId", aws_elasticache_replication_group.banking.id]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "ElastiCache Metrics"
          period  = 300
        }
      }
    ]
  })
}

# EventBridge Rule for EKS Events
resource "aws_cloudwatch_event_rule" "eks_events" {
  name        = "${local.cluster_name}-eks-events"
  description = "Capture EKS events"

  event_pattern = jsonencode({
    source      = ["aws.eks"]
    detail-type = ["EKS Cluster State Change"]
    detail = {
      clusterName = [aws_eks_cluster.banking_cluster.name]
    }
  })

  tags = local.common_tags
}

# EventBridge Target for EKS Events
resource "aws_cloudwatch_event_target" "sns_target" {
  rule      = aws_cloudwatch_event_rule.eks_events.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.banking_alerts.arn
}
