# Reentrancy Attack Simulator Dockerfile
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    jq \
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy simulation scripts
COPY . .

# Create logs directory
RUN mkdir -p /app/logs

# Set permissions
RUN chmod +x /app/simulate_*.py

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python3 -c "import requests; requests.get('http://localhost:8083/health')" || exit 1

# Expose port for monitoring
EXPOSE 8083

# Default command
CMD ["python3", "reentrancy_simulator.py"]
