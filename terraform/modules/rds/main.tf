# RDS Module for Multi-Environment DEX Infrastructure
# Supports PostgreSQL and MySQL databases

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
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

variable "subnet_ids" {
  description = "List of subnet IDs"
  type        = list(string)
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# Data sources
data "aws_region" "current" {}

# Random password for database
resource "random_password" "db_password" {
  length  = 32
  special = true
}

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.environment}-db-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.environment}-db-subnet-group"
    Type = "DB Subnet Group"
  })
}

# Parameter Group for PostgreSQL
resource "aws_db_parameter_group" "postgresql" {
  family = "postgres15"
  name   = "${var.environment}-postgresql-params"

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

  parameter {
    name  = "log_lock_waits"
    value = "1"
  }

  tags = merge(var.tags, {
    Name = "${var.environment}-postgresql-params"
    Type = "DB Parameter Group"
  })
}

# Parameter Group for MySQL
resource "aws_db_parameter_group" "mysql" {
  family = "mysql8.0"
  name   = "${var.environment}-mysql-params"

  parameter {
    name  = "slow_query_log"
    value = "1"
  }

  parameter {
    name  = "long_query_time"
    value = "1"
  }

  parameter {
    name  = "log_queries_not_using_indexes"
    value = "1"
  }

  parameter {
    name  = "general_log"
    value = "1"
  }

  tags = merge(var.tags, {
    Name = "${var.environment}-mysql-params"
    Type = "DB Parameter Group"
  })
}

# PostgreSQL RDS Instance
resource "aws_db_instance" "postgresql" {
  identifier = "${var.environment}-postgresql"

  engine         = "postgres"
  engine_version = "15.4"
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.allocated_storage * 2
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = "vaultswap"
  username = "vaultswap"
  password = random_password.db_password.result

  vpc_security_group_ids = var.security_group_ids
  db_subnet_group_name   = aws_db_subnet_group.main.name
  parameter_group_name   = aws_db_parameter_group.postgresql.name

  backup_retention_period = var.backup_retention_period
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"

  skip_final_snapshot = var.environment == "testing" ? true : false
  deletion_protection  = var.environment == "production" ? true : false

  performance_insights_enabled = true
  monitoring_interval         = 60
  monitoring_role_arn        = aws_iam_role.rds_enhanced_monitoring.arn

  tags = merge(var.tags, {
    Name = "${var.environment}-postgresql"
    Type = "RDS Instance"
    Engine = "PostgreSQL"
  })

  depends_on = [aws_cloudwatch_log_group.postgresql]
}

# MySQL RDS Instance
resource "aws_db_instance" "mysql" {
  identifier = "${var.environment}-mysql"

  engine         = "mysql"
  engine_version = "8.0.35"
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.allocated_storage * 2
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = "vaultswap"
  username = "vaultswap"
  password = random_password.db_password.result

  vpc_security_group_ids = var.security_group_ids
  db_subnet_group_name   = aws_db_subnet_group.main.name
  parameter_group_name   = aws_db_parameter_group.mysql.name

  backup_retention_period = var.backup_retention_period
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"

  skip_final_snapshot = var.environment == "testing" ? true : false
  deletion_protection  = var.environment == "production" ? true : false

  performance_insights_enabled = true
  monitoring_interval         = 60
  monitoring_role_arn        = aws_iam_role.rds_enhanced_monitoring.arn

  tags = merge(var.tags, {
    Name = "${var.environment}-mysql"
    Type = "RDS Instance"
    Engine = "MySQL"
  })

  depends_on = [aws_cloudwatch_log_group.mysql]
}

