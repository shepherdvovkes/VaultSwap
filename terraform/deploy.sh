#!/bin/bash
# VaultSwap DEX Infrastructure Deployment Script
# Supports testing, staging, and production environments

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
AUTO_APPROVE=false
DESTROY=false
PLAN_ONLY=false
ENABLE_MONITORING=false
ENABLE_COST_OPTIMIZATION=true

# Help function
show_help() {
    cat << EOF
VaultSwap DEX Infrastructure Deployment Script

USAGE:
    $0 [OPTIONS] ENVIRONMENT CLOUD_PROVIDER

ARGUMENTS:
    ENVIRONMENT      Environment to deploy (testing, staging, production)
    CLOUD_PROVIDER   Cloud provider to use (aws, azure, gcp, local)

OPTIONS:
    -h, --help              Show this help message
    -r, --region REGION     AWS region (default: us-west-2)
    -a, --auto-approve      Auto-approve terraform apply
    -d, --destroy           Destroy infrastructure instead of creating
    -p, --plan-only         Only run terraform plan
    -m, --enable-monitoring Enable comprehensive monitoring
    -c, --disable-cost-opt  Disable cost optimization
    -v, --verbose           Enable verbose output
    --var KEY=VALUE         Set terraform variable
    --var-file FILE         Use terraform variable file

EXAMPLES:
    $0 testing aws
    $0 staging aws --region us-east-1
    $0 production aws --enable-monitoring
    $0 testing aws --destroy
    $0 staging aws --plan-only
    $0 testing aws --var="instance_count=5"

ENVIRONMENTS:
    testing     Development and testing environment
    staging     Pre-production testing environment
    production  Live production environment

CLOUD PROVIDERS:
    aws         Amazon Web Services (recommended)
    azure       Microsoft Azure
    gcp         Google Cloud Platform
    local       Local development with Docker

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
TERRAFORM_VARS=()
TERRAFORM_VAR_FILES=()

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
        -a|--auto-approve)
            AUTO_APPROVE=true
            shift
            ;;
        -d|--destroy)
            DESTROY=true
            shift
            ;;
        -p|--plan-only)
            PLAN_ONLY=true
            shift
            ;;
        -m|--enable-monitoring)
            ENABLE_MONITORING=true
            shift
            ;;
        -c|--disable-cost-opt)
            ENABLE_COST_OPTIMIZATION=false
            shift
            ;;
        -v|--verbose)
            set -x
            shift
            ;;
        --var)
            TERRAFORM_VARS+=("-var=$2")
            shift 2
            ;;
        --var-file)
            TERRAFORM_VAR_FILES+=("-var-file=$2")
            shift 2
            ;;
        testing|staging|production)
            ENVIRONMENT="$1"
            shift
            ;;
        aws|azure|gcp|local)
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

# Validate environment
case $ENVIRONMENT in
    testing|staging|production)
        ;;
    *)
        error "Invalid environment: $ENVIRONMENT"
        error "Valid environments: testing, staging, production"
        exit 1
        ;;
esac

# Validate cloud provider
case $CLOUD_PROVIDER in
    aws|azure|gcp|local)
        ;;
    *)
        error "Invalid cloud provider: $CLOUD_PROVIDER"
        error "Valid cloud providers: aws, azure, gcp, local"
        exit 1
        ;;
esac

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if terraform is installed
    if ! command -v terraform &> /dev/null; then
        error "Terraform is not installed"
        error "Please install Terraform >= 1.0"
        exit 1
    fi
    
    # Check terraform version
    TERRAFORM_VERSION=$(terraform version -json | jq -r '.terraform_version')
    REQUIRED_VERSION="1.0.0"
    
    if ! terraform version -json | jq -e ".terraform_version | split(\".\") | map(tonumber) | . >= [1, 0, 0]" > /dev/null; then
        error "Terraform version $TERRAFORM_VERSION is not supported"
        error "Please upgrade to Terraform >= 1.0"
        exit 1
    fi
    
    # Check cloud provider specific prerequisites
    case $CLOUD_PROVIDER in
        aws)
            if ! command -v aws &> /dev/null; then
                error "AWS CLI is not installed"
                error "Please install AWS CLI and configure credentials"
                exit 1
            fi
            
            if ! aws sts get-caller-identity &> /dev/null; then
                error "AWS credentials not configured"
                error "Please run 'aws configure' or set AWS environment variables"
                exit 1
            fi
            ;;
        azure)
            if ! command -v az &> /dev/null; then
                error "Azure CLI is not installed"
                error "Please install Azure CLI and login"
                exit 1
            fi
            ;;
        gcp)
            if ! command -v gcloud &> /dev/null; then
                error "Google Cloud CLI is not installed"
                error "Please install Google Cloud CLI and authenticate"
                exit 1
            fi
            
            if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
                error "GCP authentication required"
                error "Please run 'gcloud auth login' and 'gcloud auth application-default login'"
                exit 1
            fi
            
            if [[ -z "${GCP_PROJECT_ID:-}" ]]; then
                error "GCP_PROJECT_ID environment variable is required for GCP deployment"
                error "Please set GCP_PROJECT_ID or use --var='gcp_project_id=your-project-id'"
                exit 1
            fi
            ;;
        local)
            if ! command -v docker &> /dev/null; then
                error "Docker is not installed"
                error "Please install Docker for local development"
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

