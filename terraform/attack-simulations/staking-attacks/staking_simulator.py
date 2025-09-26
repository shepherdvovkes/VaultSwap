#!/usr/bin/env python3
"""
Staking Attack Simulator
Simulates various staking attacks including slashing attacks, validator attacks, and delegation attacks.
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


class StakingAttackType(Enum):
    SLASHING_ATTACK = "slashing_attack"
    VALIDATOR_ATTACK = "validator_attack"
    DELEGATION_ATTACK = "delegation_attack"
    REWARD_MANIPULATION = "reward_manipulation"
    VALIDATOR_TAKEOVER = "validator_takeover"
    STAKING_POOL_ATTACK = "staking_pool_attack"
    UNBONDING_ATTACK = "unbonding_attack"
    STAKING_ECONOMICS_ATTACK = "staking_economics_attack"


class AttackStatus(Enum):
    PENDING = "pending"
    EXECUTING = "executing"
    SUCCESS = "success"
    FAILED = "failed"
    DETECTED = "detected"


@dataclass
class Validator:
    """Represents a validator node"""
    id: str
    address: str
    staked_amount: float
    commission_rate: float
    uptime: float
    is_active: bool
    slashing_risk: float
    delegation_count: int
    total_delegated: float


@dataclass
class StakingPool:
    """Represents a staking pool"""
    address: str
    total_staked: float
    reward_rate: float
    lock_period: int  # in seconds
    minimum_stake: float
    maximum_stake: float
    is_vulnerable: bool
    validator_set: List[Validator]


@dataclass
class StakingAttacker:
    """Represents a staking attacker"""
    id: str
    address: str
    staked_amount: float
    delegated_amount: float
    success_rate: float
    attack_types: List[StakingAttackType]
    max_attack_amount: float


class StakingConfig(BaseModel):
    """Configuration for staking attack simulation"""
    validator_count: int = Field(default=20, ge=1, le=100)
    pool_count: int = Field(default=5, ge=1, le=20)
    attacker_count: int = Field(default=5, ge=1, le=15)
    attack_frequency: str = Field(default="medium")
    target_pools: List[str] = Field(default=["Ethereum", "Solana", "Cardano", "Polkadot", "Cosmos"])
    simulation_duration: str = Field(default="12h")
    attack_intensity: List[str] = Field(default=["low", "medium", "high", "extreme"])


class StakingSimulator:
    """Main staking attack simulator"""
    
    def __init__(self, config_path: str, monitoring: bool = False):
        self.config = self._load_config(config_path)
        self.monitoring = monitoring
        self.attackers: List[StakingAttacker] = []
        self.validators: List[Validator] = []
        self.pools: List[StakingPool] = []
        self.attacks: List[Dict] = []
        self.metrics = self._setup_metrics()
        
        # Setup logging
        logger.add("logs/staking_simulator_{time}.log", rotation="1 day", retention="7 days")
        
        if monitoring:
            start_http_server(8087)
            logger.info("Prometheus metrics server started on port 8087")
    
    def _load_config(self, config_path: str) -> StakingConfig:
        """Load configuration from JSON file"""
        try:
            with open(config_path, 'r') as f:
                config_data = json.load(f)
            return StakingConfig(**config_data.get('simulation_config', {}))
        except Exception as e:
            logger.error(f"Failed to load config: {e}")
            return StakingConfig()
    
    def _setup_metrics(self) -> Dict:
        """Setup Prometheus metrics"""
        return {
            'staking_attacks_total': Counter('staking_attacks_total', 'Total staking attacks', ['attack_type', 'status']),
            'staking_attack_success_rate': Gauge('staking_attack_success_rate', 'Staking attack success rate', ['attack_type']),
            'staking_attack_profit': Histogram('staking_attack_profit', 'Staking attack profit', ['attack_type']),
            'staking_detection_time': Histogram('staking_detection_time_seconds', 'Time to detect staking attack'),
            'validator_uptime': Gauge('validator_uptime', 'Validator uptime percentage', ['validator_id']),
            'staking_pool_health': Gauge('staking_pool_health', 'Staking pool health score', ['pool_address']),
            'attacker_count': Gauge('staking_attacker_count', 'Number of active staking attackers'),
            'validator_count': Gauge('staking_validator_count', 'Number of monitored validators')
        }
    
    def _create_attackers(self) -> None:
        """Create staking attackers with different characteristics"""
        for i in range(self.config.attacker_count):
            attacker = StakingAttacker(
                id=f"staking_attacker_{i}",
                address=f"0x{random.randint(1000000000000000000000000000000000000000, 9999999999999999999999999999999999999999):x}",
                staked_amount=random.uniform(10000, 100000),
                delegated_amount=random.uniform(5000, 50000),
                success_rate=random.uniform(0.1, 0.7),
                attack_types=random.sample(list(StakingAttackType), random.randint(1, 4)),
                max_attack_amount=random.uniform(50000, 500000)
            )
            self.attackers.append(attacker)
        
        logger.info(f"Created {len(self.attackers)} staking attackers")
        self.metrics['attacker_count'].set(len(self.attackers))
    
    def _create_validators(self) -> None:
        """Create validators for simulation"""
        for i in range(self.config.validator_count):
            validator = Validator(
                id=f"validator_{i}",
                address=f"0x{random.randint(1000000000000000000000000000000000000000, 9999999999999999999999999999999999999999):x}",
                staked_amount=random.uniform(100000, 1000000),
                commission_rate=random.uniform(0.01, 0.1),  # 1-10% commission
                uptime=random.uniform(0.8, 1.0),  # 80-100% uptime
                is_active=random.random() < 0.9,  # 90% active
                slashing_risk=random.uniform(0.01, 0.1),  # 1-10% slashing risk
                delegation_count=random.randint(0, 100),
                total_delegated=random.uniform(0, 500000)
            )
            self.validators.append(validator)
        
        logger.info(f"Created {len(self.validators)} validators")
        self.metrics['validator_count'].set(len(self.validators))
    
    def _create_pools(self) -> None:
        """Create staking pools for simulation"""
        for i in range(self.config.pool_count):
            # Select validators for this pool
            pool_validators = random.sample(self.validators, random.randint(5, 15))
            
            pool = StakingPool(
                address=f"0x{random.randint(1000000000000000000000000000000000000000, 9999999999999999999999999999999999999999):x}",
                total_staked=random.uniform(1000000, 10000000),
                reward_rate=random.uniform(0.05, 0.2),  # 5-20% APY
                lock_period=random.randint(86400, 31536000),  # 1 day to 1 year
                minimum_stake=random.uniform(100, 1000),
                maximum_stake=random.uniform(100000, 1000000),
                is_vulnerable=random.random() < 0.2,  # 20% chance of being vulnerable
                validator_set=pool_validators
            )
            self.pools.append(pool)
        
        logger.info(f"Created {len(self.pools)} staking pools")
    
    async def _simulate_slashing_attack(self, attacker: StakingAttacker, validator: Validator) -> Dict:
        """Simulate slashing attack"""
        start_time = time.time()
        
        # Simulate slashing attack
        slashing_amount = min(random.uniform(10000, 100000), attacker.max_attack_amount)
        
        # Simulate validator misbehavior to trigger slashing
        misbehavior_events = random.randint(1, 5)
        slashing_penalty = validator.slashing_risk * slashing_amount
        
        # Calculate profit from slashing
        profit = slashing_penalty * random.uniform(0.1, 0.5)
        success = profit > 0 and validator.is_active
        
        detection_time = time.time() - start_time
        
        attack_result = {
            "attack_type": StakingAttackType.SLASHING_ATTACK.value,
            "attacker_id": attacker.id,
            "validator_id": validator.id,
            "slashing_amount": slashing_amount,
            "misbehavior_events": misbehavior_events,
            "slashing_penalty": slashing_penalty,
            "validator_uptime": validator.uptime,
            "profit": profit,
            "success": success,
            "detection_time": detection_time,
            "timestamp": time.time()
        }
        
        # Update metrics
        self.metrics['staking_attacks_total'].labels(
            attack_type=StakingAttackType.SLASHING_ATTACK.value,
            status="success" if success else "failed"
        ).inc()
        
        if success:
            self.metrics['staking_attack_profit'].labels(attack_type=StakingAttackType.SLASHING_ATTACK.value).observe(profit)
        
        self.metrics['staking_detection_time'].observe(detection_time)
        self.metrics['validator_uptime'].labels(validator_id=validator.id).set(validator.uptime)
        
        return attack_result
    
    async def _simulate_validator_attack(self, attacker: StakingAttacker, validator: Validator) -> Dict:
        """Simulate validator attack"""
        start_time = time.time()
        
        # Simulate validator compromise
        compromise_amount = min(random.uniform(20000, 200000), attacker.max_attack_amount)
        
        # Simulate validator compromise methods
        compromise_methods = ["private_key_compromise", "node_infiltration", "social_engineering"]
        compromise_method = random.choice(compromise_methods)
        
        # Calculate compromise success rate
        compromise_success_rate = random.uniform(0.1, 0.8)
        is_compromised = random.random() < compromise_success_rate
        
        # Calculate profit from validator compromise
        profit = compromise_amount * random.uniform(0.2, 0.6) if is_compromised else 0
        success = profit > 0 and is_compromised
        
        detection_time = time.time() - start_time
        
        attack_result = {
            "attack_type": StakingAttackType.VALIDATOR_ATTACK.value,
            "attacker_id": attacker.id,
            "validator_id": validator.id,
            "compromise_amount": compromise_amount,
            "compromise_method": compromise_method,
            "compromise_success_rate": compromise_success_rate,
            "is_compromised": is_compromised,
            "profit": profit,
            "success": success,
            "detection_time": detection_time,
            "timestamp": time.time()
        }
        
        # Update metrics
        self.metrics['staking_attacks_total'].labels(
            attack_type=StakingAttackType.VALIDATOR_ATTACK.value,
            status="success" if success else "failed"
        ).inc()
        
        if success:
            self.metrics['staking_attack_profit'].labels(attack_type=StakingAttackType.VALIDATOR_ATTACK.value).observe(profit)
        
        self.metrics['staking_detection_time'].observe(detection_time)
        
        return attack_result
    
    async def _simulate_delegation_attack(self, attacker: StakingAttacker, pool: StakingPool) -> Dict:
        """Simulate delegation attack"""
        start_time = time.time()
        
        # Simulate delegation manipulation
        delegation_amount = min(random.uniform(50000, 500000), attacker.max_attack_amount)
        
        # Simulate delegation gaming
        delegation_gaming = random.uniform(0.1, 0.5)  # 10-50% gaming
        manipulated_delegations = delegation_amount * delegation_gaming
        
        # Simulate reward manipulation
        reward_manipulation = random.uniform(0.05, 0.3)  # 5-30% reward manipulation
        manipulated_rewards = pool.reward_rate * reward_manipulation
        
        # Calculate profit from delegation attack
        profit = manipulated_delegations * manipulated_rewards * random.uniform(0.1, 0.4)
        success = profit > 0 and pool.is_vulnerable
        
        detection_time = time.time() - start_time
        
        attack_result = {
            "attack_type": StakingAttackType.DELEGATION_ATTACK.value,
            "attacker_id": attacker.id,
            "pool_address": pool.address,
            "delegation_amount": delegation_amount,
            "delegation_gaming": delegation_gaming,
            "manipulated_delegations": manipulated_delegations,
            "reward_manipulation": reward_manipulation,
            "manipulated_rewards": manipulated_rewards,
            "profit": profit,
            "success": success,
            "detection_time": detection_time,
            "timestamp": time.time()
        }
        
        # Update metrics
        self.metrics['staking_attacks_total'].labels(
            attack_type=StakingAttackType.DELEGATION_ATTACK.value,
            status="success" if success else "failed"
        ).inc()
        
        if success:
            self.metrics['staking_attack_profit'].labels(attack_type=StakingAttackType.DELEGATION_ATTACK.value).observe(profit)
        
        self.metrics['staking_detection_time'].observe(detection_time)
        self.metrics['staking_pool_health'].labels(pool_address=pool.address).set(1.0 - (0.2 if pool.is_vulnerable else 0.0))
        
        return attack_result
    
    async def _simulate_reward_manipulation(self, attacker: StakingAttacker, pool: StakingPool) -> Dict:
        """Simulate reward manipulation attack"""
        start_time = time.time()
        
        # Simulate reward manipulation
        reward_manipulation_amount = min(random.uniform(30000, 300000), attacker.max_attack_amount)
        
        # Simulate reward calculation manipulation
        reward_calculation_manipulation = random.uniform(0.1, 0.4)  # 10-40% manipulation
        manipulated_reward_rate = pool.reward_rate * (1 + reward_calculation_manipulation)
        
        # Simulate time manipulation
        time_manipulation = random.uniform(0.05, 0.2)  # 5-20% time manipulation
        manipulated_lock_period = pool.lock_period * (1 - time_manipulation)
        
        # Calculate profit from reward manipulation
        profit = reward_manipulation_amount * reward_calculation_manipulation * random.uniform(0.1, 0.3)
        success = profit > 0 and pool.is_vulnerable
        
        detection_time = time.time() - start_time
        
        attack_result = {
            "attack_type": StakingAttackType.REWARD_MANIPULATION.value,
            "attacker_id": attacker.id,
            "pool_address": pool.address,
            "reward_manipulation_amount": reward_manipulation_amount,
            "reward_calculation_manipulation": reward_calculation_manipulation,
            "manipulated_reward_rate": manipulated_reward_rate,
            "time_manipulation": time_manipulation,
            "manipulated_lock_period": manipulated_lock_period,
            "profit": profit,
            "success": success,
            "detection_time": detection_time,
            "timestamp": time.time()
        }
        
        # Update metrics
        self.metrics['staking_attacks_total'].labels(
            attack_type=StakingAttackType.REWARD_MANIPULATION.value,
            status="success" if success else "failed"
        ).inc()
        
        if success:
            self.metrics['staking_attack_profit'].labels(attack_type=StakingAttackType.REWARD_MANIPULATION.value).observe(profit)
        
        self.metrics['staking_detection_time'].observe(detection_time)
        
        return attack_result
    
    async def _simulate_validator_takeover(self, attacker: StakingAttacker, validator: Validator) -> Dict:
        """Simulate validator takeover attack"""
        start_time = time.time()
        
        # Simulate validator takeover
        takeover_amount = min(random.uniform(100000, 1000000), attacker.max_attack_amount)
        
        # Calculate takeover requirements
        stake_required = validator.staked_amount * random.uniform(0.1, 0.5)  # 10-50% of validator stake
        delegation_required = validator.total_delegated * random.uniform(0.2, 0.8)  # 20-80% of delegations
        
        # Check if attacker can achieve takeover
        can_takeover = (attacker.staked_amount >= stake_required and 
                       attacker.delegated_amount >= delegation_required)
        
        # Calculate profit from takeover
        profit = takeover_amount * random.uniform(0.1, 0.4) if can_takeover else 0
        success = profit > 0 and can_takeover
        
        detection_time = time.time() - start_time
        
        attack_result = {
            "attack_type": StakingAttackType.VALIDATOR_TAKEOVER.value,
            "attacker_id": attacker.id,
            "validator_id": validator.id,
            "takeover_amount": takeover_amount,
            "stake_required": stake_required,
            "delegation_required": delegation_required,
            "can_takeover": can_takeover,
            "profit": profit,
            "success": success,
            "detection_time": detection_time,
            "timestamp": time.time()
        }
        
        # Update metrics
        self.metrics['staking_attacks_total'].labels(
            attack_type=StakingAttackType.VALIDATOR_TAKEOVER.value,
            status="success" if success else "failed"
        ).inc()
        
        if success:
            self.metrics['staking_attack_profit'].labels(attack_type=StakingAttackType.VALIDATOR_TAKEOVER.value).observe(profit)
        
        self.metrics['staking_detection_time'].observe(detection_time)
        
        return attack_result
    
    async def _run_attack_simulation(self) -> None:
        """Run the main staking attack simulation loop"""
        logger.info("Starting staking attack simulation...")
        
        # Determine simulation duration
        duration_hours = 12 if self.config.simulation_duration == "12h" else 1
        
        end_time = time.time() + (duration_hours * 3600)
        
        while time.time() < end_time:
            # Select random attacker
            attacker = random.choice(self.attackers)
            
            # Select attack type based on attacker's capabilities
            available_attacks = [at for at in attacker.attack_types]
            if not available_attacks:
                continue
            
            attack_type = random.choice(available_attacks)
            
            try:
                if attack_type == StakingAttackType.SLASHING_ATTACK:
                    validator = random.choice(self.validators)
                    attack_result = await self._simulate_slashing_attack(attacker, validator)
                elif attack_type == StakingAttackType.VALIDATOR_ATTACK:
                    validator = random.choice(self.validators)
                    attack_result = await self._simulate_validator_attack(attacker, validator)
                elif attack_type == StakingAttackType.DELEGATION_ATTACK:
                    pool = random.choice(self.pools)
                    attack_result = await self._simulate_delegation_attack(attacker, pool)
                elif attack_type == StakingAttackType.REWARD_MANIPULATION:
                    pool = random.choice(self.pools)
                    attack_result = await self._simulate_reward_manipulation(attacker, pool)
                elif attack_type == StakingAttackType.VALIDATOR_TAKEOVER:
                    validator = random.choice(self.validators)
                    attack_result = await self._simulate_validator_takeover(attacker, validator)
                else:
                    continue
                
                self.attacks.append(attack_result)
                
                # Log attack result
                status = "SUCCESS" if attack_result["success"] else "FAILED"
                logger.info(f"Staking attack {attack_result['attack_type']} by {attacker.id}: {status} "
                           f"(Profit: ${attack_result.get('profit', 0):.2f}, "
                           f"Detection: {attack_result['detection_time']:.3f}s)")
                
                # Update success rate metrics
                success_rate = sum(1 for a in self.attacks if a["success"]) / len(self.attacks)
                self.metrics['staking_attack_success_rate'].labels(attack_type=attack_type.value).set(success_rate)
                
            except Exception as e:
                logger.error(f"Error in staking attack simulation: {e}")
            
            # Wait before next attack
            if self.config.attack_frequency == "high":
                await asyncio.sleep(random.uniform(2, 8))
            elif self.config.attack_frequency == "medium":
                await asyncio.sleep(random.uniform(8, 30))
            else:  # low
                await asyncio.sleep(random.uniform(30, 120))
    
    async def run_simulation(self) -> None:
        """Run the complete staking attack simulation"""
        logger.info("Initializing staking attack simulation environment...")
        
        # Initialize environment
        self._create_validators()
        self._create_pools()
        self._create_attackers()
        
        # Run simulation
        await self._run_attack_simulation()
        
        # Generate summary report
        self._generate_report()
        
        logger.info("Staking attack simulation completed")
    
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
            "validator_analysis": {},
            "pool_analysis": {}
        }
        
        # Attack type breakdown
        for attack_type in StakingAttackType:
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
                    "total_profit": sum(a["profit"] for a in attacker_attacks if a["success"]),
                    "staked_amount": attacker.staked_amount,
                    "delegated_amount": attacker.delegated_amount
                }
        
        # Validator analysis
        active_validators = [v for v in self.validators if v.is_active]
        report["validator_analysis"] = {
            "total_validators": len(self.validators),
            "active_validators": len(active_validators),
            "average_uptime": np.mean([v.uptime for v in self.validators]),
            "average_slashing_risk": np.mean([v.slashing_risk for v in self.validators]),
            "total_staked": sum(v.staked_amount for v in self.validators),
            "total_delegated": sum(v.total_delegated for v in self.validators)
        }
        
        # Pool analysis
        vulnerable_pools = [p for p in self.pools if p.is_vulnerable]
        report["pool_analysis"] = {
            "total_pools": len(self.pools),
            "vulnerable_pools": len(vulnerable_pools),
            "vulnerability_rate": len(vulnerable_pools) / len(self.pools),
            "total_staked": sum(p.total_staked for p in self.pools),
            "average_reward_rate": np.mean([p.reward_rate for p in self.pools]),
            "average_lock_period": np.mean([p.lock_period for p in self.pools])
        }
        
        # Save report
        report_file = f"logs/staking_simulation_report_{int(time.time())}.json"
        with open(report_file, 'w') as f:
            json.dump(report, f, indent=2)
        
        logger.info(f"Simulation report saved to {report_file}")
        logger.info(f"Total attacks: {total_attacks}, Success rate: {successful_attacks/total_attacks:.2%}, "
                   f"Total profit: ${total_profit:.2f}")


async def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description="Staking Attack Simulator")
    parser.add_argument("--config", required=True, help="Path to configuration file")
    parser.add_argument("--monitoring", action="store_true", help="Enable monitoring")
    parser.add_argument("--log-level", default="INFO", help="Log level")
    parser.add_argument("--output", help="Output file for results")
    
    args = parser.parse_args()
    
    # Configure logging
    logger.remove()
    logger.add(sys.stderr, level=args.log_level)
    
    # Create simulator
    simulator = StakingSimulator(args.config, args.monitoring)
    
    # Run simulation
    await simulator.run_simulation()


if __name__ == "__main__":
    asyncio.run(main())
