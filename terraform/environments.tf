# Multi-Environment Terraform Configuration for VaultSwap DEX
# Supports Testing, Staging, and Production environments
# Cross-platform support for Linux, Windows, and macOS

terraform {
  required_version = ">= 1.0"
  required_providers {
    # Cloud providers
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    azure = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
    
    # Local providers
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    
    # OS-specific providers
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

# Environment Configuration
variable "environment" {
  description = "Environment name (testing, staging, production)"
  type        = string
  default     = "testing"
  validation {
    condition     = contains(["testing", "staging", "production"], var.environment)
    error_message = "Environment must be one of: testing, staging, production."
  }
}

variable "cloud_provider" {
  description = "Cloud provider (aws, azure, gcp, local)"
  type        = string
  default     = "aws"
  validation {
    condition     = contains(["aws", "azure", "gcp", "local"], var.cloud_provider)
    error_message = "Cloud provider must be one of: aws, azure, gcp, local."
  }
}

variable "operating_systems" {
  description = "Supported operating systems"
  type        = list(string)
  default     = ["linux", "windows", "macos"]
}

variable "region" {
  description = "Cloud region"
  type        = string
  default     = "us-west-2"
}

# Environment-specific configurations
locals {
  environment_config = {
    testing = {
      instance_count     = 2
      instance_type     = "t3.medium"
      storage_size      = 50
      backup_retention  = 7
      monitoring_level  = "basic"
      security_level   = "standard"
      cost_optimization = true
    }
    staging = {
      instance_count     = 3
      instance_type     = "t3.large"
      storage_size      = 100
      backup_retention  = 14
      monitoring_level  = "enhanced"
      security_level   = "high"
      cost_optimization = false
    }
    production = {
      instance_count     = 5
      instance_type     = "t3.xlarge"
      storage_size      = 500
      backup_retention  = 30
      monitoring_level  = "comprehensive"
      security_level   = "maximum"
      cost_optimization = false
    }
  }
  
  current_config = local.environment_config[var.environment]
  
  # OS-specific configurations
  os_config = {
    linux = {
      ami_id        = "ami-0c02fb55956c7d316"  # Amazon Linux 2
      user_data     = "linux_user_data.sh"
      security_groups = ["linux-sg"]
    }
    windows = {
      ami_id        = "ami-0c02fb55956c7d316"  # Windows Server 2019
      user_data     = "windows_user_data.ps1"
      security_groups = ["windows-sg"]
    }
    macos = {
      ami_id        = "ami-0c02fb55956c7d316"  # macOS (if available)
      user_data     = "macos_user_data.sh"
      security_groups = ["macos-sg"]
    }
  }
  
  # Common tags
  common_tags = {
    Environment   = var.environment
    Project       = "VaultSwap-DEX"
    ManagedBy     = "Terraform"
    CostCenter    = "Engineering"
    Owner         = "DevOps Team"
    Backup        = "Required"
    Monitoring    = local.current_config.monitoring_level
    Security      = local.current_config.security_level
  }
}

# Data sources
data "aws_availability_zones" "available" {
  count = var.cloud_provider == "aws" ? 1 : 0
  state = "available"
}

data "aws_caller_identity" "current" {
  count = var.cloud_provider == "aws" ? 1 : 0
}

# VPC Configuration
module "vpc" {
  count  = var.cloud_provider == "aws" ? 1 : 0
  source = "./modules/vpc"
  
  environment           = var.environment
  vpc_cidr            = "10.0.0.0/16"
  availability_zones  = slice(data.aws_availability_zones.available[0].names, 0, 2)
  public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24"]
  
  tags = local.common_tags
}

# Security Groups
module "security_groups" {
  count  = var.cloud_provider == "aws" ? 1 : 0
  source = "./modules/security-groups"
  
  environment = var.environment
  vpc_id      = module.vpc[0].vpc_id
  
  # Environment-specific security rules
  security_rules = {
    testing = {
      allow_ssh_from_anywhere = true
      allow_http_from_anywhere = true
      allow_https_from_anywhere = true
      allow_custom_ports = [8080, 9090, 3000]
    }
    staging = {
      allow_ssh_from_anywhere = false
      allow_http_from_anywhere = true
      allow_https_from_anywhere = true
      allow_custom_ports = [8080, 9090, 3000]
    }
    production = {
      allow_ssh_from_anywhere = false
      allow_http_from_anywhere = false
      allow_https_from_anywhere = true
      allow_custom_ports = [443, 8080]
    }
  }
  
  tags = local.common_tags
}

# EC2 Instances for each OS
module "ec2_instances" {
  count  = var.cloud_provider == "aws" ? 1 : 0
  source = "./modules/ec2-instances"
  
  environment = var.environment
  vpc_id      = module.vpc[0].vpc_id
  subnet_ids  = module.vpc[0].private_subnet_ids
  
  # Instance configuration
  instance_count = local.current_config.instance_count
  instance_type = local.current_config.instance_type
  
  # OS-specific configurations
  operating_systems = var.operating_systems
  
  # Security
  security_group_ids = module.security_groups[0].security_group_ids
  
  # Storage
  storage_size = local.current_config.storage_size
  
  tags = local.common_tags
}

# RDS Database
module "rds" {
  count  = var.cloud_provider == "aws" ? 1 : 0
  source = "./modules/rds"
  
  environment = var.environment
  vpc_id      = module.vpc[0].vpc_id
  subnet_ids  = module.vpc[0].private_subnet_ids
  
  # Database configuration
  instance_class = local.current_config.instance_type
  allocated_storage = local.current_config.storage_size
  backup_retention_period = local.current_config.backup_retention
  
  # Security
  security_group_ids = module.security_groups[0].database_security_group_ids
  
  tags = local.common_tags
}

# Load Balancer
module "load_balancer" {
  count  = var.cloud_provider == "aws" ? 1 : 0
  source = "./modules/load-balancer"
  
  environment = var.environment
  vpc_id      = module.vpc[0].vpc_id
  subnet_ids  = module.vpc[0].public_subnet_ids
  
  # Target configuration
  target_instances = module.ec2_instances[0].instance_ids
  
  # Security
  security_group_ids = module.security_groups[0].load_balancer_security_group_ids
  
  tags = local.common_tags
}

# Monitoring and Logging
module "monitoring" {
  count  = var.cloud_provider == "aws" ? 1 : 0
  source = "./modules/monitoring"
  
  environment = var.environment
  vpc_id      = module.vpc[0].vpc_id
  
  # Monitoring configuration
  monitoring_level = local.current_config.monitoring_level
  
  # Targets
  ec2_instances = module.ec2_instances[0].instance_ids
  rds_instances = module.rds[0].instance_ids
  
  tags = local.common_tags
}

# Backup Configuration
module "backup" {
  count  = var.cloud_provider == "aws" ? 1 : 0
  source = "./modules/backup"
  
  environment = var.environment
  
  # Backup configuration
  backup_retention_days = local.current_config.backup_retention
  
  # Resources to backup
  ec2_instances = module.ec2_instances[0].instance_ids
  rds_instances = module.rds[0].instance_ids
  
  tags = local.common_tags
}

# Security Configuration
module "security" {
  count  = var.cloud_provider == "aws" ? 1 : 0
  source = "./modules/security"
  
  environment = var.environment
  vpc_id      = module.vpc[0].vpc_id
  
  # Security configuration
  security_level = local.current_config.security_level
  
  # Resources to secure
  ec2_instances = module.ec2_instances[0].instance_ids
  rds_instances = module.rds[0].instance_ids
  
  tags = local.common_tags
}

# Cost Optimization
module "cost_optimization" {
  count  = var.cloud_provider == "aws" && local.current_config.cost_optimization ? 1 : 0
  source = "./modules/cost-optimization"
  
  environment = var.environment
  
  # Cost optimization configuration
  enable_spot_instances = true
  enable_auto_scaling = true
  enable_scheduled_shutdown = true
  
  # Resources to optimize
  ec2_instances = module.ec2_instances[0].instance_ids
  
  tags = local.common_tags
}

# Outputs
output "environment_info" {
  description = "Environment information"
  value = {
    environment = var.environment
    cloud_provider = var.cloud_provider
    region = var.region
    operating_systems = var.operating_systems
    instance_count = local.current_config.instance_count
    instance_type = local.current_config.instance_type
    storage_size = local.current_config.storage_size
    backup_retention = local.current_config.backup_retention
    monitoring_level = local.current_config.monitoring_level
    security_level = local.current_config.security_level
    cost_optimization = local.current_config.cost_optimization
  }
}

output "infrastructure_endpoints" {
  description = "Infrastructure endpoints"
  value = var.cloud_provider == "aws" ? {
    load_balancer_dns = module.load_balancer[0].dns_name
    load_balancer_zone_id = module.load_balancer[0].zone_id
    rds_endpoint = module.rds[0].endpoint
    rds_port = module.rds[0].port
    monitoring_dashboard = module.monitoring[0].dashboard_url
    backup_vault = module.backup[0].vault_name
  } : null
}

output "security_info" {
  description = "Security information"
  value = var.cloud_provider == "aws" ? {
    security_groups = module.security_groups[0].security_group_ids
    encryption_enabled = module.security[0].encryption_enabled
    backup_encryption = module.backup[0].encryption_enabled
    monitoring_enabled = module.monitoring[0].monitoring_enabled
  } : null
}

output "deployment_instructions" {
  description = "Deployment instructions"
  value = <<-EOF
    Deployment Instructions for ${var.environment} environment:
    
    1. Initialize Terraform:
       terraform init
    
    2. Plan the deployment:
       terraform plan -var="environment=${var.environment}" -var="cloud_provider=${var.cloud_provider}"
    
    3. Apply the configuration:
       terraform apply -var="environment=${var.environment}" -var="cloud_provider=${var.cloud_provider}"
    
    4. Verify deployment:
       terraform output
    
    5. Access the environment:
       - Load Balancer: ${var.cloud_provider == "aws" ? module.load_balancer[0].dns_name : "N/A"}
       - Database: ${var.cloud_provider == "aws" ? module.rds[0].endpoint : "N/A"}
       - Monitoring: ${var.cloud_provider == "aws" ? module.monitoring[0].dashboard_url : "N/A"}
    
    6. Clean up (when done):
       terraform destroy -var="environment=${var.environment}" -var="cloud_provider=${var.cloud_provider}"
  EOF
}
