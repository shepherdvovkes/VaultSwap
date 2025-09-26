#!/usr/bin/env python3
"""
Economic Attack Simulator
Simulates various economic attacks including tokenomics manipulation, governance attacks, and staking attacks.
"""

import asyncio
import json
import random
import time
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
from enum import Enum
import argparse
import sys
import os

import requests
import websockets
import numpy as np
import pandas as pd
from prometheus_client import Counter, Histogram, Gauge, start_http_server
from loguru import logger
from pydantic import BaseModel, Field


class EconomicAttackType(Enum):
    TOKENOMICS_MANIPULATION = "tokenomics_manipulation"
    GOVERNANCE_ATTACK = "governance_attack"
    STAKING_ATTACK = "staking_attack"
    REWARD_MANIPULATION = "reward_manipulation"
    LIQUIDITY_MANIPULATION = "liquidity_manipulation"
    PRICE_MANIPULATION = "price_manipulation"
    SUPPLY_ATTACK = "supply_attack"
    VOTING_POWER_ATTACK = "voting_power_attack"


class AttackStatus(Enum):
    PENDING = "pending"
    EXECUTING = "executing"
    SUCCESS = "success"
    FAILED = "failed"
    DETECTED = "detected"


@dataclass
class Token:
    """Represents a token with economic properties"""
    symbol: str
    total_supply: float
    circulating_supply: float
    price: float
    market_cap: float
    holders: int
    staked_amount: float
    governance_power: float


@dataclass
class EconomicAttacker:
    """Represents an economic attacker"""
    id: str
    address: str
    balance: float
    token_holdings: Dict[str, float]
    success_rate: float
    attack_types: List[EconomicAttackType]
    max_attack_amount: float


class EconomicConfig(BaseModel):
    """Configuration for economic attack simulation"""
    token_count: int = Field(default=10, ge=1, le=50)
    attacker_count: int = Field(default=5, ge=1, le=20)
    attack_frequency: str = Field(default="medium")
    target_tokens: List[str] = Field(default=["USDC", "USDT", "SOL", "ETH", "BTC"])
    simulation_duration: str = Field(default="12h")
    attack_intensity: List[str] = Field(default=["low", "medium", "high", "extreme"])