# Initialize terraform
init_terraform() {
    log "Initializing Terraform..."
    
    # Clean up previous state if needed
    if [[ -d ".terraform" ]]; then
        warning "Cleaning up previous Terraform state..."
        rm -rf .terraform
    fi
    
    # Initialize terraform
    terraform init -upgrade
    
    if [[ $? -ne 0 ]]; then
        error "Terraform initialization failed"
        exit 1
    fi
    
    log "Terraform initialized successfully"
}

# Create terraform workspace
create_workspace() {
    log "Creating Terraform workspace: $ENVIRONMENT-$CLOUD_PROVIDER"
    
    WORKSPACE_NAME="$ENVIRONMENT-$CLOUD_PROVIDER"
    
    # Check if workspace exists
    if terraform workspace list | grep -q "$WORKSPACE_NAME"; then
        log "Workspace $WORKSPACE_NAME already exists"
    else
        terraform workspace new "$WORKSPACE_NAME"
    fi
    
    # Select workspace
    terraform workspace select "$WORKSPACE_NAME"
    
    log "Using workspace: $WORKSPACE_NAME"
}

# Build terraform command
build_terraform_command() {
    TERRAFORM_CMD="terraform"
    
    if [[ "$DESTROY" == "true" ]]; then
        TERRAFORM_CMD="$TERRAFORM_CMD destroy"
    elif [[ "$PLAN_ONLY" == "true" ]]; then
        TERRAFORM_CMD="$TERRAFORM_CMD plan"
    else
        TERRAFORM_CMD="$TERRAFORM_CMD apply"
    fi
    
    # Add auto-approve for apply/destroy
    if [[ "$AUTO_APPROVE" == "true" && "$PLAN_ONLY" != "true" ]]; then
        TERRAFORM_CMD="$TERRAFORM_CMD -auto-approve"
    fi
    
    # Add variables
    TERRAFORM_CMD="$TERRAFORM_CMD -var=\"environment=$ENVIRONMENT\""
    TERRAFORM_CMD="$TERRAFORM_CMD -var=\"cloud_provider=$CLOUD_PROVIDER\""
    TERRAFORM_CMD="$TERRAFORM_CMD -var=\"region=$REGION\""
    
    # Add monitoring variable
    if [[ "$ENABLE_MONITORING" == "true" ]]; then
        TERRAFORM_CMD="$TERRAFORM_CMD -var=\"monitoring_level=comprehensive\""
    fi
    
    # Add cost optimization variable
    if [[ "$ENABLE_COST_OPTIMIZATION" == "false" ]]; then
        TERRAFORM_CMD="$TERRAFORM_CMD -var=\"cost_optimization=false\""
    fi
    
    # Add custom variables
    for var in "${TERRAFORM_VARS[@]}"; do
        TERRAFORM_CMD="$TERRAFORM_CMD $var"
    done
    
    # Add variable files
    for var_file in "${TERRAFORM_VAR_FILES[@]}"; do
        TERRAFORM_CMD="$TERRAFORM_CMD $var_file"
    done
    
    # Add output file for plan
    if [[ "$PLAN_ONLY" == "true" ]]; then
        PLAN_FILE="plan-$ENVIRONMENT-$CLOUD_PROVIDER.tfplan"
        TERRAFORM_CMD="$TERRAFORM_CMD -out=$PLAN_FILE"
    fi
}

