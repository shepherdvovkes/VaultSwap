#!/bin/bash
# VaultSwap DEX Infrastructure Troubleshooting Script
# Diagnoses and resolves common deployment issues

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT="testing"
CLOUD_PROVIDER="aws"
REGION="us-west-2"
VERBOSE=false
FIX_ISSUES=false

# Help function
show_help() {
    cat << EOF
VaultSwap DEX Infrastructure Troubleshooting Script

USAGE:
    $0 [OPTIONS] ENVIRONMENT CLOUD_PROVIDER

ARGUMENTS:
    ENVIRONMENT      Environment to troubleshoot (testing, staging, production)
    CLOUD_PROVIDER   Cloud provider to check (aws, gcp, local)

OPTIONS:
    -h, --help              Show this help message
    -r, --region REGION     Cloud region (default: us-west-2)
    -v, --verbose           Enable verbose output
    -f, --fix               Attempt to fix issues automatically
    --check-permissions     Check cloud provider permissions
    --check-resources       Check resource availability
    --check-connectivity    Check network connectivity
    --check-costs          Check cost and billing
    --check-security        Check security configuration

EXAMPLES:
    $0 testing aws
    $0 staging gcp --fix
    $0 production aws --check-security
    $0 testing local --verbose

EOF
}

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Parse command line arguments
CHECK_PERMISSIONS=false
CHECK_RESOURCES=false
CHECK_CONNECTIVITY=false
CHECK_COSTS=false
CHECK_SECURITY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -r|--region)
            REGION="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -f|--fix)
            FIX_ISSUES=true
            shift
            ;;
        --check-permissions)
            CHECK_PERMISSIONS=true
            shift
            ;;
        --check-resources)
            CHECK_RESOURCES=true
            shift
            ;;
        --check-connectivity)
            CHECK_CONNECTIVITY=true
            shift
            ;;
        --check-costs)
            CHECK_COSTS=true
            shift
            ;;
        --check-security)
            CHECK_SECURITY=true
            shift
            ;;
        testing|staging|production)
            ENVIRONMENT="$1"
            shift
            ;;
        aws|gcp|local)
            CLOUD_PROVIDER="$1"
            shift
            ;;
        *)
            error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate arguments
if [[ -z "${ENVIRONMENT:-}" ]]; then
    error "Environment is required"
    show_help
    exit 1
fi

if [[ -z "${CLOUD_PROVIDER:-}" ]]; then
    error "Cloud provider is required"
    show_help
    exit 1
fi

# Enable verbose mode
if [[ "$VERBOSE" == "true" ]]; then
    set -x
fi

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if terraform is installed
    if ! command -v terraform &> /dev/null; then
        error "Terraform is not installed"
        error "Please install Terraform >= 1.0"
        exit 1
    fi
    
    # Check cloud provider specific prerequisites
    case $CLOUD_PROVIDER in
        aws)
            if ! command -v aws &> /dev/null; then
                error "AWS CLI is not installed"
                exit 1
            fi
            
            if ! aws sts get-caller-identity &> /dev/null; then
                error "AWS credentials not configured"
                error "Please run 'aws configure' or set AWS environment variables"
                exit 1
            fi
            ;;
        gcp)
            if ! command -v gcloud &> /dev/null; then
                error "Google Cloud CLI is not installed"
                exit 1
            fi
            
            if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
                error "GCP authentication required"
                error "Please run 'gcloud auth login' and 'gcloud auth application-default login'"
                exit 1
            fi
            ;;
        local)
            if ! command -v docker &> /dev/null; then
                error "Docker is not installed"
                exit 1
            fi
            
            if ! docker info &> /dev/null; then
                error "Docker daemon is not running"
                error "Please start Docker daemon"
                exit 1
            fi
            ;;
    esac
    
    log "Prerequisites check passed"
}

