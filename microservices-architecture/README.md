# Ultrana DEX - Java 21 Microservices Architecture

## Overview
This is a comprehensive Java 21 microservices architecture for the Ultrana DEX project, incorporating Haskell and Rust services, message relay systems, and unified monitoring with Micrometer-Prometheus-Grafana.

## Architecture Components

### Core Java 21 Microservices
- **API Gateway**: Spring Cloud Gateway with load balancing
- **User Service**: User management and authentication
- **Trading Service**: Core trading operations
- **Wallet Service**: Wallet management and transactions
- **Notification Service**: Real-time notifications
- **Analytics Service**: Trading analytics and reporting

### Haskell Services (as Microservices)
- **Security Service**: Cryptographic operations and formal verification
- **MEV Protection Service**: MEV attack detection and prevention
- **Economic Analysis Service**: Tokenomics and economic modeling

### Rust Services (as Microservices)
- **Solana Gateway Service**: High-performance Solana blockchain integration
- **Cross-Chain Service**: Multi-chain bridge operations
- **Oracle Service**: Price feed aggregation and validation

### Infrastructure Services
- **Message Relay**: Apache Kafka for event streaming
- **Service Discovery**: Consul for service registration
- **Configuration**: Spring Cloud Config
- **Monitoring**: Micrometer + Prometheus + Grafana
- **Tracing**: Zipkin for distributed tracing

## Technology Stack

### Java 21 Services
- **Framework**: Spring Boot 3.3.x
- **Java Version**: Java 21 (LTS)
- **Build Tool**: Maven 3.9+
- **Database**: PostgreSQL 15+ with connection pooling
- **Caching**: Redis 7+ for distributed caching
- **Message Queue**: Apache Kafka 3.5+

### Haskell Services
- **Framework**: Servant for REST APIs
- **Build Tool**: Stack/Cabal
- **Database**: PostgreSQL with postgresql-simple
- **HTTP Client**: http-client-tls

### Rust Services
- **Framework**: Axum for async web services
- **Build Tool**: Cargo
- **Database**: PostgreSQL with sqlx
- **HTTP Client**: reqwest

### Infrastructure
- **Container**: Docker with multi-stage builds
- **Orchestration**: Docker Compose for development
- **Service Mesh**: Istio (optional)
- **API Gateway**: Spring Cloud Gateway
- **Monitoring**: Prometheus + Grafana + Micrometer

## Quick Start

### Prerequisites
- Java 21
- Maven 3.9+
- Docker & Docker Compose
- Node.js 18+ (for frontend)
- PostgreSQL 15+
- Redis 7+
- Apache Kafka 3.5+

### Development Setup
```bash
# Clone the repository
git clone <repository-url>
cd microservices-architecture

# Start infrastructure services
docker-compose up -d postgres redis kafka consul

# Build and start Java services
mvn clean install
docker-compose up -d

# Start Haskell services
cd haskell-services
stack build
stack exec haskell-services

# Start Rust services
cd rust-services
cargo build --release
cargo run
```

## Service Communication

### Synchronous Communication
- REST APIs with OpenAPI 3.0 specifications
- Circuit breakers with Resilience4j
- Load balancing with Spring Cloud LoadBalancer

### Asynchronous Communication
- Apache Kafka for event streaming
- Event sourcing for audit trails
- CQRS pattern for read/write separation

## Monitoring & Observability

### Metrics
- **Micrometer**: Application metrics collection
- **Prometheus**: Metrics storage and querying
- **Grafana**: Metrics visualization and alerting

### Logging
- **Structured Logging**: JSON format with correlation IDs
- **Centralized Logging**: ELK Stack (Elasticsearch, Logstash, Kibana)
- **Distributed Tracing**: Zipkin for request tracing

### Health Checks
- **Spring Boot Actuator**: Health endpoints
- **Custom Health Indicators**: Database, external service checks
- **Readiness/Liveness Probes**: Kubernetes-compatible

## Security

### Authentication & Authorization
- **JWT Tokens**: Stateless authentication
- **OAuth 2.0**: Third-party integrations
- **RBAC**: Role-based access control

### Data Protection
- **Encryption**: AES-256 for sensitive data
- **TLS**: End-to-end encryption
- **Secrets Management**: HashiCorp Vault integration

## Deployment

### Development
- Docker Compose for local development
- Hot reloading for Java services
- Database migrations with Flyway

### Production
- Kubernetes deployment manifests
- Helm charts for package management
- CI/CD with GitHub Actions

## Performance Considerations

### Caching Strategy
- **Redis**: Distributed caching
- **HTTP Caching**: CDN integration
- **Database Caching**: Connection pooling

### Database Optimization
- **Connection Pooling**: HikariCP
- **Read Replicas**: For read-heavy operations
- **Sharding**: Horizontal scaling

### Message Processing
- **Kafka Partitions**: Parallel processing
- **Consumer Groups**: Load balancing
- **Dead Letter Queues**: Error handling

## Development Guidelines

### Code Standards
- **Java**: Google Java Style Guide
- **Haskell**: HLint recommendations
- **Rust**: rustfmt and clippy

### Testing Strategy
- **Unit Tests**: JUnit 5, QuickCheck (Haskell), Criterion (Rust)
- **Integration Tests**: TestContainers
- **Contract Testing**: Pact
- **Load Testing**: Gatling

### Documentation
- **API Documentation**: OpenAPI 3.0 with Swagger UI
- **Architecture Decisions**: ADR (Architecture Decision Records)
- **Runbooks**: Operational procedures

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
