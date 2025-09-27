# Ultrana DEX Smart Contracts

## Overview

This repository contains the smart contracts for the Ultrana DEX, a security-first decentralized exchange built on Ethereum and other EVM-compatible chains. The contracts implement a comprehensive DEX solution with advanced security features, MEV protection, and governance mechanisms.

## 🏗️ Architecture

### Core Contracts

- **UltranaDEXFactory**: Factory contract for creating and managing trading pairs
- **UltranaDEXPair**: Core trading pair contract with AMM functionality
- **UltranaDEXRouter**: Router contract for executing trades and managing liquidity
- **UltranaDEXGovernance**: Governance contract for DAO functionality
- **UltranaDEXStaking**: Staking contract for token rewards and farming

### Security Contracts

- **MEVProtection**: MEV attack detection and prevention
- **SlippageProtection**: Slippage protection mechanisms
- **FlashLoanProtection**: Flash loan attack prevention
- **EconomicSecurity**: Economic attack detection

### Token Contracts

- **UltranaDEXToken**: Main governance and utility token
- **UltranaDEXLP**: Liquidity provider token
- **UltranaDEXReward**: Reward token for staking

## 🚀 Features

### Trading Features
- **AMM (Automated Market Maker)**: Constant product formula with concentrated liquidity
- **Multiple Fee Tiers**: 0.01%, 0.05%, 0.3%, 1% fee tiers
- **Order Types**: Limit orders, market orders, stop-loss orders
- **Cross-Chain Trading**: Multi-chain support for EVM chains

### Security Features
- **MEV Protection**: Real-time MEV attack detection and prevention
- **Flash Loan Protection**: Flash loan attack prevention
- **Economic Security**: Economic attack detection and prevention
- **Oracle Security**: Multi-oracle price validation
- **Access Control**: Role-based access control with multi-signature support

### Governance Features
- **DAO Functionality**: Decentralized autonomous organization
- **Proposal System**: Create, vote, and execute governance proposals
- **Voting Mechanisms**: Token holder voting with quorum requirements
- **Execution Delay**: Time-locked proposal execution

### Staking Features
- **Multiple Pools**: Different staking durations and APYs
- **Reward Distribution**: Automated reward calculation and distribution
- **Farming Mechanisms**: Yield farming and liquidity mining
- **Flexible Staking**: Multiple staking options with different rewards

## 📁 Contract Structure

```
contracts/
├── UltranaDEXFactory.sol          # Factory contract
├── UltranaDEXPair.sol             # Trading pair contract
├── UltranaDEXRouter.sol           # Router contract
├── UltranaDEXGovernance.sol       # Governance contract
├── UltranaDEXStaking.sol          # Staking contract
├── UltranaDEXToken.sol            # Main token contract
├── interfaces/                    # Contract interfaces
│   ├── IUltranaDEXFactory.sol
│   ├── IUltranaDEXPair.sol
│   ├── IUltranaDEXRouter.sol
│   ├── IUltranaDEXGovernance.sol
│   ├── IUltranaDEXStaking.sol
│   └── IUltranaDEXToken.sol
├── security/                      # Security contracts
│   ├── MEVProtection.sol
│   ├── SlippageProtection.sol
│   ├── FlashLoanProtection.sol
│   └── EconomicSecurity.sol
├── libraries/                     # Utility libraries
│   ├── Math.sol
│   ├── UQ112x112.sol
│   └── UltranaDEXLibrary.sol
└── tokens/                        # Token contracts
    ├── UltranaDEXToken.sol
    ├── UltranaDEXLP.sol
    └── UltranaDEXReward.sol
```

## 🛠️ Development

### Prerequisites

- Node.js >= 16.0.0
- npm >= 8.0.0
- Hardhat
- Git

### Installation

```bash
# Clone the repository
git clone https://github.com/ultrana-dex/smart-contracts.git
cd smart-contracts

# Install dependencies
npm install

# Install additional security tools
npm install -g slither
npm install -g mythril
npm install -g echidna
```

### Environment Setup

Create a `.env` file in the root directory:

```env
# Network RPC URLs
MAINNET_RPC_URL=https://mainnet.infura.io/v3/YOUR_PROJECT_ID
GOERLI_RPC_URL=https://goerli.infura.io/v3/YOUR_PROJECT_ID
POLYGON_RPC_URL=https://polygon-rpc.com
BSC_RPC_URL=https://bsc-dataseed.binance.org
ARBITRUM_RPC_URL=https://arb1.arbitrum.io/rpc
BASE_RPC_URL=https://mainnet.base.org

# Private Keys (for deployment)
PRIVATE_KEY=your_private_key_here

# API Keys for verification
ETHERSCAN_API_KEY=your_etherscan_api_key
POLYGONSCAN_API_KEY=your_polygonscan_api_key
BSCSCAN_API_KEY=your_bscscan_api_key
ARBISCAN_API_KEY=your_arbiscan_api_key
BASESCAN_API_KEY=your_basescan_api_key

# Gas reporting
COINMARKETCAP_API_KEY=your_coinmarketcap_api_key
```

### Compilation

```bash
# Compile contracts
npm run compile

# Clean artifacts
npm run clean
```

### Testing

```bash
# Run tests
npm test

# Run tests with gas reporting
npm run gas-report

# Run coverage
npm run coverage
```

### Deployment

```bash
# Deploy to local network
npm run deploy

# Deploy to testnet
npm run deploy:goerli
npm run deploy:sepolia
npm run deploy:polygon
npm run deploy:bsc
npm run deploy:arbitrum

# Deploy to mainnet
npm run deploy:mainnet
```

