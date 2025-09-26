-- Ultrana DEX Enhanced Database Schema
-- This schema supports the enhanced DEX architecture with security-first approach

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Trading Tables
CREATE TABLE IF NOT EXISTS orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    token_pair VARCHAR(20) NOT NULL,
    order_type VARCHAR(20) NOT NULL CHECK (order_type IN ('LIMIT', 'MARKET', 'STOP_LOSS', 'STOP_LIMIT')),
    side VARCHAR(10) NOT NULL CHECK (side IN ('BUY', 'SELL')),
    amount DECIMAL(36,18) NOT NULL CHECK (amount > 0),
    price DECIMAL(36,18) CHECK (price > 0),
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'PARTIALLY_FILLED', 'FILLED', 'CANCELLED', 'EXPIRED', 'REJECTED')),
    filled_amount DECIMAL(36,18) DEFAULT 0,
    remaining_amount DECIMAL(36,18),
    fee DECIMAL(36,18) DEFAULT 0,
    chain_id BIGINT,
    transaction_hash VARCHAR(66),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP
);

-- Trades table
CREATE TABLE IF NOT EXISTS trades (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID REFERENCES orders(id),
    buyer_id UUID NOT NULL,
    seller_id UUID NOT NULL,
    token_pair VARCHAR(20) NOT NULL,
    amount DECIMAL(36,18) NOT NULL CHECK (amount > 0),
    price DECIMAL(36,18) NOT NULL CHECK (price > 0),
    fee DECIMAL(36,18) NOT NULL,
    chain_id BIGINT,
    transaction_hash VARCHAR(66),
    executed_at TIMESTAMP DEFAULT NOW()
);

-- Liquidity pools table
CREATE TABLE IF NOT EXISTS liquidity_pools (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    token_a VARCHAR(50) NOT NULL,
    token_b VARCHAR(50) NOT NULL,
    reserve_a DECIMAL(36,18) NOT NULL DEFAULT 0,
    reserve_b DECIMAL(36,18) NOT NULL DEFAULT 0,
    total_supply DECIMAL(36,18) NOT NULL DEFAULT 0,
    fee_rate DECIMAL(5,4) NOT NULL DEFAULT 0.003,
    chain_id BIGINT NOT NULL,
    contract_address VARCHAR(42),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Liquidity positions table
CREATE TABLE IF NOT EXISTS liquidity_positions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    pool_id UUID REFERENCES liquidity_pools(id),
    token_a_amount DECIMAL(36,18) NOT NULL DEFAULT 0,
    token_b_amount DECIMAL(36,18) NOT NULL DEFAULT 0,
    lp_tokens DECIMAL(36,18) NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Staking table
CREATE TABLE IF NOT EXISTS staking (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    token VARCHAR(50) NOT NULL,
    amount DECIMAL(36,18) NOT NULL CHECK (amount > 0),
    staking_period INTEGER NOT NULL, -- in days
    apy DECIMAL(5,4) NOT NULL,
    rewards DECIMAL(36,18) DEFAULT 0,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'UNSTAKED', 'EXPIRED')),
    chain_id BIGINT NOT NULL,
    contract_address VARCHAR(42),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP
);

-- Farming table
CREATE TABLE IF NOT EXISTS farming (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    pool_id UUID REFERENCES liquidity_pools(id),
    lp_tokens DECIMAL(36,18) NOT NULL CHECK (lp_tokens > 0),
    rewards DECIMAL(36,18) DEFAULT 0,
    apy DECIMAL(5,4) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'HARVESTED', 'WITHDRAWN')),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Security Tables
CREATE TABLE IF NOT EXISTS mev_attacks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    attack_type VARCHAR(50) NOT NULL,
    transaction_hash VARCHAR(66) NOT NULL,
    attacker_address VARCHAR(42) NOT NULL,
    victim_address VARCHAR(42) NOT NULL,
    profit_amount DECIMAL(36,18) NOT NULL,
    detected_at TIMESTAMP DEFAULT NOW(),
    status VARCHAR(20) NOT NULL DEFAULT 'DETECTED' CHECK (status IN ('DETECTED', 'PREVENTED', 'INVESTIGATING', 'RESOLVED')),
    chain_id BIGINT NOT NULL
);

