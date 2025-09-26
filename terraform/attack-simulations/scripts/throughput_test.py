#!/usr/bin/env python3
"""
Throughput Test for Attack Simulation Environment
Tests the throughput characteristics of the attack simulation system under various load conditions.
"""

import asyncio
import time
import argparse
import sys
import statistics
from datetime import datetime
from typing import Dict, List, Tuple
import random
import psutil

from loguru import logger


class ThroughputTest:
    """Throughput testing for attack simulation environment"""
    
    def __init__(self):
        self.throughput_metrics = {
            "attacks_per_second": [],
            "detections_per_second": [],
            "alerts_per_second": [],
            "system_load": [],
            "response_times": []
        }
        
        # Setup logging
        logger.add("logs/throughput_test_{time}.log", rotation="1 day", retention="7 days")
    
    async def test_mev_throughput(self, duration: int = 60, concurrent: int = 1) -> Dict:
        """Test MEV attack simulation throughput"""
        logger.info(f"Testing MEV throughput for {duration} seconds with {concurrent} concurrent simulations")
        
        start_time = time.time()
        end_time = start_time + duration
        
        # Create concurrent MEV simulation tasks
        tasks = []
        for i in range(concurrent):
            task = asyncio.create_task(self._simulate_mev_attacks(end_time, i))
            tasks.append(task)
        
        # Wait for all tasks to complete
        results = await asyncio.gather(*tasks)
        
        # Calculate throughput metrics
        total_attacks = sum(results)
        attacks_per_second = total_attacks / duration
        
        return {
            "test_type": "mev_throughput",
            "duration": duration,
            "concurrent": concurrent,
            "total_attacks": total_attacks,
            "attacks_per_second": attacks_per_second,
            "avg_response_time": statistics.mean(self.throughput_metrics["response_times"]) if self.throughput_metrics["response_times"] else 0,
            "system_load": statistics.mean(self.throughput_metrics["system_load"]) if self.throughput_metrics["system_load"] else 0
        }
    
    async def test_flash_loan_throughput(self, duration: int = 60, concurrent: int = 1) -> Dict:
        """Test flash loan attack simulation throughput"""
        logger.info(f"Testing flash loan throughput for {duration} seconds with {concurrent} concurrent simulations")
        
        start_time = time.time()
        end_time = start_time + duration
        
        # Create concurrent flash loan simulation tasks
        tasks = []
        for i in range(concurrent):
            task = asyncio.create_task(self._simulate_flash_loan_attacks(end_time, i))
            tasks.append(task)
        
        # Wait for all tasks to complete
        results = await asyncio.gather(*tasks)
        
        # Calculate throughput metrics
        total_attacks = sum(results)
        attacks_per_second = total_attacks / duration
        
        return {
            "test_type": "flash_loan_throughput",
            "duration": duration,
            "concurrent": concurrent,
            "total_attacks": total_attacks,
            "attacks_per_second": attacks_per_second,
            "avg_response_time": statistics.mean(self.throughput_metrics["response_times"]) if self.throughput_metrics["response_times"] else 0,
            "system_load": statistics.mean(self.throughput_metrics["system_load"]) if self.throughput_metrics["system_load"] else 0
        }
    
    async def test_oracle_throughput(self, duration: int = 60, concurrent: int = 1) -> Dict:
        """Test oracle manipulation simulation throughput"""
        logger.info(f"Testing oracle throughput for {duration} seconds with {concurrent} concurrent simulations")
        
        start_time = time.time()
        end_time = start_time + duration
        
        # Create concurrent oracle simulation tasks
        tasks = []
        for i in range(concurrent):
            task = asyncio.create_task(self._simulate_oracle_attacks(end_time, i))
            tasks.append(task)
        
        # Wait for all tasks to complete
        results = await asyncio.gather(*tasks)
        
        # Calculate throughput metrics
        total_attacks = sum(results)
        attacks_per_second = total_attacks / duration
        
        return {
            "test_type": "oracle_throughput",
            "duration": duration,
            "concurrent": concurrent,
            "total_attacks": total_attacks,
            "attacks_per_second": attacks_per_second,
            "avg_response_time": statistics.mean(self.throughput_metrics["response_times"]) if self.throughput_metrics["response_times"] else 0,
            "system_load": statistics.mean(self.throughput_metrics["system_load"]) if self.throughput_metrics["system_load"] else 0
        }
    
    async def test_mixed_throughput(self, duration: int = 60, concurrent: int = 5) -> Dict:
        """Test mixed attack simulation throughput"""
        logger.info(f"Testing mixed throughput for {duration} seconds with {concurrent} concurrent simulations")
        
        start_time = time.time()
        end_time = start_time + duration
        
        # Create mixed simulation tasks
        tasks = []
        for i in range(concurrent):
            attack_type = random.choice(["mev", "flash_loan", "oracle"])
            if attack_type == "mev":
                task = asyncio.create_task(self._simulate_mev_attacks(end_time, i))
            elif attack_type == "flash_loan":
                task = asyncio.create_task(self._simulate_flash_loan_attacks(end_time, i))
            else:
                task = asyncio.create_task(self._simulate_oracle_attacks(end_time, i))
            tasks.append(task)
        
        # Wait for all tasks to complete
        results = await asyncio.gather(*tasks)
        
        # Calculate throughput metrics
        total_attacks = sum(results)
        attacks_per_second = total_attacks / duration
        
        return {
            "test_type": "mixed_throughput",
            "duration": duration,
            "concurrent": concurrent,
            "total_attacks": total_attacks,
            "attacks_per_second": attacks_per_second,
            "avg_response_time": statistics.mean(self.throughput_metrics["response_times"]) if self.throughput_metrics["response_times"] else 0,
            "system_load": statistics.mean(self.throughput_metrics["system_load"]) if self.throughput_metrics["system_load"] else 0
        }
    
    async def test_scalability(self, max_concurrent: int = 20, duration: int = 30) -> Dict:
        """Test system scalability with increasing concurrent load"""
        logger.info(f"Testing scalability up to {max_concurrent} concurrent simulations")
        
        scalability_results = []
        
        for concurrent in range(1, max_concurrent + 1, 2):  # Test every 2 concurrent levels
            logger.info(f"Testing with {concurrent} concurrent simulations")
            
            # Test with mixed attack types
            result = await self.test_mixed_throughput(duration, concurrent)
            scalability_results.append({
                "concurrent": concurrent,
                "attacks_per_second": result["attacks_per_second"],
                "avg_response_time": result["avg_response_time"],
                "system_load": result["system_load"]
            })
            
            # Small delay between tests
            await asyncio.sleep(2)
        
        # Calculate scalability metrics
        max_throughput = max(r["attacks_per_second"] for r in scalability_results)
        optimal_concurrent = next(r["concurrent"] for r in scalability_results if r["attacks_per_second"] == max_throughput)
        
        return {
            "test_type": "scalability",
            "max_concurrent": max_concurrent,
            "duration": duration,
            "max_throughput": max_throughput,
            "optimal_concurrent": optimal_concurrent,
            "scalability_results": scalability_results
        }
    
    async def _simulate_mev_attacks(self, end_time: float, task_id: int) -> int:
        """Simulate MEV attacks until end time"""
        attack_count = 0
        
        while time.time() < end_time:
            # Simulate MEV attack
            start_time = time.time()
            await self._simulate_mev_attack()
            response_time = time.time() - start_time
            
            self.throughput_metrics["response_times"].append(response_time)
            self.throughput_metrics["system_load"].append(psutil.cpu_percent())
            
            attack_count += 1
            
            # Variable delay between attacks
            await asyncio.sleep(random.uniform(0.1, 1.0))
        
        return attack_count
    
    async def _simulate_flash_loan_attacks(self, end_time: float, task_id: int) -> int:
        """Simulate flash loan attacks until end time"""
        attack_count = 0
        
        while time.time() < end_time:
            # Simulate flash loan attack
            start_time = time.time()
            await self._simulate_flash_loan_attack()
            response_time = time.time() - start_time
            
            self.throughput_metrics["response_times"].append(response_time)
            self.throughput_metrics["system_load"].append(psutil.cpu_percent())
            
            attack_count += 1
            
            # Variable delay between attacks
            await asyncio.sleep(random.uniform(0.5, 2.0))
        
        return attack_count
    
    async def _simulate_oracle_attacks(self, end_time: float, task_id: int) -> int:
        """Simulate oracle attacks until end time"""
        attack_count = 0
        
        while time.time() < end_time:
            # Simulate oracle attack
            start_time = time.time()
            await self._simulate_oracle_attack()
            response_time = time.time() - start_time
            
            self.throughput_metrics["response_times"].append(response_time)
            self.throughput_metrics["system_load"].append(psutil.cpu_percent())
            
            attack_count += 1
            
            # Variable delay between attacks
            await asyncio.sleep(random.uniform(1.0, 5.0))
        
        return attack_count
    
    async def _simulate_mev_attack(self) -> None:
        """Simulate a single MEV attack"""
        # Simulate attack detection
        await asyncio.sleep(random.uniform(0.001, 0.01))
        
        # Simulate attack execution
        await asyncio.sleep(random.uniform(0.01, 0.1))
        
        # Simulate response
        await asyncio.sleep(random.uniform(0.001, 0.01))
    
    async def _simulate_flash_loan_attack(self) -> None:
        """Simulate a single flash loan attack"""
        # Simulate flash loan detection
        await asyncio.sleep(random.uniform(0.005, 0.02))
        
        # Simulate attack execution
        await asyncio.sleep(random.uniform(0.05, 0.2))
        
        # Simulate response
        await asyncio.sleep(random.uniform(0.001, 0.01))
    
    async def _simulate_oracle_attack(self) -> None:
        """Simulate a single oracle attack"""
        # Simulate oracle analysis
        await asyncio.sleep(random.uniform(0.01, 0.05))
        
        # Simulate attack execution
        await asyncio.sleep(random.uniform(0.1, 0.5))
        
        # Simulate response
        await asyncio.sleep(random.uniform(0.001, 0.01))
    
    async def run_throughput_tests(self, duration: int = 60, max_concurrent: int = 20) -> Dict:
        """Run all throughput tests"""
        logger.info("Starting throughput test suite")
        
        results = {
            "test_suite": "throughput_tests",
            "start_time": datetime.now().isoformat(),
            "duration": duration,
            "max_concurrent": max_concurrent,
            "tests": []
        }
        
        # Test MEV throughput
        mev_result = await self.test_mev_throughput(duration, 1)
        results["tests"].append(mev_result)
        
        # Test flash loan throughput
        flash_loan_result = await self.test_flash_loan_throughput(duration, 1)
        results["tests"].append(flash_loan_result)
        
        # Test oracle throughput
        oracle_result = await self.test_oracle_throughput(duration, 1)
        results["tests"].append(oracle_result)
        
        # Test mixed throughput
        mixed_result = await self.test_mixed_throughput(duration, 5)
        results["tests"].append(mixed_result)
        
        # Test scalability
        scalability_result = await self.test_scalability(max_concurrent, duration // 2)
        results["tests"].append(scalability_result)
        
        # Calculate overall summary
        results["summary"] = self._calculate_throughput_summary(results["tests"])
        results["end_time"] = datetime.now().isoformat()
        
        # Save results
        self._save_results(results)
        
        logger.info("Throughput test suite completed")
        return results
    
    def _calculate_throughput_summary(self, tests: List[Dict]) -> Dict:
        """Calculate overall throughput summary"""
        # Get throughput results (excluding scalability test)
        throughput_tests = [t for t in tests if t["test_type"] != "scalability"]
        
        if not throughput_tests:
            return {"error": "No throughput data available"}
        
        total_attacks = sum(t["total_attacks"] for t in throughput_tests)
        avg_throughput = statistics.mean([t["attacks_per_second"] for t in throughput_tests])
        max_throughput = max(t["attacks_per_second"] for t in throughput_tests)
        avg_response_time = statistics.mean([t["avg_response_time"] for t in throughput_tests])
        avg_system_load = statistics.mean([t["system_load"] for t in throughput_tests])
        
        # Get scalability results
        scalability_test = next((t for t in tests if t["test_type"] == "scalability"), None)
        scalability_metrics = {}
        if scalability_test:
            scalability_metrics = {
                "max_throughput": scalability_test["max_throughput"],
                "optimal_concurrent": scalability_test["optimal_concurrent"]
            }
        
        return {
            "total_attacks": total_attacks,
            "avg_throughput": avg_throughput,
            "max_throughput": max_throughput,
            "avg_response_time": avg_response_time,
            "avg_system_load": avg_system_load,
            "throughput_grade": self._calculate_throughput_grade(avg_throughput),
            **scalability_metrics
        }
    
    def _calculate_throughput_grade(self, throughput: float) -> str:
        """Calculate throughput grade based on attacks per second"""
        if throughput > 100:
            return "A+"
        elif throughput > 50:
            return "A"
        elif throughput > 20:
            return "B"
        elif throughput > 10:
            return "C"
        elif throughput > 5:
            return "D"
        else:
            return "F"
    
    def _save_results(self, results: Dict) -> None:
        """Save test results to file"""
        results_file = f"logs/throughput_test_results_{int(time.time())}.json"
        with open(results_file, 'w') as f:
            json.dump(results, f, indent=2)
        
        logger.info(f"Throughput test results saved to {results_file}")
    
    def generate_report(self, results: Dict) -> str:
        """Generate throughput test report"""
        report = f"""
# Throughput Test Report
Generated: {results['end_time']}

## Summary
- Total Attacks: {results['summary']['total_attacks']}
- Average Throughput: {results['summary']['avg_throughput']:.2f} attacks/second
- Maximum Throughput: {results['summary']['max_throughput']:.2f} attacks/second
- Average Response Time: {results['summary']['avg_response_time']:.3f} seconds
- Average System Load: {results['summary']['avg_system_load']:.1f}%
- Throughput Grade: {results['summary']['throughput_grade']}

## Test Results
"""
        
        for test in results['tests']:
            if test['test_type'] == 'scalability':
                report += f"""
### {test['test_type'].replace('_', ' ').title()}
- Maximum Concurrent: {test['max_concurrent']}
- Maximum Throughput: {test['max_throughput']:.2f} attacks/second
- Optimal Concurrent: {test['optimal_concurrent']}
- Scalability Results: {len(test['scalability_results'])} test points
"""
            else:
                report += f"""
### {test['test_type'].replace('_', ' ').title()}
- Duration: {test['duration']} seconds
- Concurrent: {test['concurrent']}
- Total Attacks: {test['total_attacks']}
- Attacks/Second: {test['attacks_per_second']:.2f}
- Average Response Time: {test['avg_response_time']:.3f} seconds
- System Load: {test['system_load']:.1f}%
"""
        
        return report


async def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description="Throughput Test for Attack Simulation")
    parser.add_argument("--duration", type=int, default=60, help="Test duration in seconds")
    parser.add_argument("--concurrent", type=int, default=20, help="Maximum concurrent simulations")
    parser.add_argument("--output", help="Output file for results")
    parser.add_argument("--report", help="Generate HTML report")
    
    args = parser.parse_args()
    
    # Configure logging
    logger.remove()
    logger.add(sys.stderr, level="INFO")
    
    if args.output:
        logger.add(args.output, level="INFO")
    
    # Create throughput test
    test = ThroughputTest()
    
    # Run tests
    results = await test.run_throughput_tests(args.duration, args.concurrent)
    
    # Generate report
    report = test.generate_report(results)
    print(report)
    
    # Save report if requested
    if args.report:
        with open(args.report, 'w') as f:
            f.write(report)
        logger.info(f"Report saved to {args.report}")


if __name__ == "__main__":
    import json
    asyncio.run(main())
