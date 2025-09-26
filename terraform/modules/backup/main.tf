# Backup Module for Multi-Environment DEX Infrastructure
# Supports automated backups with encryption and lifecycle management

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Variables
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "backup_retention_days" {
  description = "Backup retention period in days"
  type        = number
  default     = 30
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

# KMS Key for Backup Encryption
resource "aws_kms_key" "backup" {
  description             = "KMS key for VaultSwap DEX backup encryption"
  deletion_window_in_days = 7

  tags = merge(var.tags, {
    Name = "${var.environment}-backup-key"
    Type = "KMS Key"
  })
}

resource "aws_kms_alias" "backup" {
  name          = "alias/${var.environment}-backup"
  target_key_id = aws_kms_key.backup.key_id
}

# Backup Vault
resource "aws_backup_vault" "main" {
  name        = "${var.environment}-backup-vault"
  kms_key_arn = aws_kms_key.backup.arn

  tags = merge(var.tags, {
    Name = "${var.environment}-backup-vault"
    Type = "Backup Vault"
  })
}

# Backup Plan
resource "aws_backup_plan" "main" {
  name = "${var.environment}-backup-plan"

  rule {
    rule_name         = "daily_backup"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 2 * * ? *)"

    lifecycle {
      cold_storage_after = 30
      delete_after      = var.backup_retention_days
    }

    recovery_point_tags = merge(var.tags, {
      Name = "${var.environment}-daily-backup"
      Type = "Recovery Point"
    })
  }

  rule {
    rule_name         = "weekly_backup"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 3 ? * SUN *)"

    lifecycle {
      cold_storage_after = 7
      delete_after      = var.backup_retention_days * 2
    }

    recovery_point_tags = merge(var.tags, {
      Name = "${var.environment}-weekly-backup"
      Type = "Recovery Point"
    })
  }

  rule {
    rule_name         = "monthly_backup"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 4 1 * ? *)"

    lifecycle {
      cold_storage_after = 1
      delete_after      = var.backup_retention_days * 12
    }

    recovery_point_tags = merge(var.tags, {
      Name = "${var.environment}-monthly-backup"
      Type = "Recovery Point"
    })
  }

  tags = merge(var.tags, {
    Name = "${var.environment}-backup-plan"
    Type = "Backup Plan"
  })
}

# IAM Role for Backup
resource "aws_iam_role" "backup" {
  name = "${var.environment}-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.environment}-backup-role"
    Type = "IAM Role"
  })
}

resource "aws_iam_role_policy_attachment" "backup" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
  role       = aws_iam_role.backup.name
}

resource "aws_iam_role_policy_attachment" "restore" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestore"
  role       = aws_iam_role.backup.name
}

# Backup Selection
resource "aws_backup_selection" "ec2" {
  count = length(var.ec2_instances) > 0 ? 1 : 0

  iam_role_arn = aws_iam_role.backup.arn
  name         = "${var.environment}-ec2-backup-selection"
  plan_id      = aws_backup_plan.main.id

  resources = [
    for instance in var.ec2_instances : "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:instance/${instance}"
  ]

  condition {
    string_equals {
      key   = "aws:ResourceTag/Environment"
      value = var.environment
    }
  }
}

resource "aws_backup_selection" "rds" {
  count = length(var.rds_instances) > 0 ? 1 : 0

  iam_role_arn = aws_iam_role.backup.arn
  name         = "${var.environment}-rds-backup-selection"
  plan_id      = aws_backup_plan.main.id

  resources = [
    for instance in var.rds_instances : "arn:aws:rds:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:db:${instance}"
  ]

  condition {
    string_equals {
      key   = "aws:ResourceTag/Environment"
      value = var.environment
    }
  }
}

# EBS Snapshots
resource "aws_ebs_snapshot" "ec2" {
  count = length(var.ec2_instances)

  volume_id = var.ec2_instances[count.index]

  tags = merge(var.tags, {
    Name = "${var.environment}-ec2-snapshot-${count.index + 1}"
    Type = "EBS Snapshot"
  })
}

