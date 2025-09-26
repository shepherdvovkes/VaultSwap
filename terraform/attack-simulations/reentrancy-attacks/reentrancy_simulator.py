#!/usr/bin/env python3
"""
Reentrancy Attack Simulator
Simulates various reentrancy attacks to test DEX security measures.
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


class ReentrancyAttackType(Enum):
    SINGLE_FUNCTION = "single_function_reentrancy"
    CROSS_FUNCTION = "cross_function_reentrancy"
    READ_ONLY = "read_only_reentrancy"
    CROSS_CONTRACT = "cross_contract_reentrancy"
    DELEGATE_CALL = "delegate_call_reentrancy"
    EXTERNAL_CALL = "external_call_reentrancy"


class AttackStatus(Enum):
    PENDING = "pending"
    EXECUTING = "executing"
    SUCCESS = "success"
    FAILED = "failed"
    DETECTED = "detected"


@dataclass
class SmartContract:
    """Represents a smart contract"""
    address: str
    balance: float
    functions: List[str]
    is_vulnerable: bool
    reentrancy_guard: bool = False


@dataclass
class ReentrancyAttacker:
    """Represents a reentrancy attacker"""
    id: str
    address: str
    balance: float
    success_rate: float
    attack_types: List[ReentrancyAttackType]
    max_attack_amount: float


class ReentrancyConfig(BaseModel):
    """Configuration for reentrancy attack simulation"""
    contract_count: int = Field(default=10, ge=1, le=50)
    attacker_count: int = Field(default=5, ge=1, le=20)
    attack_frequency: str = Field(default="medium")
    vulnerable_contracts: List[str] = Field(default=["vault", "lending", "staking", "governance"])
    simulation_duration: str = Field(default="8h")
    attack_intensity: List[str] = Field(default=["low", "medium", "high", "extreme"])


class ReentrancySimulator:
    """Main reentrancy attack simulator"""
    
    def __init__(self, config_path: str, monitoring: bool = False):
        self.config = self._load_config(config_path)
        self.monitoring = monitoring
        self.attackers: List[ReentrancyAttacker] = []
        self.contracts: List[SmartContract] = []
        self.attacks: List[Dict] = []
        self.metrics = self._setup_metrics()
        
        # Setup logging
        logger.add("logs/reentrancy_simulator_{time}.log", rotation="1 day", retention="7 days")
        
        if monitoring:
            start_http_server(8083)
            logger.info("Prometheus metrics server started on port 8083")
    
    def _load_config(self, config_path: str) -> ReentrancyConfig:
        """Load configuration from JSON file"""
        try:
            with open(config_path, 'r') as f:
                config_data = json.load(f)
            return ReentrancyConfig(**config_data.get('simulation_config', {}))
        except Exception as e:
            logger.error(f"Failed to load config: {e}")
            return ReentrancyConfig()
    
    def _setup_metrics(self) -> Dict:
        """Setup Prometheus metrics"""
        return {
            'reentrancy_attacks_total': Counter('reentrancy_attacks_total', 'Total reentrancy attacks', ['attack_type', 'status']),
            'reentrancy_attack_success_rate': Gauge('reentrancy_attack_success_rate', 'Reentrancy attack success rate', ['attack_type']),
            'reentrancy_attack_profit': Histogram('reentrancy_attack_profit', 'Reentrancy attack profit', ['attack_type']),
            'reentrancy_detection_time': Histogram('reentrancy_detection_time_seconds', 'Time to detect reentrancy attack'),
            'contract_vulnerability': Gauge('contract_vulnerability_score', 'Contract vulnerability score', ['contract_address']),
            'attacker_count': Gauge('reentrancy_attacker_count', 'Number of active reentrancy attackers'),
            'contract_count': Gauge('reentrancy_contract_count', 'Number of monitored contracts')
        }
    
    def _create_attackers(self) -> None:
        """Create reentrancy attackers with different characteristics"""
        for i in range(self.config.attacker_count):
            attacker = ReentrancyAttacker(
                id=f"reentrancy_attacker_{i}",
                address=f"0x{random.randint(1000000000000000000000000000000000000000, 9999999999999999999999999999999999999999):x}",
                balance=random.uniform(1000, 50000),
                success_rate=random.uniform(0.1, 0.8),
                attack_types=random.sample(list(ReentrancyAttackType), random.randint(1, 4)),
                max_attack_amount=random.uniform(10000, 100000)
            )
            self.attackers.append(attacker)
        
        logger.info(f"Created {len(self.attackers)} reentrancy attackers")
        self.metrics['attacker_count'].set(len(self.attackers))
    
    def _create_contracts(self) -> None:
        """Create smart contracts for simulation"""
        contract_types = ["vault", "lending", "staking", "governance", "dex", "bridge"]
        
        for i in range(self.config.contract_count):
            contract_type = random.choice(contract_types)
            is_vulnerable = random.random() < 0.3  # 30% chance of being vulnerable
            
            contract = SmartContract(
                address=f"0x{random.randint(1000000000000000000000000000000000000000, 9999999999999999999999999999999999999999):x}",
                balance=random.uniform(100000, 10000000),
                functions=["withdraw", "deposit", "transfer", "approve", "swap"],
                is_vulnerable=is_vulnerable,
                reentrancy_guard=not is_vulnerable and random.random() < 0.7  # 70% of non-vulnerable contracts have guards
            )
            self.contracts.append(contract)
        
        logger.info(f"Created {len(self.contracts)} smart contracts")
        self.metrics['contract_count'].set(len(self.contracts))
    
    async def _simulate_single_function_reentrancy(self, attacker: ReentrancyAttacker, contract: SmartContract) -> Dict:
        """Simulate a single function reentrancy attack"""
        start_time = time.time()
        
        if not contract.is_vulnerable:
            return {
                "attack_type": ReentrancyAttackType.SINGLE_FUNCTION.value,
                "attacker_id": attacker.id,
                "contract_address": contract.address,
                "success": False,
                "reason": "Contract not vulnerable",
                "timestamp": time.time()
            }
        
        # Simulate reentrancy attack
        attack_amount = min(random.uniform(1000, 10000), attacker.max_attack_amount)
        
        # Simulate multiple recursive calls
        recursive_calls = random.randint(2, 10)
        total_drained = 0
        
        for call in range(recursive_calls):
            # Simulate external call before state update
            await asyncio.sleep(random.uniform(0.001, 0.01))
            
            # Calculate amount to drain
            call_amount = attack_amount / recursive_calls
            total_drained += call_amount
            
            # Simulate state update delay
            await asyncio.sleep(random.uniform(0.001, 0.005))
        
        # Calculate profit
        profit = total_drained - attack_amount
        success = profit > 0 and total_drained <= contract.balance
        
        detection_time = time.time() - start_time
        
        attack_result = {
            "attack_type": ReentrancyAttackType.SINGLE_FUNCTION.value,
            "attacker_id": attacker.id,
            "contract_address": contract.address,
            "attack_amount": attack_amount,
            "total_drained": total_drained,
            "recursive_calls": recursive_calls,
            "profit": profit,
            "success": success,
            "detection_time": detection_time,
            "timestamp": time.time()
        }
        
        # Update metrics
        self.metrics['reentrancy_attacks_total'].labels(
            attack_type=ReentrancyAttackType.SINGLE_FUNCTION.value,
            status="success" if success else "failed"
        ).inc()
        
        if success:
            self.metrics['reentrancy_attack_profit'].labels(attack_type=ReentrancyAttackType.SINGLE_FUNCTION.value).observe(profit)
        
        self.metrics['reentrancy_detection_time'].observe(detection_time)
        
        return attack_result
    
    async def _simulate_cross_function_reentrancy(self, attacker: ReentrancyAttacker, contract: SmartContract) -> Dict:
        """Simulate a cross-function reentrancy attack"""
        start_time = time.time()
        
        if not contract.is_vulnerable:
            return {
                "attack_type": ReentrancyAttackType.CROSS_FUNCTION.value,
                "attacker_id": attacker.id,
                "contract_address": contract.address,
                "success": False,
                "reason": "Contract not vulnerable",
                "timestamp": time.time()
            }
        
        # Simulate cross-function reentrancy
        attack_amount = min(random.uniform(5000, 50000), attacker.max_attack_amount)
        
        # Simulate calling multiple functions
        functions_called = ["withdraw", "transfer", "approve"]
        total_drained = 0
        
        for function in functions_called:
            # Simulate external call
            await asyncio.sleep(random.uniform(0.001, 0.01))
            
            # Calculate amount drained from each function
            function_amount = attack_amount / len(functions_called)
            total_drained += function_amount
            
            # Simulate state manipulation
            await asyncio.sleep(random.uniform(0.001, 0.005))
        
        # Calculate profit
        profit = total_drained - attack_amount
        success = profit > 0 and total_drained <= contract.balance
        
        detection_time = time.time() - start_time
        
        attack_result = {
            "attack_type": ReentrancyAttackType.CROSS_FUNCTION.value,
            "attacker_id": attacker.id,
            "contract_address": contract.address,
            "attack_amount": attack_amount,
            "total_drained": total_drained,
            "functions_called": functions_called,
            "profit": profit,
            "success": success,
            "detection_time": detection_time,
            "timestamp": time.time()
        }
        
        # Update metrics
        self.metrics['reentrancy_attacks_total'].labels(
            attack_type=ReentrancyAttackType.CROSS_FUNCTION.value,
            status="success" if success else "failed"
        ).inc()
        
        if success:
            self.metrics['reentrancy_attack_profit'].labels(attack_type=ReentrancyAttackType.CROSS_FUNCTION.value).observe(profit)
        
        self.metrics['reentrancy_detection_time'].observe(detection_time)
        
        return attack_result
    
    async def _simulate_read_only_reentrancy(self, attacker: ReentrancyAttacker, contract: SmartContract) -> Dict:
        """Simulate a read-only reentrancy attack"""
        start_time = time.time()
        
        # Read-only reentrancy doesn't require vulnerable contract
        attack_amount = min(random.uniform(1000, 20000), attacker.max_attack_amount)
        
        # Simulate read-only reentrancy
        # This attack manipulates state through read operations
        state_manipulation = random.uniform(0.1, 0.5)  # 10-50% state manipulation
        
        # Simulate multiple read operations
        read_operations = random.randint(3, 8)
        total_manipulated = 0
        
        for operation in range(read_operations):
            # Simulate read operation
            await asyncio.sleep(random.uniform(0.001, 0.005))
            
            # Calculate manipulation amount
            operation_amount = (attack_amount * state_manipulation) / read_operations
            total_manipulated += operation_amount
            
            # Simulate state read delay
            await asyncio.sleep(random.uniform(0.001, 0.003))
        
        # Calculate profit from state manipulation
        profit = total_manipulated * random.uniform(0.1, 0.3)  # 10-30% profit from manipulation
        success = profit > 0
        
        detection_time = time.time() - start_time
        
        attack_result = {
            "attack_type": ReentrancyAttackType.READ_ONLY.value,
            "attacker_id": attacker.id,
            "contract_address": contract.address,
            "attack_amount": attack_amount,
            "state_manipulation": state_manipulation,
            "total_manipulated": total_manipulated,
            "read_operations": read_operations,
            "profit": profit,
            "success": success,
            "detection_time": detection_time,
            "timestamp": time.time()
        }
        
        # Update metrics
        self.metrics['reentrancy_attacks_total'].labels(
            attack_type=ReentrancyAttackType.READ_ONLY.value,
            status="success" if success else "failed"
        ).inc()
        
        if success:
            self.metrics['reentrancy_attack_profit'].labels(attack_type=ReentrancyAttackType.READ_ONLY.value).observe(profit)
        
        self.metrics['reentrancy_detection_time'].observe(detection_time)
        
        return attack_result
    
    async def _simulate_cross_contract_reentrancy(self, attacker: ReentrancyAttacker, contract: SmartContract) -> Dict:
        """Simulate a cross-contract reentrancy attack"""
        start_time = time.time()
        
        # Find target contracts
        target_contracts = [c for c in self.contracts if c != contract and c.is_vulnerable]
        if not target_contracts:
            return {
                "attack_type": ReentrancyAttackType.CROSS_CONTRACT.value,
                "attacker_id": attacker.id,
                "contract_address": contract.address,
                "success": False,
                "reason": "No vulnerable target contracts",
                "timestamp": time.time()
            }
        
        target_contract = random.choice(target_contracts)
        attack_amount = min(random.uniform(2000, 20000), attacker.max_attack_amount)
        
        # Simulate cross-contract reentrancy
        total_drained = 0
        
        # Attack first contract
        await asyncio.sleep(random.uniform(0.001, 0.01))
        first_drain = attack_amount * 0.6
        total_drained += first_drain
        
        # Use first contract to attack second contract
        await asyncio.sleep(random.uniform(0.001, 0.01))
        second_drain = attack_amount * 0.4
        total_drained += second_drain
        
        # Calculate profit
        profit = total_drained - attack_amount
        success = profit > 0 and total_drained <= (contract.balance + target_contract.balance)
        
        detection_time = time.time() - start_time
        
        attack_result = {
            "attack_type": ReentrancyAttackType.CROSS_CONTRACT.value,
            "attacker_id": attacker.id,
            "contract_address": contract.address,
            "target_contract": target_contract.address,
            "attack_amount": attack_amount,
            "total_drained": total_drained,
            "profit": profit,
            "success": success,
            "detection_time": detection_time,
            "timestamp": time.time()
        }
        
        # Update metrics
        self.metrics['reentrancy_attacks_total'].labels(
            attack_type=ReentrancyAttackType.CROSS_CONTRACT.value,
            status="success" if success else "failed"
        ).inc()
        
        if success:
            self.metrics['reentrancy_attack_profit'].labels(attack_type=ReentrancyAttackType.CROSS_CONTRACT.value).observe(profit)
        
        self.metrics['reentrancy_detection_time'].observe(detection_time)
        
        return attack_result
    
    async def _run_attack_simulation(self) -> None:
        """Run the main reentrancy attack simulation loop"""
        logger.info("Starting reentrancy attack simulation...")
        
        # Determine simulation duration
        duration_hours = 8 if self.config.simulation_duration == "8h" else 1
        
        end_time = time.time() + (duration_hours * 3600)
        
        while time.time() < end_time:
            # Select random attacker and contract
            attacker = random.choice(self.attackers)
            contract = random.choice(self.contracts)
            
            # Select attack type based on attacker's capabilities
            available_attacks = [at for at in attacker.attack_types]
            if not available_attacks:
                continue
            
            attack_type = random.choice(available_attacks)
            
            try:
                if attack_type == ReentrancyAttackType.SINGLE_FUNCTION:
                    attack_result = await self._simulate_single_function_reentrancy(attacker, contract)
                elif attack_type == ReentrancyAttackType.CROSS_FUNCTION:
                    attack_result = await self._simulate_cross_function_reentrancy(attacker, contract)
                elif attack_type == ReentrancyAttackType.READ_ONLY:
                    attack_result = await self._simulate_read_only_reentrancy(attacker, contract)
                elif attack_type == ReentrancyAttackType.CROSS_CONTRACT:
                    attack_result = await self._simulate_cross_contract_reentrancy(attacker, contract)
                else:
                    continue
                
                self.attacks.append(attack_result)
                
                # Log attack result
                status = "SUCCESS" if attack_result["success"] else "FAILED"
                logger.info(f"Reentrancy attack {attack_result['attack_type']} by {attacker.id}: {status} "
                           f"(Profit: ${attack_result.get('profit', 0):.2f}, "
                           f"Detection: {attack_result['detection_time']:.3f}s)")
                
                # Update success rate metrics
                success_rate = sum(1 for a in self.attacks if a["success"]) / len(self.attacks)
                self.metrics['reentrancy_attack_success_rate'].labels(attack_type=attack_type.value).set(success_rate)
                
                # Update contract vulnerability scores
                vulnerability_score = 1.0 if contract.is_vulnerable else 0.0
                self.metrics['contract_vulnerability'].labels(contract_address=contract.address).set(vulnerability_score)
                
            except Exception as e:
                logger.error(f"Error in reentrancy attack simulation: {e}")
            
            # Wait before next attack
            if self.config.attack_frequency == "high":
                await asyncio.sleep(random.uniform(1, 5))
            elif self.config.attack_frequency == "medium":
                await asyncio.sleep(random.uniform(5, 15))
            else:  # low
                await asyncio.sleep(random.uniform(15, 60))
    
    async def run_simulation(self) -> None:
        """Run the complete reentrancy attack simulation"""
        logger.info("Initializing reentrancy attack simulation environment...")
        
        # Initialize environment
        self._create_attackers()
        self._create_contracts()
        
        # Run simulation
        await self._run_attack_simulation()
        
        # Generate summary report
        self._generate_report()
        
        logger.info("Reentrancy attack simulation completed")
    
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
            "contract_vulnerability": {}
        }
        
        # Attack type breakdown
        for attack_type in ReentrancyAttackType:
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
        
        # Contract vulnerability analysis
        vulnerable_contracts = [c for c in self.contracts if c.is_vulnerable]
        report["contract_vulnerability"] = {
            "total_contracts": len(self.contracts),
            "vulnerable_contracts": len(vulnerable_contracts),
            "vulnerability_rate": len(vulnerable_contracts) / len(self.contracts),
            "contracts_with_guards": sum(1 for c in self.contracts if c.reentrancy_guard)
        }
        
        # Save report
        report_file = f"logs/reentrancy_simulation_report_{int(time.time())}.json"
        with open(report_file, 'w') as f:
            json.dump(report, f, indent=2)
        
        logger.info(f"Simulation report saved to {report_file}")
        logger.info(f"Total attacks: {total_attacks}, Success rate: {successful_attacks/total_attacks:.2%}, "
                   f"Total profit: ${total_profit:.2f}")


async def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description="Reentrancy Attack Simulator")
    parser.add_argument("--config", required=True, help="Path to configuration file")
    parser.add_argument("--monitoring", action="store_true", help="Enable monitoring")
    parser.add_argument("--log-level", default="INFO", help="Log level")
    parser.add_argument("--output", help="Output file for results")
    
    args = parser.parse_args()
    
    # Configure logging
    logger.remove()
    logger.add(sys.stderr, level=args.log_level)
    
    # Create simulator
    simulator = ReentrancySimulator(args.config, args.monitoring)
    
    # Run simulation
    await simulator.run_simulation()


if __name__ == "__main__":
    asyncio.run(main())
