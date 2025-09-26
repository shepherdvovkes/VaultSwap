#!/bin/bash
# GCP Linux Startup Script for VaultSwap DEX Infrastructure
# Environment: ${environment}
# Region: ${region}

set -euo pipefail

# Logging
exec > >(tee /var/log/startup-script.log|logger -t startup-script -s 2>/dev/console) 2>&1

echo "Starting VaultSwap DEX Linux instance setup on GCP..."

# Update system
apt-get update
apt-get upgrade -y

# Install essential packages
apt-get install -y \
    curl \
    wget \
    git \
    unzip \
    htop \
    vim \
    jq \
    docker.io \
    docker-compose \
    nodejs \
    npm \
    python3 \
    python3-pip \
    postgresql-client \
    redis-tools \
    google-cloud-ops-agent

# Start and enable Docker
systemctl start docker
systemctl enable docker
usermod -a -G docker $USER

# Install Google Cloud SDK
curl https://sdk.cloud.google.com | bash
source ~/.bashrc

# Install Terraform
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
mv terraform /usr/local/bin/
rm terraform_1.6.0_linux_amd64.zip

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Configure environment variables
cat >> /etc/environment << EOF
export ENVIRONMENT=${environment}
export GCP_REGION=${region}
export NODE_ENV=production
export DATABASE_URL=postgresql://${db_user}:${db_password}@${db_host}:5432/${db_name}
export REDIS_URL=redis://localhost:6379
EOF

# Create application directory
mkdir -p /opt/vaultswap
chown $USER:$USER /opt/vaultswap

# Configure Google Cloud Ops Agent
cat > /etc/google-cloud-ops-agent/config.yaml << EOF
logging:
  receivers:
    vaultswap_app:
      type: files
      include_paths:
        - /opt/vaultswap/logs/*.log
      exclude_paths:
        - /opt/vaultswap/logs/*.gz
  processors:
    vaultswap_app:
      type: parse_json
      field: message
  service:
    pipelines:
      vaultswap_pipeline:
        receivers: [vaultswap_app]
        processors: [vaultswap_app]

metrics:
  receivers:
    vaultswap_metrics:
      type: hostmetrics
      collection_interval: 60s
  processors:
    vaultswap_metrics:
      type: metrics_filter
      exclude_metrics:
        matching: "system.network.io"
  service:
    pipelines:
      vaultswap_metrics_pipeline:
        receivers: [vaultswap_metrics]
        processors: [vaultswap_metrics]
EOF

# Start Google Cloud Ops Agent
systemctl start google-cloud-ops-agent
systemctl enable google-cloud-ops-agent

# Install security tools
apt-get install -y \
    fail2ban \
    ufw \
    clamav \
    rkhunter

# Configure fail2ban
cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 3
EOF

systemctl enable fail2ban
systemctl start fail2ban

# Configure firewall
ufw --force enable
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 8080/tcp

# Install development tools
apt-get install -y \
    build-essential \
    cmake \
    pkg-config \
    libssl-dev \
    libffi-dev \
    python3-dev

# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source ~/.cargo/env

# Install Node.js LTS
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt-get install -y nodejs

# Install global npm packages
npm install -g \
    yarn \
    pm2 \
    typescript \
    ts-node \
    nodemon \
    eslint \
    prettier

# Create systemd service for VaultSwap
cat > /etc/systemd/system/vaultswap.service << EOF
[Unit]
Description=VaultSwap DEX Service
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=/opt/vaultswap
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production
Environment=ENVIRONMENT=${environment}
Environment=DATABASE_URL=postgresql://${db_user}:${db_password}@${db_host}:5432/${db_name}

[Install]
WantedBy=multi-user.target
EOF

# Enable the service
systemctl daemon-reload
systemctl enable vaultswap

# Create health check script
cat > /opt/vaultswap/health-check.sh << 'EOF'
#!/bin/bash
# Health check script for VaultSwap DEX

# Check if the application is running
if ! pgrep -f "node server.js" > /dev/null; then
    echo "VaultSwap service is not running"
    exit 1
fi

# Check if the application is responding
if ! curl -f http://localhost:8080/health > /dev/null 2>&1; then
    echo "VaultSwap service is not responding"
    exit 1
fi

echo "VaultSwap service is healthy"
exit 0
EOF

chmod +x /opt/vaultswap/health-check.sh

# Create monitoring script
cat > /opt/vaultswap/monitor.sh << 'EOF'
#!/bin/bash
# Monitoring script for VaultSwap DEX

# CPU usage
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}')

# Memory usage
MEM_USAGE=$(free | grep Mem | awk '{printf("%.2f"), $3/$2 * 100.0}')

# Disk usage
DISK_USAGE=$(df -h / | awk 'NR==2{printf "%s", $5}' | sed 's/%//')

# Log metrics
echo "$(date): CPU: ${CPU_USAGE}%, Memory: ${MEM_USAGE}%, Disk: ${DISK_USAGE}%" >> /var/log/vaultswap-metrics.log

# Send to Google Cloud Monitoring
if command -v gcloud > /dev/null; then
    gcloud logging write vaultswap-metrics \
        "CPU: ${CPU_USAGE}%, Memory: ${MEM_USAGE}%, Disk: ${DISK_USAGE}%" \
        --severity=INFO
fi
EOF

chmod +x /opt/vaultswap/monitor.sh

# Set up cron job for monitoring
echo "*/5 * * * * /opt/vaultswap/monitor.sh" | crontab -u $USER -

# Create log rotation configuration
cat > /etc/logrotate.d/vaultswap << EOF
/opt/vaultswap/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 $USER $USER
    postrotate
        systemctl reload vaultswap
    endscript
}
EOF

# Set up automatic security updates
apt-get install -y unattended-upgrades
echo 'Unattended-Upgrade::Automatic-Reboot "false";' >> /etc/apt/apt.conf.d/50unattended-upgrades

# Final system configuration
echo "VaultSwap DEX Linux instance setup completed successfully!"
echo "Environment: ${environment}"
echo "Region: ${region}"
echo "Instance ready for VaultSwap DEX deployment"

# Signal completion
touch /var/log/startup-script-complete

