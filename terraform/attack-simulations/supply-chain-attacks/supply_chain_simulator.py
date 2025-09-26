#!/usr/bin/env python3
"""
Supply Chain Attack Simulator
Simulates various supply chain attacks including dependency attacks, third-party attacks, and library attacks.
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


class SupplyChainAttackType(Enum):
    DEPENDENCY_ATTACK = "dependency_attack"
    THIRD_PARTY_ATTACK = "third_party_attack"
    LIBRARY_ATTACK = "library_attack"
    INFRASTRUCTURE_ATTACK = "infrastructure_attack"
    PACKAGE_ATTACK = "package_attack"
    UPDATE_ATTACK = "update_attack"
    COMPROMISED_BUILD_ATTACK = "compromised_build_attack"
    MALICIOUS_UPDATE_ATTACK = "malicious_update_attack"


class AttackStatus(Enum):
    PENDING = "pending"
    EXECUTING = "executing"
    SUCCESS = "success"
    FAILED = "failed"
    DETECTED = "detected"


@dataclass
class Dependency:
    """Represents a software dependency"""
    name: str
    version: str
    type: str  # npm, pip, maven, etc.
    is_vulnerable: bool
    security_rating: float  # 0.0 to 1.0
    download_count: int
    maintainer: str
    last_updated: datetime


@dataclass
class ThirdPartyService:
    """Represents a third-party service"""
    name: str
    service_type: str
    api_endpoint: str
    is_trusted: bool
    security_rating: float  # 0.0 to 1.0
    access_level: str  # read, write, admin
    is_vulnerable: bool


@dataclass
class SupplyChainAttacker:
    """Represents a supply chain attacker"""
    id: str
    name: str
    attack_sophistication: float  # 0.0 to 1.0
    success_rate: float
    attack_types: List[SupplyChainAttackType]
    persistence_level: float  # 0.0 to 1.0


class SupplyChainConfig(BaseModel):
    """Configuration for supply chain attack simulation"""
    dependency_count: int = Field(default=100, ge=1, le=500)
    service_count: int = Field(default=20, ge=1, le=100)
    attacker_count: int = Field(default=3, ge=1, le=10)
    attack_frequency: str = Field(default="low")
    target_types: List[str] = Field(default=["npm", "pip", "maven", "docker", "api"])
    simulation_duration: str = Field(default="48h")
    attack_intensity: List[str] = Field(default=["low", "medium", "high", "extreme"])


class SupplyChainSimulator:
    """Main supply chain attack simulator"""
    
    def __init__(self, config_path: str, monitoring: bool = False):
        self.config = self._load_config(config_path)
        self.monitoring = monitoring
        self.attackers: List[SupplyChainAttacker] = []
        self.dependencies: List[Dependency] = []
        self.services: List[ThirdPartyService] = []
        self.attacks: List[Dict] = []
        self.metrics = self._setup_metrics()
        
        # Setup logging
        logger.add("logs/supply_chain_simulator_{time}.log", rotation="1 day", retention="7 days")
        
        if monitoring:
            start_http_server(8090)
            logger.info("Prometheus metrics server started on port 8090")
    
    def _load_config(self, config_path: str) -> SupplyChainConfig:
        """Load configuration from JSON file"""
        try:
            with open(config_path, 'r') as f:
                config_data = json.load(f)
            return SupplyChainConfig(**config_data.get('simulation_config', {}))
        except Exception as e:
            logger.error(f"Failed to load config: {e}")
            return SupplyChainConfig()
    
    def _setup_metrics(self) -> Dict:
        """Setup Prometheus metrics"""
        return {
            'supply_chain_attacks_total': Counter('supply_chain_attacks_total', 'Total supply chain attacks', ['attack_type', 'status']),
            'supply_chain_attack_success_rate': Gauge('supply_chain_attack_success_rate', 'Supply chain attack success rate', ['attack_type']),
            'supply_chain_attack_sophistication': Histogram('supply_chain_attack_sophistication', 'Supply chain attack sophistication', ['attack_type']),
            'supply_chain_detection_time': Histogram('supply_chain_detection_time_seconds', 'Time to detect supply chain attack'),
            'dependency_security_rating': Gauge('dependency_security_rating', 'Dependency security rating', ['dependency_name']),
            'service_security_rating': Gauge('service_security_rating', 'Service security rating', ['service_name']),
            'attacker_count': Gauge('supply_chain_attacker_count', 'Number of active supply chain attackers'),
            'dependency_count': Gauge('supply_chain_dependency_count', 'Number of monitored dependencies')
        }
    
    def _create_attackers(self) -> None:
        """Create supply chain attackers with different characteristics"""
        attacker_names = ["ShadowGroup", "CodeBreakers", "DependencyHunters", "SupplyChainMasters", "LibraryPirates"]
        
        for i in range(self.config.attacker_count):
            attacker = SupplyChainAttacker(
                id=f"supply_chain_attacker_{i}",
                name=random.choice(attacker_names),
                attack_sophistication=random.uniform(0.4, 1.0),
                success_rate=random.uniform(0.1, 0.7),
                attack_types=random.sample(list(SupplyChainAttackType), random.randint(1, 4)),
                persistence_level=random.uniform(0.3, 1.0)
            )
            self.attackers.append(attacker)
        
        logger.info(f"Created {len(self.attackers)} supply chain attackers")
        self.metrics['attacker_count'].set(len(self.attackers))
    
    def _create_dependencies(self) -> None:
        """Create dependencies for simulation"""
        dependency_names = [
            "lodash", "react", "express", "axios", "moment", "jquery", "bootstrap", "webpack",
            "typescript", "babel", "eslint", "prettier", "jest", "mocha", "chai", "sinon",
            "mongoose", "sequelize", "redis", "mysql", "postgresql", "mongodb", "elasticsearch"
        ]
        
        for i in range(self.config.dependency_count):
            name = random.choice(dependency_names) + f"_{i}"
            version = f"{random.randint(1, 10)}.{random.randint(0, 20)}.{random.randint(0, 50)}"
            dep_type = random.choice(self.config.target_types)
            
            dependency = Dependency(
                name=name,
                version=version,
                type=dep_type,
                is_vulnerable=random.random() < 0.2,  # 20% chance of being vulnerable
                security_rating=random.uniform(0.3, 1.0),
                download_count=random.randint(1000, 10000000),
                maintainer=f"maintainer_{i}",
                last_updated=datetime.now() - timedelta(days=random.randint(1, 365))
            )
            self.dependencies.append(dependency)
        
        logger.info(f"Created {len(self.dependencies)} dependencies")
        self.metrics['dependency_count'].set(len(self.dependencies))
    
    def _create_services(self) -> None:
        """Create third-party services for simulation"""
        service_names = [
            "AWS", "Google Cloud", "Azure", "Stripe", "PayPal", "Twilio", "SendGrid",
            "MongoDB Atlas", "Redis Cloud", "Elasticsearch", "Kibana", "Grafana",
            "Prometheus", "Docker Hub", "GitHub", "GitLab", "Bitbucket", "NPM Registry"
        ]
        
        for i in range(self.config.service_count):
            name = random.choice(service_names) + f"_{i}"
            service_type = random.choice(["cloud", "api", "database", "monitoring", "registry"])
            
            service = ThirdPartyService(
                name=name,
                service_type=service_type,
                api_endpoint=f"https://api.{name.lower()}.com",
                is_trusted=random.random() < 0.8,  # 80% chance of being trusted
                security_rating=random.uniform(0.4, 1.0),
                access_level=random.choice(["read", "write", "admin"]),
                is_vulnerable=random.random() < 0.15  # 15% chance of being vulnerable
            )
            self.services.append(service)
        
        logger.info(f"Created {len(self.services)} third-party services")
    
    async def _simulate_dependency_attack(self, attacker: SupplyChainAttacker, dependency: Dependency) -> Dict:
        """Simulate dependency attack"""
        start_time = time.time()
        
        # Simulate dependency compromise
        compromise_sophistication = attacker.attack_sophistication * random.uniform(0.5, 1.0)
        
        # Simulate attack methods
        attack_methods = ["malicious_update", "typosquatting", "dependency_confusion", "package_poisoning"]
        method = random.choice(attack_methods)
        
        # Simulate persistence
        persistence_effectiveness = attacker.persistence_level * random.uniform(0.3, 1.0)
        
        # Calculate success probability
        success_probability = (compromise_sophistication * persistence_effectiveness * 
                             (1 - dependency.security_rating) * (1 if dependency.is_vulnerable else 0.1))
        
        # Simulate attack success
        attack_success = random.random() < success_probability
        success = attack_success and dependency.is_vulnerable
        
        detection_time = time.time() - start_time
        
        attack_result = {
            "attack_type": SupplyChainAttackType.DEPENDENCY_ATTACK.value,
            "attacker_id": attacker.id,
            "dependency_name": dependency.name,
            "dependency_version": dependency.version,
            "compromise_sophistication": compromise_sophistication,
            "method": method,
            "persistence_effectiveness": persistence_effectiveness,
            "success_probability": success_probability,
            "attack_success": attack_success,
            "success": success,
            "detection_time": detection_time,
            "timestamp": time.time()
        }
        
        # Update metrics
        self.metrics['supply_chain_attacks_total'].labels(
            attack_type=SupplyChainAttackType.DEPENDENCY_ATTACK.value,
            status="success" if success else "failed"
        ).inc()
        
        self.metrics['supply_chain_attack_sophistication'].labels(attack_type=SupplyChainAttackType.DEPENDENCY_ATTACK.value).observe(compromise_sophistication)
        self.metrics['supply_chain_detection_time'].observe(detection_time)
        self.metrics['dependency_security_rating'].labels(dependency_name=dependency.name).set(dependency.security_rating)
        
        return attack_result
    
    async def _simulate_third_party_attack(self, attacker: SupplyChainAttacker, service: ThirdPartyService) -> Dict:
        """Simulate third-party service attack"""
        start_time = time.time()
        
        # Simulate service compromise
        service_compromise = attacker.attack_sophistication * random.uniform(0.4, 1.0)
        
        # Simulate attack vectors
        attack_vectors = ["api_compromise", "credential_theft", "service_infiltration", "data_exfiltration"]
        vector = random.choice(attack_vectors)
        
        # Simulate trust exploitation
        trust_exploitation = service.is_trusted * random.uniform(0.2, 0.8)
        
        # Calculate success probability
        success_probability = (service_compromise * trust_exploitation * 
                             (1 - service.security_rating) * (1 if service.is_vulnerable else 0.1))
        
        # Simulate attack success
        attack_success = random.random() < success_probability
        success = attack_success and service.is_vulnerable
        
        detection_time = time.time() - start_time
        
        attack_result = {
            "attack_type": SupplyChainAttackType.THIRD_PARTY_ATTACK.value,
            "attacker_id": attacker.id,
            "service_name": service.name,
            "service_type": service.service_type,
            "service_compromise": service_compromise,
            "vector": vector,
            "trust_exploitation": trust_exploitation,
            "success_probability": success_probability,
            "attack_success": attack_success,
            "success": success,
            "detection_time": detection_time,
            "timestamp": time.time()
        }
        
        # Update metrics
        self.metrics['supply_chain_attacks_total'].labels(
            attack_type=SupplyChainAttackType.THIRD_PARTY_ATTACK.value,
            status="success" if success else "failed"
        ).inc()
        
        self.metrics['supply_chain_attack_sophistication'].labels(attack_type=SupplyChainAttackType.THIRD_PARTY_ATTACK.value).observe(service_compromise)
        self.metrics['supply_chain_detection_time'].observe(detection_time)
        self.metrics['service_security_rating'].labels(service_name=service.name).set(service.security_rating)
        
        return attack_result
    
    async def _simulate_library_attack(self, attacker: SupplyChainAttacker, dependency: Dependency) -> Dict:
        """Simulate library attack"""
        start_time = time.time()
        
        # Simulate library compromise
        library_compromise = attacker.attack_sophistication * random.uniform(0.6, 1.0)
        
        # Simulate attack techniques
        techniques = ["code_injection", "backdoor_implant", "data_exfiltration", "crypto_mining"]
        technique = random.choice(techniques)
        
        # Simulate stealth level
        stealth_level = attacker.persistence_level * random.uniform(0.4, 1.0)
        
        # Calculate success probability
        success_probability = (library_compromise * stealth_level * 
                             (1 - dependency.security_rating) * (1 if dependency.is_vulnerable else 0.1))
        
        # Simulate attack success
        attack_success = random.random() < success_probability
        success = attack_success and dependency.is_vulnerable
        
        detection_time = time.time() - start_time
        
        attack_result = {
            "attack_type": SupplyChainAttackType.LIBRARY_ATTACK.value,
            "attacker_id": attacker.id,
            "dependency_name": dependency.name,
            "library_compromise": library_compromise,
            "technique": technique,
            "stealth_level": stealth_level,
            "success_probability": success_probability,
            "attack_success": attack_success,
            "success": success,
            "detection_time": detection_time,
            "timestamp": time.time()
        }
        
        # Update metrics
        self.metrics['supply_chain_attacks_total'].labels(
            attack_type=SupplyChainAttackType.LIBRARY_ATTACK.value,
            status="success" if success else "failed"
        ).inc()
        
        self.metrics['supply_chain_attack_sophistication'].labels(attack_type=SupplyChainAttackType.LIBRARY_ATTACK.value).observe(library_compromise)
        self.metrics['supply_chain_detection_time'].observe(detection_time)
        
        return attack_result
    
    async def _simulate_infrastructure_attack(self, attacker: SupplyChainAttacker, service: ThirdPartyService) -> Dict:
        """Simulate infrastructure attack"""
        start_time = time.time()
        
        # Simulate infrastructure compromise
        infrastructure_compromise = attacker.attack_sophistication * random.uniform(0.5, 1.0)
        
        # Simulate attack targets
        targets = ["servers", "databases", "networks", "containers", "kubernetes"]
        target = random.choice(targets)
        
        # Simulate attack persistence
        attack_persistence = attacker.persistence_level * random.uniform(0.3, 1.0)
        
        # Calculate success probability
        success_probability = (infrastructure_compromise * attack_persistence * 
                             (1 - service.security_rating) * (1 if service.is_vulnerable else 0.1))
        
        # Simulate attack success
        attack_success = random.random() < success_probability
        success = attack_success and service.is_vulnerable
        
        detection_time = time.time() - start_time
        
        attack_result = {
            "attack_type": SupplyChainAttackType.INFRASTRUCTURE_ATTACK.value,
            "attacker_id": attacker.id,
            "service_name": service.name,
            "infrastructure_compromise": infrastructure_compromise,
            "target": target,
            "attack_persistence": attack_persistence,
            "success_probability": success_probability,
            "attack_success": attack_success,
            "success": success,
            "detection_time": detection_time,
            "timestamp": time.time()
        }
        
        # Update metrics
        self.metrics['supply_chain_attacks_total'].labels(
            attack_type=SupplyChainAttackType.INFRASTRUCTURE_ATTACK.value,
            status="success" if success else "failed"
        ).inc()
        
        self.metrics['supply_chain_attack_sophistication'].labels(attack_type=SupplyChainAttackType.INFRASTRUCTURE_ATTACK.value).observe(infrastructure_compromise)
        self.metrics['supply_chain_detection_time'].observe(detection_time)
        
        return attack_result
    
    async def _simulate_package_attack(self, attacker: SupplyChainAttacker, dependency: Dependency) -> Dict:
        """Simulate package attack"""
        start_time = time.time()
        
        # Simulate package compromise
        package_compromise = attacker.attack_sophistication * random.uniform(0.4, 1.0)
        
        # Simulate attack methods
        methods = ["typosquatting", "brandjacking", "subdomain_takeover", "package_poisoning"]
        method = random.choice(methods)
        
        # Simulate download manipulation
        download_manipulation = random.uniform(0.1, 0.5)
        
        # Calculate success probability
        success_probability = (package_compromise * download_manipulation * 
                             (1 - dependency.security_rating) * (1 if dependency.is_vulnerable else 0.1))
        
        # Simulate attack success
        attack_success = random.random() < success_probability
        success = attack_success and dependency.is_vulnerable
        
        detection_time = time.time() - start_time
        
        attack_result = {
            "attack_type": SupplyChainAttackType.PACKAGE_ATTACK.value,
            "attacker_id": attacker.id,
            "dependency_name": dependency.name,
            "package_compromise": package_compromise,
            "method": method,
            "download_manipulation": download_manipulation,
            "success_probability": success_probability,
            "attack_success": attack_success,
            "success": success,
            "detection_time": detection_time,
            "timestamp": time.time()
        }
        
        # Update metrics
        self.metrics['supply_chain_attacks_total'].labels(
            attack_type=SupplyChainAttackType.PACKAGE_ATTACK.value,
            status="success" if success else "failed"
        ).inc()
        
        self.metrics['supply_chain_attack_sophistication'].labels(attack_type=SupplyChainAttackType.PACKAGE_ATTACK.value).observe(package_compromise)
        self.metrics['supply_chain_detection_time'].observe(detection_time)
        
        return attack_result
    
    async def _run_attack_simulation(self) -> None:
        """Run the main supply chain attack simulation loop"""
        logger.info("Starting supply chain attack simulation...")
        
        # Determine simulation duration
        duration_hours = 48 if self.config.simulation_duration == "48h" else 1
        
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
                if attack_type == SupplyChainAttackType.DEPENDENCY_ATTACK:
                    dependency = random.choice(self.dependencies)
                    attack_result = await self._simulate_dependency_attack(attacker, dependency)
                elif attack_type == SupplyChainAttackType.THIRD_PARTY_ATTACK:
                    service = random.choice(self.services)
                    attack_result = await self._simulate_third_party_attack(attacker, service)
                elif attack_type == SupplyChainAttackType.LIBRARY_ATTACK:
                    dependency = random.choice(self.dependencies)
                    attack_result = await self._simulate_library_attack(attacker, dependency)
                elif attack_type == SupplyChainAttackType.INFRASTRUCTURE_ATTACK:
                    service = random.choice(self.services)
                    attack_result = await self._simulate_infrastructure_attack(attacker, service)
                elif attack_type == SupplyChainAttackType.PACKAGE_ATTACK:
                    dependency = random.choice(self.dependencies)
                    attack_result = await self._simulate_package_attack(attacker, dependency)
                else:
                    continue
                
                self.attacks.append(attack_result)
                
                # Log attack result
                status = "SUCCESS" if attack_result["success"] else "FAILED"
                logger.info(f"Supply chain attack {attack_result['attack_type']} by {attacker.name}: {status} "
                           f"(Detection: {attack_result['detection_time']:.3f}s)")
                
                # Update success rate metrics
                success_rate = sum(1 for a in self.attacks if a["success"]) / len(self.attacks)
                self.metrics['supply_chain_attack_success_rate'].labels(attack_type=attack_type.value).set(success_rate)
                
            except Exception as e:
                logger.error(f"Error in supply chain attack simulation: {e}")
            
            # Wait before next attack (supply chain attacks are less frequent)
            if self.config.attack_frequency == "high":
                await asyncio.sleep(random.uniform(60, 300))
            elif self.config.attack_frequency == "medium":
                await asyncio.sleep(random.uniform(300, 1800))
            else:  # low
                await asyncio.sleep(random.uniform(1800, 7200))
    
    async def run_simulation(self) -> None:
        """Run the complete supply chain attack simulation"""
        logger.info("Initializing supply chain attack simulation environment...")
        
        # Initialize environment
        self._create_attackers()
        self._create_dependencies()
        self._create_services()
        
        # Run simulation
        await self._run_attack_simulation()
        
        # Generate summary report
        self._generate_report()
        
        logger.info("Supply chain attack simulation completed")
    
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
            "dependency_analysis": {},
            "service_analysis": {}
        }
        
        # Attack type breakdown
        for attack_type in SupplyChainAttackType:
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
                report["attacker_performance"][attacker.name] = {
                    "attack_count": len(attacker_attacks),
                    "success_rate": sum(1 for a in attacker_attacks if a["success"]) / len(attacker_attacks),
                    "attack_sophistication": attacker.attack_sophistication,
                    "persistence_level": attacker.persistence_level
                }
        
        # Dependency analysis
        vulnerable_dependencies = [d for d in self.dependencies if d.is_vulnerable]
        report["dependency_analysis"] = {
            "total_dependencies": len(self.dependencies),
            "vulnerable_dependencies": len(vulnerable_dependencies),
            "vulnerability_rate": len(vulnerable_dependencies) / len(self.dependencies),
            "average_security_rating": np.mean([d.security_rating for d in self.dependencies]),
            "type_distribution": {
                dep_type: len([d for d in self.dependencies if d.type == dep_type]) 
                for dep_type in self.config.target_types
            }
        }
        
        # Service analysis
        vulnerable_services = [s for s in self.services if s.is_vulnerable]
        trusted_services = [s for s in self.services if s.is_trusted]
        report["service_analysis"] = {
            "total_services": len(self.services),
            "vulnerable_services": len(vulnerable_services),
            "trusted_services": len(trusted_services),
            "vulnerability_rate": len(vulnerable_services) / len(self.services),
            "trust_rate": len(trusted_services) / len(self.services),
            "average_security_rating": np.mean([s.security_rating for s in self.services])
        }
        
        # Save report
        report_file = f"logs/supply_chain_simulation_report_{int(time.time())}.json"
        with open(report_file, 'w') as f:
            json.dump(report, f, indent=2)
        
        logger.info(f"Simulation report saved to {report_file}")
        logger.info(f"Total attacks: {total_attacks}, Success rate: {successful_attacks/total_attacks:.2%}")


async def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description="Supply Chain Attack Simulator")
    parser.add_argument("--config", required=True, help="Path to configuration file")
    parser.add_argument("--monitoring", action="store_true", help="Enable monitoring")
    parser.add_argument("--log-level", default="INFO", help="Log level")
    parser.add_argument("--output", help="Output file for results")
    
    args = parser.parse_args()
    
    # Configure logging
    logger.remove()
    logger.add(sys.stderr, level=args.log_level)
    
    # Create simulator
    simulator = SupplyChainSimulator(args.config, args.monitoring)
    
    # Run simulation
    await simulator.run_simulation()


if __name__ == "__main__":
    asyncio.run(main())
