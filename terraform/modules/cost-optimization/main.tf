# Cost Optimization Module for Multi-Environment DEX Infrastructure
# Implements cost-saving measures and resource optimization

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

variable "enable_spot_instances" {
  description = "Enable spot instances for cost savings"
  type        = bool
  default     = true
}

variable "enable_auto_scaling" {
  description = "Enable auto scaling for cost optimization"
  type        = bool
  default     = true
}

variable "enable_scheduled_shutdown" {
  description = "Enable scheduled shutdown for non-production environments"
  type        = bool
  default     = true
}

variable "ec2_instances" {
  description = "List of EC2 instance IDs"
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

# Spot Instance Requests
resource "aws_spot_instance_request" "cost_optimized" {
  count = var.enable_spot_instances && var.environment != "production" ? length(var.ec2_instances) : 0

  ami           = "ami-0c02fb55956c7d316"  # Amazon Linux 2
  instance_type = "t3.medium"
  spot_price    = "0.05"  # Maximum price per hour

  vpc_security_group_ids = var.security_group_ids
  subnet_id              = var.subnet_ids[count.index % length(var.subnet_ids)]

  wait_for_fulfillment = true
  spot_type            = "one-time"

  tags = merge(var.tags, {
    Name = "${var.environment}-spot-instance-${count.index + 1}"
    Type = "Spot Instance"
  })
}

# Auto Scaling Group
resource "aws_launch_template" "cost_optimized" {
  count = var.enable_auto_scaling ? 1 : 0

  name_prefix   = "${var.environment}-cost-optimized-"
  image_id      = "ami-0c02fb55956c7d316"
  instance_type = "t3.medium"

  vpc_security_group_ids = var.security_group_ids

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name = "${var.environment}-asg-instance"
      Type = "Auto Scaling Instance"
    })
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "cost_optimized" {
  count = var.enable_auto_scaling ? 1 : 0

  name                = "${var.environment}-cost-optimized-asg"
  vpc_zone_identifier = var.subnet_ids
  target_group_arns   = var.target_group_arns
  health_check_type   = "ELB"
  health_check_grace_period = 300

  min_size         = var.environment == "production" ? 2 : 1
  max_size         = var.environment == "production" ? 10 : 3
  desired_capacity = var.environment == "production" ? 3 : 1

  launch_template {
    id      = aws_launch_template.cost_optimized[0].id
    version = "$Latest"
  }

  dynamic "tag" {
    for_each = var.tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Policies
resource "aws_autoscaling_policy" "scale_up" {
  count = var.enable_auto_scaling ? 1 : 0

  name                   = "${var.environment}-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown              = 300
  autoscaling_group_name = aws_autoscaling_group.cost_optimized[0].name
}

resource "aws_autoscaling_policy" "scale_down" {
  count = var.enable_auto_scaling ? 1 : 0

  name                   = "${var.environment}-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown              = 300
  autoscaling_group_name = aws_autoscaling_group.cost_optimized[0].name
}

# CloudWatch Alarms for Auto Scaling
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  count = var.enable_auto_scaling ? 1 : 0

  alarm_name          = "${var.environment}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "70"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = [aws_autoscaling_policy.scale_up[0].arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.cost_optimized[0].name
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  count = var.enable_auto_scaling ? 1 : 0

  alarm_name          = "${var.environment}-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "20"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = [aws_autoscaling_policy.scale_down[0].arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.cost_optimized[0].name
  }
}

# Scheduled Actions for Non-Production Environments
resource "aws_autoscaling_schedule" "scale_down_night" {
  count = var.enable_scheduled_shutdown && var.environment != "production" ? 1 : 0

  scheduled_action_name  = "${var.environment}-scale-down-night"
  min_size              = 0
  max_size              = 0
  desired_capacity      = 0
  recurrence            = "0 22 * * *"  # 10 PM UTC
  autoscaling_group_name = aws_autoscaling_group.cost_optimized[0].name
}

resource "aws_autoscaling_schedule" "scale_up_morning" {
  count = var.enable_scheduled_shutdown && var.environment != "production" ? 1 : 0

  scheduled_action_name  = "${var.environment}-scale-up-morning"
  min_size              = 1
  max_size              = 3
  desired_capacity      = 1
  recurrence            = "0 8 * * *"  # 8 AM UTC
  autoscaling_group_name = aws_autoscaling_group.cost_optimized[0].name
}

