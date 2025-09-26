# DEX Attack Simulation Environment

A comprehensive Terraform-based attack simulation environment for testing DEX security measures against various attack vectors including MEV attacks, flash loan attacks, and oracle manipulation.

## 🎯 Overview

This environment provides a complete testing infrastructure to validate the security measures outlined in the Secure DEX Development Plan. It simulates real-world attack scenarios to test the effectiveness of security implementations.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Attack Simulation Environment            │
├─────────────────────────────────────────────────────────────┤
│  MEV Attacks          │  Flash Loan Attacks  │  Oracle Attacks │
│  - Sandwich           │  - Price Manipulation │  - Price Flash   │
│  - Front Running      │  - Arbitrage Exploit  │  - Oracle Delay  │
│  - Back Running       │  - Liquidity Drain    │  - Cross-Chain   │
│  - Arbitrage          │  - Governance Attack  │  - Governance    │
├─────────────────────────────────────────────────────────────┤
│                    Monitoring & Logging                     │
│  - Prometheus         │  - Grafana           │  - Elasticsearch │
│  - AlertManager       │  - Kibana            │  - Custom Dashboards │
├─────────────────────────────────────────────────────────────┤
│                    Security Testing                         │
│  - Automated Tests    │  - Performance Tests │  - Response Time │
│  - Throughput Tests   │  - Scalability Tests │  - Health Checks │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 Quick Start

### Prerequisites

- Docker and Docker Compose
- Python 3.11+
- Terraform 1.0+
- Linux environment (tested on Ubuntu 20.04+)

### Installation

1. **Clone and Setup**
   ```bash
   cd /home/vovkes/VaultSwap/terraform
   terraform init
   ```

2. **Deploy Infrastructure**
   ```bash
   terraform apply
   ```

3. **Start Attack Simulation Environment**
   ```bash
   docker-compose up -d
   ```

4. **Run Attack Simulations**
   ```bash
   ./attack-simulations/scripts/run_attack_simulation.sh
   ```

## 📊 Monitoring Dashboards

Once deployed, access the monitoring dashboards:

- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000 (admin/admin)
- **Elasticsearch**: http://localhost:9200
- **Kibana**: http://localhost:5601

## 🔧 Configuration

### Attack Simulation Configuration

Each attack type has its own configuration file:

- **MEV Attacks**: `attack-simulations/mev-attacks/config.json`
- **Flash Loan Attacks**: `attack-simulations/flash-loan-attacks/config.json`
- **Oracle Manipulation**: `attack-simulations/oracle-manipulation/config.json`

### Monitoring Configuration

- **Prometheus**: `attack-simulations/monitoring/prometheus.yml`
- **Grafana**: `attack-simulations/monitoring/grafana-dashboard.json`
- **AlertManager**: `attack-simulations/monitoring/alertmanager.yml`

## 🧪 Testing

### Automated Security Tests

Run comprehensive security tests:

```bash
python3 attack-simulations/scripts/security_test_runner.py --config config.json
```

### Performance Tests

Test system performance under attack load:

```bash
python3 attack-simulations/scripts/performance_test.py --duration 60 --concurrent 10
```

### Response Time Tests

Test attack detection response times:

```bash
python3 attack-simulations/scripts/response_time_test.py --test-count 100 --concurrent 10
```

### Throughput Tests

Test system throughput capabilities:

```bash
python3 attack-simulations/scripts/throughput_test.py --duration 60 --concurrent 20
```

## 📈 Attack Types

### MEV Attacks

1. **Sandwich Attacks**
   - Front-running victim transactions
   - Back-running for profit
   - Price manipulation detection

2. **Front-Running Attacks**
   - Transaction ordering manipulation
   - Gas price optimization
   - Mempool monitoring

3. **Arbitrage Attacks**
   - Cross-pool price differences
   - Flash loan arbitrage
   - Market inefficiency exploitation

### Flash Loan Attacks

1. **Price Manipulation**
   - Large flash loan amounts
   - Price impact exploitation
   - Liquidity pool manipulation

2. **Arbitrage Exploitation**
   - Cross-exchange arbitrage
   - Price difference exploitation
   - Risk-free profit extraction

3. **Liquidity Drain**
   - Pool liquidity extraction
   - Token value manipulation
   - Economic attack simulation

4. **Governance Attacks**
   - Voting power manipulation
   - Proposal exploitation
   - Governance token attacks

### Oracle Manipulation

1. **Price Flash Loan Attacks**
   - Oracle price manipulation
   - Flash loan price impact
   - Consensus mechanism testing

