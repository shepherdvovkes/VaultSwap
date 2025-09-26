global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "rules/*.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'vaultswap-${environment}'
    static_configs:
      - targets: 
        - 'vaultswap-linux-1:8080'
        - 'vaultswap-linux-2:8080'
        - 'vaultswap-windows-1:8080'
        - 'vaultswap-windows-2:8080'
        - 'vaultswap-macos-1:8080'
        - 'vaultswap-macos-2:8080'
    metrics_path: '/metrics'
    scrape_interval: 30s

  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres:5432']
    metrics_path: '/metrics'

  - job_name: 'redis'
    static_configs:
      - targets: ['redis:6379']
    metrics_path: '/metrics'

  - job_name: 'nginx'
    static_configs:
      - targets: ['nginx:80']
    metrics_path: '/nginx_status'

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