# Cost and Usage Reports
resource "aws_cur_report_definition" "cost_report" {
  report_name                = "${var.environment}-cost-report"
  time_unit                  = "DAILY"
  format                     = "textORcsv"
  compression                = "GZIP"
  additional_schema_elements = ["RESOURCES"]
  s3_bucket                  = aws_s3_bucket.cost_reports.bucket
  s3_prefix                  = "cost-reports"
  s3_region                  = data.aws_region.current.name
  additional_artifacts       = ["REDSHIFT", "QUICKSIGHT"]
  refresh_closed_reports     = true
  report_versioning          = "CREATE_NEW_REPORT"

  depends_on = [aws_s3_bucket_policy.cost_reports]
}

resource "aws_s3_bucket" "cost_reports" {
  bucket = "${var.environment}-cost-reports-${random_id.cost_reports_suffix.hex}"

  tags = merge(var.tags, {
    Name = "${var.environment}-cost-reports"
    Type = "S3 Bucket"
  })
}

resource "random_id" "cost_reports_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_policy" "cost_reports" {
  bucket = aws_s3_bucket.cost_reports.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSBucketPermissionsCheck"
        Effect = "Allow"
        Principal = {
          Service = "billingreports.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cost_reports.arn
      },
      {
        Sid    = "AWSBucketDelivery"
        Effect = "Allow"
        Principal = {
          Service = "billingreports.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cost_reports.arn}/*"
      }
    ]
  })
}

# Budget Alerts
resource "aws_budgets_budget" "cost_budget" {
  name         = "${var.environment}-cost-budget"
  budget_type  = "COST"
  limit_amount = var.environment == "production" ? "1000" : "100"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filters = {
    Tag = ["Environment:${var.environment}"]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.budget_email_addresses
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.budget_email_addresses
  }
}

# Reserved Instances (for production)
resource "aws_ec2_reserved_instances" "production" {
  count = var.environment == "production" ? 1 : 0

  instance_type     = "t3.medium"
  instance_count     = 2
  offering_type      = "All Upfront"
  reservation_type   = "Standard"
  term_length        = "1year"

  tags = merge(var.tags, {
    Name = "${var.environment}-reserved-instances"
    Type = "Reserved Instance"
  })
}

# Savings Plans
resource "aws_savingsplans_savings_plan" "compute" {
  count = var.environment == "production" ? 1 : 0

  commitment         = "1000"
  upfront_payment   = "1000"
  payment_option     = "All Upfront"
  term_length       = "1year"
  plan_type         = "Compute"
  currency          = "USD"

  tags = merge(var.tags, {
    Name = "${var.environment}-savings-plan"
    Type = "Savings Plan"
  })
}

# Cost Optimization Recommendations
resource "aws_ce_cost_category" "optimization" {
  name = "${var.environment}-cost-category"

  rule {
    value = "Production"
    rule {
      dimension {
        key  = "SERVICE"
        values = ["Amazon Elastic Compute Cloud - Compute"]
      }
    }
  }

  rule {
    value = "Development"
    rule {
      dimension {
        key  = "SERVICE"
        values = ["Amazon Elastic Compute Cloud - Compute"]
      }
    }
  }
}

# Outputs
output "spot_instance_ids" {
  description = "Spot instance IDs"
  value       = aws_spot_instance_request.cost_optimized[*].spot_instance_id
}

output "autoscaling_group_name" {
  description = "Auto scaling group name"
  value       = var.enable_auto_scaling ? aws_autoscaling_group.cost_optimized[0].name : null
}

output "cost_report_bucket" {
  description = "Cost report S3 bucket"
  value       = aws_s3_bucket.cost_reports.bucket
}

output "budget_name" {
  description = "Budget name"
  value       = aws_budgets_budget.cost_budget.name
}

output "reserved_instance_ids" {
  description = "Reserved instance IDs"
  value       = var.environment == "production" ? aws_ec2_reserved_instances.production[0].id : null
}

output "savings_plan_id" {
  description = "Savings plan ID"
  value       = var.environment == "production" ? aws_savingsplans_savings_plan.compute[0].id : null
}

output "cost_category_id" {
  description = "Cost category ID"
  value       = aws_ce_cost_category.optimization.id
}

output "optimization_enabled" {
  description = "Whether cost optimization is enabled"
  value = {
    spot_instances      = var.enable_spot_instances
    auto_scaling        = var.enable_auto_scaling
    scheduled_shutdown  = var.enable_scheduled_shutdown
  }
}
