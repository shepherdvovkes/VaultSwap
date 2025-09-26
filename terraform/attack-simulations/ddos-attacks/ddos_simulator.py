#!/usr/bin/env python3
"""
DDoS and Infrastructure Attack Simulator
Simulates various DDoS and infrastructure attacks including network flooding, resource exhaustion, and service disruption.
"""

import asyncio
import json
import random
import time
import psutil
import subprocess
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


class DDoSAttackType(Enum):
    NETWORK_FLOODING = "network_flooding"
    RESOURCE_EXHAUSTION = "resource_exhaustion"
    SERVICE_DISRUPTION = "service_disruption"
    INFRASTRUCTURE_ATTACK = "infrastructure_attack"
    BANDWIDTH_ATTACK = "bandwidth_attack"
    APPLICATION_LAYER_ATTACK = "application_layer_attack"
    PROTOCOL_ATTACK = "protocol_attack"
    DISTRIBUTED_ATTACK = "distributed_attack"


class AttackStatus(Enum):
    PENDING = "pending"
    EXECUTING = "executing"
    SUCCESS = "success"
    FAILED = "failed"
    DETECTED = "detected"


@dataclass
class TargetService:
    """Represents a target service"""
    name: str
    url: str
    port: int
    protocol: str
    max_connections: int
    current_connections: int
    is_vulnerable: bool
    protection_level: float  # 0.0 to 1.0


@dataclass
class DDoSAttacker:
    """Represents a DDoS attacker"""
    id: str
    ip_address: str
    bot_count: int
    attack_power: float
    success_rate: float
    attack_types: List[DDoSAttackType]
    max_attack_intensity: float


class DDoSConfig(BaseModel):
    """Configuration for DDoS attack simulation"""
    target_count: int = Field(default=10, ge=1, le=50)
    attacker_count: int = Field(default=5, ge=1, le=20)
    attack_frequency: str = Field(default="medium")
    target_services: List[str] = Field(default=["web_server", "api_server", "database", "rpc_node", "validator"])
    simulation_duration: str = Field(default="6h")
    attack_intensity: List[str] = Field(default=["low", "medium", "high", "extreme"])


