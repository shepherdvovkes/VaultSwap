# Local Deployment Module for VaultSwap DEX Infrastructure
# Uses Docker containers and local services for development and testing

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
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

variable "operating_systems" {
  description = "List of operating systems to support"
  type        = list(string)
  default     = ["linux", "windows", "macos"]
}

variable "instance_count" {
  description = "Number of instances to create"
  type        = number
  default     = 2
}

variable "storage_size" {
  description = "Storage size in GB"
  type        = number
  default     = 50
}

variable "monitoring_level" {
  description = "Monitoring level (basic, enhanced, comprehensive)"
  type        = string
  default     = "basic"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# Random passwords
resource "random_password" "postgres_password" {
  length  = 32
  special = true
}

resource "random_password" "redis_password" {
  length  = 32
  special = true
}

resource "random_password" "monitoring_password" {
  length  = 32
  special = true
}

# Docker Networks
resource "docker_network" "vaultswap_network" {
  name = "${var.environment}-vaultswap-network"
  
  ipam_config {
    subnet = "172.20.0.0/16"
  }
}

# PostgreSQL Database
resource "docker_image" "postgres" {
  name = "postgres:15-alpine"
}

resource "docker_container" "postgres" {
  name  = "${var.environment}-postgres"
  image = docker_image.postgres.image_id

  env = [
    "POSTGRES_DB=vaultswap",
    "POSTGRES_USER=vaultswap",
    "POSTGRES_PASSWORD=${random_password.postgres_password.result}",
    "POSTGRES_INITDB_ARGS=--encoding=UTF-8 --lc-collate=C --lc-ctype=C"
  ]

  ports {
    internal = 5432
    external = 5432
  }

  volumes {
    host_path      = "${path.cwd}/data/postgres"
    container_path = "/var/lib/postgresql/data"
  }

  networks_advanced {
    name = docker_network.vaultswap_network.name
  }

  restart = "unless-stopped"

  healthcheck {
    test     = ["CMD-SHELL", "pg_isready -U vaultswap -d vaultswap"]
    interval = "30s"
    timeout  = "10s"
    retries  = 3
  }
}

# Redis Cache
resource "docker_image" "redis" {
  name = "redis:7-alpine"
}

resource "docker_container" "redis" {
  name  = "${var.environment}-redis"
  image = docker_image.redis.image_id

  command = ["redis-server", "--requirepass", random_password.redis_password.result]

  ports {
    internal = 6379
    external = 6379
  }

  volumes {
    host_path      = "${path.cwd}/data/redis"
    container_path = "/data"
  }

  networks_advanced {
    name = docker_network.vaultswap_network.name
  }

  restart = "unless-stopped"

  healthcheck {
    test     = ["CMD", "redis-cli", "ping"]
    interval = "30s"
    timeout  = "10s"
    retries  = 3
  }
}

# Application Containers for different OS environments
resource "docker_image" "vaultswap_linux" {
  name = "vaultswap:latest"
  
  build {
    context    = "${path.cwd}/../../"
    dockerfile = "Dockerfile.linux"
  }
}

resource "docker_container" "vaultswap_linux" {
  count = contains(var.operating_systems, "linux") ? var.instance_count : 0

  name  = "${var.environment}-vaultswap-linux-${count.index + 1}"
  image = docker_image.vaultswap_linux.image_id

  env = [
    "NODE_ENV=production",
    "ENVIRONMENT=${var.environment}",
    "DATABASE_URL=postgresql://vaultswap:${random_password.postgres_password.result}@postgres:5432/vaultswap",
    "REDIS_URL=redis://:${random_password.redis_password.result}@redis:6379",
    "PORT=8080"
  ]

  ports {
    internal = 8080
    external = 8080 + count.index
  }

  networks_advanced {
    name = docker_network.vaultswap_network.name
  }

  restart = "unless-stopped"

  depends_on = [
    docker_container.postgres,
    docker_container.redis
  ]

  healthcheck {
    test     = ["CMD", "curl", "-f", "http://localhost:8080/health"]
    interval = "30s"
    timeout  = "10s"
    retries  = 3
  }
}

# Windows Container (using Windows Server Core)
resource "docker_image" "vaultswap_windows" {
  name = "vaultswap:windows"
  
  build {
    context    = "${path.cwd}/../../"
    dockerfile = "Dockerfile.windows"
  }
}

resource "docker_container" "vaultswap_windows" {
  count = contains(var.operating_systems, "windows") ? var.instance_count : 0

  name  = "${var.environment}-vaultswap-windows-${count.index + 1}"
  image = docker_image.vaultswap_windows.image_id

  env = [
    "NODE_ENV=production",
    "ENVIRONMENT=${var.environment}",
    "DATABASE_URL=postgresql://vaultswap:${random_password.postgres_password.result}@postgres:5432/vaultswap",
    "REDIS_URL=redis://:${random_password.redis_password.result}@redis:6379",
    "PORT=8080"
  ]

  ports {
    internal = 8080
    external = 8090 + count.index
  }

  networks_advanced {
    name = docker_network.vaultswap_network.name
  }

  restart = "unless-stopped"

  depends_on = [
    docker_container.postgres,
    docker_container.redis
  ]
}

# macOS Container (using Ubuntu as base for macOS compatibility)
resource "docker_image" "vaultswap_macos" {
  name = "vaultswap:macos"
  
  build {
    context    = "${path.cwd}/../../"
    dockerfile = "Dockerfile.macos"
  }
}

resource "docker_container" "vaultswap_macos" {
  count = contains(var.operating_systems, "macos") ? var.instance_count : 0

  name  = "${var.environment}-vaultswap-macos-${count.index + 1}"
  image = docker_image.vaultswap_macos.image_id

  env = [
    "NODE_ENV=production",
    "ENVIRONMENT=${var.environment}",
    "DATABASE_URL=postgresql://vaultswap:${random_password.postgres_password.result}@postgres:5432/vaultswap",
    "REDIS_URL=redis://:${random_password.redis_password.result}@redis:6379",
    "PORT=8080"
  ]

  ports {
    internal = 8080
    external = 8100 + count.index
  }

  networks_advanced {
    name = docker_network.vaultswap_network.name
  }

  restart = "unless-stopped"

  depends_on = [
    docker_container.postgres,
    docker_container.redis
  ]
}

# Load Balancer (Nginx)
resource "docker_image" "nginx" {
  name = "nginx:alpine"
}

resource "docker_container" "nginx" {
  name  = "${var.environment}-nginx"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = 80
  }

  ports {
    internal = 443
    external = 443
  }

  volumes {
    host_path      = "${path.cwd}/config/nginx/nginx.conf"
    container_path = "/etc/nginx/nginx.conf"
  }

  volumes {
    host_path      = "${path.cwd}/config/nginx/ssl"
    container_path = "/etc/nginx/ssl"
  }

  networks_advanced {
    name = docker_network.vaultswap_network.name
  }

  restart = "unless-stopped"

  depends_on = [
    docker_container.vaultswap_linux,
    docker_container.vaultswap_windows,
    docker_container.vaultswap_macos
  ]
}

