#!/usr/bin/env python3
"""
Governance Attack Simulator
Simulates various governance attacks including voting manipulation, proposal attacks, and governance token attacks.
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


class GovernanceAttackType(Enum):
    VOTING_MANIPULATION = "voting_manipulation"
    PROPOSAL_ATTACK = "proposal_attack"
    GOVERNANCE_TOKEN_ATTACK = "governance_token_attack"
    DELEGATION_ATTACK = "delegation_attack"
    QUORUM_ATTACK = "quorum_attack"
    TIMELOCK_ATTACK = "timelock_attack"
    MULTISIG_ATTACK = "multisig_attack"
    GOVERNANCE_TAKEOVER = "governance_takeover"


class AttackStatus(Enum):
    PENDING = "pending"
    EXECUTING = "executing"
    SUCCESS = "success"
    FAILED = "failed"
    DETECTED = "detected"


@dataclass
class GovernanceProposal:
    """Represents a governance proposal"""
    id: str
    title: str
    description: str
    proposer: str
    voting_power_required: float
    quorum_required: float
    execution_delay: int  # in seconds
    is_malicious: bool
    impact_level: str  # low, medium, high, critical


@dataclass
class GovernanceToken:
    """Represents a governance token"""
    symbol: str
    total_supply: float
    circulating_supply: float
    price: float
    voting_power: float
    delegation_enabled: bool
    staking_required: bool


@dataclass
class GovernanceAttacker:
    """Represents a governance attacker"""
    id: str
    address: str
    token_holdings: Dict[str, float]
    voting_power: float
    success_rate: float
    attack_types: List[GovernanceAttackType]
    max_attack_amount: float


class GovernanceConfig(BaseModel):
    """Configuration for governance attack simulation"""
    token_count: int = Field(default=5, ge=1, le=20)
    attacker_count: int = Field(default=3, ge=1, le=10)
    proposal_count: int = Field(default=20, ge=1, le=100)
    attack_frequency: str = Field(default="low")
    target_tokens: List[str] = Field(default=["UNI", "COMP", "AAVE", "MKR", "CRV"])
    simulation_duration: str = Field(default="24h")
    attack_intensity: List[str] = Field(default=["low", "medium", "high", "extreme"])


class GovernanceSimulator:
    """Main governance attack simulator"""
    
    def __init__(self, config_path: str, monitoring: bool = False):
        self.config = self._load_config(config_path)
        self.monitoring = monitoring
        self.attackers: List[GovernanceAttacker] = []
        self.tokens: List[GovernanceToken] = []
        self.proposals: List[GovernanceProposal] = []
        self.attacks: List[Dict] = []
        self.metrics = self._setup_metrics()
        
        # Setup logging
        logger.add("logs/governance_simulator_{time}.log", rotation="1 day", retention="7 days")
        
        if monitoring:
            start_http_server(8085)
            logger.info("Prometheus metrics server started on port 8085")
    
    def _load_config(self, config_path: str) -> GovernanceConfig:
        """Load configuration from JSON file"""
        try:
            with open(config_path, 'r') as f:
                config_data = json.load(f)
            return GovernanceConfig(**config_data.get('simulation_config', {}))
        except Exception as e:
            logger.error(f"Failed to load config: {e}")
            return GovernanceConfig()
    
    def _setup_metrics(self) -> Dict:
        """Setup Prometheus metrics"""
        return {
            'governance_attacks_total': Counter('governance_attacks_total', 'Total governance attacks', ['attack_type', 'status']),
            'governance_attack_success_rate': Gauge('governance_attack_success_rate', 'Governance attack success rate', ['attack_type']),
            'governance_attack_profit': Histogram('governance_attack_profit', 'Governance attack profit', ['attack_type']),
            'governance_detection_time': Histogram('governance_detection_time_seconds', 'Time to detect governance attack'),
            'voting_power_manipulation': Gauge('voting_power_manipulation', 'Voting power manipulation', ['token_symbol']),
            'proposal_impact': Histogram('proposal_impact', 'Proposal impact level', ['proposal_id']),
            'attacker_count': Gauge('governance_attacker_count', 'Number of active governance attackers'),
            'proposal_count': Gauge('governance_proposal_count', 'Number of governance proposals')
        }
    
    def _create_attackers(self) -> None:
        """Create governance attackers with different characteristics"""
        for i in range(self.config.attacker_count):
            # Create token holdings
            token_holdings = {}
            for token in self.config.target_tokens:
                token_holdings[token] = random.uniform(10000, 1000000)
            
            # Calculate voting power
            total_voting_power = sum(token_holdings.values()) / 1000000  # Normalize
            
            attacker = GovernanceAttacker(
                id=f"governance_attacker_{i}",
                address=f"0x{random.randint(1000000000000000000000000000000000000000, 9999999999999999999999999999999999999999):x}",
                token_holdings=token_holdings,
                voting_power=total_voting_power,
                success_rate=random.uniform(0.1, 0.6),
                attack_types=random.sample(list(GovernanceAttackType), random.randint(1, 4)),
                max_attack_amount=random.uniform(100000, 1000000)
            )
            self.attackers.append(attacker)
        
        logger.info(f"Created {len(self.attackers)} governance attackers")
        self.metrics['attacker_count'].set(len(self.attackers))
    
    def _create_tokens(self) -> None:
        """Create governance tokens for simulation"""
        base_prices = {
            "UNI": 10.0,
            "COMP": 50.0,
            "AAVE": 100.0,
            "MKR": 1000.0,
            "CRV": 1.0
        }
        
        for symbol in self.config.target_tokens:
            base_price = base_prices.get(symbol, 10.0)
            total_supply = random.uniform(1000000, 100000000)
            
            token = GovernanceToken(
                symbol=symbol,
                total_supply=total_supply,
                circulating_supply=total_supply * random.uniform(0.8, 0.95),
                price=base_price * random.uniform(0.8, 1.2),
                voting_power=random.uniform(0.1, 1.0),
                delegation_enabled=random.random() < 0.8,  # 80% chance
                staking_required=random.random() < 0.6  # 60% chance
            )
            self.tokens.append(token)
        
        logger.info(f"Created {len(self.tokens)} governance tokens")
    
    def _create_proposals(self) -> None:
        """Create governance proposals for simulation"""
        proposal_templates = [
            ("Increase Protocol Fees", "Proposal to increase protocol fees by 0.1%", "medium"),
            ("Change Treasury Allocation", "Proposal to change treasury allocation strategy", "high"),
            ("Update Governance Parameters", "Proposal to update governance voting parameters", "medium"),
            ("Emergency Protocol Shutdown", "Proposal to implement emergency protocol shutdown", "critical"),
            ("Token Distribution Change", "Proposal to change token distribution mechanism", "high"),
            ("Smart Contract Upgrade", "Proposal to upgrade core smart contracts", "critical"),
            ("Fee Structure Modification", "Proposal to modify fee structure", "low"),
            ("Governance Token Burn", "Proposal to burn governance tokens", "high")
        ]
        
        for i in range(self.config.proposal_count):
            title, description, impact = random.choice(proposal_templates)
            proposer = random.choice(self.attackers)
            
            proposal = GovernanceProposal(
                id=f"proposal_{i}",
                title=title,
                description=description,
                proposer=proposer.id,
                voting_power_required=random.uniform(0.1, 0.5),  # 10-50% voting power required
                quorum_required=random.uniform(0.2, 0.8),  # 20-80% quorum required
                execution_delay=random.randint(3600, 604800),  # 1 hour to 1 week
                is_malicious=random.random() < 0.3,  # 30% chance of being malicious
                impact_level=impact
            )
            self.proposals.append(proposal)
        
        logger.info(f"Created {len(self.proposals)} governance proposals")
        self.metrics['proposal_count'].set(len(self.proposals))
    
    async def _simulate_voting_manipulation(self, attacker: GovernanceAttacker, proposal: GovernanceProposal) -> Dict:
        """Simulate voting manipulation attack"""
        start_time = time.time()
        
        # Simulate voting power manipulation
        manipulation_amount = min(random.uniform(10000, 100000), attacker.max_attack_amount)
        voting_power_manipulation = manipulation_amount / 1000000  # Normalize
        
        # Simulate vote buying or manipulation
        vote_manipulation = random.uniform(0.1, 0.5)  # 10-50% vote manipulation
        manipulated_votes = voting_power_manipulation * vote_manipulation
        
        # Check if attacker can influence proposal
        can_influence = manipulated_votes > proposal.voting_power_required * 0.1  # Need 10% of required votes
        
        # Calculate profit from manipulation
        profit = manipulation_amount * vote_manipulation * random.uniform(0.01, 0.1) if can_influence else 0
        success = profit > 0 and can_influence
        
        detection_time = time.time() - start_time
        
        attack_result = {
            "attack_type": GovernanceAttackType.VOTING_MANIPULATION.value,
            "attacker_id": attacker.id,
            "proposal_id": proposal.id,
            "manipulation_amount": manipulation_amount,
            "voting_power_manipulation": voting_power_manipulation,
            "vote_manipulation": vote_manipulation,
            "manipulated_votes": manipulated_votes,
            "can_influence": can_influence,
            "profit": profit,
            "success": success,
            "detection_time": detection_time,
            "timestamp": time.time()
        }
        
        # Update metrics
        self.metrics['governance_attacks_total'].labels(
            attack_type=GovernanceAttackType.VOTING_MANIPULATION.value,
            status="success" if success else "failed"
        ).inc()
        
        if success:
            self.metrics['governance_attack_profit'].labels(attack_type=GovernanceAttackType.VOTING_MANIPULATION.value).observe(profit)
        
        self.metrics['governance_detection_time'].observe(detection_time)
        
        return attack_result
    
    async def _simulate_proposal_attack(self, attacker: GovernanceAttacker, proposal: GovernanceProposal) -> Dict:
        """Simulate proposal attack"""
        start_time = time.time()
        
        # Simulate malicious proposal creation
        if not proposal.is_malicious:
            return {
                "attack_type": GovernanceAttackType.PROPOSAL_ATTACK.value,
                "attacker_id": attacker.id,
                "proposal_id": proposal.id,
                "success": False,
                "reason": "Proposal not malicious",
                "timestamp": time.time()
            }
        
        # Simulate proposal impact
        impact_multiplier = {"low": 0.1, "medium": 0.3, "high": 0.6, "critical": 1.0}
        impact = impact_multiplier.get(proposal.impact_level, 0.1)
        
        # Calculate profit from malicious proposal
        profit = attacker.max_attack_amount * impact * random.uniform(0.1, 0.5)
        success = profit > 0 and proposal.impact_level in ["high", "critical"]
        
        detection_time = time.time() - start_time
        
        attack_result = {
            "attack_type": GovernanceAttackType.PROPOSAL_ATTACK.value,
            "attacker_id": attacker.id,
            "proposal_id": proposal.id,
            "proposal_title": proposal.title,
            "impact_level": proposal.impact_level,
            "impact": impact,
            "profit": profit,
            "success": success,
            "detection_time": detection_time,
            "timestamp": time.time()
        }
        
        # Update metrics
        self.metrics['governance_attacks_total'].labels(
            attack_type=GovernanceAttackType.PROPOSAL_ATTACK.value,
            status="success" if success else "failed"
        ).inc()
        
        if success:
            self.metrics['governance_attack_profit'].labels(attack_type=GovernanceAttackType.PROPOSAL_ATTACK.value).observe(profit)
        
        self.metrics['governance_detection_time'].observe(detection_time)
        self.metrics['proposal_impact'].labels(proposal_id=proposal.id).observe(impact)
        
        return attack_result
    
    async def _simulate_governance_token_attack(self, attacker: GovernanceAttacker, token: GovernanceToken) -> Dict:
        """Simulate governance token attack"""
        start_time = time.time()
        
        # Simulate governance token manipulation
        token_manipulation = min(random.uniform(50000, 500000), attacker.max_attack_amount)
        token_holdings = attacker.token_holdings.get(token.symbol, 0)
        
        # Simulate token accumulation
        accumulation_rate = random.uniform(0.1, 0.5)  # 10-50% accumulation
        accumulated_tokens = token_holdings * accumulation_rate
        
        # Simulate voting power increase
        voting_power_increase = accumulated_tokens / token.circulating_supply
        new_voting_power = attacker.voting_power + voting_power_increase
        
        # Calculate profit from token manipulation
        profit = token_manipulation * voting_power_increase * random.uniform(0.01, 0.1)
        success = profit > 0 and new_voting_power > 0.1  # Need >10% voting power
        
        detection_time = time.time() - start_time
        
        attack_result = {
            "attack_type": GovernanceAttackType.GOVERNANCE_TOKEN_ATTACK.value,
            "attacker_id": attacker.id,
            "token_symbol": token.symbol,
            "token_manipulation": token_manipulation,
            "accumulation_rate": accumulation_rate,
            "accumulated_tokens": accumulated_tokens,
            "voting_power_increase": voting_power_increase,
            "new_voting_power": new_voting_power,
            "profit": profit,
            "success": success,
            "detection_time": detection_time,
            "timestamp": time.time()
        }
        
        # Update metrics
        self.metrics['governance_attacks_total'].labels(
            attack_type=GovernanceAttackType.GOVERNANCE_TOKEN_ATTACK.value,
            status="success" if success else "failed"
        ).inc()
        
        if success:
            self.metrics['governance_attack_profit'].labels(attack_type=GovernanceAttackType.GOVERNANCE_TOKEN_ATTACK.value).observe(profit)
        
        self.metrics['governance_detection_time'].observe(detection_time)
        self.metrics['voting_power_manipulation'].labels(token_symbol=token.symbol).set(voting_power_increase)
        
        return attack_result
    
    async def _simulate_governance_takeover(self, attacker: GovernanceAttacker) -> Dict:
        """Simulate governance takeover attack"""
        start_time = time.time()
        
        # Simulate governance takeover
        takeover_amount = min(random.uniform(100000, 1000000), attacker.max_attack_amount)
        
        # Calculate total voting power needed for takeover
        total_voting_power_needed = 0.51  # 51% for majority
        current_voting_power = attacker.voting_power
        
        # Simulate voting power accumulation
        voting_power_accumulated = takeover_amount / 10000000  # Normalize
        new_total_power = current_voting_power + voting_power_accumulated
        
        # Check if takeover is possible
        can_takeover = new_total_power > total_voting_power_needed
        
        # Calculate profit from takeover
        profit = takeover_amount * random.uniform(0.1, 0.3) if can_takeover else 0
        success = profit > 0 and can_takeover
        
        detection_time = time.time() - start_time
        
        attack_result = {
            "attack_type": GovernanceAttackType.GOVERNANCE_TAKEOVER.value,
            "attacker_id": attacker.id,
            "takeover_amount": takeover_amount,
            "current_voting_power": current_voting_power,
            "voting_power_accumulated": voting_power_accumulated,
            "new_total_power": new_total_power,
            "total_voting_power_needed": total_voting_power_needed,
            "can_takeover": can_takeover,
            "profit": profit,
            "success": success,
            "detection_time": detection_time,
            "timestamp": time.time()
        }
        
        # Update metrics
        self.metrics['governance_attacks_total'].labels(
            attack_type=GovernanceAttackType.GOVERNANCE_TAKEOVER.value,
            status="success" if success else "failed"
        ).inc()
        
        if success:
            self.metrics['governance_attack_profit'].labels(attack_type=GovernanceAttackType.GOVERNANCE_TAKEOVER.value).observe(profit)
        
        self.metrics['governance_detection_time'].observe(detection_time)
        
        return attack_result
    
    async def _run_attack_simulation(self) -> None:
        """Run the main governance attack simulation loop"""
        logger.info("Starting governance attack simulation...")
        
        # Determine simulation duration
        duration_hours = 24 if self.config.simulation_duration == "24h" else 1
        
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
                if attack_type == GovernanceAttackType.VOTING_MANIPULATION:
                    proposal = random.choice(self.proposals)
                    attack_result = await self._simulate_voting_manipulation(attacker, proposal)
                elif attack_type == GovernanceAttackType.PROPOSAL_ATTACK:
                    proposal = random.choice(self.proposals)
                    attack_result = await self._simulate_proposal_attack(attacker, proposal)
                elif attack_type == GovernanceAttackType.GOVERNANCE_TOKEN_ATTACK:
                    token = random.choice(self.tokens)
                    attack_result = await self._simulate_governance_token_attack(attacker, token)
                elif attack_type == GovernanceAttackType.GOVERNANCE_TAKEOVER:
                    attack_result = await self._simulate_governance_takeover(attacker)
                else:
                    continue
                
                self.attacks.append(attack_result)
                
                # Log attack result
                status = "SUCCESS" if attack_result["success"] else "FAILED"
                logger.info(f"Governance attack {attack_result['attack_type']} by {attacker.id}: {status} "
                           f"(Profit: ${attack_result.get('profit', 0):.2f}, "
                           f"Detection: {attack_result['detection_time']:.3f}s)")
                
                # Update success rate metrics
                success_rate = sum(1 for a in self.attacks if a["success"]) / len(self.attacks)
                self.metrics['governance_attack_success_rate'].labels(attack_type=attack_type.value).set(success_rate)
                
            except Exception as e:
                logger.error(f"Error in governance attack simulation: {e}")
            
            # Wait before next attack (governance attacks are less frequent)
            if self.config.attack_frequency == "high":
                await asyncio.sleep(random.uniform(10, 30))
            elif self.config.attack_frequency == "medium":
                await asyncio.sleep(random.uniform(30, 120))
            else:  # low
                await asyncio.sleep(random.uniform(120, 600))
    
    async def run_simulation(self) -> None:
        """Run the complete governance attack simulation"""
        logger.info("Initializing governance attack simulation environment...")
        
        # Initialize environment
        self._create_attackers()
        self._create_tokens()
        self._create_proposals()
        
        # Run simulation
        await self._run_attack_simulation()
        
        # Generate summary report
        self._generate_report()
        
        logger.info("Governance attack simulation completed")
    
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
            "proposal_analysis": {}
        }
        
        # Attack type breakdown
        for attack_type in GovernanceAttackType:
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
                    "voting_power": attacker.voting_power
                }
        
        # Proposal analysis
        malicious_proposals = [p for p in self.proposals if p.is_malicious]
        report["proposal_analysis"] = {
            "total_proposals": len(self.proposals),
            "malicious_proposals": len(malicious_proposals),
            "malicious_rate": len(malicious_proposals) / len(self.proposals),
            "impact_distribution": {
                "low": len([p for p in malicious_proposals if p.impact_level == "low"]),
                "medium": len([p for p in malicious_proposals if p.impact_level == "medium"]),
                "high": len([p for p in malicious_proposals if p.impact_level == "high"]),
                "critical": len([p for p in malicious_proposals if p.impact_level == "critical"])
            }
        }
        
        # Save report
        report_file = f"logs/governance_simulation_report_{int(time.time())}.json"
        with open(report_file, 'w') as f:
            json.dump(report, f, indent=2)
        
        logger.info(f"Simulation report saved to {report_file}")
        logger.info(f"Total attacks: {total_attacks}, Success rate: {successful_attacks/total_attacks:.2%}, "
                   f"Total profit: ${total_profit:.2f}")


async def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description="Governance Attack Simulator")
    parser.add_argument("--config", required=True, help="Path to configuration file")
    parser.add_argument("--monitoring", action="store_true", help="Enable monitoring")
    parser.add_argument("--log-level", default="INFO", help="Log level")
    parser.add_argument("--output", help="Output file for results")
    
    args = parser.parse_args()
    
    # Configure logging
    logger.remove()
    logger.add(sys.stderr, level=args.log_level)
    
    # Create simulator
    simulator = GovernanceSimulator(args.config, args.monitoring)
    
    # Run simulation
    await simulator.run_simulation()


if __name__ == "__main__":
    asyncio.run(main())