-- Security events table
CREATE TABLE IF NOT EXISTS security_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_type VARCHAR(50) NOT NULL,
    severity VARCHAR(20) NOT NULL CHECK (severity IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    description TEXT NOT NULL,
    user_id UUID,
    transaction_hash VARCHAR(66),
    chain_id BIGINT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Flash loan attacks table
CREATE TABLE IF NOT EXISTS flash_loan_attacks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    transaction_hash VARCHAR(66) NOT NULL,
    attacker_address VARCHAR(42) NOT NULL,
    victim_address VARCHAR(42) NOT NULL,
    loan_amount DECIMAL(36,18) NOT NULL,
    profit_amount DECIMAL(36,18) NOT NULL,
    attack_method VARCHAR(100) NOT NULL,
    detected_at TIMESTAMP DEFAULT NOW(),
    status VARCHAR(20) NOT NULL DEFAULT 'DETECTED' CHECK (status IN ('DETECTED', 'PREVENTED', 'INVESTIGATING', 'RESOLVED')),
    chain_id BIGINT NOT NULL
);

-- Economic attacks table
CREATE TABLE IF NOT EXISTS economic_attacks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    attack_type VARCHAR(50) NOT NULL,
    user_id UUID NOT NULL,
    transaction_hash VARCHAR(66) NOT NULL,
    manipulated_token VARCHAR(50) NOT NULL,
    manipulation_amount DECIMAL(36,18) NOT NULL,
    detected_at TIMESTAMP DEFAULT NOW(),
    status VARCHAR(20) NOT NULL DEFAULT 'DETECTED' CHECK (status IN ('DETECTED', 'PREVENTED', 'INVESTIGATING', 'RESOLVED')),
    chain_id BIGINT NOT NULL
);

-- Governance Tables
CREATE TABLE IF NOT EXISTS proposals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    proposer_id UUID NOT NULL,
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    proposal_type VARCHAR(50) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'ACTIVE', 'SUCCEEDED', 'DEFEATED', 'EXECUTED', 'EXPIRED')),
    voting_start TIMESTAMP NOT NULL,
    voting_end TIMESTAMP NOT NULL,
    execution_start TIMESTAMP,
    execution_end TIMESTAMP,
    for_votes DECIMAL(36,18) DEFAULT 0,
    against_votes DECIMAL(36,18) DEFAULT 0,
    abstain_votes DECIMAL(36,18) DEFAULT 0,
    quorum_threshold DECIMAL(5,4) NOT NULL DEFAULT 0.1,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Votes table
CREATE TABLE IF NOT EXISTS votes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    proposal_id UUID REFERENCES proposals(id),
    voter_id UUID NOT NULL,
    support VARCHAR(10) NOT NULL CHECK (support IN ('FOR', 'AGAINST', 'ABSTAIN')),
    voting_power DECIMAL(36,18) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Cross-chain Tables
CREATE TABLE IF NOT EXISTS cross_chain_transfers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    source_chain_id BIGINT NOT NULL,
    target_chain_id BIGINT NOT NULL,
    token VARCHAR(50) NOT NULL,
    amount DECIMAL(36,18) NOT NULL CHECK (amount > 0),
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'PROCESSING', 'COMPLETED', 'FAILED', 'CANCELLED')),
    source_transaction_hash VARCHAR(66),
    target_transaction_hash VARCHAR(66),
    bridge_fee DECIMAL(36,18) DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Oracle Tables
CREATE TABLE IF NOT EXISTS price_feeds (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    token VARCHAR(50) NOT NULL,
    price DECIMAL(36,18) NOT NULL CHECK (price > 0),
    source VARCHAR(50) NOT NULL, -- chainlink, pyth, band, twap
    chain_id BIGINT NOT NULL,
    timestamp TIMESTAMP DEFAULT NOW()
);

-- Chain configuration table
CREATE TABLE IF NOT EXISTS chain_configurations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    chain_id BIGINT UNIQUE NOT NULL,
    chain_name VARCHAR(50) NOT NULL,
    rpc_url VARCHAR(200) NOT NULL,
    explorer_url VARCHAR(200),
    native_token VARCHAR(10) NOT NULL,
    is_active BOOLEAN DEFAULT true,
    gas_price_gwei DECIMAL(10,2),
    block_time_seconds INTEGER,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_token_pair ON orders(token_pair);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at);

