#!/usr/bin/env python3
"""
MEV Attack Simulator
Simulates various MEV (Maximal Extractable Value) attacks to test DEX security measures.
"""

import asyncio
import json
import logging
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


class AttackType(Enum):
    SANDWICH = "sandwich_attack"
    FRONT_RUNNING = "front_running"
    BACK_RUNNING = "back_running"
    ARBITRAGE = "arbitrage_attack"


class AttackStatus(Enum):
    PENDING = "pending"
    EXECUTING = "executing"
    SUCCESS = "success"
    FAILED = "failed"
    DETECTED = "detected"


@dataclass
class Transaction:
    """Represents a blockchain transaction"""
    hash: str
    from_address: str
    to_address: str
    amount: float
    gas_price: float
    gas_limit: int
    timestamp: float
    nonce: int
    data: str = ""


@dataclass
class Pool:
    """Represents a liquidity pool"""
    address: str
    token_a: str
    token_b: str
    reserve_a: float
    reserve_b: float
    fee: float
    last_update: float


@dataclass
class MEVBot:
    """Represents an MEV bot"""
    id: str
    address: str
    balance: float
    gas_price_multiplier: float
    success_rate: float
    attack_types: List[AttackType]


class AttackConfig(BaseModel):
    """Configuration for attack simulation"""
    bot_count: int = Field(default=10, ge=1, le=100)
    attack_frequency: str = Field(default="high")
    target_pools: List[str] = Field(default=["USDC/USDT", "SOL/USDC", "ETH/USDC"])
    attack_patterns: List[str] = Field(default=["sandwich_attack", "front_running", "back_running", "arbitrage_attack"])
    simulation_duration: str = Field(default="24h")
    intensity_levels: List[str] = Field(default=["low", "medium", "high", "extreme"])


