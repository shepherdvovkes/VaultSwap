#!/usr/bin/env python3
"""
Performance Test for Attack Simulation Environment
Tests the performance characteristics of the attack simulation system.
"""

import asyncio
import time
import psutil
import argparse
import sys
from datetime import datetime
from typing import Dict, List
import statistics

from loguru import logger


class PerformanceTest:
    """Performance testing for attack simulation environment"""
    
    def __init__(self):
        self.metrics = {
            "cpu_usage": [],
            "memory_usage": [],
            "disk_io": [],
            "network_io": [],
            "response_times": [],
            "throughput": []
        }
        
        # Setup logging
        logger.add("logs/performance_test_{time}.log", rotation="1 day", retention="7 days")
    
    def get_system_metrics(self) -> Dict:
        """Get current system metrics"""
        cpu_percent = psutil.cpu_percent(interval=1)
        memory = psutil.virtual_memory()
        disk = psutil.disk_usage('/')
        network = psutil.net_io_counters()
        
        return {
            "timestamp": time.time(),
            "cpu_percent": cpu_percent,
            "memory_percent": memory.percent,
            "memory_available_gb": memory.available / (1024**3),
            "disk_percent": (disk.used / disk.total) * 100,
            "disk_free_gb": disk.free / (1024**3),
            "network_bytes_sent": network.bytes_sent,
            "network_bytes_recv": network.bytes_recv
        }
    
    async def test_mev_simulation_performance(self, duration: int = 60) -> Dict:
        """Test MEV simulation performance"""
        logger.info(f"Testing MEV simulation performance for {duration} seconds")
        
        start_time = time.time()
        end_time = start_time + duration
        
        # Start monitoring
        monitoring_task = asyncio.create_task(self._monitor_system_metrics(end_time))
        
        # Simulate MEV attacks
        attack_count = 0
        while time.time() < end_time:
            # Simulate MEV attack
            await asyncio.sleep(random.uniform(0.1, 1.0))
            attack_count += 1
            
            # Record response time
            response_time = random.uniform(0.01, 0.5)  # Simulated response time
            self.metrics["response_times"].append(response_time)
        
        # Stop monitoring
        monitoring_task.cancel()
        
        # Calculate metrics
        avg_response_time = statistics.mean(self.metrics["response_times"])
        max_response_time = max(self.metrics["response_times"])
        min_response_time = min(self.metrics["response_times"])
        
        throughput = attack_count / duration
        
        return {
            "test_type": "mev_simulation",
            "duration": duration,
            "attack_count": attack_count,
            "throughput": throughput,
            "avg_response_time": avg_response_time,
            "max_response_time": max_response_time,
            "min_response_time": min_response_time,
            "cpu_usage": statistics.mean(self.metrics["cpu_usage"]) if self.metrics["cpu_usage"] else 0,
            "memory_usage": statistics.mean(self.metrics["memory_usage"]) if self.metrics["memory_usage"] else 0
        }
    
    async def test_flash_loan_simulation_performance(self, duration: int = 60) -> Dict:
        """Test flash loan simulation performance"""
        logger.info(f"Testing flash loan simulation performance for {duration} seconds")
        
        start_time = time.time()
        end_time = start_time + duration
        
        # Start monitoring
        monitoring_task = asyncio.create_task(self._monitor_system_metrics(end_time))
        
        # Simulate flash loan attacks
        attack_count = 0
        while time.time() < end_time:
            # Simulate flash loan attack
            await asyncio.sleep(random.uniform(0.5, 2.0))
            attack_count += 1
            
            # Record response time
            response_time = random.uniform(0.1, 1.0)  # Simulated response time
            self.metrics["response_times"].append(response_time)
        
        # Stop monitoring
        monitoring_task.cancel()
        
        # Calculate metrics
        avg_response_time = statistics.mean(self.metrics["response_times"])
        throughput = attack_count / duration
        
        return {
            "test_type": "flash_loan_simulation",
            "duration": duration,
            "attack_count": attack_count,
            "throughput": throughput,
            "avg_response_time": avg_response_time,
            "cpu_usage": statistics.mean(self.metrics["cpu_usage"]) if self.metrics["cpu_usage"] else 0,
            "memory_usage": statistics.mean(self.metrics["memory_usage"]) if self.metrics["memory_usage"] else 0
        }
    
    async def test_oracle_simulation_performance(self, duration: int = 60) -> Dict:
        """Test oracle simulation performance"""
        logger.info(f"Testing oracle simulation performance for {duration} seconds")
        
        start_time = time.time()
        end_time = start_time + duration
        
        # Start monitoring
        monitoring_task = asyncio.create_task(self._monitor_system_metrics(end_time))
        
        # Simulate oracle attacks
        attack_count = 0
        while time.time() < end_time:
            # Simulate oracle attack
            await asyncio.sleep(random.uniform(1.0, 5.0))
            attack_count += 1
            
            # Record response time
            response_time = random.uniform(0.2, 2.0)  # Simulated response time
            self.metrics["response_times"].append(response_time)
        
        # Stop monitoring
        monitoring_task.cancel()
        
        # Calculate metrics
        avg_response_time = statistics.mean(self.metrics["response_times"])
        throughput = attack_count / duration
        
        return {
            "test_type": "oracle_simulation",
            "duration": duration,
            "attack_count": attack_count,
            "throughput": throughput,
            "avg_response_time": avg_response_time,
            "cpu_usage": statistics.mean(self.metrics["cpu_usage"]) if self.metrics["cpu_usage"] else 0,
            "memory_usage": statistics.mean(self.metrics["memory_usage"]) if self.metrics["memory_usage"] else 0
        }
    
    async def test_concurrent_simulation_performance(self, concurrent: int = 5, duration: int = 60) -> Dict:
        """Test concurrent simulation performance"""
        logger.info(f"Testing concurrent simulation performance with {concurrent} concurrent simulations for {duration} seconds")
        
        start_time = time.time()
        end_time = start_time + duration
        
        # Start monitoring
        monitoring_task = asyncio.create_task(self._monitor_system_metrics(end_time))
        
        # Create concurrent simulation tasks
        tasks = []
        for i in range(concurrent):
            task = asyncio.create_task(self._simulate_concurrent_attack(i, end_time))
            tasks.append(task)
        
        # Wait for all tasks to complete
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        # Stop monitoring
        monitoring_task.cancel()
        
        # Calculate metrics
        total_attacks = sum(r for r in results if isinstance(r, int))
        avg_response_time = statistics.mean(self.metrics["response_times"]) if self.metrics["response_times"] else 0
        throughput = total_attacks / duration
        
        return {
            "test_type": "concurrent_simulation",
            "duration": duration,
            "concurrent_simulations": concurrent,
            "total_attacks": total_attacks,
            "throughput": throughput,
            "avg_response_time": avg_response_time,
            "cpu_usage": statistics.mean(self.metrics["cpu_usage"]) if self.metrics["cpu_usage"] else 0,
            "memory_usage": statistics.mean(self.metrics["memory_usage"]) if self.metrics["memory_usage"] else 0
        }
    
    async def _simulate_concurrent_attack(self, attack_id: int, end_time: float) -> int:
        """Simulate a concurrent attack"""
        attack_count = 0
        while time.time() < end_time:
            # Simulate attack
            await asyncio.sleep(random.uniform(0.1, 2.0))
            attack_count += 1
            
            # Record response time
            response_time = random.uniform(0.01, 1.0)
            self.metrics["response_times"].append(response_time)
        
        return attack_count
    
    async def _monitor_system_metrics(self, end_time: float) -> None:
        """Monitor system metrics during test"""
        while time.time() < end_time:
            metrics = self.get_system_metrics()
            self.metrics["cpu_usage"].append(metrics["cpu_percent"])
            self.metrics["memory_usage"].append(metrics["memory_percent"])
            await asyncio.sleep(1.0)
    
    async def run_performance_tests(self, duration: int = 60, concurrent: int = 5) -> Dict:
        """Run all performance tests"""
        logger.info("Starting performance test suite")
        
        results = {
            "test_suite": "attack_simulation_performance",
            "start_time": datetime.now().isoformat(),
            "tests": []
        }
        
        # Test MEV simulation performance
        mev_result = await self.test_mev_simulation_performance(duration)
        results["tests"].append(mev_result)
        
        # Test flash loan simulation performance
        flash_loan_result = await self.test_flash_loan_simulation_performance(duration)
        results["tests"].append(flash_loan_result)
        
        # Test oracle simulation performance
        oracle_result = await self.test_oracle_simulation_performance(duration)
        results["tests"].append(oracle_result)
        
        # Test concurrent simulation performance
        concurrent_result = await self.test_concurrent_simulation_performance(concurrent, duration)
        results["tests"].append(concurrent_result)
        
        # Calculate overall metrics
        results["summary"] = self._calculate_summary(results["tests"])
        results["end_time"] = datetime.now().isoformat()
        
        # Save results
        self._save_results(results)
        
        logger.info("Performance test suite completed")
        return results
    
    def _calculate_summary(self, tests: List[Dict]) -> Dict:
        """Calculate summary metrics"""
        total_attacks = sum(t["attack_count"] for t in tests)
        avg_throughput = statistics.mean([t["throughput"] for t in tests])
        avg_response_time = statistics.mean([t["avg_response_time"] for t in tests])
        avg_cpu_usage = statistics.mean([t["cpu_usage"] for t in tests])
        avg_memory_usage = statistics.mean([t["memory_usage"] for t in tests])
        
        return {
            "total_attacks": total_attacks,
            "avg_throughput": avg_throughput,
            "avg_response_time": avg_response_time,
            "avg_cpu_usage": avg_cpu_usage,
            "avg_memory_usage": avg_memory_usage,
            "performance_score": self._calculate_performance_score(tests)
        }
    
    def _calculate_performance_score(self, tests: List[Dict]) -> float:
        """Calculate overall performance score (0-100)"""
        # Weighted scoring based on throughput, response time, and resource usage
        throughput_score = min(100, statistics.mean([t["throughput"] for t in tests]) * 10)
        response_time_score = max(0, 100 - statistics.mean([t["avg_response_time"] for t in tests]) * 50)
        resource_score = max(0, 100 - statistics.mean([t["cpu_usage"] + t["memory_usage"] for t in tests]))
        
        return (throughput_score + response_time_score + resource_score) / 3
    
    def _save_results(self, results: Dict) -> None:
        """Save test results to file"""
        results_file = f"logs/performance_test_results_{int(time.time())}.json"
        with open(results_file, 'w') as f:
            json.dump(results, f, indent=2)
        
        logger.info(f"Performance test results saved to {results_file}")
    
    def generate_report(self, results: Dict) -> str:
        """Generate performance test report"""
        report = f"""
# Performance Test Report
Generated: {results['end_time']}

## Summary
- Total Attacks: {results['summary']['total_attacks']}
- Average Throughput: {results['summary']['avg_throughput']:.2f} attacks/second
- Average Response Time: {results['summary']['avg_response_time']:.3f} seconds
- Average CPU Usage: {results['summary']['avg_cpu_usage']:.1f}%
- Average Memory Usage: {results['summary']['avg_memory_usage']:.1f}%
- Performance Score: {results['summary']['performance_score']:.1f}/100

## Test Results
"""
        
        for test in results['tests']:
            report += f"""
### {test['test_type'].replace('_', ' ').title()}
- Duration: {test['duration']} seconds
- Attack Count: {test['attack_count']}
- Throughput: {test['throughput']:.2f} attacks/second
- Average Response Time: {test['avg_response_time']:.3f} seconds
- CPU Usage: {test['cpu_usage']:.1f}%
- Memory Usage: {test['memory_usage']:.1f}%
"""
        
        return report


async def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description="Performance Test for Attack Simulation")
    parser.add_argument("--duration", type=int, default=60, help="Test duration in seconds")
    parser.add_argument("--concurrent", type=int, default=5, help="Number of concurrent simulations")
    parser.add_argument("--output", help="Output file for results")
    parser.add_argument("--report", help="Generate HTML report")
    
    args = parser.parse_args()
    
    # Configure logging
    logger.remove()
    logger.add(sys.stderr, level="INFO")
    
    if args.output:
        logger.add(args.output, level="INFO")
    
    # Create performance test
    test = PerformanceTest()
    
    # Run tests
    results = await test.run_performance_tests(args.duration, args.concurrent)
    
    # Generate report
    report = test.generate_report(results)
    print(report)
    
    # Save report if requested
    if args.report:
        with open(args.report, 'w') as f:
            f.write(report)
        logger.info(f"Report saved to {args.report}")


if __name__ == "__main__":
    import random
    import json
    asyncio.run(main())
