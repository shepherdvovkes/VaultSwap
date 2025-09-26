#!/bin/bash
# macOS User Data Script for VaultSwap DEX Infrastructure
# Environment: ${environment}
# Region: ${region}

set -euo pipefail

# Logging
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting VaultSwap DEX macOS instance setup..."

# Update system
softwareupdate --install --all --agree-to-license

# Install Xcode Command Line Tools
xcode-select --install

# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add Homebrew to PATH
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"

# Install essential packages
brew install \
    git \
    curl \
    wget \
    unzip \
    htop \
    vim \
    jq \
    docker \
    docker-compose \
    node \
    npm \
    python3 \
    pipenv \
    go \
    rust \
    postgresql \
    redis \
    awscli \
    terraform \
    kubectl \
    helm

# Install Docker Desktop
brew install --cask docker

# Start Docker
open -a Docker

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /
rm AWSCLIV2.pkg

# Install Terraform
brew install terraform

# Install kubectl
brew install kubectl

# Install Helm
brew install helm

# Configure environment variables
cat >> ~/.zshrc << EOF
export ENVIRONMENT=${environment}
export AWS_REGION=${region}
export NODE_ENV=production
export DOCKER_BUILDKIT=1
EOF

# Create application directory
mkdir -p /opt/vaultswap
sudo chown $(whoami):staff /opt/vaultswap

# Install monitoring tools
brew install amazon-cloudwatch-agent

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
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
    -s

# Install security tools
brew install \
    fail2ban \
    clamav \
    rkhunter

# Configure fail2ban
sudo cp /opt/homebrew/etc/fail2ban/jail.conf /opt/homebrew/etc/fail2ban/jail.local

cat >> /opt/homebrew/etc/fail2ban/jail.local << EOF
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

sudo brew services start fail2ban

# Configure firewall
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /usr/local/bin/node
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /opt/homebrew/bin/node

# Install development tools
xcode-select --install

# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source ~/.cargo/env

# Install Node.js LTS
brew install node

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
sudo sysctl vm.swappiness=10
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf

# Configure system limits
sudo launchctl limit maxfiles 65536 65536
echo 'kern.maxfiles=65536' | sudo tee -a /etc/sysctl.conf
echo 'kern.maxfilesperproc=65536' | sudo tee -a /etc/sysctl.conf

# Create launchd service for VaultSwap
cat > ~/Library/LaunchAgents/com.vaultswap.dex.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.vaultswap.dex</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/node</string>
        <string>/opt/vaultswap/server.js</string>
    </array>
    <key>WorkingDirectory</key>
    <string>/opt/vaultswap</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>EnvironmentVariables</key>
    <dict>
        <key>NODE_ENV</key>
        <string>production</string>
        <key>ENVIRONMENT</key>
        <string>${environment}</string>
    </dict>
</dict>
</plist>
EOF

# Load the service
launchctl load ~/Library/LaunchAgents/com.vaultswap.dex.plist

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
cat > /opt/vaultswap/logrotate.conf << EOF
/opt/vaultswap/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 $(whoami) staff
    postrotate
        launchctl unload ~/Library/LaunchAgents/com.vaultswap.dex.plist
        launchctl load ~/Library/LaunchAgents/com.vaultswap.dex.plist
    endscript
}
EOF

# Set up automatic security updates
sudo softwareupdate --schedule on

# Configure log aggregation
brew install rsyslog
sudo brew services start rsyslog

# Create monitoring script
cat > /opt/vaultswap/monitor.sh << 'EOF'
#!/bin/bash
# Monitoring script for VaultSwap DEX

# CPU usage
CPU_USAGE=$(top -l 1 | grep "CPU usage" | awk '{print $3}' | sed 's/%//')

# Memory usage
MEM_USAGE=$(top -l 1 | grep "PhysMem" | awk '{print $2}' | sed 's/M//')

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
echo "*/5 * * * * /opt/vaultswap/monitor.sh" | crontab -

# Final system configuration
echo "VaultSwap DEX macOS instance setup completed successfully!"
echo "Environment: ${environment}"
echo "Region: ${region}"
echo "Instance ready for VaultSwap DEX deployment"

# Signal completion
touch /var/log/user-data-complete