# IAM Role for Enhanced Monitoring
resource "aws_iam_role" "rds_enhanced_monitoring" {
  name = "${var.environment}-rds-enhanced-monitoring"

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

  tags = merge(var.tags, {
    Name = "${var.environment}-rds-enhanced-monitoring"
    Type = "IAM Role"
  })
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  role       = aws_iam_role.rds_enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "postgresql" {
  name              = "/aws/rds/instance/${var.environment}-postgresql/postgresql"
  retention_in_days = 30

  tags = merge(var.tags, {
    Name = "${var.environment}-postgresql-logs"
    Type = "CloudWatch Log Group"
  })
}

resource "aws_cloudwatch_log_group" "mysql" {
  name              = "/aws/rds/instance/${var.environment}-mysql/mysql"
  retention_in_days = 30

  tags = merge(var.tags, {
    Name = "${var.environment}-mysql-logs"
    Type = "CloudWatch Log Group"
  })
}

# DB Option Groups
resource "aws_db_option_group" "postgresql" {
  name                     = "${var.environment}-postgresql-options"
  option_group_description = "Option group for PostgreSQL"
  engine_name              = "postgres"
  major_engine_version     = "15"

  tags = merge(var.tags, {
    Name = "${var.environment}-postgresql-options"
    Type = "DB Option Group"
  })
}

resource "aws_db_option_group" "mysql" {
  name                     = "${var.environment}-mysql-options"
  option_group_description = "Option group for MySQL"
  engine_name              = "mysql"
  major_engine_version     = "8.0"

  tags = merge(var.tags, {
    Name = "${var.environment}-mysql-options"
    Type = "DB Option Group"
  })
}

# RDS Snapshots
resource "aws_db_snapshot" "postgresql" {
  count = var.environment == "production" ? 1 : 0

  db_instance_identifier = aws_db_instance.postgresql.id
  db_snapshot_identifier = "${var.environment}-postgresql-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  tags = merge(var.tags, {
    Name = "${var.environment}-postgresql-snapshot"
    Type = "DB Snapshot"
  })
}

resource "aws_db_snapshot" "mysql" {
  count = var.environment == "production" ? 1 : 0

  db_instance_identifier = aws_db_instance.mysql.id
  db_snapshot_identifier = "${var.environment}-mysql-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  tags = merge(var.tags, {
    Name = "${var.environment}-mysql-snapshot"
    Type = "DB Snapshot"
  })
}

# Outputs
output "instance_ids" {
  description = "List of RDS instance IDs"
  value = [
    aws_db_instance.postgresql.id,
    aws_db_instance.mysql.id
  ]
}

output "postgresql_endpoint" {
  description = "PostgreSQL endpoint"
  value       = aws_db_instance.postgresql.endpoint
}

output "mysql_endpoint" {
  description = "MySQL endpoint"
  value       = aws_db_instance.mysql.endpoint
}

output "postgresql_port" {
  description = "PostgreSQL port"
  value       = aws_db_instance.postgresql.port
}

output "mysql_port" {
  description = "MySQL port"
  value       = aws_db_instance.mysql.port
}

output "database_password" {
  description = "Database password"
  value       = random_password.db_password.result
  sensitive   = true
}

output "database_username" {
  description = "Database username"
  value       = "vaultswap"
}

output "database_name" {
  description = "Database name"
  value       = "vaultswap"
}

output "connection_strings" {
  description = "Database connection strings"
  value = {
    postgresql = "postgresql://vaultswap:${random_password.db_password.result}@${aws_db_instance.postgresql.endpoint}:${aws_db_instance.postgresql.port}/vaultswap"
    mysql      = "mysql://vaultswap:${random_password.db_password.result}@${aws_db_instance.mysql.endpoint}:${aws_db_instance.mysql.port}/vaultswap"
  }
  sensitive = true
}

output "log_groups" {
  description = "CloudWatch log groups"
  value = {
    postgresql = aws_cloudwatch_log_group.postgresql.name
    mysql      = aws_cloudwatch_log_group.mysql.name
  }
}

output "snapshots" {
  description = "RDS snapshots"
  value = {
    postgresql = var.environment == "production" ? aws_db_snapshot.postgresql[0].id : null
    mysql      = var.environment == "production" ? aws_db_snapshot.mysql[0].id : null
  }
}
