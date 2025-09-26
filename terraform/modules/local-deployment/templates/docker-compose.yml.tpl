version: '3.8'

services:
  # PostgreSQL Database
  postgres:
    image: postgres:15-alpine
    container_name: ${environment}-postgres
    environment:
      POSTGRES_DB: vaultswap
      POSTGRES_USER: vaultswap
      POSTGRES_PASSWORD: ${postgres_password}
      POSTGRES_INITDB_ARGS: "--encoding=UTF-8 --lc-collate=C --lc-ctype=C"
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - ${network_name}
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U vaultswap -d vaultswap"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Redis Cache
  redis:
    image: redis:7-alpine
    container_name: ${environment}-redis
    command: redis-server --requirepass ${redis_password}
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    networks:
      - ${network_name}
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3

  # VaultSwap Application - Linux
  %{ if contains(operating_systems, "linux") ~}
  vaultswap-linux-1:
    build:
      context: ../../
      dockerfile: Dockerfile.linux
    container_name: ${environment}-vaultswap-linux-1
    environment:
      NODE_ENV: production
      ENVIRONMENT: ${environment}
      DATABASE_URL: postgresql://vaultswap:${postgres_password}@postgres:5432/vaultswap
      REDIS_URL: redis://:${redis_password}@redis:6379
      PORT: 8080
    ports:
      - "8080:8080"
    networks:
      - ${network_name}
    restart: unless-stopped
    depends_on:
      - postgres
      - redis
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  vaultswap-linux-2:
    build:
      context: ../../
      dockerfile: Dockerfile.linux
    container_name: ${environment}-vaultswap-linux-2
    environment:
      NODE_ENV: production
      ENVIRONMENT: ${environment}
      DATABASE_URL: postgresql://vaultswap:${postgres_password}@postgres:5432/vaultswap
      REDIS_URL: redis://:${redis_password}@redis:6379
      PORT: 8080
    ports:
      - "8081:8080"
    networks:
      - ${network_name}
    restart: unless-stopped
    depends_on:
      - postgres
      - redis
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
  %{ endif ~}

  # VaultSwap Application - Windows
  %{ if contains(operating_systems, "windows") ~}
  vaultswap-windows-1:
    build:
      context: ../../
      dockerfile: Dockerfile.windows
    container_name: ${environment}-vaultswap-windows-1
    environment:
      NODE_ENV: production
      ENVIRONMENT: ${environment}
      DATABASE_URL: postgresql://vaultswap:${postgres_password}@postgres:5432/vaultswap
      REDIS_URL: redis://:${redis_password}@redis:6379
      PORT: 8080
    ports:
      - "8090:8080"
    networks:
      - ${network_name}
    restart: unless-stopped
    depends_on:
      - postgres
      - redis

  vaultswap-windows-2:
    build:
      context: ../../
      dockerfile: Dockerfile.windows
    container_name: ${environment}-vaultswap-windows-2
    environment:
      NODE_ENV: production
      ENVIRONMENT: ${environment}
      DATABASE_URL: postgresql://vaultswap:${postgres_password}@postgres:5432/vaultswap
      REDIS_URL: redis://:${redis_password}@redis:6379
      PORT: 8080
    ports:
      - "8091:8080"
    networks:
      - ${network_name}
    restart: unless-stopped
    depends_on:
      - postgres
      - redis
  %{ endif ~}

  # VaultSwap Application - macOS
  %{ if contains(operating_systems, "macos") ~}
  vaultswap-macos-1:
    build:
      context: ../../
      dockerfile: Dockerfile.macos
    container_name: ${environment}-vaultswap-macos-1
    environment:
      NODE_ENV: production
      ENVIRONMENT: ${environment}
      DATABASE_URL: postgresql://vaultswap:${postgres_password}@postgres:5432/vaultswap
      REDIS_URL: redis://:${redis_password}@redis:6379
      PORT: 8080
    ports:
      - "8100:8080"
    networks:
      - ${network_name}
    restart: unless-stopped
    depends_on:
      - postgres
      - redis

  vaultswap-macos-2:
    build:
      context: ../../
      dockerfile: Dockerfile.macos
    container_name: ${environment}-vaultswap-macos-2
    environment:
      NODE_ENV: production
      ENVIRONMENT: ${environment}
      DATABASE_URL: postgresql://vaultswap:${postgres_password}@postgres:5432/vaultswap
      REDIS_URL: redis://:${redis_password}@redis:6379
      PORT: 8080
    ports:
      - "8101:8080"
    networks:
      - ${network_name}
    restart: unless-stopped
    depends_on:
      - postgres
      - redis
  %{ endif ~}

  # Load Balancer
  nginx:
    image: nginx:alpine
    container_name: ${environment}-nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./config/nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./config/nginx/ssl:/etc/nginx/ssl:ro
    networks:
      - ${network_name}
    restart: unless-stopped
    depends_on:
      - vaultswap-linux-1
      - vaultswap-linux-2
      - vaultswap-windows-1
      - vaultswap-windows-2
      - vaultswap-macos-1
      - vaultswap-macos-2

  # Monitoring Stack
  %{ if monitoring_level != "basic" ~}
  prometheus:
    image: prom/prometheus:latest
    container_name: ${environment}-prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./config/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus_data:/prometheus
    networks:
      - ${network_name}
    restart: unless-stopped
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'

  node-exporter:
    image: prom/node-exporter:latest
    container_name: ${environment}-node-exporter
    ports:
      - "9100:9100"
    networks:
      - ${network_name}
    restart: unless-stopped
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
  %{ endif ~}

  %{ if monitoring_level == "comprehensive" ~}
  grafana:
    image: grafana/grafana:latest
    container_name: ${environment}-grafana
    ports:
      - "3000:3000"
    environment:
      GF_SECURITY_ADMIN_PASSWORD: ${monitoring_password}
      GF_USERS_ALLOW_SIGN_UP: false
    volumes:
      - grafana_data:/var/lib/grafana
      - ./config/grafana/provisioning:/etc/grafana/provisioning:ro
    networks:
      - ${network_name}
    restart: unless-stopped
    depends_on:
      - prometheus

  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.8.0
    container_name: ${environment}-elasticsearch
    environment:
      discovery.type: single-node
      xpack.security.enabled: false
      ES_JAVA_OPTS: "-Xms512m -Xmx512m"
    ports:
      - "9200:9200"
    volumes:
      - elasticsearch_data:/usr/share/elasticsearch/data
    networks:
      - ${network_name}
    restart: unless-stopped

  kibana:
    image: docker.elastic.co/kibana/kibana:8.8.0
    container_name: ${environment}-kibana
    environment:
      ELASTICSEARCH_HOSTS: http://elasticsearch:9200
    ports:
      - "5601:5601"
    networks:
      - ${network_name}
    restart: unless-stopped
    depends_on:
      - elasticsearch
  %{ endif ~}

volumes:
  postgres_data:
  redis_data:
  prometheus_data:
  grafana_data:
  elasticsearch_data:

networks:
  ${network_name}:
    external: true

