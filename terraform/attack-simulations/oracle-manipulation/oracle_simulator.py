#!/usr/bin/env python3
"""
Oracle Manipulation Attack Simulator
Simulates various oracle manipulation attacks to test DEX security measures.
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


class OracleSource(Enum):
    CHAINLINK = "chainlink"
    PYTH = "pyth"
    BAND = "band"
    TWAP = "twap"
    CUSTOM = "custom"


class OracleAttackType(Enum):
    PRICE_FLASH_LOAN = "price_flash_loan"
    ORACLE_DELAY_EXPLOIT = "oracle_delay_exploit"
    CROSS_CHAIN_MANIPULATION = "cross_chain_manipulation"
    GOVERNANCE_ORACLE_ATTACK = "governance_oracle_attack"


class AttackStatus(Enum):
    PENDING = "pending"
    EXECUTING = "executing"
    SUCCESS = "success"
    FAILED = "failed"
    DETECTED = "detected"


@dataclass
class OraclePrice:
    """Represents an oracle price feed"""
    source: OracleSource
    token: str
    price: float
    timestamp: float
    confidence: float
    deviation: float = 0.0


@dataclass
class OracleManipulator:
    """Represents an oracle manipulator"""
    id: str
    address: str
    balance: float
    success_rate: float
    attack_types: List[OracleAttackType]
    max_manipulation_amount: float


class OracleConfig(BaseModel):
    """Configuration for oracle manipulation attack simulation"""
    oracle_sources: List[str] = Field(default=["chainlink", "pyth", "band", "twap"])
    manipulation_methods: List[str] = Field(default=["price_flash_loan", "oracle_delay_exploit", "cross_chain_manipulation", "governance_oracle_attack"])
    target_pairs: List[str] = Field(default=["SOL/USD", "ETH/USD", "BTC/USD"])
    simulation_duration: str = Field(default="6h")
    manipulation_intensity: List[str] = Field(default=["subtle", "moderate", "aggressive", "extreme"])


class OracleSimulator:
    """Main oracle manipulation attack simulator"""
    
    def __init__(self, config_path: str, monitoring: bool = False):
        self.config = self._load_config(config_path)
        self.monitoring = monitoring
        self.manipulators: List[OracleManipulator] = []
        self.oracle_prices: Dict[str, List[OraclePrice]] = {}
        self.attacks: List[Dict] = []
        self.metrics = self._setup_metrics()
        
        # Setup logging
        logger.add("logs/oracle_simulator_{time}.log", rotation="1 day", retention="7 days")
        
        if monitoring:
            start_http_server(8082)
            logger.info("Prometheus metrics server started on port 8082")
    
    def _load_config(self, config_path: str) -> OracleConfig:
        """Load configuration from JSON file"""
        try:
            with open(config_path, 'r') as f:
                config_data = json.load(f)
            return OracleConfig(**config_data.get('simulation_config', {}))
        except Exception as e:
            logger.error(f"Failed to load config: {e}")
            return OracleConfig()
    
    def _setup_metrics(self) -> Dict:
        """Setup Prometheus metrics"""
        return {
            'oracle_attacks_total': Counter('oracle_attacks_total', 'Total oracle manipulation attacks', ['attack_type', 'status']),
            'oracle_attack_success_rate': Gauge('oracle_attack_success_rate', 'Oracle attack success rate', ['attack_type']),
            'oracle_attack_profit': Histogram('oracle_attack_profit', 'Oracle attack profit', ['attack_type']),
            'oracle_detection_time': Histogram('oracle_detection_time_seconds', 'Time to detect oracle manipulation'),
            'price_deviation': Histogram('oracle_price_deviation', 'Oracle price deviation', ['token', 'source']),
            'oracle_consensus': Gauge('oracle_consensus_score', 'Oracle consensus score', ['token']),
            'manipulator_count': Gauge('oracle_manipulator_count', 'Number of active oracle manipulators')
        }
    
    def _create_manipulators(self) -> None:
        """Create oracle manipulators with different characteristics"""
        manipulator_count = random.randint(3, 8)
        
        for i in range(manipulator_count):
            manipulator = OracleManipulator(
                id=f"manipulator_{i}",
                address=f"0x{random.randint(1000000000000000000000000000000000000000, 9999999999999999999999999999999999999999):x}",
                balance=random.uniform(5000, 100000),
                success_rate=random.uniform(0.1, 0.7),
                attack_types=random.sample(list(OracleAttackType), random.randint(1, 3)),
                max_manipulation_amount=random.uniform(100000, 10000000)
            )
            self.manipulators.append(manipulator)
        
        logger.info(f"Created {len(self.manipulators)} oracle manipulators")
        self.metrics['manipulator_count'].set(len(self.manipulators))
    
    def _initialize_oracle_prices(self) -> None:
        """Initialize oracle price feeds"""
        base_prices = {
            "SOL/USD": 100.0,
            "ETH/USD": 2000.0,
            "BTC/USD": 30000.0,
            "USDC/USD": 1.0,
            "USDT/USD": 1.0
        }
        
        for pair in self.config.target_pairs:
            self.oracle_prices[pair] = []
            
            # Create initial prices from different sources
            for source in self.config.oracle_sources:
                base_price = base_prices.get(pair, 100.0)
                price = OraclePrice(
                    source=OracleSource(source),
                    token=pair,
                    price=base_price * random.uniform(0.99, 1.01),  # Small variation
                    timestamp=time.time(),
                    confidence=random.uniform(0.8, 1.0)
                )
                self.oracle_prices[pair].append(price)
    
    async def _simulate_price_flash_loan_attack(self, manipulator: OracleManipulator, target_pair: str) -> Dict:
        """Simulate a price flash loan attack"""
        start_time = time.time()
        
        # Get current oracle prices
        current_prices = self.oracle_prices.get(target_pair, [])
        if not current_prices:
            return {"error": "No oracle prices available"}
        
        # Select target oracle source
        target_source = random.choice(current_prices)
        
        # Simulate flash loan for price manipulation
        flash_loan_amount = min(random.uniform(100000, 1000000), manipulator.max_manipulation_amount)
        
        # Calculate price manipulation impact
        manipulation_impact = random.uniform(0.05, 0.2)  # 5-20% price manipulation
        
        # Simulate attack execution
        await asyncio.sleep(random.uniform(0.1, 0.5))
        
        # Create manipulated price
        manipulated_price = OraclePrice(
            source=target_source.source,
            token=target_pair,
            price=target_source.price * (1 + manipulation_impact),
            timestamp=time.time(),
            confidence=target_source.confidence * 0.5,  # Lower confidence
            deviation=manipulation_impact
        )
        
        # Calculate profit from manipulation
        profit = flash_loan_amount * manipulation_impact * random.uniform(0.1, 0.5)
        
        # Check if manipulation is detected
        consensus_threshold = 0.1  # 10% deviation threshold
        is_detected = manipulation_impact > consensus_threshold
        
        success = profit > 0 and not is_detected
        detection_time = time.time() - start_time
        
        attack_result = {
            "attack_type": OracleAttackType.PRICE_FLASH_LOAN.value,
            "manipulator_id": manipulator.id,
            "target_pair": target_pair,
            "target_source": target_source.source.value,
            "flash_loan_amount": flash_loan_amount,
            "manipulation_impact": manipulation_impact,
            "original_price": target_source.price,
            "manipulated_price": manipulated_price.price,
            "profit": profit,
            "success": success,
            "detected": is_detected,
            "detection_time": detection_time,
            "timestamp": time.time()
        }
        
        # Update metrics
        self.metrics['oracle_attacks_total'].labels(
            attack_type=OracleAttackType.PRICE_FLASH_LOAN.value,
            status="success" if success else "failed"
        ).inc()
        
        if success:
            self.metrics['oracle_attack_profit'].labels(attack_type=OracleAttackType.PRICE_FLASH_LOAN.value).observe(profit)
        
        self.metrics['oracle_detection_time'].observe(detection_time)
        self.metrics['price_deviation'].labels(token=target_pair, source=target_source.source.value).observe(manipulation_impact)
        
        return attack_result
    
    async def _simulate_oracle_delay_exploit(self, manipulator: OracleManipulator, target_pair: str) -> Dict:
        """Simulate an oracle delay exploit attack"""
        start_time = time.time()
        
        # Get current oracle prices
        current_prices = self.oracle_prices.get(target_pair, [])
        if not current_prices:
            return {"error": "No oracle prices available"}
        
        # Simulate oracle delay
        delay_seconds = random.uniform(30, 300)  # 30 seconds to 5 minutes delay
        
        # Simulate price movement during delay
        price_movement = random.uniform(-0.1, 0.1)  # -10% to +10% movement
        
        # Simulate attack execution
        await asyncio.sleep(random.uniform(0.2, 1.0))
        
        # Calculate profit from delay exploit
        exploit_amount = random.uniform(10000, 100000)
        profit = exploit_amount * abs(price_movement) * random.uniform(0.5, 1.0)
        
        # Check if delay is detected
        max_acceptable_delay = 60  # 1 minute
        is_detected = delay_seconds > max_acceptable_delay
        
        success = profit > 0 and not is_detected
        detection_time = time.time() - start_time
        
        attack_result = {
            "attack_type": OracleAttackType.ORACLE_DELAY_EXPLOIT.value,
            "manipulator_id": manipulator.id,
            "target_pair": target_pair,
            "delay_seconds": delay_seconds,
            "price_movement": price_movement,
            "exploit_amount": exploit_amount,
            "profit": profit,
            "success": success,
            "detected": is_detected,
            "detection_time": detection_time,
            "timestamp": time.time()
        }
        
        # Update metrics
        self.metrics['oracle_attacks_total'].labels(
            attack_type=OracleAttackType.ORACLE_DELAY_EXPLOIT.value,
            status="success" if success else "failed"
        ).inc()
        
        if success:
            self.metrics['oracle_attack_profit'].labels(attack_type=OracleAttackType.ORACLE_DELAY_EXPLOIT.value).observe(profit)
        
        self.metrics['oracle_detection_time'].observe(detection_time)
        
        return attack_result
    
    async def _simulate_cross_chain_manipulation(self, manipulator: OracleManipulator, target_pair: str) -> Dict:
        """Simulate a cross-chain oracle manipulation attack"""
        start_time = time.time()
        
        # Simulate cross-chain price differences
        chain_a_price = random.uniform(95, 105)
        chain_b_price = random.uniform(95, 105)
        price_difference = abs(chain_a_price - chain_b_price)
        
        # Simulate attack execution
        await asyncio.sleep(random.uniform(0.3, 1.5))
        
        # Calculate profit from cross-chain arbitrage
        arbitrage_amount = random.uniform(50000, 500000)
        profit = arbitrage_amount * (price_difference / 100) * random.uniform(0.3, 0.8)
        
        # Check if cross-chain manipulation is detected
        max_acceptable_difference = 2.0  # 2% maximum difference
        is_detected = price_difference > max_acceptable_difference
        
        success = profit > 0 and not is_detected
        detection_time = time.time() - start_time
        
        attack_result = {
            "attack_type": OracleAttackType.CROSS_CHAIN_MANIPULATION.value,
            "manipulator_id": manipulator.id,
            "target_pair": target_pair,
            "chain_a_price": chain_a_price,
            "chain_b_price": chain_b_price,
            "price_difference": price_difference,
            "arbitrage_amount": arbitrage_amount,
            "profit": profit,
            "success": success,
            "detected": is_detected,
            "detection_time": detection_time,
            "timestamp": time.time()
        }
        
        # Update metrics
        self.metrics['oracle_attacks_total'].labels(
            attack_type=OracleAttackType.CROSS_CHAIN_MANIPULATION.value,
            status="success" if success else "failed"
        ).inc()
        
        if success:
            self.metrics['oracle_attack_profit'].labels(attack_type=OracleAttackType.CROSS_CHAIN_MANIPULATION.value).observe(profit)
        
        self.metrics['oracle_detection_time'].observe(detection_time)
        
        return attack_result
    
    async def _simulate_governance_oracle_attack(self, manipulator: OracleManipulator, target_pair: str) -> Dict:
        """Simulate a governance oracle attack"""
        start_time = time.time()
        
        # Simulate governance token manipulation
        governance_power = random.uniform(0.1, 0.9)  # 10-90% governance power
        
        # Simulate oracle parameter manipulation
        parameter_change = random.uniform(-0.5, 0.5)  # -50% to +50% parameter change
        
        # Simulate attack execution
        await asyncio.sleep(random.uniform(1.0, 5.0))
        
        # Calculate profit from governance manipulation
        governance_amount = random.uniform(100000, 1000000)
        profit = governance_amount * abs(parameter_change) * governance_power * random.uniform(0.1, 0.3)
        
        # Check if governance attack is detected
        max_acceptable_change = 0.2  # 20% maximum parameter change
        is_detected = abs(parameter_change) > max_acceptable_change
        
        success = profit > 0 and not is_detected
        detection_time = time.time() - start_time
        
        attack_result = {
            "attack_type": OracleAttackType.GOVERNANCE_ORACLE_ATTACK.value,
            "manipulator_id": manipulator.id,
            "target_pair": target_pair,
            "governance_power": governance_power,
            "parameter_change": parameter_change,
            "governance_amount": governance_amount,
            "profit": profit,
            "success": success,
            "detected": is_detected,
            "detection_time": detection_time,
            "timestamp": time.time()
        }
        
        # Update metrics
        self.metrics['oracle_attacks_total'].labels(
            attack_type=OracleAttackType.GOVERNANCE_ORACLE_ATTACK.value,
            status="success" if success else "failed"
        ).inc()
        
        if success:
            self.metrics['oracle_attack_profit'].labels(attack_type=OracleAttackType.GOVERNANCE_ORACLE_ATTACK.value).observe(profit)
        
        self.metrics['oracle_detection_time'].observe(detection_time)
        
        return attack_result
    
    def _calculate_oracle_consensus(self, target_pair: str) -> float:
        """Calculate oracle consensus score for a token pair"""
        prices = self.oracle_prices.get(target_pair, [])
        if len(prices) < 2:
            return 1.0
        
        # Calculate price variance
        price_values = [p.price for p in prices]
        mean_price = np.mean(price_values)
        variance = np.var(price_values)
        
        # Calculate consensus score (higher is better)
        consensus_score = 1.0 - (variance / (mean_price ** 2))
        return max(0.0, min(1.0, consensus_score))
    
    async def _run_attack_simulation(self) -> None:
        """Run the main oracle manipulation attack simulation loop"""
        logger.info("Starting oracle manipulation attack simulation...")
        
        # Determine simulation duration
        duration_hours = 6 if self.config.simulation_duration == "6h" else 1
        
        end_time = time.time() + (duration_hours * 3600)
        
        while time.time() < end_time:
            # Select random manipulator and target pair
            manipulator = random.choice(self.manipulators)
            target_pair = random.choice(self.config.target_pairs)
            
            # Select attack type based on manipulator's capabilities
            available_attacks = [at for at in manipulator.attack_types]
            if not available_attacks:
                continue
            
            attack_type = random.choice(available_attacks)
            
            try:
                if attack_type == OracleAttackType.PRICE_FLASH_LOAN:
                    attack_result = await self._simulate_price_flash_loan_attack(manipulator, target_pair)
                elif attack_type == OracleAttackType.ORACLE_DELAY_EXPLOIT:
                    attack_result = await self._simulate_oracle_delay_exploit(manipulator, target_pair)
                elif attack_type == OracleAttackType.CROSS_CHAIN_MANIPULATION:
                    attack_result = await self._simulate_cross_chain_manipulation(manipulator, target_pair)
                elif attack_type == OracleAttackType.GOVERNANCE_ORACLE_ATTACK:
                    attack_result = await self._simulate_governance_oracle_attack(manipulator, target_pair)
                else:
                    continue
                
                if "error" not in attack_result:
                    self.attacks.append(attack_result)
                    
                    # Log attack result
                    status = "SUCCESS" if attack_result["success"] else "FAILED"
                    detected = "DETECTED" if attack_result.get("detected", False) else "UNDETECTED"
                    logger.info(f"Oracle attack {attack_result['attack_type']} by {manipulator.id}: {status} "
                               f"(Profit: ${attack_result['profit']:.2f}, {detected}, "
                               f"Detection: {attack_result['detection_time']:.3f}s)")
                    
                    # Update success rate metrics
                    success_rate = sum(1 for a in self.attacks if a["success"]) / len(self.attacks)
                    self.metrics['oracle_attack_success_rate'].labels(attack_type=attack_type.value).set(success_rate)
                    
                    # Update oracle consensus
                    consensus_score = self._calculate_oracle_consensus(target_pair)
                    self.metrics['oracle_consensus'].labels(token=target_pair).set(consensus_score)
                
            except Exception as e:
                logger.error(f"Error in oracle manipulation attack simulation: {e}")
            
            # Wait before next attack
            await asyncio.sleep(random.uniform(5, 30))
    
    async def run_simulation(self) -> None:
        """Run the complete oracle manipulation attack simulation"""
        logger.info("Initializing oracle manipulation attack simulation environment...")
        
        # Initialize environment
        self._create_manipulators()
        self._initialize_oracle_prices()
        
        # Run simulation
        await self._run_attack_simulation()
        
        # Generate summary report
        self._generate_report()
        
        logger.info("Oracle manipulation attack simulation completed")
    
    def _generate_report(self) -> None:
        """Generate simulation report"""
        total_attacks = len(self.attacks)
        successful_attacks = sum(1 for a in self.attacks if a["success"])
        detected_attacks = sum(1 for a in self.attacks if a.get("detected", False))
        total_profit = sum(a["profit"] for a in self.attacks if a["success"])
        avg_detection_time = np.mean([a["detection_time"] for a in self.attacks])
        
        report = {
            "simulation_summary": {
                "total_attacks": total_attacks,
                "successful_attacks": successful_attacks,
                "detected_attacks": detected_attacks,
                "success_rate": successful_attacks / total_attacks if total_attacks > 0 else 0,
                "detection_rate": detected_attacks / total_attacks if total_attacks > 0 else 0,
                "total_profit": total_profit,
                "average_detection_time": avg_detection_time
            },
            "attack_breakdown": {},
            "manipulator_performance": {},
            "oracle_consensus": {}
        }
        
        # Attack type breakdown
        for attack_type in OracleAttackType:
            type_attacks = [a for a in self.attacks if a["attack_type"] == attack_type.value]
            if type_attacks:
                report["attack_breakdown"][attack_type.value] = {
                    "count": len(type_attacks),
                    "success_rate": sum(1 for a in type_attacks if a["success"]) / len(type_attacks),
                    "detection_rate": sum(1 for a in type_attacks if a.get("detected", False)) / len(type_attacks),
                    "total_profit": sum(a["profit"] for a in type_attacks if a["success"]),
                    "avg_detection_time": np.mean([a["detection_time"] for a in type_attacks])
                }
        
        # Manipulator performance
        for manipulator in self.manipulators:
            manipulator_attacks = [a for a in self.attacks if a["manipulator_id"] == manipulator.id]
            if manipulator_attacks:
                report["manipulator_performance"][manipulator.id] = {
                    "attack_count": len(manipulator_attacks),
                    "success_rate": sum(1 for a in manipulator_attacks if a["success"]) / len(manipulator_attacks),
                    "detection_rate": sum(1 for a in manipulator_attacks if a.get("detected", False)) / len(manipulator_attacks),
                    "total_profit": sum(a["profit"] for a in manipulator_attacks if a["success"])
                }
        
        # Oracle consensus scores
        for target_pair in self.config.target_pairs:
            consensus_score = self._calculate_oracle_consensus(target_pair)
            report["oracle_consensus"][target_pair] = consensus_score
        
        # Save report
        report_file = f"logs/oracle_manipulation_simulation_report_{int(time.time())}.json"
        with open(report_file, 'w') as f:
            json.dump(report, f, indent=2)
        
        logger.info(f"Simulation report saved to {report_file}")
        logger.info(f"Total attacks: {total_attacks}, Success rate: {successful_attacks/total_attacks:.2%}, "
                   f"Detection rate: {detected_attacks/total_attacks:.2%}, Total profit: ${total_profit:.2f}")


async def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description="Oracle Manipulation Attack Simulator")
    parser.add_argument("--config", required=True, help="Path to configuration file")
    parser.add_argument("--monitoring", action="store_true", help="Enable monitoring")
    parser.add_argument("--log-level", default="INFO", help="Log level")
    parser.add_argument("--output", help="Output file for results")
    
    args = parser.parse_args()
    
    # Configure logging
    logger.remove()
    logger.add(sys.stderr, level=args.log_level)
    
    # Create simulator
    simulator = OracleSimulator(args.config, args.monitoring)
    
    # Run simulation
    await simulator.run_simulation()


if __name__ == "__main__":
    asyncio.run(main())
