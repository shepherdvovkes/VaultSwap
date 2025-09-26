#!/usr/bin/env python3
"""
Security Test Runner
Automated security testing for DEX attack simulation environment.
"""

import asyncio
import json
import subprocess
import time
import argparse
import sys
from datetime import datetime, timedelta
from typing import Dict, List, Optional
from dataclasses import dataclass
from enum import Enum
import requests
import yaml

from loguru import logger


class TestStatus(Enum):
    PENDING = "pending"
    RUNNING = "running"
    PASSED = "passed"
    FAILED = "failed"
    SKIPPED = "skipped"


class TestType(Enum):
    MEV_PROTECTION = "mev_protection"
    FLASH_LOAN_PROTECTION = "flash_loan_protection"
    ORACLE_SECURITY = "oracle_security"
    SYSTEM_HEALTH = "system_health"
    MONITORING = "monitoring"
    PERFORMANCE = "performance"


@dataclass
class SecurityTest:
    """Represents a security test"""
    id: str
    name: str
    test_type: TestType
    description: str
    command: str
    expected_result: str
    timeout: int = 300  # 5 minutes default
    retries: int = 3
    status: TestStatus = TestStatus.PENDING
    result: Optional[Dict] = None
    error_message: Optional[str] = None


class SecurityTestRunner:
    """Main security test runner"""
    
    def __init__(self, config_path: str):
        self.config = self._load_config(config_path)
        self.tests: List[SecurityTest] = []
        self.results: Dict[str, Dict] = {}
        
        # Setup logging
        logger.add("logs/security_test_runner_{time}.log", rotation="1 day", retention="7 days")
        
        # Initialize tests
        self._initialize_tests()
    
    def _load_config(self, config_path: str) -> Dict:
        """Load configuration from JSON file"""
        try:
            with open(config_path, 'r') as f:
                return json.load(f)
        except Exception as e:
            logger.error(f"Failed to load config: {e}")
            return {}
    
    def _initialize_tests(self) -> None:
        """Initialize security tests"""
        # MEV Protection Tests
        self.tests.extend([
            SecurityTest(
                id="mev_001",
                name="MEV Attack Detection",
                test_type=TestType.MEV_PROTECTION,
                description="Test MEV attack detection capabilities",
                command="python3 /opt/attack-simulations/mev-attacks/simulate_sandwich_attack.py --config /opt/attack-simulations/mev-attacks/config.json --duration 5",
                expected_result="MEV attack should be detected within 5 seconds"
            ),
            SecurityTest(
                id="mev_002",
                name="MEV Protection Effectiveness",
                test_type=TestType.MEV_PROTECTION,
                description="Test MEV protection mechanism effectiveness",
                command="python3 /opt/attack-simulations/mev-attacks/mev_simulator.py --config /opt/attack-simulations/mev-attacks/config.json --monitoring",
                expected_result="MEV protection should prevent 90% of attacks"
            ),
            SecurityTest(
                id="mev_003",
                name="MEV Bot Detection",
                test_type=TestType.MEV_PROTECTION,
                description="Test MEV bot detection algorithms",
                command="python3 /opt/attack-simulations/mev-attacks/simulate_front_running_attack.py --config /opt/attack-simulations/mev-attacks/config.json",
                expected_result="MEV bots should be detected and blocked"
            )
        ])
        
        # Flash Loan Protection Tests
        self.tests.extend([
            SecurityTest(
                id="flash_001",
                name="Flash Loan Attack Detection",
                test_type=TestType.FLASH_LOAN_PROTECTION,
                description="Test flash loan attack detection",
                command="python3 /opt/attack-simulations/flash-loan-attacks/flash_loan_simulator.py --config /opt/attack-simulations/flash-loan-attacks/config.json --monitoring",
                expected_result="Flash loan attacks should be detected within 10 seconds"
            ),
            SecurityTest(
                id="flash_002",
                name="Flash Loan Protection Effectiveness",
                test_type=TestType.FLASH_LOAN_PROTECTION,
                description="Test flash loan protection mechanism",
                command="python3 /opt/attack-simulations/flash-loan-attacks/simulate_price_manipulation_attack.py --config /opt/attack-simulations/flash-loan-attacks/config.json",
                expected_result="Flash loan protection should prevent 95% of attacks"
            ),
            SecurityTest(
                id="flash_003",
                name="Large Flash Loan Detection",
                test_type=TestType.FLASH_LOAN_PROTECTION,
                description="Test detection of large flash loan amounts",
                command="python3 /opt/attack-simulations/flash-loan-attacks/simulate_liquidity_drain_attack.py --config /opt/attack-simulations/flash-loan-attacks/config.json",
                expected_result="Large flash loans should be flagged and blocked"
            )
        ])
        
        # Oracle Security Tests
        self.tests.extend([
            SecurityTest(
                id="oracle_001",
                name="Oracle Manipulation Detection",
                test_type=TestType.ORACLE_SECURITY,
                description="Test oracle manipulation detection",
                command="python3 /opt/attack-simulations/oracle-manipulation/oracle_simulator.py --config /opt/attack-simulations/oracle-manipulation/config.json --monitoring",
                expected_result="Oracle manipulation should be detected within 15 seconds"
            ),
            SecurityTest(
                id="oracle_002",
                name="Oracle Consensus Validation",
                test_type=TestType.ORACLE_SECURITY,
                description="Test oracle consensus mechanism",
                command="python3 /opt/attack-simulations/oracle-manipulation/simulate_price_flash_loan_attack.py --config /opt/attack-simulations/oracle-manipulation/config.json",
                expected_result="Oracle consensus should maintain >80% agreement"
            ),
            SecurityTest(
                id="oracle_003",
                name="Cross-Chain Oracle Security",
                test_type=TestType.ORACLE_SECURITY,
                description="Test cross-chain oracle security",
                command="python3 /opt/attack-simulations/oracle-manipulation/simulate_cross_chain_manipulation_attack.py --config /opt/attack-simulations/oracle-manipulation/config.json",
                expected_result="Cross-chain oracle attacks should be prevented"
            )
        ])
        
        # System Health Tests
        self.tests.extend([
            SecurityTest(
                id="system_001",
                name="System Resource Usage",
                test_type=TestType.SYSTEM_HEALTH,
                description="Test system resource usage during attacks",
                command="python3 -c \"import psutil; print(f'CPU: {psutil.cpu_percent()}%, Memory: {psutil.virtual_memory().percent}%')\"",
                expected_result="System resources should remain below 80%"
            ),
            SecurityTest(
                id="system_002",
                name="Service Availability",
                test_type=TestType.SYSTEM_HEALTH,
                description="Test service availability during attacks",
                command="curl -f http://localhost:9090/api/v1/query?query=up",
                expected_result="All services should remain available"
            ),
            SecurityTest(
                id="system_003",
                name="Database Performance",
                test_type=TestType.SYSTEM_HEALTH,
                description="Test database performance under load",
                command="curl -f http://localhost:9200/_cluster/health",
                expected_result="Database should maintain good health status"
            )
        ])
        
        # Monitoring Tests
        self.tests.extend([
            SecurityTest(
                id="monitoring_001",
                name="Prometheus Metrics Collection",
                test_type=TestType.MONITORING,
                description="Test Prometheus metrics collection",
                command="curl -f http://localhost:9090/api/v1/query?query=mev_attacks_total",
                expected_result="Prometheus should collect attack metrics"
            ),
            SecurityTest(
                id="monitoring_002",
                name="Grafana Dashboard Access",
                test_type=TestType.MONITORING,
                description="Test Grafana dashboard accessibility",
                command="curl -f http://localhost:3000/api/health",
                expected_result="Grafana should be accessible and healthy"
            ),
            SecurityTest(
                id="monitoring_003",
                name="Alert Generation",
                test_type=TestType.MONITORING,
                description="Test alert generation for security events",
                command="curl -f http://localhost:9093/api/v1/alerts",
                expected_result="Alerts should be generated for security events"
            )
        ])
        
        # Performance Tests
        self.tests.extend([
            SecurityTest(
                id="performance_001",
                name="Attack Simulation Performance",
                test_type=TestType.PERFORMANCE,
                description="Test attack simulation performance",
                command="python3 /opt/attack-simulations/scripts/performance_test.py --duration 60",
                expected_result="Attack simulations should complete within time limits"
            ),
            SecurityTest(
                id="performance_002",
                name="Detection Response Time",
                test_type=TestType.PERFORMANCE,
                description="Test attack detection response time",
                command="python3 /opt/attack-simulations/scripts/response_time_test.py",
                expected_result="Attack detection should respond within 5 seconds"
            ),
            SecurityTest(
                id="performance_003",
                name="System Throughput",
                test_type=TestType.PERFORMANCE,
                description="Test system throughput under attack load",
                command="python3 /opt/attack-simulations/scripts/throughput_test.py --concurrent 10",
                expected_result="System should handle concurrent attacks"
            )
        ])
        
        logger.info(f"Initialized {len(self.tests)} security tests")
    
    async def run_test(self, test: SecurityTest) -> Dict:
        """Run a single security test"""
        logger.info(f"Running test: {test.name} ({test.id})")
        test.status = TestStatus.RUNNING
        
        start_time = time.time()
        
        for attempt in range(test.retries):
            try:
                # Run the test command
                result = subprocess.run(
                    test.command,
                    shell=True,
                    capture_output=True,
                    text=True,
                    timeout=test.timeout
                )
                
                # Analyze result
                success = result.returncode == 0
                execution_time = time.time() - start_time
                
                test_result = {
                    "test_id": test.id,
                    "test_name": test.name,
                    "test_type": test.test_type.value,
                    "status": "passed" if success else "failed",
                    "execution_time": execution_time,
                    "attempt": attempt + 1,
                    "stdout": result.stdout,
                    "stderr": result.stderr,
                    "return_code": result.returncode,
                    "timestamp": datetime.now().isoformat()
                }
                
                if success:
                    test.status = TestStatus.PASSED
                    logger.info(f"Test {test.name} PASSED (attempt {attempt + 1})")
                else:
                    test.status = TestStatus.FAILED
                    test.error_message = result.stderr
                    logger.warning(f"Test {test.name} FAILED (attempt {attempt + 1}): {result.stderr}")
                
                test.result = test_result
                return test_result
                
            except subprocess.TimeoutExpired:
                logger.error(f"Test {test.name} TIMEOUT (attempt {attempt + 1})")
                if attempt == test.retries - 1:
                    test.status = TestStatus.FAILED
                    test.error_message = "Test timeout"
                    return {
                        "test_id": test.id,
                        "test_name": test.name,
                        "status": "failed",
                        "error": "Test timeout",
                        "timestamp": datetime.now().isoformat()
                    }
            except Exception as e:
                logger.error(f"Test {test.name} ERROR (attempt {attempt + 1}): {e}")
                if attempt == test.retries - 1:
                    test.status = TestStatus.FAILED
                    test.error_message = str(e)
                    return {
                        "test_id": test.id,
                        "test_name": test.name,
                        "status": "failed",
                        "error": str(e),
                        "timestamp": datetime.now().isoformat()
                    }
        
        return {
            "test_id": test.id,
            "test_name": test.name,
            "status": "failed",
            "error": "All retry attempts failed",
            "timestamp": datetime.now().isoformat()
        }
    
    async def run_all_tests(self, test_types: Optional[List[TestType]] = None) -> Dict:
        """Run all security tests"""
        logger.info("Starting security test suite")
        
        start_time = time.time()
        results = {
            "total_tests": 0,
            "passed_tests": 0,
            "failed_tests": 0,
            "skipped_tests": 0,
            "test_results": [],
            "summary": {},
            "start_time": datetime.now().isoformat(),
            "end_time": None,
            "duration": 0
        }
        
        # Filter tests by type if specified
        tests_to_run = self.tests
        if test_types:
            tests_to_run = [t for t in self.tests if t.test_type in test_types]
            logger.info(f"Running {len(tests_to_run)} tests of types: {[t.value for t in test_types]}")
        else:
            logger.info(f"Running all {len(tests_to_run)} tests")
        
        results["total_tests"] = len(tests_to_run)
        
        # Run tests
        for test in tests_to_run:
            test_result = await self.run_test(test)
            results["test_results"].append(test_result)
            
            if test_result["status"] == "passed":
                results["passed_tests"] += 1
            elif test_result["status"] == "failed":
                results["failed_tests"] += 1
            else:
                results["skipped_tests"] += 1
        
        # Calculate summary
        end_time = time.time()
        results["end_time"] = datetime.now().isoformat()
        results["duration"] = end_time - start_time
        
        # Generate summary by test type
        for test_type in TestType:
            type_tests = [t for t in tests_to_run if t.test_type == test_type]
            type_passed = sum(1 for t in type_tests if t.status == TestStatus.PASSED)
            type_failed = sum(1 for t in type_tests if t.status == TestStatus.FAILED)
            
            results["summary"][test_type.value] = {
                "total": len(type_tests),
                "passed": type_passed,
                "failed": type_failed,
                "success_rate": type_passed / len(type_tests) if type_tests else 0
            }
        
        # Save results
        self._save_results(results)
        
        logger.info(f"Security test suite completed: {results['passed_tests']}/{results['total_tests']} passed")
        return results
    
    def _save_results(self, results: Dict) -> None:
        """Save test results to file"""
        results_file = f"logs/security_test_results_{int(time.time())}.json"
        with open(results_file, 'w') as f:
            json.dump(results, f, indent=2)
        
        logger.info(f"Test results saved to {results_file}")
    
    def generate_report(self, results: Dict) -> str:
        """Generate security test report"""
        report = f"""
# Security Test Report
Generated: {results['end_time']}
Duration: {results['duration']:.2f} seconds

## Summary
- Total Tests: {results['total_tests']}
- Passed: {results['passed_tests']}
- Failed: {results['failed_tests']}
- Success Rate: {results['passed_tests']/results['total_tests']:.2%}

## Test Results by Category
"""
        
        for test_type, summary in results['summary'].items():
            report += f"""
### {test_type.replace('_', ' ').title()}
- Total: {summary['total']}
- Passed: {summary['passed']}
- Failed: {summary['failed']}
- Success Rate: {summary['success_rate']:.2%}
"""
        
        report += "\n## Detailed Results\n"
        
        for result in results['test_results']:
            status_emoji = "✅" if result['status'] == 'passed' else "❌"
            report += f"""
### {status_emoji} {result['test_name']} ({result['test_id']})
- Status: {result['status'].upper()}
- Type: {result['test_type']}
- Execution Time: {result.get('execution_time', 'N/A')}s
"""
            
            if result['status'] == 'failed' and 'error' in result:
                report += f"- Error: {result['error']}\n"
        
        return report


async def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description="Security Test Runner")
    parser.add_argument("--config", required=True, help="Path to configuration file")
    parser.add_argument("--test-types", nargs="+", help="Specific test types to run")
    parser.add_argument("--output", help="Output file for results")
    parser.add_argument("--report", help="Generate HTML report")
    
    args = parser.parse_args()
    
    # Configure logging
    logger.remove()
    logger.add(sys.stderr, level="INFO")
    
    if args.output:
        logger.add(args.output, level="INFO")
    
    # Create test runner
    runner = SecurityTestRunner(args.config)
    
    # Parse test types if specified
    test_types = None
    if args.test_types:
        test_types = [TestType(t) for t in args.test_types if t in [t.value for t in TestType]]
    
    # Run tests
    results = await runner.run_all_tests(test_types)
    
    # Generate report
    report = runner.generate_report(results)
    print(report)
    
    # Save report if requested
    if args.report:
        with open(args.report, 'w') as f:
            f.write(report)
        logger.info(f"Report saved to {args.report}")


if __name__ == "__main__":
    asyncio.run(main())