CREATE INDEX IF NOT EXISTS idx_trades_buyer_id ON trades(buyer_id);
CREATE INDEX IF NOT EXISTS idx_trades_seller_id ON trades(seller_id);
CREATE INDEX IF NOT EXISTS idx_trades_token_pair ON trades(token_pair);
CREATE INDEX IF NOT EXISTS idx_trades_executed_at ON trades(executed_at);

CREATE INDEX IF NOT EXISTS idx_liquidity_pools_chain_id ON liquidity_pools(chain_id);
CREATE INDEX IF NOT EXISTS idx_liquidity_pools_is_active ON liquidity_pools(is_active);

CREATE INDEX IF NOT EXISTS idx_liquidity_positions_user_id ON liquidity_positions(user_id);
CREATE INDEX IF NOT EXISTS idx_liquidity_positions_pool_id ON liquidity_positions(pool_id);

CREATE INDEX IF NOT EXISTS idx_staking_user_id ON staking(user_id);
CREATE INDEX IF NOT EXISTS idx_staking_status ON staking(status);
CREATE INDEX IF NOT EXISTS idx_staking_chain_id ON staking(chain_id);

CREATE INDEX IF NOT EXISTS idx_farming_user_id ON farming(user_id);
CREATE INDEX IF NOT EXISTS idx_farming_pool_id ON farming(pool_id);
CREATE INDEX IF NOT EXISTS idx_farming_status ON farming(status);

CREATE INDEX IF NOT EXISTS idx_mev_attacks_detected_at ON mev_attacks(detected_at);
CREATE INDEX IF NOT EXISTS idx_mev_attacks_status ON mev_attacks(status);
CREATE INDEX IF NOT EXISTS idx_mev_attacks_chain_id ON mev_attacks(chain_id);

CREATE INDEX IF NOT EXISTS idx_security_events_created_at ON security_events(created_at);
CREATE INDEX IF NOT EXISTS idx_security_events_severity ON security_events(severity);
CREATE INDEX IF NOT EXISTS idx_security_events_chain_id ON security_events(chain_id);

CREATE INDEX IF NOT EXISTS idx_flash_loan_attacks_detected_at ON flash_loan_attacks(detected_at);
CREATE INDEX IF NOT EXISTS idx_flash_loan_attacks_status ON flash_loan_attacks(status);
CREATE INDEX IF NOT EXISTS idx_flash_loan_attacks_chain_id ON flash_loan_attacks(chain_id);

CREATE INDEX IF NOT EXISTS idx_economic_attacks_detected_at ON economic_attacks(detected_at);
CREATE INDEX IF NOT EXISTS idx_economic_attacks_status ON economic_attacks(status);
CREATE INDEX IF NOT EXISTS idx_economic_attacks_chain_id ON economic_attacks(chain_id);

CREATE INDEX IF NOT EXISTS idx_proposals_status ON proposals(status);
CREATE INDEX IF NOT EXISTS idx_proposals_voting_start ON proposals(voting_start);
CREATE INDEX IF NOT EXISTS idx_proposals_voting_end ON proposals(voting_end);

CREATE INDEX IF NOT EXISTS idx_votes_proposal_id ON votes(proposal_id);
CREATE INDEX IF NOT EXISTS idx_votes_voter_id ON votes(voter_id);

CREATE INDEX IF NOT EXISTS idx_cross_chain_transfers_user_id ON cross_chain_transfers(user_id);
CREATE INDEX IF NOT EXISTS idx_cross_chain_transfers_status ON cross_chain_transfers(status);
CREATE INDEX IF NOT EXISTS idx_cross_chain_transfers_source_chain_id ON cross_chain_transfers(source_chain_id);
CREATE INDEX IF NOT EXISTS idx_cross_chain_transfers_target_chain_id ON cross_chain_transfers(target_chain_id);

CREATE INDEX IF NOT EXISTS idx_price_feeds_token ON price_feeds(token);
CREATE INDEX IF NOT EXISTS idx_price_feeds_source ON price_feeds(source);
CREATE INDEX IF NOT EXISTS idx_price_feeds_chain_id ON price_feeds(chain_id);
CREATE INDEX IF NOT EXISTS idx_price_feeds_timestamp ON price_feeds(timestamp);

