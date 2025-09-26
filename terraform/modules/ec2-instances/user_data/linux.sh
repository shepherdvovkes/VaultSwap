#!/bin/bash
# Linux User Data Script for VaultSwap DEX Infrastructure
# Environment: ${environment}
# Region: ${region}

set -euo pipefail

# Logging
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting VaultSwap DEX Linux instance setup..."

# Update system
yum update -y

# Install essential packages
yum install -y \
    git \
    curl \
    wget \
    unzip \
    htop \
    vim \
    jq \
    docker \
    docker-compose \
    nodejs \
    npm \
    python3 \
    python3-pip \
    golang \
    rust \
    postgresql-client \
    redis-tools

# Start and enable Docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

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
export AWS_REGION=${region}
export NODE_ENV=production
export DOCKER_BUILDKIT=1
EOF

# Create application directory
mkdir -p /opt/vaultswap
chown ec2-user:ec2-user /opt/vaultswap

# Install monitoring tools
yum install -y amazon-cloudwatch-agent

# Configure CloudWatch agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << EOF
{
    "agent": {
        "metrics_collection_interval": 60,
        "run_as_user": "root"
    },
    "metrics": {
        "namespace": "VaultSwap/${environment}",
        "metrics_collected": {
            "cpu": {
                "measurement": [
                    "cpu_usage_idle",
                    "cpu_usage_iowait",
                    "cpu_usage_user",
                    "cpu_usage_system"
                ],
                "metrics_collection_interval": 60,
                "totalcpu": false
            },
            "disk": {
                "measurement": [
                    "used_percent"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "diskio": {
                "measurement": [
                    "io_time"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "mem": {
                "measurement": [
                    "mem_used_percent"
                ],
                "metrics_collection_interval": 60
            }
        }
    }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
    -s

# Install security tools
yum install -y \
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
logpath = /var/log/secure
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
ufw allow 9090/tcp
ufw allow 3000/tcp

# Install development tools
yum groupinstall -y "Development Tools"
yum install -y \
    gcc \
    gcc-c++ \
    make \
    cmake \
    autoconf \
    automake \
    libtool \
    pkgconfig

# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source ~/.cargo/env

# Install Node.js LTS
curl -fsSL https://rpm.nodesource.com/setup_lts.x | bash -
yum install -y nodejs

# Install global npm packages
npm install -g \
    yarn \
    pm2 \
    typescript \
    ts-node \
    nodemon \
    eslint \
    prettier

# Create swap file
dd if=/dev/zero of=/swapfile bs=1M count=2048
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab

# Configure system limits
cat >> /etc/security/limits.conf << EOF
* soft nofile 65536
* hard nofile 65536
* soft nproc 65536
* hard nproc 65536
EOF

# Configure kernel parameters
cat >> /etc/sysctl.conf << EOF
vm.swappiness = 10
vm.max_map_count = 262144
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
EOF

sysctl -p

# Create systemd service for VaultSwap
cat > /etc/systemd/system/vaultswap.service << EOF
[Unit]
Description=VaultSwap DEX Service
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/vaultswap
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production
Environment=ENVIRONMENT=${environment}

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

# Create log rotation configuration
cat > /etc/logrotate.d/vaultswap << EOF
/opt/vaultswap/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 ec2-user ec2-user
    postrotate
        systemctl reload vaultswap
    endscript
}
EOF

# Set up automatic security updates
yum install -y yum-cron
systemctl enable yum-cron
systemctl start yum-cron

# Configure log aggregation
yum install -y rsyslog
systemctl enable rsyslog
systemctl start rsyslog

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

# Send to CloudWatch (if configured)
if command -v aws > /dev/null; then
    aws cloudwatch put-metric-data \
        --namespace "VaultSwap/${environment}" \
        --metric-data MetricName=CPUUsage,Value=${CPU_USAGE},Unit=Percent \
        --region ${region}
fi
EOF

chmod +x /opt/vaultswap/monitor.sh

# Set up cron job for monitoring
echo "*/5 * * * * /opt/vaultswap/monitor.sh" | crontab -u ec2-user -

# Final system configuration
echo "VaultSwap DEX Linux instance setup completed successfully!"
echo "Environment: ${environment}"
echo "Region: ${region}"
echo "Instance ready for VaultSwap DEX deployment"

# Signal completion
touch /var/log/user-data-complete
