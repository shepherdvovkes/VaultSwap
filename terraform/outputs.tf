# Outputs for VaultSwap DEX Infrastructure
# Provides comprehensive information about deployed resources

# Environment Information
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

# Infrastructure Endpoints
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

# Security Information
output "security_info" {
  description = "Security information"
  value = var.cloud_provider == "aws" ? {
    security_groups = module.security_groups[0].security_group_ids
    encryption_enabled = module.security[0].encryption_enabled
    backup_encryption = module.backup[0].encryption_enabled
    monitoring_enabled = module.monitoring[0].monitoring_enabled
    kms_key_id = module.security[0].kms_key_id
    kms_key_arn = module.security[0].kms_key_arn
  } : null
}

# Network Information
output "network_info" {
  description = "Network information"
  value = var.cloud_provider == "aws" ? {
    vpc_id = module.vpc[0].vpc_id
    vpc_cidr_block = module.vpc[0].vpc_cidr_block
    public_subnet_ids = module.vpc[0].public_subnet_ids
    private_subnet_ids = module.vpc[0].private_subnet_ids
    internet_gateway_id = module.vpc[0].internet_gateway_id
    nat_gateway_ids = module.vpc[0].nat_gateway_ids
  } : null
}

# Instance Information
output "instance_info" {
  description = "Instance information"
  value = var.cloud_provider == "aws" ? {
    instance_ids = module.ec2_instances[0].instance_ids
    linux_instance_ids = module.ec2_instances[0].linux_instance_ids
    windows_instance_ids = module.ec2_instances[0].windows_instance_ids
    macos_instance_ids = module.ec2_instances[0].macos_instance_ids
    instance_ips = module.ec2_instances[0].instance_ips
    key_pair_name = module.ec2_instances[0].key_pair_name
  } : null
}

# Database Information
output "database_info" {
  description = "Database information"
  value = var.cloud_provider == "aws" ? {
    postgresql_endpoint = module.rds[0].postgresql_endpoint
    mysql_endpoint = module.rds[0].mysql_endpoint
    postgresql_port = module.rds[0].postgresql_port
    mysql_port = module.rds[0].mysql_port
    database_name = module.rds[0].database_name
    database_username = module.rds[0].database_username
  } : null
}

# Load Balancer Information
output "load_balancer_info" {
  description = "Load balancer information"
  value = var.cloud_provider == "aws" ? {
    load_balancer_arn = module.load_balancer[0].load_balancer_arn
    dns_name = module.load_balancer[0].dns_name
    zone_id = module.load_balancer[0].zone_id
    target_group_arns = module.load_balancer[0].target_group_arns
    ssl_certificate_arn = module.load_balancer[0].ssl_certificate_arn
  } : null
}

# Monitoring Information
output "monitoring_info" {
  description = "Monitoring information"
  value = var.cloud_provider == "aws" ? {
    monitoring_enabled = module.monitoring[0].monitoring_enabled
    dashboard_url = module.monitoring[0].dashboard_url
    log_groups = module.monitoring[0].log_groups
    alarms = module.monitoring[0].alarms
    sns_topic_arn = module.monitoring[0].sns_topic_arn
    grafana_url = module.monitoring[0].grafana_url
  } : null
}

# Backup Information
output "backup_info" {
  description = "Backup information"
  value = var.cloud_provider == "aws" ? {
    vault_name = module.backup[0].vault_name
    backup_plan_id = module.backup[0].backup_plan_id
    kms_key_id = module.backup[0].kms_key_id
    s3_bucket_name = module.backup[0].s3_bucket_name
    encryption_enabled = module.backup[0].encryption_enabled
    backup_retention_days = module.backup[0].backup_retention_days
  } : null
}

# Cost Optimization Information
output "cost_optimization_info" {
  description = "Cost optimization information"
  value = var.cloud_provider == "aws" && local.current_config.cost_optimization ? {
    spot_instance_ids = module.cost_optimization[0].spot_instance_ids
    autoscaling_group_name = module.cost_optimization[0].autoscaling_group_name
    cost_report_bucket = module.cost_optimization[0].cost_report_bucket
    budget_name = module.cost_optimization[0].budget_name
    optimization_enabled = module.cost_optimization[0].optimization_enabled
  } : null
}

# Connection Information
output "connection_info" {
  description = "Connection information for accessing the infrastructure"
  value = var.cloud_provider == "aws" ? {
    ssh_connection = "ssh -i ${module.ec2_instances[0].key_pair_name}.pem ec2-user@${module.load_balancer[0].dns_name}"
    rds_connection = "postgresql://${module.rds[0].database_username}:<password>@${module.rds[0].postgresql_endpoint}:${module.rds[0].postgresql_port}/${module.rds[0].database_name}"
    monitoring_url = module.monitoring[0].dashboard_url
    grafana_url = module.monitoring[0].grafana_url
  } : null
}

# Deployment Instructions
output "deployment_instructions" {
  description = "Instructions for deploying and managing the infrastructure"
  value = <<-EOF
    VaultSwap DEX Infrastructure Deployment Instructions
    
    Environment: ${var.environment}
    Cloud Provider: ${var.cloud_provider}
    Region: ${var.region}
    
    ## Deployment Steps:
    
    1. Initialize Terraform:
       terraform init
    
    2. Plan the deployment:
       terraform plan -var="environment=${var.environment}" -var="cloud_provider=${var.cloud_provider}"
    
    3. Apply the configuration:
       terraform apply -var="environment=${var.environment}" -var="cloud_provider=${var.cloud_provider}"
    
    4. Verify deployment:
       terraform output
    
    ## Access Information:
    
    - Load Balancer: ${var.cloud_provider == "aws" ? module.load_balancer[0].dns_name : "N/A"}
    - Database: ${var.cloud_provider == "aws" ? module.rds[0].postgresql_endpoint : "N/A"}
    - Monitoring: ${var.cloud_provider == "aws" ? module.monitoring[0].dashboard_url : "N/A"}
    - Grafana: ${var.cloud_provider == "aws" ? module.monitoring[0].grafana_url : "N/A"}
    
    ## Management Commands:
    
    - View resources: terraform show
    - Update resources: terraform apply
    - Destroy resources: terraform destroy
    
    ## Security Notes:
    
    - All resources are encrypted with KMS
    - Security groups are configured per environment
    - Monitoring and logging are enabled
    - Backup and disaster recovery are configured
    
    ## Cost Optimization:
    
    - Spot instances: ${local.current_config.cost_optimization ? "Enabled" : "Disabled"}
    - Auto scaling: ${local.current_config.cost_optimization ? "Enabled" : "Disabled"}
    - Scheduled shutdown: ${local.current_config.cost_optimization ? "Enabled" : "Disabled"}
    
    ## Support:
    
    For issues or questions, contact the DevOps team.
  EOF
}