# Monitoring Stack
resource "docker_image" "prometheus" {
  count = var.monitoring_level != "basic" ? 1 : 0
  name  = "prom/prometheus:latest"
}

resource "docker_container" "prometheus" {
  count = var.monitoring_level != "basic" ? 1 : 0

  name  = "${var.environment}-prometheus"
  image = docker_image.prometheus[0].image_id

  ports {
    internal = 9090
    external = 9090
  }

  volumes {
    host_path      = "${path.cwd}/config/prometheus/prometheus.yml"
    container_path = "/etc/prometheus/prometheus.yml"
  }

  volumes {
    host_path      = "${path.cwd}/data/prometheus"
    container_path = "/prometheus"
  }

  networks_advanced {
    name = docker_network.vaultswap_network.name
  }

  restart = "unless-stopped"
}

resource "docker_image" "grafana" {
  count = var.monitoring_level == "comprehensive" ? 1 : 0
  name  = "grafana/grafana:latest"
}

resource "docker_container" "grafana" {
  count = var.monitoring_level == "comprehensive" ? 1 : 0

  name  = "${var.environment}-grafana"
  image = docker_image.grafana[0].image_id

  env = [
    "GF_SECURITY_ADMIN_PASSWORD=${random_password.monitoring_password.result}",
    "GF_USERS_ALLOW_SIGN_UP=false"
  ]

  ports {
    internal = 3000
    external = 3000
  }

  volumes {
    host_path      = "${path.cwd}/data/grafana"
    container_path = "/var/lib/grafana"
  }

  volumes {
    host_path      = "${path.cwd}/config/grafana/provisioning"
    container_path = "/etc/grafana/provisioning"
  }

  networks_advanced {
    name = docker_network.vaultswap_network.name
  }

  restart = "unless-stopped"

  depends_on = [docker_container.prometheus]
}

# Log Aggregation
resource "docker_image" "elasticsearch" {
  count = var.monitoring_level == "comprehensive" ? 1 : 0
  name  = "docker.elastic.co/elasticsearch/elasticsearch:8.8.0"
}