# Run terraform command
run_terraform() {
    log "Running Terraform command: $TERRAFORM_CMD"
    
    # Execute terraform command
    eval $TERRAFORM_CMD
    
    if [[ $? -ne 0 ]]; then
        error "Terraform command failed"
        exit 1
    fi
    
    log "Terraform command completed successfully"
}

# Show outputs
show_outputs() {
    if [[ "$DESTROY" != "true" && "$PLAN_ONLY" != "true" ]]; then
        log "Infrastructure deployed successfully!"
        log "Showing outputs..."
        
        echo ""
        echo "=== INFRASTRUCTURE OUTPUTS ==="
        terraform output
        
        echo ""
        echo "=== CONNECTION INFORMATION ==="
        echo "Environment: $ENVIRONMENT"
        echo "Cloud Provider: $CLOUD_PROVIDER"
        echo "Region: $REGION"
        echo ""
        
        # Show specific outputs based on cloud provider
        case $CLOUD_PROVIDER in
            aws)
                echo "Load Balancer: $(terraform output -raw 'infrastructure_endpoints.aws.load_balancer_dns' 2>/dev/null || echo 'N/A')"
                echo "Database: $(terraform output -raw 'infrastructure_endpoints.aws.rds_endpoint' 2>/dev/null || echo 'N/A')"
                echo "Monitoring: $(terraform output -raw 'infrastructure_endpoints.aws.monitoring_dashboard' 2>/dev/null || echo 'N/A')"
                ;;
            azure)
                echo "Load Balancer: $(terraform output -raw 'infrastructure_endpoints.azure.load_balancer_dns' 2>/dev/null || echo 'N/A')"
                echo "Database: $(terraform output -raw 'infrastructure_endpoints.azure.database_endpoint' 2>/dev/null || echo 'N/A')"
                ;;
            gcp)
                echo "Load Balancer: $(terraform output -raw 'infrastructure_endpoints.gcp.load_balancer_ip' 2>/dev/null || echo 'N/A')"
                echo "Database: $(terraform output -raw 'infrastructure_endpoints.gcp.database_connection_name' 2>/dev/null || echo 'N/A')"
                echo "Instances: $(terraform output -raw 'infrastructure_endpoints.gcp.instance_ips' 2>/dev/null || echo 'N/A')"
                ;;
            local)
                echo "Application: $(terraform output -raw 'infrastructure_endpoints.local.application_url' 2>/dev/null || echo 'N/A')"
                echo "Database: $(terraform output -raw 'infrastructure_endpoints.local.database_url' 2>/dev/null || echo 'N/A')"
                echo "Monitoring: $(terraform output -raw 'infrastructure_endpoints.local.prometheus_url' 2>/dev/null || echo 'N/A')"
                echo "Docker Compose: $(terraform output -raw 'infrastructure_endpoints.local.docker_compose_file' 2>/dev/null || echo 'N/A')"
                echo ""
                echo "To start local services:"
                echo "  docker-compose -f $(terraform output -raw 'infrastructure_endpoints.local.docker_compose_file' 2>/dev/null) up -d"
                ;;
        esac
        
        echo ""
        echo "=== NEXT STEPS ==="
        echo "1. Verify deployment: terraform show"
        echo "2. View resources: terraform state list"
        echo "3. Update configuration: terraform apply"
        echo "4. Destroy resources: terraform destroy"
        echo ""
    fi
}

# Cleanup function
cleanup() {
    if [[ "$PLAN_ONLY" == "true" && -f "$PLAN_FILE" ]]; then
        log "Plan file saved: $PLAN_FILE"
        log "To apply this plan: terraform apply $PLAN_FILE"
    fi
}

# Main execution
main() {
    log "Starting VaultSwap DEX Infrastructure Deployment"
    log "Environment: $ENVIRONMENT"
    log "Cloud Provider: $CLOUD_PROVIDER"
    log "Region: $REGION"
    
    # Check prerequisites
    check_prerequisites
    
    # Initialize terraform
    init_terraform
    
    # Create workspace
    create_workspace
    
    # Build terraform command
    build_terraform_command
    
    # Run terraform command
    run_terraform
    
    # Show outputs
    show_outputs
    
    # Cleanup
    cleanup
    
    log "Deployment completed successfully!"
}

# Signal handlers
trap 'error "Deployment interrupted"; exit 1' INT TERM

# Run main function
main "$@"