# Check permissions
check_permissions() {
    log "Checking permissions..."
    
    case $CLOUD_PROVIDER in
        aws)
            info "Checking AWS permissions..."
            
            # Check IAM permissions
            if ! aws iam get-user &> /dev/null; then
                error "Insufficient IAM permissions"
                warning "Please ensure your user has the necessary IAM permissions"
                if [[ "$FIX_ISSUES" == "true" ]]; then
                    info "Attempting to attach AdministratorAccess policy..."
                    aws iam attach-user-policy --user-name $(aws sts get-caller-identity --query User.UserName --output text) --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
                fi
            fi
            
            # Check service quotas
            info "Checking service quotas..."
            QUOTA_CHECK=$(aws service-quotas get-service-quota --service-code ec2 --quota-code L-34B43A08 --query 'Quota.Value' --output text 2>/dev/null || echo "0")
            if [[ "$QUOTA_CHECK" -lt 20 ]]; then
                warning "EC2 instance quota is low: $QUOTA_CHECK"
                if [[ "$FIX_ISSUES" == "true" ]]; then
                    info "Requesting quota increase..."
                    aws service-quotas request-service-quota-increase --service-code ec2 --quota-code L-34B43A08 --desired-value 20
                fi
            fi
            ;;
        gcp)
            info "Checking GCP permissions..."
            
            # Check project permissions
            if ! gcloud projects describe $(gcloud config get-value project) &> /dev/null; then
                error "Insufficient GCP project permissions"
                warning "Please ensure you have the necessary project permissions"
            fi
            
            # Check API enablement
            info "Checking required APIs..."
            REQUIRED_APIS=("compute.googleapis.com" "sqladmin.googleapis.com" "monitoring.googleapis.com")
            for api in "${REQUIRED_APIS[@]}"; do
                if ! gcloud services list --enabled --filter="name:$api" --format="value(name)" | grep -q "$api"; then
                    warning "API $api is not enabled"
                    if [[ "$FIX_ISSUES" == "true" ]]; then
                        info "Enabling API $api..."
                        gcloud services enable "$api"
                    fi
                fi
            done
            ;;
        local)
            info "Checking local permissions..."
            
            # Check Docker permissions
            if ! docker ps &> /dev/null; then
                error "Insufficient Docker permissions"
                warning "Please ensure your user is in the docker group"
                if [[ "$FIX_ISSUES" == "true" ]]; then
                    info "Adding user to docker group..."
                    sudo usermod -aG docker $USER
                    warning "Please log out and log back in for changes to take effect"
                fi
            fi
            ;;
    esac
    
    log "Permissions check completed"
}

# Check resources
check_resources() {
    log "Checking resources..."
    
    case $CLOUD_PROVIDER in
        aws)
            info "Checking AWS resources..."
            
            # Check VPC limits
            VPC_COUNT=$(aws ec2 describe-vpcs --query 'length(Vpcs)' --output text)
            if [[ "$VPC_COUNT" -gt 5 ]]; then
                warning "VPC count is high: $VPC_COUNT"
                if [[ "$FIX_ISSUES" == "true" ]]; then
                    info "Listing unused VPCs..."
                    aws ec2 describe-vpcs --query 'Vpcs[?IsDefault==`false`].[VpcId,Tags[?Key==`Name`].Value|[0]]' --output table
                fi
            fi
            
            # Check RDS instances
            RDS_COUNT=$(aws rds describe-db-instances --query 'length(DBInstances)' --output text)
            if [[ "$RDS_COUNT" -gt 10 ]]; then
                warning "RDS instance count is high: $RDS_COUNT"
            fi
            ;;
        gcp)
            info "Checking GCP resources..."
            
            # Check compute instances
            INSTANCE_COUNT=$(gcloud compute instances list --format="value(name)" | wc -l)
            if [[ "$INSTANCE_COUNT" -gt 20 ]]; then
                warning "Compute instance count is high: $INSTANCE_COUNT"
            fi
            
            # Check Cloud SQL instances
            SQL_COUNT=$(gcloud sql instances list --format="value(name)" | wc -l)
            if [[ "$SQL_COUNT" -gt 10 ]]; then
                warning "Cloud SQL instance count is high: $SQL_COUNT"
            fi
            ;;
        local)
            info "Checking local resources..."
            
            # Check Docker resources
            CONTAINER_COUNT=$(docker ps -a --format="table {{.Names}}" | wc -l)
            if [[ "$CONTAINER_COUNT" -gt 20 ]]; then
                warning "Docker container count is high: $CONTAINER_COUNT"
                if [[ "$FIX_ISSUES" == "true" ]]; then
                    info "Cleaning up stopped containers..."
                    docker container prune -f
                fi
            fi
            
            # Check disk space
            DISK_USAGE=$(df -h / | awk 'NR==2{print $5}' | sed 's/%//')
            if [[ "$DISK_USAGE" -gt 80 ]]; then
                warning "Disk usage is high: ${DISK_USAGE}%"
                if [[ "$FIX_ISSUES" == "true" ]]; then
                    info "Cleaning up Docker resources..."
                    docker system prune -a -f
                fi
            fi
            ;;
    esac
    
    log "Resources check completed"
}