resource "docker_container" "elasticsearch" {
  count = var.monitoring_level == "comprehensive" ? 1 : 0

  name  = "${var.environment}-elasticsearch"
  image = docker_image.elasticsearch[0].image_id

  env = [
    "discovery.type=single-node",
    "xpack.security.enabled=false",
    "ES_JAVA_OPTS=-Xms512m -Xmx512m"
  ]

  ports {
    internal = 9200
    external = 9200
  }

  volumes {
    host_path      = "${path.cwd}/data/elasticsearch"
    container_path = "/usr/share/elasticsearch/data"
  }

  networks_advanced {
    name = docker_network.vaultswap_network.name
  }

  restart = "unless-stopped"
}

resource "docker_image" "kibana" {
  count = var.monitoring_level == "comprehensive" ? 1 : 0
  name  = "docker.elastic.co/kibana/kibana:8.8.0"
}

resource "docker_container" "kibana" {
  count = var.monitoring_level == "comprehensive" ? 1 : 0

  name  = "${var.environment}-kibana"
  image = docker_image.kibana[0].image_id

  env = [
    "ELASTICSEARCH_HOSTS=http://elasticsearch:9200"
  ]

  ports {
    internal = 5601
    external = 5601
  }

  networks_advanced {
    name = docker_network.vaultswap_network.name
  }

  restart = "unless-stopped"

  depends_on = [docker_container.elasticsearch]
}

# Configuration Files
resource "local_file" "nginx_config" {
  filename = "${path.cwd}/config/nginx/nginx.conf"
  content = templatefile("${path.module}/templates/nginx.conf.tpl", {
    environment = var.environment
    linux_containers = docker_container.vaultswap_linux[*].name
    windows_containers = docker_container.vaultswap_windows[*].name
    macos_containers = docker_container.vaultswap_macos[*].name
  })
}

resource "local_file" "prometheus_config" {
  count    = var.monitoring_level != "basic" ? 1 : 0
  filename = "${path.cwd}/config/prometheus/prometheus.yml"
  content = templatefile("${path.module}/templates/prometheus.yml.tpl", {
    environment = var.environment
    network_name = docker_network.vaultswap_network.name
  })
}

resource "local_file" "docker_compose" {
  filename = "${path.cwd}/docker-compose.${var.environment}.yml"
  content = templatefile("${path.module}/templates/docker-compose.yml.tpl", {
    environment = var.environment
    postgres_password = random_password.postgres_password.result
    redis_password = random_password.redis_password.result
    monitoring_password = random_password.monitoring_password.result
    network_name = docker_network.vaultswap_network.name
    operating_systems = var.operating_systems
    monitoring_level = var.monitoring_level
  })
}

# Environment File
resource "local_file" "env_file" {
  filename = "${path.cwd}/.env.${var.environment}"
  content = templatefile("${path.module}/templates/env.tpl", {
    environment = var.environment
    postgres_password = random_password.postgres_password.result
    redis_password = random_password.redis_password.result
    monitoring_password = random_password.monitoring_password.result
  })
}

# Outputs
output "network_name" {
  description = "Docker network name"
  value       = docker_network.vaultswap_network.name
}

output "container_ids" {
  description = "Container IDs"
  value = {
    postgres = docker_container.postgres.id
    redis    = docker_container.redis.id
    nginx    = docker_container.nginx.id
    linux    = docker_container.vaultswap_linux[*].id
    windows  = docker_container.vaultswap_windows[*].id
    macos    = docker_container.vaultswap_macos[*].id
    prometheus = var.monitoring_level != "basic" ? docker_container.prometheus[0].id : null
    grafana    = var.monitoring_level == "comprehensive" ? docker_container.grafana[0].id : null
    elasticsearch = var.monitoring_level == "comprehensive" ? docker_container.elasticsearch[0].id : null
    kibana       = var.monitoring_level == "comprehensive" ? docker_container.kibana[0].id : null
  }
}

output "service_urls" {
  description = "Service URLs"
  value = {
    application = "http://localhost:80"
    database   = "postgresql://vaultswap:${random_password.postgres_password.result}@localhost:5432/vaultswap"
    redis      = "redis://:${random_password.redis_password.result}@localhost:6379"
    prometheus = var.monitoring_level != "basic" ? "http://localhost:9090" : null
    grafana    = var.monitoring_level == "comprehensive" ? "http://localhost:3000" : null
    elasticsearch = var.monitoring_level == "comprehensive" ? "http://localhost:9200" : null
    kibana     = var.monitoring_level == "comprehensive" ? "http://localhost:5601" : null
  }
}

output "credentials" {
  description = "Service credentials"
  value = {
    postgres_password = random_password.postgres_password.result
    redis_password    = random_password.redis_password.result
    monitoring_password = random_password.monitoring_password.result
  }
  sensitive = true
}

output "docker_compose_file" {
  description = "Docker Compose file path"
  value       = local_file.docker_compose.filename
}

output "environment_file" {
  description = "Environment file path"
  value       = local_file.env_file.filename
}
