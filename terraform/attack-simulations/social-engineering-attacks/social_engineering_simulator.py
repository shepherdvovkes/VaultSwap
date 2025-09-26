#!/usr/bin/env python3
"""
Social Engineering Attack Simulator
Simulates various social engineering and phishing attacks including phishing, impersonation, and social manipulation.
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


class SocialEngineeringAttackType(Enum):
    PHISHING_ATTACK = "phishing_attack"
    IMPERSONATION_ATTACK = "impersonation_attack"
    SOCIAL_MANIPULATION = "social_manipulation"
    INFORMATION_DISCLOSURE = "information_disclosure"
    PRETEXTING_ATTACK = "pretexting_attack"
    BAITING_ATTACK = "baiting_attack"
    QUID_PRO_QUO_ATTACK = "quid_pro_quo_attack"
    TAILGATING_ATTACK = "tailgating_attack"


class AttackStatus(Enum):
    PENDING = "pending"
    EXECUTING = "executing"
    SUCCESS = "success"
    FAILED = "failed"
    DETECTED = "detected"


@dataclass
class TargetUser:
    """Represents a target user"""
    id: str
    email: str
    role: str
    security_awareness: float  # 0.0 to 1.0
    trust_level: float  # 0.0 to 1.0
    is_vulnerable: bool
    access_level: str  # low, medium, high, admin


@dataclass
class SocialEngineeringAttacker:
    """Represents a social engineering attacker"""
    id: str
    name: str
    attack_sophistication: float  # 0.0 to 1.0
    success_rate: float
    attack_types: List[SocialEngineeringAttackType]
    social_skills: float  # 0.0 to 1.0


class SocialEngineeringConfig(BaseModel):
    """Configuration for social engineering attack simulation"""
    target_count: int = Field(default=50, ge=1, le=200)
    attacker_count: int = Field(default=3, ge=1, le=10)
    attack_frequency: str = Field(default="low")
    target_roles: List[str] = Field(default=["user", "developer", "admin", "manager", "support"])
    simulation_duration: str = Field(default="24h")
    attack_intensity: List[str] = Field(default=["low", "medium", "high", "extreme"])


class SocialEngineeringSimulator:
    """Main social engineering attack simulator"""
    
    def __init__(self, config_path: str, monitoring: bool = False):
        self.config = self._load_config(config_path)
        self.monitoring = monitoring
        self.attackers: List[SocialEngineeringAttacker] = []
        self.targets: List[TargetUser] = []
        self.attacks: List[Dict] = []
        self.metrics = self._setup_metrics()
        
        # Setup logging
        logger.add("logs/social_engineering_simulator_{time}.log", rotation="1 day", retention="7 days")
        
        if monitoring:
            start_http_server(8089)
            logger.info("Prometheus metrics server started on port 8089")
    
    def _load_config(self, config_path: str) -> SocialEngineeringConfig:
        """Load configuration from JSON file"""
        try:
            with open(config_path, 'r') as f:
                config_data = json.load(f)
            return SocialEngineeringConfig(**config_data.get('simulation_config', {}))
        except Exception as e:
            logger.error(f"Failed to load config: {e}")
            return SocialEngineeringConfig()
    
    def _setup_metrics(self) -> Dict:
        """Setup Prometheus metrics"""
        return {
            'social_engineering_attacks_total': Counter('social_engineering_attacks_total', 'Total social engineering attacks', ['attack_type', 'status']),
            'social_engineering_attack_success_rate': Gauge('social_engineering_attack_success_rate', 'Social engineering attack success rate', ['attack_type']),
            'social_engineering_attack_sophistication': Histogram('social_engineering_attack_sophistication', 'Social engineering attack sophistication', ['attack_type']),
            'social_engineering_detection_time': Histogram('social_engineering_detection_time_seconds', 'Time to detect social engineering attack'),
            'target_security_awareness': Gauge('target_security_awareness', 'Target security awareness level', ['target_id']),
            'target_trust_level': Gauge('target_trust_level', 'Target trust level', ['target_id']),
            'attacker_count': Gauge('social_engineering_attacker_count', 'Number of active social engineering attackers'),
            'target_count': Gauge('social_engineering_target_count', 'Number of monitored targets')
        }
    
    def _create_attackers(self) -> None:
        """Create social engineering attackers with different characteristics"""
        attacker_names = ["Alice", "Bob", "Charlie", "Diana", "Eve", "Frank", "Grace", "Henry"]
        
        for i in range(self.config.attacker_count):
            attacker = SocialEngineeringAttacker(
                id=f"social_engineering_attacker_{i}",
                name=random.choice(attacker_names),
                attack_sophistication=random.uniform(0.3, 1.0),
                success_rate=random.uniform(0.1, 0.8),
                attack_types=random.sample(list(SocialEngineeringAttackType), random.randint(1, 4)),
                social_skills=random.uniform(0.4, 1.0)
            )
            self.attackers.append(attacker)
        
        logger.info(f"Created {len(self.attackers)} social engineering attackers")
        self.metrics['attacker_count'].set(len(self.attackers))
    
    def _create_targets(self) -> None:
        """Create target users for simulation"""
        for i in range(self.config.target_count):
            # Generate realistic email
            domains = ["company.com", "organization.org", "business.net", "enterprise.io"]
            username = f"user{i}"
            domain = random.choice(domains)
            email = f"{username}@{domain}"
            
            target = TargetUser(
                id=f"target_user_{i}",
                email=email,
                role=random.choice(self.config.target_roles),
                security_awareness=random.uniform(0.2, 1.0),
                trust_level=random.uniform(0.3, 1.0),
                is_vulnerable=random.random() < 0.4,  # 40% chance of being vulnerable
                access_level=random.choice(["low", "medium", "high", "admin"])
            )
            self.targets.append(target)
        
        logger.info(f"Created {len(self.targets)} target users")
        self.metrics['target_count'].set(len(self.targets))
    
    async def _simulate_phishing_attack(self, attacker: SocialEngineeringAttacker, target: TargetUser) -> Dict:
        """Simulate phishing attack"""
        start_time = time.time()
        
        # Simulate phishing sophistication
        phishing_sophistication = attacker.attack_sophistication * random.uniform(0.5, 1.0)
        
        # Simulate phishing methods
        phishing_methods = ["email", "sms", "phone", "social_media", "fake_website"]
        method = random.choice(phishing_methods)
        
        # Simulate phishing content
        content_types = ["urgent_action", "fake_reward", "security_alert", "account_verification", "payment_request"]
        content_type = random.choice(content_types)
        
        # Calculate success probability
        success_probability = (phishing_sophistication * attacker.social_skills * 
                             (1 - target.security_awareness) * target.trust_level)
        
        # Simulate target response
        target_response = random.random() < success_probability
        success = target_response and target.is_vulnerable
        
        detection_time = time.time() - start_time
        
        attack_result = {
            "attack_type": SocialEngineeringAttackType.PHISHING_ATTACK.value,
            "attacker_id": attacker.id,
            "target_id": target.id,
            "phishing_sophistication": phishing_sophistication,
            "method": method,
            "content_type": content_type,
            "success_probability": success_probability,
            "target_response": target_response,
            "success": success,
            "detection_time": detection_time,
            "timestamp": time.time()
        }
        
        # Update metrics
        self.metrics['social_engineering_attacks_total'].labels(
            attack_type=SocialEngineeringAttackType.PHISHING_ATTACK.value,
            status="success" if success else "failed"
        ).inc()
        
        self.metrics['social_engineering_attack_sophistication'].labels(attack_type=SocialEngineeringAttackType.PHISHING_ATTACK.value).observe(phishing_sophistication)
        self.metrics['social_engineering_detection_time'].observe(detection_time)
        
        return attack_result
    
    async def _simulate_impersonation_attack(self, attacker: SocialEngineeringAttacker, target: TargetUser) -> Dict:
        """Simulate impersonation attack"""
        start_time = time.time()
        
        # Simulate impersonation sophistication
        impersonation_sophistication = attacker.attack_sophistication * random.uniform(0.6, 1.0)
        
        # Simulate impersonation targets
        impersonation_targets = ["IT_support", "HR_department", "security_team", "management", "vendor"]
        impersonated_entity = random.choice(impersonation_targets)
        
        # Simulate communication channels
        channels = ["email", "phone", "video_call", "chat", "in_person"]
        channel = random.choice(channels)
        
        # Calculate success probability
        success_probability = (impersonation_sophistication * attacker.social_skills * 
                             target.trust_level * (1 - target.security_awareness))
        
        # Simulate target response
        target_response = random.random() < success_probability
        success = target_response and target.is_vulnerable
        
        detection_time = time.time() - start_time
        
        attack_result = {
            "attack_type": SocialEngineeringAttackType.IMPERSONATION_ATTACK.value,
            "attacker_id": attacker.id,
            "target_id": target.id,
            "impersonation_sophistication": impersonation_sophistication,
            "impersonated_entity": impersonated_entity,
            "channel": channel,
            "success_probability": success_probability,
            "target_response": target_response,
            "success": success,
            "detection_time": detection_time,
            "timestamp": time.time()
        }
        
        # Update metrics
        self.metrics['social_engineering_attacks_total'].labels(
            attack_type=SocialEngineeringAttackType.IMPERSONATION_ATTACK.value,
            status="success" if success else "failed"
        ).inc()
        
        self.metrics['social_engineering_attack_sophistication'].labels(attack_type=SocialEngineeringAttackType.IMPERSONATION_ATTACK.value).observe(impersonation_sophistication)
        self.metrics['social_engineering_detection_time'].observe(detection_time)
        
        return attack_result
    
    async def _simulate_social_manipulation(self, attacker: SocialEngineeringAttacker, target: TargetUser) -> Dict:
        """Simulate social manipulation attack"""
        start_time = time.time()
        
        # Simulate manipulation techniques
        manipulation_techniques = ["authority", "urgency", "reciprocity", "social_proof", "commitment"]
        technique = random.choice(manipulation_techniques)
        
        # Simulate manipulation intensity
        manipulation_intensity = attacker.social_skills * random.uniform(0.4, 1.0)
        
        # Simulate psychological pressure
        psychological_pressure = random.uniform(0.2, 0.8)
        
        # Calculate success probability
        success_probability = (manipulation_intensity * (1 - target.security_awareness) * 
                             target.trust_level * psychological_pressure)
        
        # Simulate target response
        target_response = random.random() < success_probability
        success = target_response and target.is_vulnerable
        
        detection_time = time.time() - start_time
        
        attack_result = {
            "attack_type": SocialEngineeringAttackType.SOCIAL_MANIPULATION.value,
            "attacker_id": attacker.id,
            "target_id": target.id,
            "technique": technique,
            "manipulation_intensity": manipulation_intensity,
            "psychological_pressure": psychological_pressure,
            "success_probability": success_probability,
            "target_response": target_response,
            "success": success,
            "detection_time": detection_time,
            "timestamp": time.time()
        }
        
        # Update metrics
        self.metrics['social_engineering_attacks_total'].labels(
            attack_type=SocialEngineeringAttackType.SOCIAL_MANIPULATION.value,
            status="success" if success else "failed"
        ).inc()
        
        self.metrics['social_engineering_attack_sophistication'].labels(attack_type=SocialEngineeringAttackType.SOCIAL_MANIPULATION.value).observe(manipulation_intensity)
        self.metrics['social_engineering_detection_time'].observe(detection_time)
        
        return attack_result
    
    async def _simulate_information_disclosure(self, attacker: SocialEngineeringAttacker, target: TargetUser) -> Dict:
        """Simulate information disclosure attack"""
        start_time = time.time()
        
        # Simulate information types
        information_types = ["credentials", "personal_data", "company_secrets", "access_codes", "financial_info"]
        information_type = random.choice(information_types)
        
        # Simulate disclosure methods
        disclosure_methods = ["direct_questioning", "casual_conversation", "technical_support", "survey", "social_engineering"]
        method = random.choice(disclosure_methods)
        
        # Simulate attacker persistence
        persistence_level = attacker.attack_sophistication * random.uniform(0.3, 1.0)
        
        # Calculate success probability
        success_probability = (persistence_level * attacker.social_skills * 
                             (1 - target.security_awareness) * target.trust_level)
        
        # Simulate target response
        target_response = random.random() < success_probability
        success = target_response and target.is_vulnerable
        
        detection_time = time.time() - start_time
        
        attack_result = {
            "attack_type": SocialEngineeringAttackType.INFORMATION_DISCLOSURE.value,
            "attacker_id": attacker.id,
            "target_id": target.id,
            "information_type": information_type,
            "disclosure_method": method,
            "persistence_level": persistence_level,
            "success_probability": success_probability,
            "target_response": target_response,
            "success": success,
            "detection_time": detection_time,
            "timestamp": time.time()
        }
        
        # Update metrics
        self.metrics['social_engineering_attacks_total'].labels(
            attack_type=SocialEngineeringAttackType.INFORMATION_DISCLOSURE.value,
            status="success" if success else "failed"
        ).inc()
        
        self.metrics['social_engineering_attack_sophistication'].labels(attack_type=SocialEngineeringAttackType.INFORMATION_DISCLOSURE.value).observe(persistence_level)
        self.metrics['social_engineering_detection_time'].observe(detection_time)
        
        return attack_result
    
    async def _simulate_pretexting_attack(self, attacker: SocialEngineeringAttacker, target: TargetUser) -> Dict:
        """Simulate pretexting attack"""
        start_time = time.time()
        
        # Simulate pretext scenarios
        pretext_scenarios = ["IT_maintenance", "security_audit", "system_upgrade", "compliance_check", "emergency_access"]
        scenario = random.choice(pretext_scenarios)
        
        # Simulate pretext sophistication
        pretext_sophistication = attacker.attack_sophistication * random.uniform(0.5, 1.0)
        
        # Simulate credibility factors
        credibility_factors = ["official_documentation", "company_letterhead", "technical_knowledge", "authority_claim", "urgency_claim"]
        credibility_factor = random.choice(credibility_factors)
        
        # Calculate success probability
        success_probability = (pretext_sophistication * attacker.social_skills * 
                             target.trust_level * (1 - target.security_awareness))
        
        # Simulate target response
        target_response = random.random() < success_probability
        success = target_response and target.is_vulnerable
        
        detection_time = time.time() - start_time
        
        attack_result = {
            "attack_type": SocialEngineeringAttackType.PRETEXTING_ATTACK.value,
            "attacker_id": attacker.id,
            "target_id": target.id,
            "scenario": scenario,
            "pretext_sophistication": pretext_sophistication,
            "credibility_factor": credibility_factor,
            "success_probability": success_probability,
            "target_response": target_response,
            "success": success,
            "detection_time": detection_time,
            "timestamp": time.time()
        }
        
        # Update metrics
        self.metrics['social_engineering_attacks_total'].labels(
            attack_type=SocialEngineeringAttackType.PRETEXTING_ATTACK.value,
            status="success" if success else "failed"
        ).inc()
        
        self.metrics['social_engineering_attack_sophistication'].labels(attack_type=SocialEngineeringAttackType.PRETEXTING_ATTACK.value).observe(pretext_sophistication)
        self.metrics['social_engineering_detection_time'].observe(detection_time)
        
        return attack_result
    
    async def _run_attack_simulation(self) -> None:
        """Run the main social engineering attack simulation loop"""
        logger.info("Starting social engineering attack simulation...")
        
        # Determine simulation duration
        duration_hours = 24 if self.config.simulation_duration == "24h" else 1
        
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
                if attack_type == SocialEngineeringAttackType.PHISHING_ATTACK:
                    attack_result = await self._simulate_phishing_attack(attacker, target)
                elif attack_type == SocialEngineeringAttackType.IMPERSONATION_ATTACK:
                    attack_result = await self._simulate_impersonation_attack(attacker, target)
                elif attack_type == SocialEngineeringAttackType.SOCIAL_MANIPULATION:
                    attack_result = await self._simulate_social_manipulation(attacker, target)
                elif attack_type == SocialEngineeringAttackType.INFORMATION_DISCLOSURE:
                    attack_result = await self._simulate_information_disclosure(attacker, target)
                elif attack_type == SocialEngineeringAttackType.PRETEXTING_ATTACK:
                    attack_result = await self._simulate_pretexting_attack(attacker, target)
                else:
                    continue
                
                self.attacks.append(attack_result)
                
                # Log attack result
                status = "SUCCESS" if attack_result["success"] else "FAILED"
                logger.info(f"Social engineering attack {attack_result['attack_type']} by {attacker.name}: {status} "
                           f"(Target: {target.email}, Detection: {attack_result['detection_time']:.3f}s)")
                
                # Update success rate metrics
                success_rate = sum(1 for a in self.attacks if a["success"]) / len(self.attacks)
                self.metrics['social_engineering_attack_success_rate'].labels(attack_type=attack_type.value).set(success_rate)
                
                # Update target metrics
                self.metrics['target_security_awareness'].labels(target_id=target.id).set(target.security_awareness)
                self.metrics['target_trust_level'].labels(target_id=target.id).set(target.trust_level)
                
            except Exception as e:
                logger.error(f"Error in social engineering attack simulation: {e}")
            
            # Wait before next attack (social engineering attacks are less frequent)
            if self.config.attack_frequency == "high":
                await asyncio.sleep(random.uniform(30, 120))
            elif self.config.attack_frequency == "medium":
                await asyncio.sleep(random.uniform(120, 600))
            else:  # low
                await asyncio.sleep(random.uniform(600, 1800))
    
    async def run_simulation(self) -> None:
        """Run the complete social engineering attack simulation"""
        logger.info("Initializing social engineering attack simulation environment...")
        
        # Initialize environment
        self._create_attackers()
        self._create_targets()
        
        # Run simulation
        await self._run_attack_simulation()
        
        # Generate summary report
        self._generate_report()
        
        logger.info("Social engineering attack simulation completed")
    
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
        for attack_type in SocialEngineeringAttackType:
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
                    "social_skills": attacker.social_skills
                }
        
        # Target analysis
        vulnerable_targets = [t for t in self.targets if t.is_vulnerable]
        report["target_analysis"] = {
            "total_targets": len(self.targets),
            "vulnerable_targets": len(vulnerable_targets),
            "vulnerability_rate": len(vulnerable_targets) / len(self.targets),
            "average_security_awareness": np.mean([t.security_awareness for t in self.targets]),
            "average_trust_level": np.mean([t.trust_level for t in self.targets]),
            "role_distribution": {
                role: len([t for t in self.targets if t.role == role]) 
                for role in self.config.target_roles
            }
        }
        
        # Save report
        report_file = f"logs/social_engineering_simulation_report_{int(time.time())}.json"
        with open(report_file, 'w') as f:
            json.dump(report, f, indent=2)
        
        logger.info(f"Simulation report saved to {report_file}")
        logger.info(f"Total attacks: {total_attacks}, Success rate: {successful_attacks/total_attacks:.2%}")


async def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description="Social Engineering Attack Simulator")
    parser.add_argument("--config", required=True, help="Path to configuration file")
    parser.add_argument("--monitoring", action="store_true", help="Enable monitoring")
    parser.add_argument("--log-level", default="INFO", help="Log level")
    parser.add_argument("--output", help="Output file for results")
    
    args = parser.parse_args()
    
    # Configure logging
    logger.remove()
    logger.add(sys.stderr, level=args.log_level)
    
    # Create simulator
    simulator = SocialEngineeringSimulator(args.config, args.monitoring)
    
    # Run simulation
    await simulator.run_simulation()


if __name__ == "__main__":
    asyncio.run(main())