# Check connectivity
check_connectivity() {
    log "Checking connectivity..."
    
    case $CLOUD_PROVIDER in
        aws)
            info "Checking AWS connectivity..."
            
            # Check internet connectivity
            if ! ping -c 1 8.8.8.8 &> /dev/null; then
                error "No internet connectivity"
                return 1
            fi
            
            # Check AWS service connectivity
            if ! aws sts get-caller-identity &> /dev/null; then
                error "Cannot connect to AWS services"
                return 1
            fi
            ;;
        gcp)
            info "Checking GCP connectivity..."
            
            # Check internet connectivity
            if ! ping -c 1 8.8.8.8 &> /dev/null; then
                error "No internet connectivity"
                return 1
            fi
            
            # Check GCP service connectivity
            if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
                error "Cannot connect to GCP services"
                return 1
            fi
            ;;
        local)
            info "Checking local connectivity..."
            
            # Check Docker daemon
            if ! docker info &> /dev/null; then
                error "Cannot connect to Docker daemon"
                return 1
            fi
            
            # Check port availability
            PORTS=(80 443 8080 5432 6379 9090 3000)
            for port in "${PORTS[@]}"; do
                if netstat -tulpn | grep -q ":$port "; then
                    warning "Port $port is already in use"
                    if [[ "$FIX_ISSUES" == "true" ]]; then
                        info "Attempting to free port $port..."
                        sudo fuser -k $port/tcp 2>/dev/null || true
                    fi
                fi
            done
            ;;
    esac
    
    log "Connectivity check completed"
}

# Check costs
check_costs() {
    log "Checking costs..."
    
    case $CLOUD_PROVIDER in
        aws)
            info "Checking AWS costs..."
            
            # Check for expensive resources
            EXPENSIVE_INSTANCES=$(aws ec2 describe-instances --query 'Reservations[].Instances[?InstanceType!=`t3.micro`].[InstanceId,InstanceType]' --output table)
            if [[ -n "$EXPENSIVE_INSTANCES" ]]; then
                warning "Found expensive instances:"
                echo "$EXPENSIVE_INSTANCES"
            fi
            
            # Check for unused resources
            UNUSED_EBS=$(aws ec2 describe-volumes --query 'Volumes[?State==`available`].[VolumeId,Size]' --output table)
            if [[ -n "$UNUSED_EBS" ]]; then
                warning "Found unused EBS volumes:"
                echo "$UNUSED_EBS"
                if [[ "$FIX_ISSUES" == "true" ]]; then
                    info "Deleting unused EBS volumes..."
                    aws ec2 describe-volumes --query 'Volumes[?State==`available`].VolumeId' --output text | xargs -I {} aws ec2 delete-volume --volume-id {}
                fi
            fi
            ;;
        gcp)
            info "Checking GCP costs..."
            
            # Check for expensive instances
            EXPENSIVE_INSTANCES=$(gcloud compute instances list --filter="machineType!=e2-micro" --format="table(name,machineType)" 2>/dev/null || true)
            if [[ -n "$EXPENSIVE_INSTANCES" ]]; then
                warning "Found expensive instances:"
                echo "$EXPENSIVE_INSTANCES"
            fi
            
            # Check for unused disks
            UNUSED_DISKS=$(gcloud compute disks list --filter="status=READY" --format="table(name,sizeGb)" 2>/dev/null || true)
            if [[ -n "$UNUSED_DISKS" ]]; then
                warning "Found unused disks:"
                echo "$UNUSED_DISKS"
            fi
            ;;
        local)
            info "Checking local costs..."
            
            # Check Docker resource usage
            DOCKER_SIZE=$(docker system df --format "table {{.Type}}\t{{.Size}}" 2>/dev/null || true)
            if [[ -n "$DOCKER_SIZE" ]]; then
                info "Docker resource usage:"
                echo "$DOCKER_SIZE"
            fi
            ;;
    esac
    
    log "Costs check completed"
}

