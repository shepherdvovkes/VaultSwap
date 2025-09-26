# EC2 Instances Module for Multi-Environment DEX Infrastructure
# Supports Linux, Windows, and macOS instances

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
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

variable "instance_count" {
  description = "Number of instances to create"
  type        = number
  default     = 2
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "operating_systems" {
  description = "List of operating systems to support"
  type        = list(string)
  default     = ["linux", "windows", "macos"]
}

variable "security_group_ids" {
  description = "Map of security group IDs"
  type        = map(string)
}

variable "storage_size" {
  description = "Storage size in GB"
  type        = number
  default     = 50
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# Data sources
data "aws_region" "current" {}
data "aws_availability_zones" "available" {}

# AMI data sources for different operating systems
data "aws_ami" "linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_ami" "windows" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2019-English-Full-Base-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Key pair for SSH access
resource "tls_private_key" "main" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "main" {
  key_name   = "${var.environment}-key-pair"
  public_key = tls_private_key.main.public_key_openssh

  tags = merge(var.tags, {
    Name = "${var.environment}-key-pair"
    Type = "Key Pair"
  })
}

# User data scripts for different operating systems
locals {
  linux_user_data = base64encode(templatefile("${path.module}/user_data/linux.sh", {
    environment = var.environment
    region      = data.aws_region.current.name
  }))

  windows_user_data = base64encode(templatefile("${path.module}/user_data/windows.ps1", {
    environment = var.environment
    region      = data.aws_region.current.name
  }))

  macos_user_data = base64encode(templatefile("${path.module}/user_data/macos.sh", {
    environment = var.environment
    region      = data.aws_region.current.name
  }))
}

# Linux Instances
resource "aws_instance" "linux" {
  count = contains(var.operating_systems, "linux") ? var.instance_count : 0

  ami                    = data.aws_ami.linux.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_ids[count.index % length(var.subnet_ids)]
  vpc_security_group_ids = [
    var.security_group_ids["linux"],
    var.security_group_ids["ssh"],
    var.security_group_ids["web"]
  ]
  key_name = aws_key_pair.main.key_name

  user_data = local.linux_user_data

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.storage_size
    delete_on_termination = true
    encrypted             = true

    tags = merge(var.tags, {
      Name = "${var.environment}-linux-${count.index + 1}-root"
      Type = "EBS Volume"
      OS   = "Linux"
    })
  }

  tags = merge(var.tags, {
    Name = "${var.environment}-linux-${count.index + 1}"
    Type = "EC2 Instance"
    OS   = "Linux"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Windows Instances
resource "aws_instance" "windows" {
  count = contains(var.operating_systems, "windows") ? var.instance_count : 0

  ami                    = data.aws_ami.windows.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_ids[count.index % length(var.subnet_ids)]
  vpc_security_group_ids = [
    var.security_group_ids["windows"],
    var.security_group_ids["web"]
  ]
  key_name = aws_key_pair.main.key_name

  user_data = local.windows_user_data

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.storage_size
    delete_on_termination = true
    encrypted             = true

    tags = merge(var.tags, {
      Name = "${var.environment}-windows-${count.index + 1}-root"
      Type = "EBS Volume"
      OS   = "Windows"
    })
  }

  tags = merge(var.tags, {
    Name = "${var.environment}-windows-${count.index + 1}"
    Type = "EC2 Instance"
    OS   = "Windows"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# macOS Instances (Note: macOS instances are limited and expensive)
resource "aws_instance" "macos" {
  count = contains(var.operating_systems, "macos") ? var.instance_count : 0

  # Note: macOS AMIs are not publicly available and require special approval
  # This is a placeholder configuration
  ami                    = "ami-0c02fb55956c7d316"  # Placeholder - replace with actual macOS AMI
  instance_type          = var.instance_type
  subnet_id              = var.subnet_ids[count.index % length(var.subnet_ids)]
  vpc_security_group_ids = [
    var.security_group_ids["macos"],
    var.security_group_ids["ssh"],
    var.security_group_ids["web"]
  ]
  key_name = aws_key_pair.main.key_name

  user_data = local.macos_user_data

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.storage_size
    delete_on_termination = true
    encrypted             = true

    tags = merge(var.tags, {
      Name = "${var.environment}-macos-${count.index + 1}-root"
      Type = "EBS Volume"
      OS   = "macOS"
    })
  }

  tags = merge(var.tags, {
    Name = "${var.environment}-macos-${count.index + 1}"
    Type = "EC2 Instance"
    OS   = "macOS"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Elastic IPs for instances that need static IPs
resource "aws_eip" "linux" {
  count = contains(var.operating_systems, "linux") ? var.instance_count : 0

  instance = aws_instance.linux[count.index].id
  domain   = "vpc"

  tags = merge(var.tags, {
    Name = "${var.environment}-linux-${count.index + 1}-eip"
    Type = "Elastic IP"
    OS   = "Linux"
  })

  depends_on = [aws_instance.linux]
}

resource "aws_eip" "windows" {
  count = contains(var.operating_systems, "windows") ? var.instance_count : 0

  instance = aws_instance.windows[count.index].id
  domain   = "vpc"

  tags = merge(var.tags, {
    Name = "${var.environment}-windows-${count.index + 1}-eip"
    Type = "Elastic IP"
    OS   = "Windows"
  })

  depends_on = [aws_instance.windows]
}

resource "aws_eip" "macos" {
  count = contains(var.operating_systems, "macos") ? var.instance_count : 0

  instance = aws_instance.macos[count.index].id
  domain   = "vpc"

  tags = merge(var.tags, {
    Name = "${var.environment}-macos-${count.index + 1}-eip"
    Type = "Elastic IP"
    OS   = "macOS"
  })

  depends_on = [aws_instance.macos]
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "linux" {
  count = contains(var.operating_systems, "linux") ? 1 : 0

  name              = "/aws/ec2/${var.environment}-linux"
  retention_in_days = 30

  tags = merge(var.tags, {
    Name = "${var.environment}-linux-logs"
    Type = "CloudWatch Log Group"
    OS   = "Linux"
  })
}

resource "aws_cloudwatch_log_group" "windows" {
  count = contains(var.operating_systems, "windows") ? 1 : 0

  name              = "/aws/ec2/${var.environment}-windows"
  retention_in_days = 30

  tags = merge(var.tags, {
    Name = "${var.environment}-windows-logs"
    Type = "CloudWatch Log Group"
    OS   = "Windows"
  })
}

resource "aws_cloudwatch_log_group" "macos" {
  count = contains(var.operating_systems, "macos") ? 1 : 0

  name              = "/aws/ec2/${var.environment}-macos"
  retention_in_days = 30

  tags = merge(var.tags, {
    Name = "${var.environment}-macos-logs"
    Type = "CloudWatch Log Group"
    OS   = "macOS"
  })
}

# Outputs
output "instance_ids" {
  description = "List of all instance IDs"
  value = concat(
    aws_instance.linux[*].id,
    aws_instance.windows[*].id,
    aws_instance.macos[*].id
  )
}

output "linux_instance_ids" {
  description = "Linux instance IDs"
  value       = aws_instance.linux[*].id
}

output "windows_instance_ids" {
  description = "Windows instance IDs"
  value       = aws_instance.windows[*].id
}

output "macos_instance_ids" {
  description = "macOS instance IDs"
  value       = aws_instance.macos[*].id
}

output "instance_ips" {
  description = "Map of instance IPs by OS"
  value = {
    linux = {
      private_ips = aws_instance.linux[*].private_ip
      public_ips  = aws_eip.linux[*].public_ip
    }
    windows = {
      private_ips = aws_instance.windows[*].private_ip
      public_ips  = aws_eip.windows[*].public_ip
    }
    macos = {
      private_ips = aws_instance.macos[*].private_ip
      public_ips  = aws_eip.macos[*].public_ip
    }
  }
}

output "key_pair_name" {
  description = "Key pair name"
  value       = aws_key_pair.main.key_name
}

output "private_key" {
  description = "Private key for SSH access"
  value       = tls_private_key.main.private_key_pem
  sensitive   = true
}

output "public_key" {
  description = "Public key for SSH access"
  value       = tls_private_key.main.public_key_openssh
}

output "log_groups" {
  description = "CloudWatch log groups"
  value = {
    linux   = aws_cloudwatch_log_group.linux[*].name
    windows = aws_cloudwatch_log_group.windows[*].name
    macos   = aws_cloudwatch_log_group.macos[*].name
  }
}
