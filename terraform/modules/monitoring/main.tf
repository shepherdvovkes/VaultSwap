# Monitoring Module for Multi-Environment DEX Infrastructure
# Supports Prometheus, Grafana, and CloudWatch integration

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

# Variables
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "monitoring_level" {
  description = "Monitoring level (basic, enhanced, comprehensive)"
  type        = string
  default     = "basic"
}

variable "ec2_instances" {
  description = "List of EC2 instance IDs"
  type        = list(string)
}

variable "rds_instances" {
  description = "List of RDS instance IDs"
  type        = list(string)
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# Data sources
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "application" {
  name              = "/aws/ec2/${var.environment}-application"
  retention_in_days = 30

  tags = merge(var.tags, {
    Name = "${var.environment}-application-logs"
    Type = "CloudWatch Log Group"
  })
}

resource "aws_cloudwatch_log_group" "security" {
  name              = "/aws/ec2/${var.environment}-security"
  retention_in_days = 90

  tags = merge(var.tags, {
    Name = "${var.environment}-security-logs"
    Type = "CloudWatch Log Group"
  })
}

resource "aws_cloudwatch_log_group" "audit" {
  name              = "/aws/ec2/${var.environment}-audit"
  retention_in_days = 365

  tags = merge(var.tags, {
    Name = "${var.environment}-audit-logs"
    Type = "CloudWatch Log Group"
  })
}

# CloudWatch Dashboards
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.environment}-vaultswap-dashboard"

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
            ["AWS/EC2", "CPUUtilization", "InstanceId", var.ec2_instances[0]],
            [".", "NetworkIn", ".", "."],
            [".", "NetworkOut", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "EC2 Metrics"
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
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.rds_instances[0]],
            [".", "DatabaseConnections", ".", "."],
            [".", "FreeableMemory", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "RDS Metrics"
          period  = 300
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.environment}-dashboard"
    Type = "CloudWatch Dashboard"
  })
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.environment}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    InstanceId = var.ec2_instances[0]
  }

  tags = merge(var.tags, {
    Name = "${var.environment}-high-cpu"
    Type = "CloudWatch Alarm"
  })
}

resource "aws_cloudwatch_metric_alarm" "high_memory" {
  alarm_name          = "${var.environment}-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "CWAgent"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors memory utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  tags = merge(var.tags, {
    Name = "${var.environment}-high-memory"
    Type = "CloudWatch Alarm"
  })
}

resource "aws_cloudwatch_metric_alarm" "disk_space" {
  alarm_name          = "${var.environment}-disk-space"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "disk_used_percent"
  namespace           = "CWAgent"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors disk space usage"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  tags = merge(var.tags, {
    Name = "${var.environment}-disk-space"
    Type = "CloudWatch Alarm"
  })
}

# SNS Topic for Alerts
resource "aws_sns_topic" "alerts" {
  name = "${var.environment}-monitoring-alerts"

  tags = merge(var.tags, {
    Name = "${var.environment}-monitoring-alerts"
    Type = "SNS Topic"
  })
}

# SNS Topic Policy
resource "aws_sns_topic_policy" "alerts" {
  arn = aws_sns_topic.alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.alerts.arn
      }
    ]
  })
}

# Prometheus Configuration (if using EKS)
resource "aws_eks_cluster" "monitoring" {
  count = var.monitoring_level == "comprehensive" ? 1 : 0

  name     = "${var.environment}-monitoring-cluster"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = "1.28"

  vpc_config {
    subnet_ids = var.subnet_ids
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.eks_cluster_AmazonEKSVPCResourceController,
  ]

  tags = merge(var.tags, {
    Name = "${var.environment}-monitoring-cluster"
    Type = "EKS Cluster"
  })
}

# EKS IAM Role
resource "aws_iam_role" "eks_cluster" {
  count = var.monitoring_level == "comprehensive" ? 1 : 0

  name = "${var.environment}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.environment}-eks-cluster-role"
    Type = "IAM Role"
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSClusterPolicy" {
  count = var.monitoring_level == "comprehensive" ? 1 : 0

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster[0].name
}

resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSVPCResourceController" {
  count = var.monitoring_level == "comprehensive" ? 1 : 0

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster[0].name
}

# Prometheus Helm Chart
resource "helm_release" "prometheus" {
  count = var.monitoring_level == "comprehensive" ? 1 : 0

  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = "monitoring"
  version    = "45.0.0"

  values = [
    yamlencode({
      prometheus = {
        prometheusSpec = {
          retention = "30d"
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = "gp2"
                resources = {
                  requests = {
                    storage = "50Gi"
                  }
                }
              }
            }
          }
        }
      }
      grafana = {
        enabled = true
        adminPassword = "admin"
        persistence = {
          enabled = true
          size = "10Gi"
        }
      }
    })
  ]

  depends_on = [aws_eks_cluster.monitoring]
}

# Grafana Dashboard
resource "aws_cloudwatch_dashboard" "grafana" {
  count = var.monitoring_level == "comprehensive" ? 1 : 0

  dashboard_name = "${var.environment}-grafana-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 3

        properties = {
          markdown = "## Grafana Dashboard\n\nAccess Grafana at: http://grafana.${var.environment}.vaultswap.com\n\nDefault credentials: admin/admin"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.environment}-grafana-dashboard"
    Type = "CloudWatch Dashboard"
  })
}

# Monitoring IAM Role
resource "aws_iam_role" "monitoring" {
  name = "${var.environment}-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.environment}-monitoring-role"
    Type = "IAM Role"
  })
}

resource "aws_iam_role_policy_attachment" "monitoring_cloudwatch" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.monitoring.name
}

resource "aws_iam_role_policy_attachment" "monitoring_ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.monitoring.name
}

# Instance Profile for Monitoring
resource "aws_iam_instance_profile" "monitoring" {
  name = "${var.environment}-monitoring-profile"
  role = aws_iam_role.monitoring.name

  tags = merge(var.tags, {
    Name = "${var.environment}-monitoring-profile"
    Type = "IAM Instance Profile"
  })
}

# Outputs
output "monitoring_enabled" {
  description = "Whether monitoring is enabled"
  value       = var.monitoring_level != "basic"
}

output "dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}

output "log_groups" {
  description = "CloudWatch log groups"
  value = {
    application = aws_cloudwatch_log_group.application.name
    security    = aws_cloudwatch_log_group.security.name
    audit       = aws_cloudwatch_log_group.audit.name
  }
}

output "alarms" {
  description = "CloudWatch alarm names"
  value = {
    high_cpu    = aws_cloudwatch_metric_alarm.high_cpu.alarm_name
    high_memory = aws_cloudwatch_metric_alarm.high_memory.alarm_name
    disk_space  = aws_cloudwatch_metric_alarm.disk_space.alarm_name
  }
}

output "sns_topic_arn" {
  description = "SNS topic ARN for alerts"
  value       = aws_sns_topic.alerts.arn
}

output "eks_cluster_name" {
  description = "EKS cluster name (if comprehensive monitoring)"
  value       = var.monitoring_level == "comprehensive" ? aws_eks_cluster.monitoring[0].name : null
}

output "prometheus_release" {
  description = "Prometheus Helm release name"
  value       = var.monitoring_level == "comprehensive" ? helm_release.prometheus[0].name : null
}

output "grafana_url" {
  description = "Grafana URL (if comprehensive monitoring)"
  value       = var.monitoring_level == "comprehensive" ? "http://grafana.${var.environment}.vaultswap.com" : null
}

output "monitoring_iam_role_arn" {
  description = "Monitoring IAM role ARN"
  value       = aws_iam_role.monitoring.arn
}

output "monitoring_instance_profile_arn" {
  description = "Monitoring instance profile ARN"
  value       = aws_iam_instance_profile.monitoring.arn
}
