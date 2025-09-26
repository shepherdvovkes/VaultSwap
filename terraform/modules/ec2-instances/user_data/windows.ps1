# Windows User Data Script for VaultSwap DEX Infrastructure
# Environment: ${environment}
# Region: ${region}

# Set execution policy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force

# Enable logging
Start-Transcript -Path "C:\ProgramData\Amazon\EC2-Windows\Launch\Log\UserDataExecution.log" -Append

Write-Host "Starting VaultSwap DEX Windows instance setup..."

# Update Windows
Write-Host "Updating Windows..."
Install-Module -Name PSWindowsUpdate -Force
Get-WindowsUpdate -AcceptAll -Install -AutoReboot

# Install Chocolatey
Write-Host "Installing Chocolatey..."
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install essential packages
Write-Host "Installing essential packages..."
choco install -y git
choco install -y curl
choco install -y wget
choco install -y 7zip
choco install -y vscode
choco install -y nodejs
choco install -y python
choco install -y golang
choco install -y rust
choco install -y docker-desktop
choco install -y postgresql
choco install -y redis-64
choco install -y awscli
choco install -y terraform
choco install -y kubectl
choco install -y helm

# Install AWS CLI v2
Write-Host "Installing AWS CLI v2..."
$awsCliUrl = "https://awscli.amazonaws.com/AWSCLIV2.msi"
$awsCliPath = "$env:TEMP\AWSCLIV2.msi"
Invoke-WebRequest -Uri $awsCliUrl -OutFile $awsCliPath
Start-Process -FilePath "msiexec.exe" -ArgumentList "/i $awsCliPath /quiet" -Wait

# Install Docker Desktop
Write-Host "Installing Docker Desktop..."
$dockerUrl = "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
$dockerPath = "$env:TEMP\DockerDesktopInstaller.exe"
Invoke-WebRequest -Uri $dockerUrl -OutFile $dockerPath
Start-Process -FilePath $dockerPath -ArgumentList "install --quiet" -Wait

# Install Node.js LTS
Write-Host "Installing Node.js LTS..."
$nodeUrl = "https://nodejs.org/dist/v18.17.0/node-v18.17.0-x64.msi"
$nodePath = "$env:TEMP\node-v18.17.0-x64.msi"
Invoke-WebRequest -Uri $nodeUrl -OutFile $nodePath
Start-Process -FilePath "msiexec.exe" -ArgumentList "/i $nodePath /quiet" -Wait

# Install Python
Write-Host "Installing Python..."
$pythonUrl = "https://www.python.org/ftp/python/3.11.4/python-3.11.4-amd64.exe"
$pythonPath = "$env:TEMP\python-3.11.4-amd64.exe"
Invoke-WebRequest -Uri $pythonUrl -OutFile $pythonPath
Start-Process -FilePath $pythonPath -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1" -Wait

# Install Rust
Write-Host "Installing Rust..."
$rustUrl = "https://win.rustup.rs/x86_64"
$rustPath = "$env:TEMP\rustup-init.exe"
Invoke-WebRequest -Uri $rustUrl -OutFile $rustPath
Start-Process -FilePath $rustPath -ArgumentList "-y" -Wait

# Install Go
Write-Host "Installing Go..."
$goUrl = "https://go.dev/dl/go1.21.0.windows-amd64.msi"
$goPath = "$env:TEMP\go1.21.0.windows-amd64.msi"
Invoke-WebRequest -Uri $goUrl -OutFile $goPath
Start-Process -FilePath "msiexec.exe" -ArgumentList "/i $goPath /quiet" -Wait

# Install Terraform
Write-Host "Installing Terraform..."
$terraformUrl = "https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_windows_amd64.zip"
$terraformPath = "$env:TEMP\terraform.zip"
$terraformDir = "C:\terraform"
Invoke-WebRequest -Uri $terraformUrl -OutFile $terraformPath
Expand-Archive -Path $terraformPath -DestinationPath $terraformDir -Force
$env:PATH += ";$terraformDir"

