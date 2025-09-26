# Terraform Version Constraints
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    # AWS Provider
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    
    # Azure Provider
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    
    # Google Cloud Provider
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
    
    # Local Provider
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    
    # Null Provider
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    
    # Docker Provider
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    
    # TLS Provider
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    
    # Random Provider
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
    
    # Helm Provider
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    
    # Kubernetes Provider
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    
    # ACME Provider
    acme = {
      source  = "vancluever/acme"
      version = "~> 2.0"
    }
  }
}