CREATE INDEX IF NOT EXISTS idx_chain_configurations_chain_id ON chain_configurations(chain_id);
CREATE INDEX IF NOT EXISTS idx_chain_configurations_is_active ON chain_configurations(is_active);

-- Insert initial chain configurations
INSERT INTO chain_configurations (chain_id, chain_name, rpc_url, explorer_url, native_token, gas_price_gwei, block_time_seconds) VALUES
(1, 'Ethereum', 'https://mainnet.infura.io/v3/YOUR_PROJECT_ID', 'https://etherscan.io', 'ETH', 20.0, 12),
(56, 'BSC', 'https://bsc-dataseed.binance.org', 'https://bscscan.com', 'BNB', 5.0, 3),
(137, 'Polygon', 'https://polygon-rpc.com', 'https://polygonscan.com', 'MATIC', 30.0, 2),
(42161, 'Arbitrum', 'https://arb1.arbitrum.io/rpc', 'https://arbiscan.io', 'ETH', 0.1, 1),
(8453, 'Base', 'https://mainnet.base.org', 'https://basescan.org', 'ETH', 0.001, 2),
(101, 'Solana', 'https://api.mainnet-beta.solana.com', 'https://explorer.solana.com', 'SOL', 0.0, 0.4);

-- Create views for analytics
CREATE OR REPLACE VIEW trading_volume_24h AS
SELECT 
    token_pair,
    chain_id,
    SUM(amount * price) as volume_24h,
    COUNT(*) as trade_count_24h
FROM trades 
WHERE executed_at >= NOW() - INTERVAL '24 hours'
GROUP BY token_pair, chain_id;

CREATE OR REPLACE VIEW liquidity_pool_metrics AS
SELECT 
    lp.id,
    lp.token_a,
    lp.token_b,
    lp.reserve_a,
    lp.reserve_b,
    lp.fee_rate,
    lp.chain_id,
    lp.contract_address,
    (lp.reserve_a * p_a.price + lp.reserve_b * p_b.price) as total_value_locked,
    CASE 
        WHEN lp.reserve_b > 0 THEN lp.reserve_a / lp.reserve_b 
        ELSE 0 
    END as price_ratio
FROM liquidity_pools lp
LEFT JOIN price_feeds p_a ON lp.token_a = p_a.token AND lp.chain_id = p_a.chain_id
LEFT JOIN price_feeds p_b ON lp.token_b = p_b.token AND lp.chain_id = p_b.chain_id
WHERE lp.is_active = true;

CREATE OR REPLACE VIEW security_events_summary AS
SELECT 
    event_type,
    severity,
    chain_id,
    COUNT(*) as event_count,
    MAX(created_at) as last_occurrence
FROM security_events 
WHERE created_at >= NOW() - INTERVAL '24 hours'
GROUP BY event_type, severity, chain_id;

-- Create functions for common operations
CREATE OR REPLACE FUNCTION calculate_apy(
    staked_amount DECIMAL,
    reward_rate DECIMAL,
    time_period_days INTEGER
) RETURNS DECIMAL AS $$
BEGIN
    RETURN (reward_rate * 365.0 / time_period_days) * 100.0;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION calculate_liquidity_rewards(
    lp_tokens DECIMAL,
    pool_fee_rate DECIMAL,
    time_period_hours INTEGER
) RETURNS DECIMAL AS $$
BEGIN
    RETURN lp_tokens * pool_fee_rate * (time_period_hours / 24.0);
END;
$$ LANGUAGE plpgsql;

-- Create triggers for updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply triggers to relevant tables
CREATE TRIGGER update_orders_updated_at BEFORE UPDATE ON orders FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_liquidity_pools_updated_at BEFORE UPDATE ON liquidity_pools FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_liquidity_positions_updated_at BEFORE UPDATE ON liquidity_positions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_staking_updated_at BEFORE UPDATE ON staking FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_farming_updated_at BEFORE UPDATE ON farming FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_proposals_updated_at BEFORE UPDATE ON proposals FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_cross_chain_transfers_updated_at BEFORE UPDATE ON cross_chain_transfers FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_chain_configurations_updated_at BEFORE UPDATE ON chain_configurations FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