# Install kubectl
Write-Host "Installing kubectl..."
$kubectlUrl = "https://dl.k8s.io/release/v1.28.0/bin/windows/amd64/kubectl.exe"
$kubectlPath = "C:\kubectl\kubectl.exe"
New-Item -ItemType Directory -Path "C:\kubectl" -Force
Invoke-WebRequest -Uri $kubectlUrl -OutFile $kubectlPath
$env:PATH += ";C:\kubectl"

# Install Helm
Write-Host "Installing Helm..."
$helmUrl = "https://get.helm.sh/helm-v3.12.0-windows-amd64.zip"
$helmPath = "$env:TEMP\helm.zip"
$helmDir = "C:\helm"
Invoke-WebRequest -Uri $helmUrl -OutFile $helmPath
Expand-Archive -Path $helmPath -DestinationPath $helmDir -Force
$env:PATH += ";$helmDir"

# Configure environment variables
Write-Host "Configuring environment variables..."
[Environment]::SetEnvironmentVariable("ENVIRONMENT", "${environment}", "Machine")
[Environment]::SetEnvironmentVariable("AWS_REGION", "${region}", "Machine")
[Environment]::SetEnvironmentVariable("NODE_ENV", "production", "Machine")
[Environment]::SetEnvironmentVariable("DOCKER_BUILDKIT", "1", "Machine")

# Create application directory
Write-Host "Creating application directory..."
$appDir = "C:\VaultSwap"
New-Item -ItemType Directory -Path $appDir -Force

# Install monitoring tools
Write-Host "Installing monitoring tools..."
choco install -y amazon-cloudwatch-agent