# Check security
check_security() {
    log "Checking security..."
    
    case $CLOUD_PROVIDER in
        aws)
            info "Checking AWS security..."
            
            # Check for open security groups
            OPEN_SG=$(aws ec2 describe-security-groups --query 'SecurityGroups[?IpPermissions[?IpRanges[?CidrIp==`0.0.0.0/0`]]].[GroupName,GroupId]' --output table)
            if [[ -n "$OPEN_SG" ]]; then
                warning "Found open security groups:"
                echo "$OPEN_SG"
            fi
            
            # Check for unencrypted RDS instances
            UNENCRYPTED_RDS=$(aws rds describe-db-instances --query 'DBInstances[?StorageEncrypted==`false`].[DBInstanceIdentifier,DBInstanceClass]' --output table)
            if [[ -n "$UNENCRYPTED_RDS" ]]; then
                warning "Found unencrypted RDS instances:"
                echo "$UNENCRYPTED_RDS"
            fi
            ;;
        gcp)
            info "Checking GCP security..."
            
            # Check for open firewall rules
            OPEN_FW=$(gcloud compute firewall-rules list --filter="allowed[].ports:22 AND sourceRanges.list():0.0.0.0/0" --format="table(name,direction,priority)" 2>/dev/null || true)
            if [[ -n "$OPEN_FW" ]]; then
                warning "Found open firewall rules:"
                echo "$OPEN_FW"
            fi
            
            # Check for unencrypted disks
            UNENCRYPTED_DISKS=$(gcloud compute disks list --filter="NOT diskEncryptionKey:*" --format="table(name,sizeGb)" 2>/dev/null || true)
            if [[ -n "$UNENCRYPTED_DISKS" ]]; then
                warning "Found unencrypted disks:"
                echo "$UNENCRYPTED_DISKS"
            fi
            ;;
        local)
            info "Checking local security..."
            
            # Check Docker daemon security
            if docker info --format '{{.SecurityOptions}}' | grep -q "name=apparmor"; then
                info "AppArmor is enabled"
            else
                warning "AppArmor is not enabled"
            fi
            
            # Check for exposed ports
            EXPOSED_PORTS=$(docker ps --format "table {{.Names}}\t{{.Ports}}" | grep -v "PORTS" | grep -v "^$" || true)
            if [[ -n "$EXPOSED_PORTS" ]]; then
                info "Exposed ports:"
                echo "$EXPOSED_PORTS"
            fi
            ;;
    esac
    
    log "Security check completed"
}

# Run Terraform validation
validate_terraform() {
    log "Validating Terraform configuration..."
    
    # Check if terraform files exist
    if [[ ! -f "environments.tf" ]]; then
        error "environments.tf not found"
        return 1
    fi
    
    # Validate Terraform configuration
    if ! terraform validate; then
        error "Terraform configuration validation failed"
        return 1
    fi
    
    # Check for potential issues
    if terraform plan -var="environment=$ENVIRONMENT" -var="cloud_provider=$CLOUD_PROVIDER" 2>&1 | grep -i "error\|warning"; then
        warning "Potential issues found in Terraform plan"
    fi
    
    log "Terraform validation completed"
}

