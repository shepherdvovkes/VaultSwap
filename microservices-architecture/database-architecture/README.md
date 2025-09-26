# Ultrana DEX - Robust Database Architecture

## Overview
This document outlines the comprehensive database architecture for the Ultrana DEX microservices, implementing both SQL (PostgreSQL) and NoSQL (MongoDB) databases with advanced features for scalability, performance, and reliability.

## Database Strategy

### SQL Database (PostgreSQL)
- **Primary Use**: Transactional data, user accounts, trading orders
- **Features**: ACID compliance, complex queries, relationships
- **Scaling**: Read replicas, connection pooling, sharding

### NoSQL Database (MongoDB)
- **Primary Use**: Analytics, logs, time-series data, flexible schemas
- **Features**: Horizontal scaling, document storage, aggregation
- **Scaling**: Sharding, replica sets, gridFS

## Database Architecture

### 1. PostgreSQL Cluster
```
Primary Database (Write)
├── Read Replica 1 (Analytics)
├── Read Replica 2 (Reporting)
├── Read Replica 3 (Backup)
└── Standby (Disaster Recovery)
```

### 2. MongoDB Cluster
```
MongoDB Replica Set
├── Primary (Write)
├── Secondary 1 (Read)
├── Secondary 2 (Read)
└── Arbiter (Election)
```

### 3. Database Sharding
```
Shard 1: Users 1-1000000
Shard 2: Users 1000001-2000000
Shard 3: Users 2000001-3000000
Shard N: Users (N-1)*1000000+1-N*1000000
```

## Data Distribution

### PostgreSQL Tables
- **Users**: User accounts, profiles, authentication
- **Wallets**: Wallet addresses, balances, transactions
- **Trading**: Orders, trades, positions
- **Security**: Audit logs, security events
- **Analytics**: Aggregated trading data

### MongoDB Collections
- **Trading Events**: Real-time trading events
- **Price History**: Time-series price data
- **User Activity**: User behavior analytics
- **System Logs**: Application and system logs
- **Notifications**: User notifications and alerts

## Performance Optimizations

### 1. Connection Pooling
```yaml
# PostgreSQL Connection Pool
database:
  postgresql:
    max-pool-size: 20
    min-pool-size: 5
    connection-timeout: 30s
    idle-timeout: 10m
    max-lifetime: 1h
```

### 2. Read Replicas
```yaml
# Read Replica Configuration
read-replicas:
  analytics-replica:
    url: jdbc:postgresql://analytics-replica:5432/ultrana_dex
    read-only: true
  reporting-replica:
    url: jdbc:postgresql://reporting-replica:5432/ultrana_dex
    read-only: true
```

### 3. Database Indexing
```sql
-- User table indexes
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_created_at ON users(created_at);
CREATE INDEX idx_users_status ON users(status);

-- Trading table indexes
CREATE INDEX idx_trades_user_id ON trades(user_id);
CREATE INDEX idx_trades_created_at ON trades(created_at);
CREATE INDEX idx_trades_status ON trades(status);
CREATE INDEX idx_trades_pair ON trades(trading_pair);

-- Composite indexes
CREATE INDEX idx_trades_user_status ON trades(user_id, status);
CREATE INDEX idx_trades_pair_time ON trades(trading_pair, created_at);
```

### 4. MongoDB Indexes
```javascript
// Trading events collection
db.trading_events.createIndex({ "timestamp": 1, "user_id": 1 });
db.trading_events.createIndex({ "trading_pair": 1, "timestamp": 1 });
db.trading_events.createIndex({ "event_type": 1, "timestamp": 1 });

// Price history collection
db.price_history.createIndex({ "symbol": 1, "timestamp": 1 });
db.price_history.createIndex({ "timestamp": 1 }, { expireAfterSeconds: 2592000 }); // 30 days TTL
```

## Data Migration Strategy

### 1. Database Migrations
```yaml
# Flyway Configuration
flyway:
  locations: classpath:db/migration
  baseline-on-migrate: true
  validate-on-migrate: true
  clean-disabled: true
```

### 2. Data Synchronization
```yaml
# Data Sync Configuration
data-sync:
  postgres-to-mongodb:
    enabled: true
    batch-size: 1000
    interval: 5m
  mongodb-to-postgres:
    enabled: true
    batch-size: 500
    interval: 10m
```

## Backup and Recovery