class MEVSimulator:
    """Main MEV attack simulator"""
    
    def __init__(self, config_path: str, monitoring: bool = False):
        self.config = self._load_config(config_path)
        self.monitoring = monitoring
        self.bots: List[MEVBot] = []
        self.pools: List[Pool] = []
        self.attacks: List[Dict] = []
        self.metrics = self._setup_metrics()
        
        # Setup logging
        logger.add("logs/mev_simulator_{time}.log", rotation="1 day", retention="7 days")
        
        if monitoring:
            start_http_server(8080)
            logger.info("Prometheus metrics server started on port 8080")
    
    def _load_config(self, config_path: str) -> AttackConfig:
        """Load configuration from JSON file"""
        try:
            with open(config_path, 'r') as f:
                config_data = json.load(f)
            return AttackConfig(**config_data.get('simulation_config', {}))
        except Exception as e:
            logger.error(f"Failed to load config: {e}")
            return AttackConfig()
    
    def _setup_metrics(self) -> Dict:
        """Setup Prometheus metrics"""
        return {
            'attacks_total': Counter('mev_attacks_total', 'Total MEV attacks', ['attack_type', 'status']),
            'attack_success_rate': Gauge('mev_attack_success_rate', 'MEV attack success rate', ['attack_type']),
            'attack_profit': Histogram('mev_attack_profit', 'MEV attack profit', ['attack_type']),
            'detection_time': Histogram('mev_detection_time_seconds', 'Time to detect MEV attack'),
            'bot_count': Gauge('mev_bot_count', 'Number of active MEV bots'),
            'pool_count': Gauge('mev_pool_count', 'Number of monitored pools')
        }
    
    def _create_bots(self) -> None:
        """Create MEV bots with different characteristics"""
        for i in range(self.config.bot_count):
            bot = MEVBot(
                id=f"bot_{i}",
                address=f"0x{random.randint(1000000000000000000000000000000000000000, 9999999999999999999999999999999999999999):x}",
                balance=random.uniform(100, 10000),
                gas_price_multiplier=random.uniform(1.1, 2.0),
                success_rate=random.uniform(0.3, 0.9),
                attack_types=random.sample(list(AttackType), random.randint(1, 3))
            )
            self.bots.append(bot)
        
        logger.info(f"Created {len(self.bots)} MEV bots")
        self.metrics['bot_count'].set(len(self.bots))
    
    def _create_pools(self) -> None:
        """Create liquidity pools for simulation"""
        pool_configs = [
            {"token_a": "USDC", "token_b": "USDT", "reserve_a": 1000000, "reserve_b": 1000000, "fee": 0.003},
            {"token_a": "SOL", "token_b": "USDC", "reserve_a": 10000, "reserve_b": 500000, "fee": 0.003},
            {"token_a": "ETH", "token_b": "USDC", "reserve_a": 1000, "reserve_b": 2000000, "fee": 0.003},
        ]
        
        for i, config in enumerate(pool_configs):
            pool = Pool(
                address=f"pool_{i}",
                token_a=config["token_a"],
                token_b=config["token_b"],
                reserve_a=config["reserve_a"],
                reserve_b=config["reserve_b"],
                fee=config["fee"],
                last_update=time.time()
            )
            self.pools.append(pool)
        
        logger.info(f"Created {len(self.pools)} liquidity pools")
        self.metrics['pool_count'].set(len(self.pools))
    
    async def _simulate_sandwich_attack(self, bot: MEVBot, pool: Pool) -> Dict:
        """Simulate a sandwich attack"""
        start_time = time.time()
        
        # Generate victim transaction
        victim_tx = Transaction(
            hash=f"victim_{int(time.time())}",
            from_address="victim_address",
            to_address=pool.address,
            amount=random.uniform(100, 1000),
            gas_price=20,
            gas_limit=21000,
            timestamp=time.time(),
            nonce=random.randint(1, 1000)
        )
        
        # Generate front-running transaction
        front_tx = Transaction(
            hash=f"front_{int(time.time())}",
            from_address=bot.address,
            to_address=pool.address,
            amount=victim_tx.amount * 0.5,  # Smaller amount to manipulate price
            gas_price=victim_tx.gas_price * bot.gas_price_multiplier,
            gas_limit=21000,
            timestamp=victim_tx.timestamp - 1,
            nonce=random.randint(1, 1000)
        )
        
        # Generate back-running transaction
        back_tx = Transaction(
            hash=f"back_{int(time.time())}",
            from_address=bot.address,
            to_address=pool.address,
            amount=victim_tx.amount * 0.3,  # Profit from price difference
            gas_price=victim_tx.gas_price * bot.gas_price_multiplier,
            gas_limit=21000,
            timestamp=victim_tx.timestamp + 1,
            nonce=random.randint(1, 1000)
        )
        
        # Simulate attack execution
        await asyncio.sleep(random.uniform(0.1, 0.5))  # Simulate network delay
        
        # Calculate profit (simplified)
        profit = random.uniform(10, 500) if random.random() < bot.success_rate else 0
        success = profit > 0
        
        detection_time = time.time() - start_time
        
        attack_result = {
            "attack_type": AttackType.SANDWICH.value,
            "bot_id": bot.id,
            "pool_address": pool.address,
            "victim_tx": victim_tx.__dict__,
            "front_tx": front_tx.__dict__,
            "back_tx": back_tx.__dict__,
            "profit": profit,
            "success": success,
            "detection_time": detection_time,
            "timestamp": time.time()
        }
        
        # Update metrics
        self.metrics['attacks_total'].labels(
            attack_type=AttackType.SANDWICH.value,
            status="success" if success else "failed"
        ).inc()
        
        if success:
            self.metrics['attack_profit'].labels(attack_type=AttackType.SANDWICH.value).observe(profit)
        
        self.metrics['detection_time'].observe(detection_time)
        
        return attack_result
    
    async def _simulate_front_running_attack(self, bot: MEVBot, pool: Pool) -> Dict:
        """Simulate a front-running attack"""
        start_time = time.time()
        
        # Generate victim transaction
        victim_tx = Transaction(
            hash=f"victim_{int(time.time())}",
            from_address="victim_address",
            to_address=pool.address,
            amount=random.uniform(100, 1000),
            gas_price=20,
            gas_limit=21000,
            timestamp=time.time(),
            nonce=random.randint(1, 1000)
        )
        
        # Generate front-running transaction
        front_tx = Transaction(
            hash=f"front_{int(time.time())}",
            from_address=bot.address,
            to_address=pool.address,
            amount=victim_tx.amount * 0.8,
            gas_price=victim_tx.gas_price * bot.gas_price_multiplier,
            gas_limit=21000,
            timestamp=victim_tx.timestamp - 1,
            nonce=random.randint(1, 1000)
        )
        
        # Simulate attack execution
        await asyncio.sleep(random.uniform(0.05, 0.3))
        
        profit = random.uniform(5, 200) if random.random() < bot.success_rate else 0
        success = profit > 0
        detection_time = time.time() - start_time
        
        attack_result = {
            "attack_type": AttackType.FRONT_RUNNING.value,
            "bot_id": bot.id,
            "pool_address": pool.address,
            "victim_tx": victim_tx.__dict__,
            "front_tx": front_tx.__dict__,
            "profit": profit,
            "success": success,
            "detection_time": detection_time,
            "timestamp": time.time()
        }
        
        # Update metrics
        self.metrics['attacks_total'].labels(
            attack_type=AttackType.FRONT_RUNNING.value,
            status="success" if success else "failed"
        ).inc()
        
        if success:
            self.metrics['attack_profit'].labels(attack_type=AttackType.FRONT_RUNNING.value).observe(profit)
        
        self.metrics['detection_time'].observe(detection_time)
        
        return attack_result
    
    async def _simulate_arbitrage_attack(self, bot: MEVBot, pool: Pool) -> Dict:
        """Simulate an arbitrage attack"""
        start_time = time.time()
        
        # Simulate price difference between pools
        price_difference = random.uniform(0.01, 0.05)  # 1-5% price difference
        
        arbitrage_tx = Transaction(
            hash=f"arb_{int(time.time())}",
            from_address=bot.address,
            to_address=pool.address,
            amount=random.uniform(1000, 10000),
            gas_price=20 * bot.gas_price_multiplier,
            gas_limit=21000,
            timestamp=time.time(),
            nonce=random.randint(1, 1000)
        )
        
        # Simulate attack execution
        await asyncio.sleep(random.uniform(0.1, 0.8))
        
        profit = random.uniform(50, 1000) * price_difference if random.random() < bot.success_rate else 0
        success = profit > 0
        detection_time = time.time() - start_time
        
        attack_result = {
            "attack_type": AttackType.ARBITRAGE.value,
            "bot_id": bot.id,
            "pool_address": pool.address,
            "arbitrage_tx": arbitrage_tx.__dict__,
            "price_difference": price_difference,
            "profit": profit,
            "success": success,
            "detection_time": detection_time,
            "timestamp": time.time()
        }
        
        # Update metrics
        self.metrics['attacks_total'].labels(
            attack_type=AttackType.ARBITRAGE.value,
            status="success" if success else "failed"
        ).inc()
        
        if success:
            self.metrics['attack_profit'].labels(attack_type=AttackType.ARBITRAGE.value).observe(profit)
        
        self.metrics['detection_time'].observe(detection_time)
        
        return attack_result
    
    async def _run_attack_simulation(self) -> None:
        """Run the main attack simulation loop"""
        logger.info("Starting MEV attack simulation...")
        
        # Determine simulation duration
        duration_hours = 24 if self.config.simulation_duration == "24h" else 1
        
        end_time = time.time() + (duration_hours * 3600)
        
        while time.time() < end_time:
            # Select random bot and pool
            bot = random.choice(self.bots)
            pool = random.choice(self.pools)
            
            # Select attack type based on bot's capabilities
            available_attacks = [at for at in bot.attack_types]
            if not available_attacks:
                continue
            
            attack_type = random.choice(available_attacks)
            
            try:
                if attack_type == AttackType.SANDWICH:
                    attack_result = await self._simulate_sandwich_attack(bot, pool)
                elif attack_type == AttackType.FRONT_RUNNING:
                    attack_result = await self._simulate_front_running_attack(bot, pool)
                elif attack_type == AttackType.ARBITRAGE:
                    attack_result = await self._simulate_arbitrage_attack(bot, pool)
                else:
                    continue
                
                self.attacks.append(attack_result)
                
                # Log attack result
                status = "SUCCESS" if attack_result["success"] else "FAILED"
                logger.info(f"Attack {attack_result['attack_type']} by {bot.id}: {status} "
                           f"(Profit: ${attack_result['profit']:.2f}, "
                           f"Detection: {attack_result['detection_time']:.3f}s)")
                
                # Update success rate metrics
                success_rate = sum(1 for a in self.attacks if a["success"]) / len(self.attacks)
                self.metrics['attack_success_rate'].labels(attack_type=attack_type.value).set(success_rate)
                
            except Exception as e:
                logger.error(f"Error in attack simulation: {e}")
            
            # Wait before next attack based on frequency setting
            if self.config.attack_frequency == "high":
                await asyncio.sleep(random.uniform(1, 5))
            elif self.config.attack_frequency == "medium":
                await asyncio.sleep(random.uniform(5, 15))
            else:  # low
                await asyncio.sleep(random.uniform(15, 60))
    
    async def run_simulation(self) -> None:
        """Run the complete MEV attack simulation"""
        logger.info("Initializing MEV attack simulation environment...")
        
        # Initialize environment
        self._create_bots()
        self._create_pools()
        
        # Run simulation
        await self._run_attack_simulation()
        
        # Generate summary report
        self._generate_report()
        
        logger.info("MEV attack simulation completed")
    
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
            "bot_performance": {}
        }
        
        # Attack type breakdown
        for attack_type in AttackType:
            type_attacks = [a for a in self.attacks if a["attack_type"] == attack_type.value]
            if type_attacks:
                report["attack_breakdown"][attack_type.value] = {
                    "count": len(type_attacks),
                    "success_rate": sum(1 for a in type_attacks if a["success"]) / len(type_attacks),
                    "total_profit": sum(a["profit"] for a in type_attacks if a["success"]),
                    "avg_detection_time": np.mean([a["detection_time"] for a in type_attacks])
                }
        
        # Bot performance
        for bot in self.bots:
            bot_attacks = [a for a in self.attacks if a["bot_id"] == bot.id]
            if bot_attacks:
                report["bot_performance"][bot.id] = {
                    "attack_count": len(bot_attacks),
                    "success_rate": sum(1 for a in bot_attacks if a["success"]) / len(bot_attacks),
                    "total_profit": sum(a["profit"] for a in bot_attacks if a["success"])
                }
        
        # Save report
        report_file = f"logs/mev_simulation_report_{int(time.time())}.json"
        with open(report_file, 'w') as f:
            json.dump(report, f, indent=2)
        
        logger.info(f"Simulation report saved to {report_file}")
        logger.info(f"Total attacks: {total_attacks}, Success rate: {successful_attacks/total_attacks:.2%}, "
                   f"Total profit: ${total_profit:.2f}")


async def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description="MEV Attack Simulator")
    parser.add_argument("--config", required=True, help="Path to configuration file")
    parser.add_argument("--monitoring", action="store_true", help="Enable monitoring")
    parser.add_argument("--log-level", default="INFO", help="Log level")
    parser.add_argument("--output", help="Output file for results")
    
    args = parser.parse_args()
    
    # Configure logging
    logger.remove()
    logger.add(sys.stderr, level=args.log_level)
    
    # Create simulator
    simulator = MEVSimulator(args.config, args.monitoring)
    
    # Run simulation
    await simulator.run_simulation()


if __name__ == "__main__":
    asyncio.run(main())
