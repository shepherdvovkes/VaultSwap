#!/bin/bash
# Attack Simulation Environment Deployment Script
# This script automates the deployment of the DEX attack simulation environment

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ENVIRONMENT_NAME="dex-attack-sim"
LOG_DIR="/var/log/attack-simulations"
SIMULATION_DIR="/opt/attack-simulations"

# Logging function
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

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if running as root or with sudo
    if [[ $EUID -eq 0 ]]; then
        warning "Running as root. Consider using a non-root user with sudo privileges."
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        error "Python 3 is not installed. Please install Python 3 first."
        exit 1
    fi
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        error "Terraform is not installed. Please install Terraform first."
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        error "Docker daemon is not running. Please start Docker first."
        exit 1
    fi
    
    log "All prerequisites satisfied"
}

# Create directories
create_directories() {
    log "Creating directories..."
    
    sudo mkdir -p "$LOG_DIR"
    sudo mkdir -p "$SIMULATION_DIR"
    sudo mkdir -p "attack-simulations/logs"
    sudo mkdir -p "attack-simulations/monitoring"
    
    # Set permissions
    sudo chown -R $USER:$USER "$LOG_DIR"
    sudo chown -R $USER:$USER "$SIMULATION_DIR"
    sudo chown -R $USER:$USER "attack-simulations"
    
    log "Directories created successfully"
}

# Install Python dependencies
install_python_dependencies() {
    log "Installing Python dependencies..."
    
    # Create virtual environment
    python3 -m venv venv
    source venv/bin/activate
    
    # Install common dependencies
    pip install --upgrade pip
    pip install -r attack-simulations/mev-attacks/requirements.txt
    pip install -r attack-simulations/flash-loan-attacks/requirements.txt
    pip install -r attack-simulations/oracle-manipulation/requirements.txt
    
    log "Python dependencies installed successfully"
}

# Deploy Terraform infrastructure
deploy_terraform() {
    log "Deploying Terraform infrastructure..."
    
    # Initialize Terraform
    terraform init
    
    # Plan deployment
    terraform plan -var="simulation_environment=$ENVIRONMENT_NAME"
    
    # Apply configuration
    terraform apply -auto-approve -var="simulation_environment=$ENVIRONMENT_NAME"
    
    log "Terraform infrastructure deployed successfully"
}

# Build Docker images
build_docker_images() {
    log "Building Docker images..."
    
    # Build MEV attack simulator
    docker build -t mev-attack-simulator attack-simulations/mev-attacks/
    
    # Build flash loan attack simulator
    docker build -t flash-loan-attack-simulator attack-simulations/flash-loan-attacks/
    
    # Build oracle attack simulator
    docker build -t oracle-attack-simulator attack-simulations/oracle-manipulation/
    
    log "Docker images built successfully"
}

# Start monitoring services
start_monitoring() {
    log "Starting monitoring services..."
    
    # Start Prometheus
    docker run -d --name prometheus \
        -p 9090:9090 \
        -v $(pwd)/attack-simulations/monitoring/prometheus.yml:/etc/prometheus/prometheus.yml \
        -v $(pwd)/attack-simulations/monitoring/prometheus-rules.yml:/etc/prometheus/rules.yml \
        prom/prometheus:latest \
        --config.file=/etc/prometheus/prometheus.yml \
        --storage.tsdb.path=/prometheus \
        --web.console.libraries=/etc/prometheus/console_libraries \
        --web.console.templates=/etc/prometheus/consoles \
        --web.enable-lifecycle
    
    # Start Grafana
    docker run -d --name grafana \
        -p 3000:3000 \
        -v $(pwd)/attack-simulations/monitoring/grafana-dashboard.json:/var/lib/grafana/dashboards/dashboard.json \
        -e GF_SECURITY_ADMIN_PASSWORD=admin \
        grafana/grafana:latest
    
    # Start Elasticsearch
    docker run -d --name elasticsearch \
        -p 9200:9200 \
        -e discovery.type=single-node \
        -e xpack.security.enabled=false \
        -v $(pwd)/attack-simulations/monitoring/elasticsearch.yml:/usr/share/elasticsearch/config/elasticsearch.yml \
        docker.elastic.co/elasticsearch/elasticsearch:8.8.0
    
    # Start Kibana
    docker run -d --name kibana \
        -p 5601:5601 \
        -e ELASTICSEARCH_HOSTS=http://elasticsearch:9200 \
        -v $(pwd)/attack-simulations/monitoring/kibana.yml:/usr/share/kibana/config/kibana.yml \
        docker.elastic.co/kibana/kibana:8.8.0
    
    # Start AlertManager
    docker run -d --name alertmanager \
        -p 9093:9093 \
        -v $(pwd)/attack-simulations/monitoring/alertmanager.yml:/etc/alertmanager/alertmanager.yml \
        prom/alertmanager:latest \
        --config.file=/etc/alertmanager/alertmanager.yml \
        --storage.path=/alertmanager
    
    log "Monitoring services started successfully"
}

# Start attack simulation services
start_simulation_services() {
    log "Starting attack simulation services..."
    
    # Start MEV attack simulator
    docker run -d --name mev-simulator \
        --network host \
        -v $(pwd)/attack-simulations/mev-attacks:/app \
        -v $(pwd)/attack-simulations/logs:/app/logs \
        mev-attack-simulator
    
    # Start flash loan attack simulator
    docker run -d --name flash-loan-simulator \
        --network host \
        -v $(pwd)/attack-simulations/flash-loan-attacks:/app \
        -v $(pwd)/attack-simulations/logs:/app/logs \
        flash-loan-attack-simulator
    
    # Start oracle attack simulator
    docker run -d --name oracle-simulator \
        --network host \
        -v $(pwd)/attack-simulations/oracle-manipulation:/app \
        -v $(pwd)/attack-simulations/logs:/app/logs \
        oracle-attack-simulator
    
    log "Attack simulation services started successfully"
}

