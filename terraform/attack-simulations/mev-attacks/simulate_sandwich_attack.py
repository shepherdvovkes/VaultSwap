#!/usr/bin/env python3
"""
Sandwich Attack Simulator
Simulates sandwich attacks to test DEX security measures.
"""

import asyncio
import json
import random
import time
from typing import Dict, List
import argparse
import sys

from loguru import logger


class SandwichAttackSimulator:
    """Simulates sandwich attacks against DEX pools"""
    
    def __init__(self, config_path: str):
        self.config = self._load_config(config_path)
        self.attacks = []
        
    def _load_config(self, config_path: str) -> Dict:
        """Load configuration from JSON file"""
        try:
            with open(config_path, 'r') as f:
                return json.load(f)
        except Exception as e:
            logger.error(f"Failed to load config: {e}")
            return {}
    
    async def simulate_sandwich_attack(self, victim_amount: float, pool_reserves: tuple) -> Dict:
        """
        Simulate a sandwich attack
        
        Args:
            victim_amount: Amount the victim is trying to swap
            pool_reserves: (reserve_a, reserve_b) of the pool
            
        Returns:
            Dictionary containing attack details and results
        """
        start_time = time.time()
        
        # Extract pool reserves
        reserve_a, reserve_b = pool_reserves
        
        # Calculate victim's expected output (simplified AMM formula)
        victim_output = (victim_amount * reserve_b) / (reserve_a + victim_amount)
        
        # Front-running transaction (bot buys before victim)
        front_amount = victim_amount * 0.3  # 30% of victim amount
        front_output = (front_amount * reserve_b) / (reserve_a + front_amount)
        
        # Update reserves after front-running
        new_reserve_a = reserve_a + front_amount
        new_reserve_b = reserve_b - front_output
        
        # Victim transaction (now with worse price due to front-running)
        victim_actual_output = (victim_amount * new_reserve_b) / (new_reserve_a + victim_amount)
        
        # Back-running transaction (bot sells after victim)
        back_amount = front_output + victim_actual_output * 0.1  # Sell slightly more than front output
        back_output = (back_amount * new_reserve_a) / (new_reserve_b + back_amount)
        
        # Calculate profit
        profit = back_output - front_amount
        
        # Simulate detection time
        detection_time = time.time() - start_time
        
        # Determine if attack was successful
        success = profit > 0 and detection_time < 5.0  # Must be profitable and fast
        
        attack_result = {
            "attack_type": "sandwich_attack",
            "timestamp": time.time(),
            "victim_amount": victim_amount,
            "front_amount": front_amount,
            "back_amount": back_amount,
            "victim_expected_output": victim_output,
            "victim_actual_output": victim_actual_output,
            "profit": profit,
            "success": success,
            "detection_time": detection_time,
            "price_impact": (victim_expected_output - victim_actual_output) / victim_expected_output,
            "gas_cost": random.uniform(0.01, 0.05),  # Simulated gas cost
            "net_profit": profit - random.uniform(0.01, 0.05)
        }
        
        self.attacks.append(attack_result)
        
        logger.info(f"Sandwich attack: {'SUCCESS' if success else 'FAILED'} "
                   f"(Profit: ${profit:.2f}, Detection: {detection_time:.3f}s)")
        
        return attack_result
    
    async def run_simulation(self, duration_minutes: int = 60) -> None:
        """Run sandwich attack simulation for specified duration"""
        logger.info(f"Starting sandwich attack simulation for {duration_minutes} minutes")
        
        end_time = time.time() + (duration_minutes * 60)
        
        # Simulate different pool sizes and victim amounts
        pool_configs = [
            {"reserves": (1000000, 1000000), "name": "Large Pool"},
            {"reserves": (100000, 100000), "name": "Medium Pool"},
            {"reserves": (10000, 10000), "name": "Small Pool"},
        ]
        
        while time.time() < end_time:
            # Select random pool and victim amount
            pool = random.choice(pool_configs)
            victim_amount = random.uniform(100, 10000)
            
            # Run sandwich attack
            await self.simulate_sandwich_attack(victim_amount, pool["reserves"])
            
            # Wait before next attack
            await asyncio.sleep(random.uniform(1, 10))
        
        # Generate summary
        self._generate_summary()
    
    def _generate_summary(self) -> None:
        """Generate simulation summary"""
        total_attacks = len(self.attacks)
        successful_attacks = sum(1 for a in self.attacks if a["success"])
        total_profit = sum(a["net_profit"] for a in self.attacks if a["success"])
        avg_detection_time = sum(a["detection_time"] for a in self.attacks) / total_attacks
        
        summary = {
            "total_attacks": total_attacks,
            "successful_attacks": successful_attacks,
            "success_rate": successful_attacks / total_attacks if total_attacks > 0 else 0,
            "total_profit": total_profit,
            "average_detection_time": avg_detection_time,
            "average_profit_per_successful_attack": total_profit / successful_attacks if successful_attacks > 0 else 0
        }
        
        logger.info(f"Sandwich Attack Simulation Summary:")
        logger.info(f"  Total Attacks: {total_attacks}")
        logger.info(f"  Success Rate: {summary['success_rate']:.2%}")
        logger.info(f"  Total Profit: ${total_profit:.2f}")
        logger.info(f"  Average Detection Time: {avg_detection_time:.3f}s")
        
        # Save detailed results
        results_file = f"logs/sandwich_attack_results_{int(time.time())}.json"
        with open(results_file, 'w') as f:
            json.dump({
                "summary": summary,
                "attacks": self.attacks
            }, f, indent=2)
        
        logger.info(f"Detailed results saved to {results_file}")


async def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description="Sandwich Attack Simulator")
    parser.add_argument("--config", required=True, help="Path to configuration file")
    parser.add_argument("--duration", type=int, default=60, help="Simulation duration in minutes")
    parser.add_argument("--log-level", default="INFO", help="Log level")
    parser.add_argument("--output", help="Output file for results")
    
    args = parser.parse_args()
    
    # Configure logging
    logger.remove()
    logger.add(sys.stderr, level=args.log_level)
    
    if args.output:
        logger.add(args.output, level=args.log_level)
    
    # Create simulator
    simulator = SandwichAttackSimulator(args.config)
    
    # Run simulation
    await simulator.run_simulation(args.duration)


if __name__ == "__main__":
    asyncio.run(main())
