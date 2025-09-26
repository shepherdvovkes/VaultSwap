# GCP Module for Multi-Environment DEX Infrastructure
# Supports Google Cloud Platform deployment

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
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

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "us-central1-a"
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

variable "machine_type" {
  description = "GCP machine type"
  type        = string
  default     = "e2-medium"
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

# Data sources
data "google_client_config" "current" {}

# Random ID for unique resource names
resource "random_id" "suffix" {
  byte_length = 4
}

# VPC Network
resource "google_compute_network" "vaultswap_vpc" {
  name                    = "${var.environment}-vaultswap-vpc"
  auto_create_subnetworks = false
  mtu                     = 1460

  tags = merge(var.tags, {
    Name = "${var.environment}-vaultswap-vpc"
    Type = "VPC Network"
  })
}

# Subnet
resource "google_compute_subnetwork" "vaultswap_subnet" {
  name          = "${var.environment}-vaultswap-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.vaultswap_vpc.id

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.1.0.0/16"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.2.0.0/16"
  }

  tags = merge(var.tags, {
    Name = "${var.environment}-vaultswap-subnet"
    Type = "Subnet"
  })
}

# Firewall Rules
resource "google_compute_firewall" "allow_http" {
  name    = "${var.environment}-allow-http"
  network = google_compute_network.vaultswap_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server"]

  tags = merge(var.tags, {
    Name = "${var.environment}-allow-http"
    Type = "Firewall Rule"
  })
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "${var.environment}-allow-ssh"
  network = google_compute_network.vaultswap_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ssh-server"]

  tags = merge(var.tags, {
    Name = "${var.environment}-allow-ssh"
    Type = "Firewall Rule"
  })
}

resource "google_compute_firewall" "allow_internal" {
  name    = "${var.environment}-allow-internal"
  network = google_compute_network.vaultswap_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/24"]
  target_tags   = ["internal"]

  tags = merge(var.tags, {
    Name = "${var.environment}-allow-internal"
    Type = "Firewall Rule"
  })
}

# Cloud SQL Database
resource "google_sql_database_instance" "vaultswap_db" {
  name             = "${var.environment}-vaultswap-db"
  database_version = "POSTGRES_15"
  region           = var.region

  settings {
    tier = "db-f1-micro"
    
    disk_size = var.storage_size
    disk_type = "PD_SSD"
    
    backup_configuration {
      enabled                        = true
      start_time                     = "03:00"
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = 7
      backup_retention_settings {
        retained_backups = 7
        retention_unit   = "COUNT"
      }
    }

    ip_configuration {
      ipv4_enabled    = true
      require_ssl     = true
      authorized_networks {
        name  = "vaultswap-network"
        value = google_compute_subnetwork.vaultswap_subnet.ip_cidr_range
      }
    }

    database_flags {
      name  = "log_statement"
      value = "all"
    }

    database_flags {
      name  = "log_min_duration_statement"
      value = "1000"
    }
  }

  deletion_protection = var.environment == "production" ? true : false

  tags = merge(var.tags, {
    Name = "${var.environment}-vaultswap-db"
    Type = "Cloud SQL Instance"
  })
}

resource "google_sql_database" "vaultswap_database" {
  name     = "vaultswap"
  instance = google_sql_database_instance.vaultswap_db.name
}

resource "google_sql_user" "vaultswap_user" {
  name     = "vaultswap"
  instance = google_sql_database_instance.vaultswap_db.name
  password = random_password.db_password.result
}

resource "random_password" "db_password" {
  length  = 32
  special = true
}

# Compute Engine Instances
resource "google_compute_instance" "vaultswap_linux" {
  count = contains(var.operating_systems, "linux") ? var.instance_count : 0

  name         = "${var.environment}-vaultswap-linux-${count.index + 1}"
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["http-server", "ssh-server", "internal"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = var.storage_size
      type  = "pd-ssd"
    }
  }

  network_interface {
    network    = google_compute_network.vaultswap_vpc.id
    subnetwork = google_compute_subnetwork.vaultswap_subnet.id

    access_config {
      // Ephemeral public IP
    }
  }

  metadata = {
    startup-script = templatefile("${path.module}/startup-scripts/linux.sh", {
      environment = var.environment
      region      = var.region
      db_host     = google_sql_database_instance.vaultswap_db.private_ip_address
      db_name     = google_sql_database.vaultswap_database.name
      db_user     = google_sql_user.vaultswap_user.name
      db_password = random_password.db_password.result
    })
  }

  service_account {
    email  = google_service_account.vaultswap.email
    scopes = ["cloud-platform"]
  }

  tags = merge(var.tags, {
    Name = "${var.environment}-vaultswap-linux-${count.index + 1}"
    Type = "Compute Instance"
    OS   = "Linux"
  })
}