class EconomicSimulator:
    """Main economic attack simulator"""
    
    def __init__(self, config_path: str, monitoring: bool = False):
        self.config = self._load_config(config_path)
        self.monitoring = monitoring
        self.attackers: List[EconomicAttacker] = []
        self.tokens: List[Token] = []
        self.attacks: List[Dict] = []
        self.metrics = self._setup_metrics()
        
        # Setup logging
        logger.add("logs/economic_simulator_{time}.log", rotation="1 day", retention="7 days")
        
        if monitoring:
            start_http_server(8084)
            logger.info("Prometheus metrics server started on port 8084")
    
    def _load_config(self, config_path: str) -> EconomicConfig:
        """Load configuration from JSON file"""
        try:
            with open(config_path, 'r') as f:
                config_data = json.load(f)
            return EconomicConfig(**config_data.get('simulation_config', {}))
        except Exception as e:
            logger.error(f"Failed to load config: {e}")
            return EconomicConfig()
    
    def _setup_metrics(self) -> Dict:
        """Setup Prometheus metrics"""
        return {
            'economic_attacks_total': Counter('economic_attacks_total', 'Total economic attacks', ['attack_type', 'status']),
            'economic_attack_success_rate': Gauge('economic_attack_success_rate', 'Economic attack success rate', ['attack_type']),
            'economic_attack_profit': Histogram('economic_attack_profit', 'Economic attack profit', ['attack_type']),
            'economic_detection_time': Histogram('economic_detection_time_seconds', 'Time to detect economic attack'),
            'token_price_impact': Histogram('token_price_impact', 'Token price impact from attacks', ['token_symbol']),
            'governance_power_manipulation': Gauge('governance_power_manipulation', 'Governance power manipulation', ['token_symbol']),
            'attacker_count': Gauge('economic_attacker_count', 'Number of active economic attackers'),
            'token_count': Gauge('economic_token_count', 'Number of monitored tokens')
        }
    
    def _create_attackers(self) -> None:
        """Create economic attackers with different characteristics"""
        for i in range(self.config.attacker_count):
            # Create token holdings
            token_holdings = {}
            for token in self.config.target_tokens:
                token_holdings[token] = random.uniform(1000, 100000)
            
            attacker = EconomicAttacker(
                id=f"economic_attacker_{i}",
                address=f"0x{random.randint(1000000000000000000000000000000000000000, 9999999999999999999999999999999999999999):x}",
                balance=random.uniform(10000, 500000),
                token_holdings=token_holdings,
                success_rate=random.uniform(0.1, 0.7),
                attack_types=random.sample(list(EconomicAttackType), random.randint(1, 4)),
                max_attack_amount=random.uniform(50000, 500000)
            )
            self.attackers.append(attacker)
        
        logger.info(f"Created {len(self.attackers)} economic attackers")
        self.metrics['attacker_count'].set(len(self.attackers))
    
    def _create_tokens(self) -> None:
        """Create tokens for simulation"""
        base_prices = {
            "USDC": 1.0,
            "USDT": 1.0,
            "SOL": 100.0,
            "ETH": 2000.0,
            "BTC": 30000.0
        }
        
        for i, symbol in enumerate(self.config.target_tokens):
            base_price = base_prices.get(symbol, 100.0)
            total_supply = random.uniform(1000000, 1000000000)
            circulating_supply = total_supply * random.uniform(0.7, 0.95)
            
            token = Token(
                symbol=symbol,
                total_supply=total_supply,
                circulating_supply=circulating_supply,
                price=base_price * random.uniform(0.9, 1.1),
                market_cap=circulating_supply * base_price,
                holders=random.randint(1000, 100000),
                staked_amount=total_supply * random.uniform(0.1, 0.5),
                governance_power=random.uniform(0.1, 1.0)
            )
            self.tokens.append(token)
        
        logger.info(f"Created {len(self.tokens)} tokens")
        self.metrics['token_count'].set(len(self.tokens))
    
    async def _simulate_tokenomics_manipulation(self, attacker: EconomicAttacker, token: Token) -> Dict:
        """Simulate tokenomics manipulation attack"""
        start_time = time.time()
        
        # Simulate tokenomics manipulation
        manipulation_amount = min(random.uniform(10000, 100000), attacker.max_attack_amount)
        
        # Simulate supply manipulation
        supply_manipulation = random.uniform(0.01, 0.1)  # 1-10% supply manipulation
        new_supply = token.total_supply * (1 + supply_manipulation)
        
        # Simulate price impact
        price_impact = supply_manipulation * random.uniform(0.5, 2.0)
        new_price = token.price * (1 - price_impact)
        
        # Calculate profit from manipulation
        profit = manipulation_amount * price_impact * random.uniform(0.1, 0.5)
        success = profit > 0
        
        detection_time = time.time() - start_time
        
        attack_result = {
            "attack_type": EconomicAttackType.TOKENOMICS_MANIPULATION.value,
            "attacker_id": attacker.id,
            "token_symbol": token.symbol,
            "manipulation_amount": manipulation_amount,
            "supply_manipulation": supply_manipulation,
            "price_impact": price_impact,
            "original_price": token.price,
            "new_price": new_price,
            "profit": profit,
            "success": success,
            "detection_time": detection_time,
            "timestamp": time.time()
        }
        
        # Update metrics
        self.metrics['economic_attacks_total'].labels(
            attack_type=EconomicAttackType.TOKENOMICS_MANIPULATION.value,
            status="success" if success else "failed"
        ).inc()
        
        if success:
            self.metrics['economic_attack_profit'].labels(attack_type=EconomicAttackType.TOKENOMICS_MANIPULATION.value).observe(profit)
        
        self.metrics['economic_detection_time'].observe(detection_time)
        self.metrics['token_price_impact'].labels(token_symbol=token.symbol).observe(price_impact)
        
        return attack_result
    
    async def _simulate_governance_attack(self, attacker: EconomicAttacker, token: Token) -> Dict:
        """Simulate governance attack"""
        start_time = time.time()
        
        # Simulate governance power manipulation
        governance_manipulation = random.uniform(0.1, 0.5)  # 10-50% governance manipulation
        attacker_governance_power = attacker.token_holdings.get(token.symbol, 0) / token.circulating_supply
        
        # Simulate voting power accumulation
        voting_power_accumulated = attacker_governance_power * governance_manipulation
        
        # Simulate malicious proposal
        proposal_impact = random.uniform(0.01, 0.1)  # 1-10% impact from malicious proposal
        profit = voting_power_accumulated * proposal_impact * token.market_cap * random.uniform(0.001, 0.01)
        
        success = profit > 0 and voting_power_accumulated > 0.1  # Need >10% voting power
        
        detection_time = time.time() - start_time
        
        attack_result = {
            "attack_type": EconomicAttackType.GOVERNANCE_ATTACK.value,
            "attacker_id": attacker.id,
            "token_symbol": token.symbol,
            "governance_manipulation": governance_manipulation,
            "voting_power_accumulated": voting_power_accumulated,
            "proposal_impact": proposal_impact,
            "profit": profit,
            "success": success,
            "detection_time": detection_time,
            "timestamp": time.time()
        }
        
        # Update metrics
        self.metrics['economic_attacks_total'].labels(
            attack_type=EconomicAttackType.GOVERNANCE_ATTACK.value,
            status="success" if success else "failed"
        ).inc()
        
        if success:
            self.metrics['economic_attack_profit'].labels(attack_type=EconomicAttackType.GOVERNANCE_ATTACK.value).observe(profit)
        
        self.metrics['economic_detection_time'].observe(detection_time)
        self.metrics['governance_power_manipulation'].labels(token_symbol=token.symbol).set(voting_power_accumulated)
        
        return attack_result
    
    async def _simulate_staking_attack(self, attacker: EconomicAttacker, token: Token) -> Dict:
        """Simulate staking attack"""
        start_time = time.time()
        
        # Simulate staking manipulation
        staking_amount = min(random.uniform(10000, 50000), attacker.max_attack_amount)
        staking_manipulation = random.uniform(0.05, 0.2)  # 5-20% staking manipulation
        
        # Simulate reward manipulation
        reward_manipulation = random.uniform(0.1, 0.5)  # 10-50% reward manipulation
        manipulated_rewards = token.staked_amount * reward_manipulation
        
        # Calculate profit from staking manipulation
        profit = staking_amount * staking_manipulation * random.uniform(0.1, 0.3)
        success = profit > 0
        
        detection_time = time.time() - start_time
        
        attack_result = {
            "attack_type": EconomicAttackType.STAKING_ATTACK.value,
            "attacker_id": attacker.id,
            "token_symbol": token.symbol,
            "staking_amount": staking_amount,
            "staking_manipulation": staking_manipulation,
            "reward_manipulation": reward_manipulation,
            "manipulated_rewards": manipulated_rewards,
            "profit": profit,
            "success": success,
            "detection_time": detection_time,
            "timestamp": time.time()
        }
        
        # Update metrics
        self.metrics['economic_attacks_total'].labels(
            attack_type=EconomicAttackType.STAKING_ATTACK.value,
            status="success" if success else "failed"
        ).inc()
        
        if success:
            self.metrics['economic_attack_profit'].labels(attack_type=EconomicAttackType.STAKING_ATTACK.value).observe(profit)
        
        self.metrics['economic_detection_time'].observe(detection_time)
        
        return attack_result
    
    async def _simulate_liquidity_manipulation(self, attacker: EconomicAttacker, token: Token) -> Dict:
        """Simulate liquidity manipulation attack"""
        start_time = time.time()
        
        # Simulate liquidity manipulation
        liquidity_amount = min(random.uniform(50000, 200000), attacker.max_attack_amount)
        liquidity_manipulation = random.uniform(0.1, 0.3)  # 10-30% liquidity manipulation
        
        # Simulate price impact from liquidity manipulation
        price_impact = liquidity_manipulation * random.uniform(0.5, 1.5)
        new_price = token.price * (1 - price_impact)
        
        # Calculate profit from liquidity manipulation
        profit = liquidity_amount * price_impact * random.uniform(0.1, 0.4)
        success = profit > 0
        
        detection_time = time.time() - start_time
        
        attack_result = {
            "attack_type": EconomicAttackType.LIQUIDITY_MANIPULATION.value,
            "attacker_id": attacker.id,
            "token_symbol": token.symbol,
            "liquidity_amount": liquidity_amount,
            "liquidity_manipulation": liquidity_manipulation,
            "price_impact": price_impact,
            "original_price": token.price,
            "new_price": new_price,
            "profit": profit,
            "success": success,
            "detection_time": detection_time,
            "timestamp": time.time()
        }
        
        # Update metrics
        self.metrics['economic_attacks_total'].labels(
            attack_type=EconomicAttackType.LIQUIDITY_MANIPULATION.value,
            status="success" if success else "failed"
        ).inc()
        
        if success:
            self.metrics['economic_attack_profit'].labels(attack_type=EconomicAttackType.LIQUIDITY_MANIPULATION.value).observe(profit)
        
        self.metrics['economic_detection_time'].observe(detection_time)
        self.metrics['token_price_impact'].labels(token_symbol=token.symbol).observe(price_impact)
        
        return attack_result
    
    async def _run_attack_simulation(self) -> None:
        """Run the main economic attack simulation loop"""
        logger.info("Starting economic attack simulation...")
        
        # Determine simulation duration
        duration_hours = 12 if self.config.simulation_duration == "12h" else 1
        
        end_time = time.time() + (duration_hours * 3600)
        
        while time.time() < end_time:
            # Select random attacker and token
            attacker = random.choice(self.attackers)
            token = random.choice(self.tokens)
            
            # Select attack type based on attacker's capabilities
            available_attacks = [at for at in attacker.attack_types]
            if not available_attacks:
                continue
            
            attack_type = random.choice(available_attacks)
            
            try:
                if attack_type == EconomicAttackType.TOKENOMICS_MANIPULATION:
                    attack_result = await self._simulate_tokenomics_manipulation(attacker, token)
                elif attack_type == EconomicAttackType.GOVERNANCE_ATTACK:
                    attack_result = await self._simulate_governance_attack(attacker, token)
                elif attack_type == EconomicAttackType.STAKING_ATTACK:
                    attack_result = await self._simulate_staking_attack(attacker, token)
                elif attack_type == EconomicAttackType.LIQUIDITY_MANIPULATION:
                    attack_result = await self._simulate_liquidity_manipulation(attacker, token)
                else:
                    continue
                
                self.attacks.append(attack_result)
                
                # Log attack result
                status = "SUCCESS" if attack_result["success"] else "FAILED"
                logger.info(f"Economic attack {attack_result['attack_type']} by {attacker.id}: {status} "
                           f"(Profit: ${attack_result.get('profit', 0):.2f}, "
                           f"Detection: {attack_result['detection_time']:.3f}s)")
                
                # Update success rate metrics
                success_rate = sum(1 for a in self.attacks if a["success"]) / len(self.attacks)
                self.metrics['economic_attack_success_rate'].labels(attack_type=attack_type.value).set(success_rate)
                
            except Exception as e:
                logger.error(f"Error in economic attack simulation: {e}")
            
            # Wait before next attack
            if self.config.attack_frequency == "high":
                await asyncio.sleep(random.uniform(2, 8))
            elif self.config.attack_frequency == "medium":
                await asyncio.sleep(random.uniform(8, 20))
            else:  # low
                await asyncio.sleep(random.uniform(20, 60))
    
    async def run_simulation(self) -> None:
        """Run the complete economic attack simulation"""
        logger.info("Initializing economic attack simulation environment...")
        
        # Initialize environment
        self._create_attackers()
        self._create_tokens()
        
        # Run simulation
        await self._run_attack_simulation()
        
        # Generate summary report
        self._generate_report()
        
        logger.info("Economic attack simulation completed")
    
    def _generate_report(self) -> None:
        """Generate simulation report"""
        total_attacks = len(self.attacks)
        successful_attacks = sum(1 for a in self.attacks if a["success"])
        total_profit = sum(a["profit"] for a in self.attacks if a["success"])
        avg_detection_time = np.mean([a["detection_time"] for a in self.attacks])
        
        report = {
            "simulation_summary": {
                "total_attacks": total_attacks,
                "successful_attacks": successful_attacks,
                "success_rate": successful_attacks / total_attacks if total_attacks > 0 else 0,
                "total_profit": total_profit,
                "average_detection_time": avg_detection_time
            },
            "attack_breakdown": {},
            "attacker_performance": {},
            "token_impact": {}
        }
        
        # Attack type breakdown
        for attack_type in EconomicAttackType:
            type_attacks = [a for a in self.attacks if a["attack_type"] == attack_type.value]
            if type_attacks:
                report["attack_breakdown"][attack_type.value] = {
                    "count": len(type_attacks),
                    "success_rate": sum(1 for a in type_attacks if a["success"]) / len(type_attacks),
                    "total_profit": sum(a["profit"] for a in type_attacks if a["success"]),
                    "avg_detection_time": np.mean([a["detection_time"] for a in type_attacks])
                }
        
        # Attacker performance
        for attacker in self.attackers:
            attacker_attacks = [a for a in self.attacks if a["attacker_id"] == attacker.id]
            if attacker_attacks:
                report["attacker_performance"][attacker.id] = {
                    "attack_count": len(attacker_attacks),
                    "success_rate": sum(1 for a in attacker_attacks if a["success"]) / len(attacker_attacks),
                    "total_profit": sum(a["profit"] for a in attacker_attacks if a["success"])
                }
        
        # Token impact analysis
        for token in self.tokens:
            token_attacks = [a for a in self.attacks if a.get("token_symbol") == token.symbol]
            if token_attacks:
                report["token_impact"][token.symbol] = {
                    "attack_count": len(token_attacks),
                    "success_rate": sum(1 for a in token_attacks if a["success"]) / len(token_attacks),
                    "total_profit": sum(a["profit"] for a in token_attacks if a["success"]),
                    "price_impact": np.mean([a.get("price_impact", 0) for a in token_attacks])
                }
        
        # Save report
        report_file = f"logs/economic_simulation_report_{int(time.time())}.json"
        with open(report_file, 'w') as f:
            json.dump(report, f, indent=2)
        
        logger.info(f"Simulation report saved to {report_file}")
        logger.info(f"Total attacks: {total_attacks}, Success rate: {successful_attacks/total_attacks:.2%}, "
                   f"Total profit: ${total_profit:.2f}")


async def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description="Economic Attack Simulator")
    parser.add_argument("--config", required=True, help="Path to configuration file")
    parser.add_argument("--monitoring", action="store_true", help="Enable monitoring")
    parser.add_argument("--log-level", default="INFO", help="Log level")
    parser.add_argument("--output", help="Output file for results")
    
    args = parser.parse_args()
    
    # Configure logging
    logger.remove()
    logger.add(sys.stderr, level=args.log_level)
    
    # Create simulator
    simulator = EconomicSimulator(args.config, args.monitoring)
    
    # Run simulation
    await simulator.run_simulation()


if __name__ == "__main__":
    asyncio.run(main())
