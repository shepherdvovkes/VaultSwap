package com.ultrana.governance;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.client.discovery.EnableDiscoveryClient;
import org.springframework.kafka.annotation.EnableKafka;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.annotation.EnableScheduling;

/**
 * Ultrana DEX Governance Service
 * 
 * Governance functionality including:
 * - Proposal creation and management
 * - Voting mechanisms and validation
 * - DAO operations and token holder rights
 * - Governance analytics and reporting
 * - Multi-signature wallet integration
 * - Proposal execution and implementation
 */
@SpringBootApplication
@EnableDiscoveryClient
@EnableKafka
@EnableAsync
@EnableScheduling
public class GovernanceServiceApplication {

    public static void main(String[] args) {
        SpringApplication.run(GovernanceServiceApplication.class, args);
    }
}