# Generate report
generate_report() {
    log "Generating troubleshooting report..."
    
    REPORT_FILE="troubleshoot-report-${ENVIRONMENT}-${CLOUD_PROVIDER}-$(date +%Y%m%d_%H%M%S).md"
    
    cat > "$REPORT_FILE" << EOF
# VaultSwap DEX Infrastructure Troubleshooting Report

**Generated**: $(date)
**Environment**: $ENVIRONMENT
**Cloud Provider**: $CLOUD_PROVIDER
**Region**: $REGION

## Summary

This report contains the results of the troubleshooting analysis for the VaultSwap DEX infrastructure.

## Issues Found

EOF

    # Add specific issues based on checks performed
    if [[ "$CHECK_PERMISSIONS" == "true" ]]; then
        echo "### Permissions Issues" >> "$REPORT_FILE"
        echo "Check the permissions section above for any issues found." >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
    fi
    
    if [[ "$CHECK_RESOURCES" == "true" ]]; then
        echo "### Resource Issues" >> "$REPORT_FILE"
        echo "Check the resources section above for any issues found." >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
    fi
    
    if [[ "$CHECK_CONNECTIVITY" == "true" ]]; then
        echo "### Connectivity Issues" >> "$REPORT_FILE"
        echo "Check the connectivity section above for any issues found." >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
    fi
    
    if [[ "$CHECK_COSTS" == "true" ]]; then
        echo "### Cost Issues" >> "$REPORT_FILE"
        echo "Check the costs section above for any issues found." >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
    fi
    
    if [[ "$CHECK_SECURITY" == "true" ]]; then
        echo "### Security Issues" >> "$REPORT_FILE"
        echo "Check the security section above for any issues found." >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
    fi
    
    cat >> "$REPORT_FILE" << EOF
## Recommendations

1. **Regular Monitoring**: Set up regular monitoring for all environments
2. **Cost Optimization**: Review and optimize costs regularly
3. **Security Updates**: Keep security configurations up to date
4. **Backup Strategy**: Ensure proper backup and recovery procedures
5. **Documentation**: Keep troubleshooting procedures documented

## Next Steps

1. Address any critical issues found
2. Implement monitoring and alerting
3. Set up regular health checks
4. Document procedures for future reference

---
*Report generated by VaultSwap DEX Infrastructure Troubleshooting Script*
EOF

    log "Report generated: $REPORT_FILE"
}

# Main execution
main() {
    log "Starting VaultSwap DEX Infrastructure Troubleshooting"
    log "Environment: $ENVIRONMENT"
    log "Cloud Provider: $CLOUD_PROVIDER"
    log "Region: $REGION"
    
    # Check prerequisites
    check_prerequisites
    
    # Run specific checks based on options
    if [[ "$CHECK_PERMISSIONS" == "true" ]]; then
        check_permissions
    fi
    
    if [[ "$CHECK_RESOURCES" == "true" ]]; then
        check_resources
    fi
    
    if [[ "$CHECK_CONNECTIVITY" == "true" ]]; then
        check_connectivity
    fi
    
    if [[ "$CHECK_COSTS" == "true" ]]; then
        check_costs
    fi
    
    if [[ "$CHECK_SECURITY" == "true" ]]; then
        check_security
    fi
    
    # If no specific checks requested, run all checks
    if [[ "$CHECK_PERMISSIONS" == "false" && "$CHECK_RESOURCES" == "false" && "$CHECK_CONNECTIVITY" == "false" && "$CHECK_COSTS" == "false" && "$CHECK_SECURITY" == "false" ]]; then
        check_permissions
        check_resources
        check_connectivity
        check_costs
        check_security
    fi
    
    # Validate Terraform
    validate_terraform
    
    # Generate report
    generate_report
    
    log "Troubleshooting completed successfully"
}

# Signal handlers
trap 'error "Troubleshooting interrupted"; exit 1' INT TERM

# Run main function
main "$@"