# Run health checks
run_health_checks() {
    log "Running health checks..."
    
    # Check Prometheus
    if curl -f http://localhost:9090/api/v1/query?query=up &> /dev/null; then
        log "Prometheus is healthy"
    else
        error "Prometheus health check failed"
    fi
    
    # Check Grafana
    if curl -f http://localhost:3000/api/health &> /dev/null; then
        log "Grafana is healthy"
    else
        error "Grafana health check failed"
    fi
    
    # Check Elasticsearch
    if curl -f http://localhost:9200/_cluster/health &> /dev/null; then
        log "Elasticsearch is healthy"
    else
        error "Elasticsearch health check failed"
    fi
    
    # Check Kibana
    if curl -f http://localhost:5601/api/status &> /dev/null; then
        log "Kibana is healthy"
    else
        error "Kibana health check failed"
    fi
    
    # Check attack simulators
    if docker ps | grep -q mev-simulator; then
        log "MEV simulator is running"
    else
        error "MEV simulator is not running"
    fi
    
    if docker ps | grep -q flash-loan-simulator; then
        log "Flash loan simulator is running"
    else
        error "Flash loan simulator is not running"
    fi
    
    if docker ps | grep -q oracle-simulator; then
        log "Oracle simulator is running"
    else
        error "Oracle simulator is not running"
    fi
    
    log "Health checks completed"
}

# Run initial tests
run_initial_tests() {
    log "Running initial security tests..."
    
    # Activate virtual environment
    source venv/bin/activate
    
    # Run security tests
    python3 attack-simulations/scripts/security_test_runner.py \
        --config attack-simulations/mev-attacks/config.json \
        --test-types mev_protection system_health
    
    log "Initial tests completed"
}

# Display access information
display_access_info() {
    log "Deployment completed successfully!"
    
    echo -e "\n${BLUE}=== Access Information ===${NC}"
    echo -e "Prometheus: ${GREEN}http://localhost:9090${NC}"
    echo -e "Grafana: ${GREEN}http://localhost:3000${NC} (admin/admin)"
    echo -e "Elasticsearch: ${GREEN}http://localhost:9200${NC}"
    echo -e "Kibana: ${GREEN}http://localhost:5601${NC}"
    echo -e "AlertManager: ${GREEN}http://localhost:9093${NC}"
    
    echo -e "\n${BLUE}=== Attack Simulation Scripts ===${NC}"
    echo -e "Run attack simulation: ${GREEN}./attack-simulations/scripts/run_attack_simulation.sh${NC}"
    echo -e "Security tests: ${GREEN}python3 attack-simulations/scripts/security_test_runner.py --config config.json${NC}"
    echo -e "Performance tests: ${GREEN}python3 attack-simulations/scripts/performance_test.py --duration 60${NC}"
    echo -e "Response time tests: ${GREEN}python3 attack-simulations/scripts/response_time_test.py --test-count 100${NC}"
    echo -e "Throughput tests: ${GREEN}python3 attack-simulations/scripts/throughput_test.py --duration 60 --concurrent 10${NC}"
    
    echo -e "\n${BLUE}=== Logs ===${NC}"
    echo -e "Attack simulation logs: ${GREEN}$LOG_DIR${NC}"
    echo -e "Docker logs: ${GREEN}docker logs <container_name>${NC}"
    
    echo -e "\n${BLUE}=== Management Commands ===${NC}"
    echo -e "Stop all services: ${GREEN}docker stop \$(docker ps -q)${NC}"
    echo -e "Start all services: ${GREEN}docker start \$(docker ps -aq)${NC}"
    echo -e "View running containers: ${GREEN}docker ps${NC}"
    echo -e "View logs: ${GREEN}docker logs <container_name>${NC}"
}

# Cleanup function
cleanup() {
    log "Cleaning up on exit..."
    
    # Stop all containers
    docker stop $(docker ps -q) 2>/dev/null || true
    
    # Remove containers
    docker rm $(docker ps -aq) 2>/dev/null || true
    
    log "Cleanup completed"
}

# Main deployment function
main() {
    log "Starting DEX Attack Simulation Environment deployment..."
    
    # Set up signal handlers
    trap cleanup EXIT INT TERM
    
    # Run deployment steps
    check_prerequisites
    create_directories
    install_python_dependencies
    deploy_terraform
    build_docker_images
    start_monitoring
    start_simulation_services
    
    # Wait for services to start
    log "Waiting for services to start..."
    sleep 30
    
    # Run health checks
    run_health_checks
    
    # Run initial tests
    run_initial_tests
    
    # Display access information
    display_access_info
    
    log "Deployment completed successfully!"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --help, -h          Show this help message"
            echo "  --skip-tests         Skip running initial tests"
            echo "  --skip-health-checks Skip running health checks"
            echo "  --monitoring-only    Only start monitoring services"
            echo "  --simulation-only    Only start simulation services"
            exit 0
            ;;
        --skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        --skip-health-checks)
            SKIP_HEALTH_CHECKS=true
            shift
            ;;
        --monitoring-only)
            MONITORING_ONLY=true
            shift
            ;;
        --simulation-only)
            SIMULATION_ONLY=true
            shift
            ;;
        *)
            error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Run main deployment
main
