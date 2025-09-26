# Security Groups Module for Multi-Environment DEX Infrastructure
# Implements environment-specific security rules

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

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "security_rules" {
  description = "Environment-specific security rules"
  type        = map(object({
    allow_ssh_from_anywhere      = bool
    allow_http_from_anywhere     = bool
    allow_https_from_anywhere    = bool
    allow_custom_ports          = list(number)
  }))
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# Data sources
data "aws_caller_identity" "current" {}

# Get current environment rules
locals {
  current_rules = var.security_rules[var.environment]
}

# Web Application Security Group
resource "aws_security_group" "web" {
  name_prefix = "${var.environment}-web-"
  vpc_id      = var.vpc_id

  # HTTP
  dynamic "ingress" {
    for_each = local.current_rules.allow_http_from_anywhere ? [1] : []
    content {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  # HTTPS
  dynamic "ingress" {
    for_each = local.current_rules.allow_https_from_anywhere ? [1] : []
    content {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  # Custom ports
  dynamic "ingress" {
    for_each = local.current_rules.allow_custom_ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.environment}-web-sg"
    Type = "Security Group"
    Tier = "Web"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# SSH Security Group
resource "aws_security_group" "ssh" {
  name_prefix = "${var.environment}-ssh-"
  vpc_id      = var.vpc_id

  # SSH
  dynamic "ingress" {
    for_each = local.current_rules.allow_ssh_from_anywhere ? [1] : []
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  # SSH from VPC only (more secure)
  dynamic "ingress" {
    for_each = local.current_rules.allow_ssh_from_anywhere ? [] : [1]
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [var.vpc_id]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.environment}-ssh-sg"
    Type = "Security Group"
    Tier = "SSH"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Database Security Group
resource "aws_security_group" "database" {
  name_prefix = "${var.environment}-database-"
  vpc_id      = var.vpc_id

  # PostgreSQL
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  # MySQL
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  # Redis
  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.environment}-database-sg"
    Type = "Security Group"
    Tier = "Database"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Load Balancer Security Group
resource "aws_security_group" "load_balancer" {
  name_prefix = "${var.environment}-lb-"
  vpc_id      = var.vpc_id

  # HTTP
  dynamic "ingress" {
    for_each = local.current_rules.allow_http_from_anywhere ? [1] : []
    content {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  # HTTPS
  dynamic "ingress" {
    for_each = local.current_rules.allow_https_from_anywhere ? [1] : []
    content {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.environment}-lb-sg"
    Type = "Security Group"
    Tier = "Load Balancer"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Monitoring Security Group
resource "aws_security_group" "monitoring" {
  name_prefix = "${var.environment}-monitoring-"
  vpc_id      = var.vpc_id

  # Prometheus
  ingress {
    from_port       = 9090
    to_port         = 9090
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  # Grafana
  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  # Node Exporter
  ingress {
    from_port       = 9100
    to_port         = 9100
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.environment}-monitoring-sg"
    Type = "Security Group"
    Tier = "Monitoring"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# OS-specific Security Groups
resource "aws_security_group" "linux" {
  name_prefix = "${var.environment}-linux-"
  vpc_id      = var.vpc_id

  # SSH
  dynamic "ingress" {
    for_each = local.current_rules.allow_ssh_from_anywhere ? [1] : []
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  # Custom ports for Linux
  dynamic "ingress" {
    for_each = local.current_rules.allow_custom_ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.environment}-linux-sg"
    Type = "Security Group"
    OS   = "Linux"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "windows" {
  name_prefix = "${var.environment}-windows-"
  vpc_id      = var.vpc_id

  # RDP
  dynamic "ingress" {
    for_each = local.current_rules.allow_ssh_from_anywhere ? [1] : []
    content {
      from_port   = 3389
      to_port     = 3389
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  # WinRM
  dynamic "ingress" {
    for_each = local.current_rules.allow_ssh_from_anywhere ? [1] : []
    content {
      from_port   = 5985
      to_port     = 5986
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  # Custom ports for Windows
  dynamic "ingress" {
    for_each = local.current_rules.allow_custom_ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.environment}-windows-sg"
    Type = "Security Group"
    OS   = "Windows"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "macos" {
  name_prefix = "${var.environment}-macos-"
  vpc_id      = var.vpc_id

  # SSH
  dynamic "ingress" {
    for_each = local.current_rules.allow_ssh_from_anywhere ? [1] : []
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  # Custom ports for macOS
  dynamic "ingress" {
    for_each = local.current_rules.allow_custom_ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.environment}-macos-sg"
    Type = "Security Group"
    OS   = "macOS"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Outputs
output "security_group_ids" {
  description = "Map of security group IDs"
  value = {
    web        = aws_security_group.web.id
    ssh        = aws_security_group.ssh.id
    database   = aws_security_group.database.id
    load_balancer = aws_security_group.load_balancer.id
    monitoring = aws_security_group.monitoring.id
    linux      = aws_security_group.linux.id
    windows    = aws_security_group.windows.id
    macos      = aws_security_group.macos.id
  }
}

output "database_security_group_ids" {
  description = "Database security group IDs"
  value       = [aws_security_group.database.id]
}

output "load_balancer_security_group_ids" {
  description = "Load balancer security group IDs"
  value       = [aws_security_group.load_balancer.id]
}

output "web_security_group_id" {
  description = "Web security group ID"
  value       = aws_security_group.web.id
}

output "ssh_security_group_id" {
  description = "SSH security group ID"
  value       = aws_security_group.ssh.id
}