resource "google_compute_instance" "vaultswap_windows" {
  count = contains(var.operating_systems, "windows") ? var.instance_count : 0

  name         = "${var.environment}-vaultswap-windows-${count.index + 1}"
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["http-server", "ssh-server", "internal"]

  boot_disk {
    initialize_params {
      image = "windows-cloud/windows-server-2022"
      size  = var.storage_size
      type  = "pd-ssd"
    }
  }

  network_interface {
    network    = google_compute_network.vaultswap_vpc.id
    subnetwork = google_compute_subnetwork.vaultswap_subnet.id

    access_config {
      // Ephemeral public IP
    }
  }

  metadata = {
    windows-startup-script-cmd = templatefile("${path.module}/startup-scripts/windows.ps1", {
      environment = var.environment
      region      = var.region
      db_host     = google_sql_database_instance.vaultswap_db.private_ip_address
      db_name     = google_sql_database.vaultswap_database.name
      db_user     = google_sql_user.vaultswap_user.name
      db_password = random_password.db_password.result
    })
  }

  service_account {
    email  = google_service_account.vaultswap.email
    scopes = ["cloud-platform"]
  }

  tags = merge(var.tags, {
    Name = "${var.environment}-vaultswap-windows-${count.index + 1}"
    Type = "Compute Instance"
    OS   = "Windows"
  })
}

# Service Account
resource "google_service_account" "vaultswap" {
  account_id   = "${var.environment}-vaultswap-sa"
  display_name = "VaultSwap DEX Service Account"
  description  = "Service account for VaultSwap DEX ${var.environment} environment"
}

resource "google_project_iam_member" "vaultswap_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.vaultswap.email}"
}

resource "google_project_iam_member" "vaultswap_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.vaultswap.email}"
}

resource "google_project_iam_member" "vaultswap_sql" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.vaultswap.email}"
}

# Load Balancer
resource "google_compute_global_forwarding_rule" "vaultswap_lb" {
  name       = "${var.environment}-vaultswap-lb"
  target     = google_compute_target_http_proxy.vaultswap_proxy.id
  port_range = "80"
  ip_address = google_compute_global_address.vaultswap_ip.address
}

resource "google_compute_global_address" "vaultswap_ip" {
  name = "${var.environment}-vaultswap-ip"
}

resource "google_compute_target_http_proxy" "vaultswap_proxy" {
  name    = "${var.environment}-vaultswap-proxy"
  url_map = google_compute_url_map.vaultswap_url_map.id
}

resource "google_compute_url_map" "vaultswap_url_map" {
  name            = "${var.environment}-vaultswap-url-map"
  default_service = google_compute_backend_service.vaultswap_backend.id
}

resource "google_compute_backend_service" "vaultswap_backend" {
  name        = "${var.environment}-vaultswap-backend"
  protocol    = "HTTP"
  port_name   = "http"
  timeout_sec = 30

  health_checks = [google_compute_health_check.vaultswap_health.id]

  backend {
    group = google_compute_instance_group.vaultswap_group.id
  }
}

resource "google_compute_instance_group" "vaultswap_group" {
  name        = "${var.environment}-vaultswap-group"
  description = "VaultSwap DEX instance group"
  zone        = var.zone

  instances = concat(
    google_compute_instance.vaultswap_linux[*].id,
    google_compute_instance.vaultswap_windows[*].id
  )

  named_port {
    name = "http"
    port = "8080"
  }
}

resource "google_compute_health_check" "vaultswap_health" {
  name               = "${var.environment}-vaultswap-health"
  check_interval_sec = 30
  timeout_sec        = 5
  healthy_threshold  = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = "8080"
    request_path = "/health"
  }
}

# Monitoring
resource "google_monitoring_notification_channel" "email" {
  count = var.monitoring_level != "basic" ? 1 : 0

  display_name = "${var.environment}-email-notifications"
  type         = "email"
  
  labels = {
    email_address = "admin@vaultswap.com"
  }
}

resource "google_monitoring_alert_policy" "high_cpu" {
  count = var.monitoring_level != "basic" ? 1 : 0

  display_name = "${var.environment} High CPU Usage"
  combiner     = "OR"
  conditions {
    display_name = "CPU usage is high"
    condition_threshold {
      filter         = "resource.type=\"gce_instance\" AND resource.labels.instance_name=~\"${var.environment}-vaultswap-.*\""
      duration       = "300s"
      comparison     = "COMPARISON_GREATER_THAN"
      threshold_value = 0.8
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email[0].id]
}

# Outputs
output "project_id" {
  description = "GCP Project ID"
  value       = var.project_id
}

output "region" {
  description = "GCP region"
  value       = var.region
}

output "zone" {
  description = "GCP zone"
  value       = var.zone
}

output "network_name" {
  description = "VPC network name"
  value       = google_compute_network.vaultswap_vpc.name
}

output "subnet_name" {
  description = "Subnet name"
  value       = google_compute_subnetwork.vaultswap_subnet.name
}

output "instance_ids" {
  description = "Compute instance IDs"
  value = {
    linux   = google_compute_instance.vaultswap_linux[*].id
    windows = google_compute_instance.vaultswap_windows[*].id
  }
}

output "instance_ips" {
  description = "Compute instance IPs"
  value = {
    linux   = google_compute_instance.vaultswap_linux[*].network_interface[0].access_config[0].nat_ip
    windows = google_compute_instance.vaultswap_windows[*].network_interface[0].access_config[0].nat_ip
  }
}

output "database_connection_name" {
  description = "Cloud SQL connection name"
  value       = google_sql_database_instance.vaultswap_db.connection_name
}

output "database_private_ip" {
  description = "Cloud SQL private IP"
  value       = google_sql_database_instance.vaultswap_db.private_ip_address
}

output "load_balancer_ip" {
  description = "Load balancer IP address"
  value       = google_compute_global_address.vaultswap_ip.address
}

output "service_account_email" {
  description = "Service account email"
  value       = google_service_account.vaultswap.email
}