### 1. PostgreSQL Backup
```bash
# Automated backup script
#!/bin/bash
pg_dump -h primary-db -U ultrana ultrana_dex | gzip > backup_$(date +%Y%m%d_%H%M%S).sql.gz
```

### 2. MongoDB Backup
```bash
# MongoDB backup script
#!/bin/bash
mongodump --host mongodb-cluster --db ultrana_dex --gzip --archive=backup_$(date +%Y%m%d_%H%M%S).gz
```

### 3. Point-in-Time Recovery
```yaml
# PITR Configuration
pitr:
  postgresql:
    wal-level: replica
    archive-mode: on
    archive-command: 'cp %p /backup/wal/%f'
  mongodb:
    oplog-size: 1024MB
    backup-frequency: 1h
```

## Security

### 1. Database Encryption
```yaml
# Encryption Configuration
encryption:
  postgresql:
    ssl-mode: require
    ssl-cert: /certs/server.crt
    ssl-key: /certs/server.key
  mongodb:
    ssl-mode: require
    ssl-cert: /certs/mongodb.crt
    ssl-key: /certs/mongodb.key
```

### 2. Access Control
```sql
-- PostgreSQL User Roles
CREATE ROLE ultrana_readonly;
CREATE ROLE ultrana_readwrite;
CREATE ROLE ultrana_admin;

-- Grant permissions
GRANT SELECT ON ALL TABLES IN SCHEMA public TO ultrana_readonly;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO ultrana_readwrite;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ultrana_admin;
```

### 3. Audit Logging
```yaml
# Audit Configuration
audit:
  postgresql:
    enabled: true
    log-statement: all
    log-connections: true
    log-disconnections: true
  mongodb:
    enabled: true
    audit-destination: file
    audit-format: JSON
```

## Monitoring

### 1. Database Metrics
```yaml
# Metrics Configuration
metrics:
  postgresql:
    - connection-count
    - query-duration
    - lock-waits
    - cache-hit-ratio
  mongodb:
    - connection-count
    - operation-duration
    - index-usage
    - memory-usage
```

### 2. Alerting
```yaml
# Alert Rules
alerts:
  - name: HighConnectionCount
    condition: postgresql_connections > 80
    severity: warning
  - name: SlowQueries
    condition: postgresql_query_duration > 5s
    severity: critical
  - name: DatabaseDown
    condition: postgresql_up == 0
    severity: critical
```

## Performance Tuning

### 1. PostgreSQL Tuning
```sql
-- PostgreSQL Configuration
ALTER SYSTEM SET shared_buffers = '256MB';
ALTER SYSTEM SET effective_cache_size = '1GB';
ALTER SYSTEM SET maintenance_work_mem = '64MB';
ALTER SYSTEM SET checkpoint_completion_target = 0.9;
ALTER SYSTEM SET wal_buffers = '16MB';
ALTER SYSTEM SET default_statistics_target = 100;
```

### 2. MongoDB Tuning
```javascript
// MongoDB Configuration
db.adminCommand({
  setParameter: 1,
  wiredTigerConcurrentReadTransactions: 128,
  wiredTigerConcurrentWriteTransactions: 128
});
```

## Data Archiving

### 1. Historical Data
```sql
-- Archive old trading data
CREATE TABLE trades_archive (LIKE trades);
INSERT INTO trades_archive SELECT * FROM trades WHERE created_at < NOW() - INTERVAL '1 year';
DELETE FROM trades WHERE created_at < NOW() - INTERVAL '1 year';
```

### 2. MongoDB TTL
```javascript
// Set TTL for logs
db.system_logs.createIndex({ "timestamp": 1 }, { expireAfterSeconds: 2592000 }); // 30 days
db.trading_events.createIndex({ "timestamp": 1 }, { expireAfterSeconds: 7776000 }); // 90 days
```

## Disaster Recovery

### 1. RTO/RPO Targets
- **RTO (Recovery Time Objective)**: 4 hours
- **RPO (Recovery Point Objective)**: 1 hour
- **Backup Retention**: 30 days
- **Cross-Region Replication**: Enabled

### 2. Failover Procedures
```yaml
# Failover Configuration
failover:
  postgresql:
    primary: primary-db
    standby: standby-db
    promotion-timeout: 30s
  mongodb:
    replica-set: ultrana-rs
    failover-timeout: 10s
```

This comprehensive database architecture ensures high availability, performance, and data integrity for the Ultrana DEX platform.