# Configure CloudWatch agent
$cloudWatchConfig = @"
{
    "agent": {
        "metrics_collection_interval": 60,
        "run_as_user": "SYSTEM"
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
"@

$cloudWatchConfig | Out-File -FilePath "C:\Program Files\Amazon\AmazonCloudWatchAgent\amazon-cloudwatch-agent.json" -Encoding UTF8

# Start CloudWatch agent
Start-Service "AmazonCloudWatchAgent"

# Install security tools
Write-Host "Installing security tools..."
choco install -y windows-defender
choco install -y malwarebytes

# Configure Windows Firewall
Write-Host "Configuring Windows Firewall..."
New-NetFirewallRule -DisplayName "VaultSwap HTTP" -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow
New-NetFirewallRule -DisplayName "VaultSwap HTTPS" -Direction Inbound -Protocol TCP -LocalPort 443 -Action Allow
New-NetFirewallRule -DisplayName "VaultSwap App" -Direction Inbound -Protocol TCP -LocalPort 8080 -Action Allow
New-NetFirewallRule -DisplayName "VaultSwap Monitoring" -Direction Inbound -Protocol TCP -LocalPort 9090 -Action Allow
New-NetFirewallRule -DisplayName "VaultSwap Grafana" -Direction Inbound -Protocol TCP -LocalPort 3000 -Action Allow

# Install development tools
Write-Host "Installing development tools..."
choco install -y visualstudio2019buildtools
choco install -y cmake
choco install -y ninja
choco install -y nasm
choco install -y yasm

# Install global npm packages
Write-Host "Installing global npm packages..."
npm install -g yarn
npm install -g pm2
npm install -g typescript
npm install -g ts-node
npm install -g nodemon
npm install -g eslint
npm install -g prettier

# Create Windows service for VaultSwap
Write-Host "Creating Windows service..."
$serviceScript = @"
@echo off
cd /d C:\VaultSwap
node server.js
"@

$serviceScript | Out-File -FilePath "C:\VaultSwap\start-vaultswap.bat" -Encoding ASCII

# Install NSSM (Non-Sucking Service Manager)
choco install -y nssm

# Create the service
nssm install VaultSwap "C:\VaultSwap\start-vaultswap.bat"
nssm set VaultSwap DisplayName "VaultSwap DEX Service"
nssm set VaultSwap Description "VaultSwap DEX Service for ${environment}"
nssm set VaultSwap Start SERVICE_AUTO_START
nssm start VaultSwap

# Create health check script
$healthCheckScript = @"
@echo off
REM Health check script for VaultSwap DEX

REM Check if the application is running
tasklist /FI "IMAGENAME eq node.exe" 2>NUL | find /I /N "node.exe" >NUL
if "%ERRORLEVEL%"=="0" (
    echo VaultSwap service is running
) else (
    echo VaultSwap service is not running
    exit /b 1
)

REM Check if the application is responding
curl -f http://localhost:8080/health >NUL 2>&1
if "%ERRORLEVEL%"=="0" (
    echo VaultSwap service is healthy
    exit /b 0
) else (
    echo VaultSwap service is not responding
    exit /b 1
)
"@

$healthCheckScript | Out-File -FilePath "C:\VaultSwap\health-check.bat" -Encoding ASCII

# Create monitoring script
$monitorScript = @"
@echo off
REM Monitoring script for VaultSwap DEX

REM Get system metrics
for /f "tokens=2 delims=," %%a in ('wmic cpu get loadpercentage /value ^| find "="') do set CPU_USAGE=%%a
for /f "tokens=2 delims=," %%a in ('wmic OS get TotalVisibleMemorySize /value ^| find "="') do set TOTAL_MEM=%%a
for /f "tokens=2 delims=," %%a in ('wmic OS get FreePhysicalMemory /value ^| find "="') do set FREE_MEM=%%a

REM Calculate memory usage
set /a MEM_USAGE=100-((%FREE_MEM%*100)/%TOTAL_MEM%)

REM Get disk usage
for /f "tokens=3" %%a in ('dir /-c C:\ ^| find "bytes free"') do set DISK_FREE=%%a
for /f "tokens=1" %%a in ('dir /-c C:\ ^| find "bytes free"') do set DISK_TOTAL=%%a
set /a DISK_USAGE=100-((%DISK_FREE%*100)/%DISK_TOTAL%)

REM Log metrics
echo %date% %time%: CPU: %CPU_USAGE%%, Memory: %MEM_USAGE%%, Disk: %DISK_USAGE%% >> C:\VaultSwap\metrics.log

REM Send to CloudWatch (if configured)
if exist "C:\Program Files\Amazon\AWSCLIV2\aws.exe" (
    "C:\Program Files\Amazon\AWSCLIV2\aws.exe" cloudwatch put-metric-data --namespace "VaultSwap/${environment}" --metric-data MetricName=CPUUsage,Value=%CPU_USAGE%,Unit=Percent --region ${region}
)
"@

$monitorScript | Out-File -FilePath "C:\VaultSwap\monitor.bat" -Encoding ASCII

# Set up scheduled task for monitoring
$action = New-ScheduledTaskAction -Execute "C:\VaultSwap\monitor.bat"
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration (New-TimeSpan -Days 365)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName "VaultSwapMonitor" -Action $action -Trigger $trigger -Settings $settings

# Configure log rotation
Write-Host "Configuring log rotation..."
$logRotationScript = @"
@echo off
REM Log rotation script for VaultSwap DEX

REM Rotate logs older than 30 days
forfiles /p C:\VaultSwap\logs /s /m *.log /d -30 /c "cmd /c del @path"

REM Compress logs older than 7 days
forfiles /p C:\VaultSwap\logs /s /m *.log /d -7 /c "cmd /c powershell Compress-Archive -Path @path -DestinationPath @path.zip -Force && del @path"
"@

$logRotationScript | Out-File -FilePath "C:\VaultSwap\log-rotation.bat" -Encoding ASCII

# Set up scheduled task for log rotation
$logAction = New-ScheduledTaskAction -Execute "C:\VaultSwap\log-rotation.bat"
$logTrigger = New-ScheduledTaskTrigger -Daily -At 2AM
$logSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName "VaultSwapLogRotation" -Action $logAction -Trigger $logTrigger -Settings $logSettings

# Final system configuration
Write-Host "VaultSwap DEX Windows instance setup completed successfully!"
Write-Host "Environment: ${environment}"
Write-Host "Region: ${region}"
Write-Host "Instance ready for VaultSwap DEX deployment"

# Signal completion
New-Item -ItemType File -Path "C:\ProgramData\Amazon\EC2-Windows\Launch\Log\UserDataComplete.flag" -Force

# Stop logging
Stop-Transcript