2. **Oracle Delay Exploits**
   - Stale price exploitation
   - Time-based attacks
   - Update frequency manipulation

3. **Cross-Chain Manipulation**
   - Multi-chain oracle attacks
   - Bridge price manipulation
   - Cross-chain consensus testing

4. **Governance Oracle Attacks**
   - Oracle parameter manipulation
   - Governance-based attacks
   - System configuration exploitation

## 📊 Metrics and Monitoring

### Key Metrics

- **Attack Success Rate**: Percentage of successful attacks
- **Detection Time**: Time to detect and respond to attacks
- **System Performance**: CPU, memory, and network usage
- **Throughput**: Attacks per second capacity
- **Response Time**: System response times under load

### Alerting

The system includes comprehensive alerting for:

- High attack success rates
- System resource exhaustion
- Service availability issues
- Security event detection
- Performance degradation

## 🔒 Security Features

### Attack Detection

- Real-time attack pattern recognition
- Machine learning-based detection
- Statistical anomaly detection
- Behavioral analysis

### Protection Mechanisms

- Rate limiting and throttling
- Economic attack prevention
- Oracle consensus validation
- MEV protection algorithms

### Monitoring and Alerting

- 24/7 security monitoring
- Automated incident response
- Real-time alerting
- Comprehensive logging

## 📝 Usage Examples

### Running MEV Attack Simulation

```bash
# Start MEV simulation
python3 attack-simulations/mev-attacks/mev_simulator.py \
    --config attack-simulations/mev-attacks/config.json \
    --monitoring

# Run specific MEV attack
python3 attack-simulations/mev-attacks/simulate_sandwich_attack.py \
    --config attack-simulations/mev-attacks/config.json \
    --duration 30
```

### Running Flash Loan Attack Simulation

```bash
# Start flash loan simulation
python3 attack-simulations/flash-loan-attacks/flash_loan_simulator.py \
    --config attack-simulations/flash-loan-attacks/config.json \
    --monitoring

# Run specific flash loan attack
python3 attack-simulations/flash-loan-attacks/simulate_price_manipulation_attack.py \
    --config attack-simulations/flash-loan-attacks/config.json
```

### Running Oracle Attack Simulation

```bash
# Start oracle simulation
python3 attack-simulations/oracle-manipulation/oracle_simulator.py \
    --config attack-simulations/oracle-manipulation/config.json \
    --monitoring

# Run specific oracle attack
python3 attack-simulations/oracle-manipulation/simulate_price_flash_loan_attack.py \
    --config attack-simulations/oracle-manipulation/config.json
```

## 🛠️ Development

### Adding New Attack Types

1. Create new attack simulation script
2. Add configuration to Terraform
3. Update monitoring dashboards
4. Add security tests
5. Update documentation

### Customizing Tests

Modify test parameters in the configuration files:

```json
{
  "simulation_config": {
    "bot_count": 10,
    "attack_frequency": "high",
    "target_pools": ["USDC/USDT", "SOL/USDC"],
    "simulation_duration": "24h"
  }
}
```

## 📋 Troubleshooting

### Common Issues

1. **Docker containers not starting**
   - Check Docker daemon status
   - Verify port availability
   - Check resource constraints

2. **Attack simulations failing**
   - Check Python dependencies
   - Verify configuration files
   - Check system resources

3. **Monitoring not working**
   - Verify service connectivity
   - Check configuration files
   - Restart monitoring services

### Logs

Check logs in the following locations:

- **Attack Simulations**: `attack-simulations/logs/`
- **Docker Containers**: `docker logs <container_name>`
- **System Logs**: `/var/log/`

## 🔄 Maintenance

### Regular Tasks

1. **Update Dependencies**
   ```bash
   pip install -r requirements.txt --upgrade
   ```

2. **Clean Logs**
   ```bash
   find attack-simulations/logs/ -name "*.log" -mtime +7 -delete
   ```

3. **Restart Services**
   ```bash
   docker-compose restart
   ```

### Backup

Regularly backup:
- Configuration files
- Test results
- Monitoring data
- Log files

## 📚 Documentation

- [Secure DEX Development Plan](../Secure_DEX_Development_Plan.md)
- [Attack Simulation API Documentation](docs/api.md)
- [Monitoring Setup Guide](docs/monitoring.md)
- [Security Testing Guide](docs/security-testing.md)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For support and questions:

- Create an issue in the repository
- Check the troubleshooting section
- Review the documentation
- Contact the development team

---

**Note**: This attack simulation environment is designed for testing and validation purposes only. Do not use in production environments without proper security measures and monitoring.