### Verification

```bash
# Verify contracts on Etherscan
npm run verify
```

## 🔒 Security

### Security Features

1. **MEV Protection**
   - Real-time MEV attack detection
   - Sandwich attack prevention
   - Front-running protection
   - Commit-reveal schemes

2. **Flash Loan Protection**
   - Flash loan attack detection
   - Economic attack prevention
   - Reward manipulation protection
   - Staking security measures

3. **Economic Security**
   - Tokenomics validation
   - Economic attack detection
   - Reward manipulation protection
   - Governance security

4. **Oracle Security**
   - Multi-oracle integration
   - Price validation and manipulation detection
   - Oracle failover mechanisms
   - Secure price aggregation

### Security Tools

```bash
# Run Slither static analysis
npm run security

# Run Mythril security analysis
npm run security:mythril

# Run Echidna fuzzing
npm run security:echidna

# Run Solhint linting
npm run lint
```

### Security Best Practices

1. **Access Control**: Role-based access control with multi-signature support
2. **Reentrancy Protection**: ReentrancyGuard on all external functions
3. **Pausable Contracts**: Emergency pause functionality
4. **Input Validation**: Comprehensive input validation
5. **Gas Optimization**: Gas-efficient contract design
6. **Upgradeability**: Proxy patterns for upgradeable contracts

## 📊 Gas Optimization

### Gas Usage

| Contract | Deployment | Function Call | Gas Used |
|----------|------------|---------------|----------|
| UltranaDEXFactory | ~2,500,000 | createPair | ~1,200,000 |
| UltranaDEXPair | ~1,800,000 | swap | ~150,000 |
| UltranaDEXRouter | ~2,200,000 | swapExactTokensForTokens | ~200,000 |
| UltranaDEXGovernance | ~2,000,000 | propose | ~300,000 |
| UltranaDEXStaking | ~1,900,000 | stake | ~180,000 |

### Optimization Techniques

1. **Packed Structs**: Efficient storage layout
2. **Custom Errors**: Gas-efficient error handling
3. **Assembly**: Low-level optimizations where needed
4. **Library Usage**: Reusable code patterns
5. **Batch Operations**: Multiple operations in single transaction

## 🌐 Multi-Chain Support

### Supported Networks

- **Ethereum**: Mainnet, Goerli, Sepolia
- **Polygon**: Mainnet, Mumbai
- **BSC**: Mainnet, Testnet
- **Arbitrum**: Mainnet, Goerli
- **Base**: Mainnet, Goerli

### Network Configuration

Each network has specific configuration for:
- Gas prices and limits
- Block times and confirmation requirements
- Bridge contracts and addresses
- Oracle integrations
- Security parameters

## 📈 Monitoring

### Events

All contracts emit comprehensive events for monitoring:
- Trading events (swaps, liquidity changes)
- Security events (attacks detected, protection triggered)
- Governance events (proposals, votes, executions)
- Staking events (stakes, unstakes, rewards)

### Metrics

Key metrics to monitor:
- Trading volume and frequency
- Liquidity pool TVL
- Security events and attacks
- Governance participation
- Staking rewards and distribution

## 🔧 Configuration

### Fee Tiers

| Tier | Fee | Tick Spacing | Use Case |
|------|-----|--------------|----------|
| 0.01% | 100 | 1 | Stable pairs |
| 0.05% | 500 | 10 | Common pairs |
| 0.3% | 3000 | 60 | Standard pairs |
| 1% | 10000 | 200 | Exotic pairs |

### Security Parameters

- **Max Slippage**: 5% (500 basis points)
- **Max Price Impact**: 10% (1000 basis points)
- **Min Liquidity**: 10,000 tokens
- **Max Gas Price**: 100 gwei
- **MEV Protection**: Real-time detection
- **Flash Loan Protection**: Economic attack prevention

## 📚 Documentation

### API Reference

- [Factory Contract API](docs/factory-api.md)
- [Pair Contract API](docs/pair-api.md)
- [Router Contract API](docs/router-api.md)
- [Governance Contract API](docs/governance-api.md)
- [Staking Contract API](docs/staking-api.md)

### Integration Guides

- [Frontend Integration](docs/frontend-integration.md)
- [Backend Integration](docs/backend-integration.md)
- [Mobile Integration](docs/mobile-integration.md)
- [API Integration](docs/api-integration.md)

### Security Guides

- [Security Best Practices](docs/security-best-practices.md)
- [Attack Prevention](docs/attack-prevention.md)
- [Emergency Procedures](docs/emergency-procedures.md)
- [Audit Guidelines](docs/audit-guidelines.md)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Run security checks
6. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Documentation**: [docs.ultrana-dex.com](https://docs.ultrana-dex.com)
- **Discord**: [discord.gg/ultrana-dex](https://discord.gg/ultrana-dex)
- **Telegram**: [t.me/ultrana_dex](https://t.me/ultrana_dex)
- **Twitter**: [@UltranaDEX](https://twitter.com/UltranaDEX)
- **GitHub Issues**: [github.com/ultrana-dex/smart-contracts/issues](https://github.com/ultrana-dex/smart-contracts/issues)

## ⚠️ Disclaimer

This software is provided "as is" without warranty of any kind. Use at your own risk. Always conduct thorough testing and security audits before deploying to mainnet.

---

**Built with ❤️ by the Ultrana DEX Team**