# RDS Snapshots
resource "aws_db_snapshot" "rds" {
  count = length(var.rds_instances)

  db_instance_identifier = var.rds_instances[count.index]
  db_snapshot_identifier = "${var.environment}-rds-snapshot-${count.index + 1}-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  tags = merge(var.tags, {
    Name = "${var.environment}-rds-snapshot-${count.index + 1}"
    Type = "RDS Snapshot"
  })
}

# S3 Bucket for Backup Storage
resource "aws_s3_bucket" "backup" {
  bucket = "${var.environment}-vaultswap-backup-${random_id.bucket_suffix.hex}"

  tags = merge(var.tags, {
    Name = "${var.environment}-backup-bucket"
    Type = "S3 Bucket"
  })
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "backup" {
  bucket = aws_s3_bucket.backup.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "backup" {
  bucket = aws_s3_bucket.backup.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.backup.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# S3 Bucket Lifecycle
resource "aws_s3_bucket_lifecycle_configuration" "backup" {
  bucket = aws_s3_bucket.backup.id

  rule {
    id     = "backup_lifecycle"
    status = "Enabled"

    expiration {
      days = var.backup_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }
  }
}

# S3 Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "backup" {
  bucket = aws_s3_bucket.backup.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls       = true
  restrict_public_buckets = true
}

# CloudWatch Alarms for Backup
resource "aws_cloudwatch_metric_alarm" "backup_failed" {
  alarm_name          = "${var.environment}-backup-failed"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "NumberOfBackupJobsFailed"
  namespace           = "AWS/Backup"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors failed backup jobs"
  alarm_actions       = [aws_sns_topic.backup_alerts.arn]

  tags = merge(var.tags, {
    Name = "${var.environment}-backup-failed"
    Type = "CloudWatch Alarm"
  })
}

# SNS Topic for Backup Alerts
resource "aws_sns_topic" "backup_alerts" {
  name = "${var.environment}-backup-alerts"

  tags = merge(var.tags, {
    Name = "${var.environment}-backup-alerts"
    Type = "SNS Topic"
  })
}

# Backup Testing
resource "aws_backup_test_restore_job" "test" {
  count = var.environment == "testing" ? 1 : 0

  iam_role_arn = aws_iam_role.backup.arn
  recovery_point_arn = "arn:aws:backup:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:recovery-point:test"
  resource_type = "EC2"

  tags = merge(var.tags, {
    Name = "${var.environment}-backup-test"
    Type = "Backup Test"
  })
}

# Outputs
output "vault_name" {
  description = "Backup vault name"
  value       = aws_backup_vault.main.name
}

output "backup_plan_id" {
  description = "Backup plan ID"
  value       = aws_backup_plan.main.id
}

output "kms_key_id" {
  description = "KMS key ID for backup encryption"
  value       = aws_kms_key.backup.key_id
}

output "kms_key_arn" {
  description = "KMS key ARN for backup encryption"
  value       = aws_kms_key.backup.arn
}

output "s3_bucket_name" {
  description = "S3 bucket name for backup storage"
  value       = aws_s3_bucket.backup.bucket
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN for backup storage"
  value       = aws_s3_bucket.backup.arn
}

output "encryption_enabled" {
  description = "Whether backup encryption is enabled"
  value       = true
}

output "backup_retention_days" {
  description = "Backup retention period in days"
  value       = var.backup_retention_days
}

output "sns_topic_arn" {
  description = "SNS topic ARN for backup alerts"
  value       = aws_sns_topic.backup_alerts.arn
}

output "backup_selections" {
  description = "Backup selection IDs"
  value = {
    ec2 = length(var.ec2_instances) > 0 ? aws_backup_selection.ec2[0].id : null
    rds = length(var.rds_instances) > 0 ? aws_backup_selection.rds[0].id : null
  }
}

output "snapshots" {
  description = "Snapshot information"
  value = {
    ec2_snapshots = aws_ebs_snapshot.ec2[*].id
    rds_snapshots = aws_db_snapshot.rds[*].id
  }
}