class DDoSSimulator:
    """Main DDoS attack simulator"""
    
    def __init__(self, config_path: str, monitoring: bool = False):
        self.config = self._load_config(config_path)
        self.monitoring = monitoring
        self.attackers: List[DDoSAttacker] = []
        self.targets: List[TargetService] = []
        self.attacks: List[Dict] = []
        self.metrics = self._setup_metrics()
        
        # Setup logging
        logger.add("logs/ddos_simulator_{time}.log", rotation="1 day", retention="7 days")
        
        if monitoring:
            start_http_server(8088)
            logger.info("Prometheus metrics server started on port 8088")
    
    def _load_config(self, config_path: str) -> DDoSConfig:
        """Load configuration from JSON file"""
        try:
            with open(config_path, 'r') as f:
                config_data = json.load(f)
            return DDoSConfig(**config_data.get('simulation_config', {}))
        except Exception as e:
            logger.error(f"Failed to load config: {e}")
            return DDoSConfig()
    
    def _setup_metrics(self) -> Dict:
        """Setup Prometheus metrics"""
        return {
            'ddos_attacks_total': Counter('ddos_attacks_total', 'Total DDoS attacks', ['attack_type', 'status']),
            'ddos_attack_success_rate': Gauge('ddos_attack_success_rate', 'DDoS attack success rate', ['attack_type']),
            'ddos_attack_intensity': Histogram('ddos_attack_intensity', 'DDoS attack intensity', ['attack_type']),
            'ddos_detection_time': Histogram('ddos_detection_time_seconds', 'Time to detect DDoS attack'),
            'target_service_health': Gauge('target_service_health', 'Target service health', ['service_name']),
            'network_bandwidth_usage': Gauge('network_bandwidth_usage', 'Network bandwidth usage percentage'),
            'system_resource_usage': Gauge('system_resource_usage', 'System resource usage percentage', ['resource_type']),
            'attacker_count': Gauge('ddos_attacker_count', 'Number of active DDoS attackers'),
            'target_count': Gauge('ddos_target_count', 'Number of monitored targets')
        }
    
    def _create_attackers(self) -> None:
        """Create DDoS attackers with different characteristics"""
        for i in range(self.config.attacker_count):
            attacker = DDoSAttacker(
                id=f"ddos_attacker_{i}",
                ip_address=f"192.168.{random.randint(1, 255)}.{random.randint(1, 255)}",
                bot_count=random.randint(100, 10000),
                attack_power=random.uniform(0.1, 1.0),
                success_rate=random.uniform(0.1, 0.8),
                attack_types=random.sample(list(DDoSAttackType), random.randint(1, 4)),
                max_attack_intensity=random.uniform(0.5, 2.0)
            )
            self.attackers.append(attacker)
        
        logger.info(f"Created {len(self.attackers)} DDoS attackers")
        self.metrics['attacker_count'].set(len(self.attackers))
    
    def _create_targets(self) -> None:
        """Create target services for simulation"""
        service_configs = [
            {"name": "web_server", "port": 80, "protocol": "HTTP", "max_connections": 1000},
            {"name": "api_server", "port": 8080, "protocol": "HTTP", "max_connections": 500},
            {"name": "database", "port": 5432, "protocol": "TCP", "max_connections": 200},
            {"name": "rpc_node", "port": 8545, "protocol": "HTTP", "max_connections": 100},
            {"name": "validator", "port": 9000, "protocol": "TCP", "max_connections": 50}
        ]
        
        for i, config in enumerate(service_configs[:self.config.target_count]):
            target = TargetService(
                name=f"{config['name']}_{i}",
                url=f"http://localhost:{config['port']}",
                port=config['port'],
                protocol=config['protocol'],
                max_connections=config['max_connections'],
                current_connections=random.randint(0, config['max_connections'] // 2),
                is_vulnerable=random.random() < 0.3,  # 30% chance of being vulnerable
                protection_level=random.uniform(0.3, 1.0)  # 30-100% protection
            )
            self.targets.append(target)
        
        logger.info(f"Created {len(self.targets)} target services")
        self.metrics['target_count'].set(len(self.targets))
    
    async def _simulate_network_flooding(self, attacker: DDoSAttacker, target: TargetService) -> Dict:
        """Simulate network flooding attack"""
        start_time = time.time()
        
        # Simulate network flooding
        flood_intensity = min(random.uniform(0.5, 2.0), attacker.max_attack_intensity)
        flood_duration = random.uniform(10, 300)  # 10 seconds to 5 minutes
        
        # Simulate packet flooding
        packets_per_second = int(1000 * flood_intensity)
        total_packets = packets_per_second * flood_duration
        
        # Simulate bandwidth consumption
        bandwidth_consumption = flood_intensity * random.uniform(0.1, 0.8)  # 10-80% bandwidth
        
        # Check if target can handle the flood
        can_handle_flood = target.protection_level > flood_intensity * 0.5
        success = not can_handle_flood and target.is_vulnerable
        
        detection_time = time.time() - start_time
        
        attack_result = {
            "attack_type": DDoSAttackType.NETWORK_FLOODING.value,
            "attacker_id": attacker.id,
            "target_name": target.name,
            "flood_intensity": flood_intensity,
            "flood_duration": flood_duration,
            "packets_per_second": packets_per_second,
            "total_packets": total_packets,
            "bandwidth_consumption": bandwidth_consumption,
            "can_handle_flood": can_handle_flood,
            "success": success,
            "detection_time": detection_time,
            "timestamp": time.time()
        }
        
        # Update metrics
        self.metrics['ddos_attacks_total'].labels(
            attack_type=DDoSAttackType.NETWORK_FLOODING.value,
            status="success" if success else "failed"
        ).inc()
        
        self.metrics['ddos_attack_intensity'].labels(attack_type=DDoSAttackType.NETWORK_FLOODING.value).observe(flood_intensity)
        self.metrics['ddos_detection_time'].observe(detection_time)
        self.metrics['network_bandwidth_usage'].set(bandwidth_consumption * 100)
        
        return attack_result
    
    async def _simulate_resource_exhaustion(self, attacker: DDoSAttacker, target: TargetService) -> Dict:
        """Simulate resource exhaustion attack"""
        start_time = time.time()
        
        # Simulate resource exhaustion
        resource_intensity = min(random.uniform(0.3, 1.5), attacker.max_attack_intensity)
        
        # Simulate CPU exhaustion
        cpu_exhaustion = resource_intensity * random.uniform(0.2, 0.8)
        
        # Simulate memory exhaustion
        memory_exhaustion = resource_intensity * random.uniform(0.1, 0.6)
        
        # Simulate connection exhaustion
        connection_exhaustion = resource_intensity * random.uniform(0.3, 0.9)
        
        # Check if target can handle resource exhaustion
        total_exhaustion = (cpu_exhaustion + memory_exhaustion + connection_exhaustion) / 3
        can_handle_exhaustion = target.protection_level > total_exhaustion
        success = not can_handle_exhaustion and target.is_vulnerable
        
        detection_time = time.time() - start_time
        
        attack_result = {
            "attack_type": DDoSAttackType.RESOURCE_EXHAUSTION.value,
            "attacker_id": attacker.id,
            "target_name": target.name,
            "resource_intensity": resource_intensity,
            "cpu_exhaustion": cpu_exhaustion,
            "memory_exhaustion": memory_exhaustion,
            "connection_exhaustion": connection_exhaustion,
            "total_exhaustion": total_exhaustion,
            "can_handle_exhaustion": can_handle_exhaustion,
            "success": success,
            "detection_time": detection_time,
            "timestamp": time.time()
        }
        
        # Update metrics
        self.metrics['ddos_attacks_total'].labels(
            attack_type=DDoSAttackType.RESOURCE_EXHAUSTION.value,
            status="success" if success else "failed"
        ).inc()
        
        self.metrics['ddos_attack_intensity'].labels(attack_type=DDoSAttackType.RESOURCE_EXHAUSTION.value).observe(resource_intensity)
        self.metrics['ddos_detection_time'].observe(detection_time)
        self.metrics['system_resource_usage'].labels(resource_type="cpu").set(cpu_exhaustion * 100)
        self.metrics['system_resource_usage'].labels(resource_type="memory").set(memory_exhaustion * 100)
        
        return attack_result
    
    async def _simulate_service_disruption(self, attacker: DDoSAttacker, target: TargetService) -> Dict:
        """Simulate service disruption attack"""
        start_time = time.time()
        
        # Simulate service disruption
        disruption_intensity = min(random.uniform(0.4, 1.8), attacker.max_attack_intensity)
        
        # Simulate service unavailability
        service_downtime = random.uniform(30, 1800)  # 30 seconds to 30 minutes
        
        # Simulate response time degradation
        response_time_degradation = disruption_intensity * random.uniform(0.5, 2.0)
        
        # Simulate error rate increase
        error_rate_increase = disruption_intensity * random.uniform(0.1, 0.5)
        
        # Check if service can handle disruption
        can_handle_disruption = target.protection_level > disruption_intensity * 0.6
        success = not can_handle_disruption and target.is_vulnerable
        
        detection_time = time.time() - start_time
        
        attack_result = {
            "attack_type": DDoSAttackType.SERVICE_DISRUPTION.value,
            "attacker_id": attacker.id,
            "target_name": target.name,
            "disruption_intensity": disruption_intensity,
            "service_downtime": service_downtime,
            "response_time_degradation": response_time_degradation,
            "error_rate_increase": error_rate_increase,
            "can_handle_disruption": can_handle_disruption,
            "success": success,
            "detection_time": detection_time,
            "timestamp": time.time()
        }
        
        # Update metrics
        self.metrics['ddos_attacks_total'].labels(
            attack_type=DDoSAttackType.SERVICE_DISRUPTION.value,
            status="success" if success else "failed"
        ).inc()
        
        self.metrics['ddos_attack_intensity'].labels(attack_type=DDoSAttackType.SERVICE_DISRUPTION.value).observe(disruption_intensity)
        self.metrics['ddos_detection_time'].observe(detection_time)
        self.metrics['target_service_health'].labels(service_name=target.name).set(1.0 - (0.3 if success else 0.0))
        
        return attack_result
    
    async def _simulate_infrastructure_attack(self, attacker: DDoSAttacker, target: TargetService) -> Dict:
        """Simulate infrastructure attack"""
        start_time = time.time()
        
        # Simulate infrastructure attack
        infrastructure_intensity = min(random.uniform(0.6, 2.0), attacker.max_attack_intensity)
        
        # Simulate infrastructure components
        components_attacked = random.randint(1, 5)
        component_types = ["load_balancer", "database", "cache", "message_queue", "monitoring"]
        attacked_components = random.sample(component_types, components_attacked)
        
        # Simulate infrastructure degradation
        infrastructure_degradation = infrastructure_intensity * random.uniform(0.3, 0.8)
        
        # Simulate cascading failures
        cascading_failures = random.randint(0, 3)
        
        # Check if infrastructure can handle attack
        can_handle_attack = target.protection_level > infrastructure_intensity * 0.7
        success = not can_handle_attack and target.is_vulnerable
        
        detection_time = time.time() - start_time
        
        attack_result = {
            "attack_type": DDoSAttackType.INFRASTRUCTURE_ATTACK.value,
            "attacker_id": attacker.id,
            "target_name": target.name,
            "infrastructure_intensity": infrastructure_intensity,
            "components_attacked": components_attacked,
            "attacked_components": attacked_components,
            "infrastructure_degradation": infrastructure_degradation,
            "cascading_failures": cascading_failures,
            "can_handle_attack": can_handle_attack,
            "success": success,
            "detection_time": detection_time,
            "timestamp": time.time()
        }
        
        # Update metrics
        self.metrics['ddos_attacks_total'].labels(
            attack_type=DDoSAttackType.INFRASTRUCTURE_ATTACK.value,
            status="success" if success else "failed"
        ).inc()
        
        self.metrics['ddos_attack_intensity'].labels(attack_type=DDoSAttackType.INFRASTRUCTURE_ATTACK.value).observe(infrastructure_intensity)
        self.metrics['ddos_detection_time'].observe(detection_time)
        
        return attack_result
    
    async def _simulate_bandwidth_attack(self, attacker: DDoSAttacker, target: TargetService) -> Dict:
        """Simulate bandwidth attack"""
        start_time = time.time()
        
        # Simulate bandwidth attack
        bandwidth_intensity = min(random.uniform(0.8, 2.5), attacker.max_attack_intensity)
        
        # Simulate bandwidth consumption
        bandwidth_consumption = bandwidth_intensity * random.uniform(0.5, 1.0)
        
        # Simulate network congestion
        network_congestion = bandwidth_intensity * random.uniform(0.3, 0.9)
        
        # Simulate packet loss
        packet_loss = bandwidth_intensity * random.uniform(0.1, 0.4)
        
        # Check if network can handle bandwidth attack
        can_handle_bandwidth = target.protection_level > bandwidth_intensity * 0.5
        success = not can_handle_bandwidth and target.is_vulnerable
        
        detection_time = time.time() - start_time
        
        attack_result = {
            "attack_type": DDoSAttackType.BANDWIDTH_ATTACK.value,
            "attacker_id": attacker.id,
            "target_name": target.name,
            "bandwidth_intensity": bandwidth_intensity,
            "bandwidth_consumption": bandwidth_consumption,
            "network_congestion": network_congestion,
            "packet_loss": packet_loss,
            "can_handle_bandwidth": can_handle_bandwidth,
            "success": success,
            "detection_time": detection_time,
            "timestamp": time.time()
        }
        
        # Update metrics
        self.metrics['ddos_attacks_total'].labels(
            attack_type=DDoSAttackType.BANDWIDTH_ATTACK.value,
            status="success" if success else "failed"
        ).inc()
        
        self.metrics['ddos_attack_intensity'].labels(attack_type=DDoSAttackType.BANDWIDTH_ATTACK.value).observe(bandwidth_intensity)
        self.metrics['ddos_detection_time'].observe(detection_time)
        self.metrics['network_bandwidth_usage'].set(bandwidth_consumption * 100)
        
        return attack_result
    
    async def _run_attack_simulation(self) -> None:
        """Run the main DDoS attack simulation loop"""
        logger.info("Starting DDoS attack simulation...")
        
        # Determine simulation duration
        duration_hours = 6 if self.config.simulation_duration == "6h" else 1
        
        end_time = time.time() + (duration_hours * 3600)
        
        while time.time() < end_time:
            # Select random attacker and target
            attacker = random.choice(self.attackers)
            target = random.choice(self.targets)
            
            # Select attack type based on attacker's capabilities
            available_attacks = [at for at in attacker.attack_types]
            if not available_attacks:
                continue
            
            attack_type = random.choice(available_attacks)
            
            try:
                if attack_type == DDoSAttackType.NETWORK_FLOODING:
                    attack_result = await self._simulate_network_flooding(attacker, target)
                elif attack_type == DDoSAttackType.RESOURCE_EXHAUSTION:
                    attack_result = await self._simulate_resource_exhaustion(attacker, target)
                elif attack_type == DDoSAttackType.SERVICE_DISRUPTION:
                    attack_result = await self._simulate_service_disruption(attacker, target)
                elif attack_type == DDoSAttackType.INFRASTRUCTURE_ATTACK:
                    attack_result = await self._simulate_infrastructure_attack(attacker, target)
                elif attack_type == DDoSAttackType.BANDWIDTH_ATTACK:
                    attack_result = await self._simulate_bandwidth_attack(attacker, target)
                else:
                    continue
                
                self.attacks.append(attack_result)
                
                # Log attack result
                status = "SUCCESS" if attack_result["success"] else "FAILED"
                logger.info(f"DDoS attack {attack_result['attack_type']} by {attacker.id}: {status} "
                           f"(Target: {target.name}, Detection: {attack_result['detection_time']:.3f}s)")
                
                # Update success rate metrics
                success_rate = sum(1 for a in self.attacks if a["success"]) / len(self.attacks)
                self.metrics['ddos_attack_success_rate'].labels(attack_type=attack_type.value).set(success_rate)
                
            except Exception as e:
                logger.error(f"Error in DDoS attack simulation: {e}")
            
            # Wait before next attack
            if self.config.attack_frequency == "high":
                await asyncio.sleep(random.uniform(1, 5))
            elif self.config.attack_frequency == "medium":
                await asyncio.sleep(random.uniform(5, 15))
            else:  # low
                await asyncio.sleep(random.uniform(15, 60))
    
    async def run_simulation(self) -> None:
        """Run the complete DDoS attack simulation"""
        logger.info("Initializing DDoS attack simulation environment...")
        
        # Initialize environment
        self._create_attackers()
        self._create_targets()
        
        # Run simulation
        await self._run_attack_simulation()
        
        # Generate summary report
        self._generate_report()
        
        logger.info("DDoS attack simulation completed")
    
    def _generate_report(self) -> None:
        """Generate simulation report"""
        total_attacks = len(self.attacks)
        successful_attacks = sum(1 for a in self.attacks if a["success"])
        avg_detection_time = np.mean([a["detection_time"] for a in self.attacks])
        
        report = {
            "simulation_summary": {
                "total_attacks": total_attacks,
                "successful_attacks": successful_attacks,
                "success_rate": successful_attacks / total_attacks if total_attacks > 0 else 0,
                "average_detection_time": avg_detection_time
            },
            "attack_breakdown": {},
            "attacker_performance": {},
            "target_analysis": {}
        }
        
        # Attack type breakdown
        for attack_type in DDoSAttackType:
            type_attacks = [a for a in self.attacks if a["attack_type"] == attack_type.value]
            if type_attacks:
                report["attack_breakdown"][attack_type.value] = {
                    "count": len(type_attacks),
                    "success_rate": sum(1 for a in type_attacks if a["success"]) / len(type_attacks),
                    "avg_detection_time": np.mean([a["detection_time"] for a in type_attacks])
                }
        
        # Attacker performance
        for attacker in self.attackers:
            attacker_attacks = [a for a in self.attacks if a["attacker_id"] == attacker.id]
            if attacker_attacks:
                report["attacker_performance"][attacker.id] = {
                    "attack_count": len(attacker_attacks),
                    "success_rate": sum(1 for a in attacker_attacks if a["success"]) / len(attacker_attacks),
                    "bot_count": attacker.bot_count,
                    "attack_power": attacker.attack_power
                }
        
        # Target analysis
        vulnerable_targets = [t for t in self.targets if t.is_vulnerable]
        report["target_analysis"] = {
            "total_targets": len(self.targets),
            "vulnerable_targets": len(vulnerable_targets),
            "vulnerability_rate": len(vulnerable_targets) / len(self.targets),
            "average_protection_level": np.mean([t.protection_level for t in self.targets]),
            "total_max_connections": sum(t.max_connections for t in self.targets)
        }
        
        # Save report
        report_file = f"logs/ddos_simulation_report_{int(time.time())}.json"
        with open(report_file, 'w') as f:
            json.dump(report, f, indent=2)
        
        logger.info(f"Simulation report saved to {report_file}")
        logger.info(f"Total attacks: {total_attacks}, Success rate: {successful_attacks/total_attacks:.2%}")


async def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description="DDoS Attack Simulator")
    parser.add_argument("--config", required=True, help="Path to configuration file")
    parser.add_argument("--monitoring", action="store_true", help="Enable monitoring")
    parser.add_argument("--log-level", default="INFO", help="Log level")
    parser.add_argument("--output", help="Output file for results")
    
    args = parser.parse_args()
    
    # Configure logging
    logger.remove()
    logger.add(sys.stderr, level=args.log_level)
    
    # Create simulator
    simulator = DDoSSimulator(args.config, args.monitoring)
    
    # Run simulation
    await simulator.run_simulation()


if __name__ == "__main__":
    asyncio.run(main())
