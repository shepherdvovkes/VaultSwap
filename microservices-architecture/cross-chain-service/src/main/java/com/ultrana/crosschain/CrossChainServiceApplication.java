package com.ultrana.crosschain;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.client.discovery.EnableDiscoveryClient;
import org.springframework.kafka.annotation.EnableKafka;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.annotation.EnableScheduling;

/**
 * Ultrana DEX Cross-Chain Service
 * 
 * Cross-chain functionality including:
 * - Multi-chain bridge operations
 * - Asset transfers between chains
 * - Chain detection and switching
 * - Gas optimization across chains
 * - Bridge security validation
 * - Cross-chain transaction monitoring
 * - Multi-signature bridge operations
 */
@SpringBootApplication
@EnableDiscoveryClient
@EnableKafka
@EnableAsync
@EnableScheduling
public class CrossChainServiceApplication {

    public static void main(String[] args) {
        SpringApplication.run(CrossChainServiceApplication.class, args);
    }
}
