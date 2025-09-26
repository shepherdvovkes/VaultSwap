package com.ultrana.liquidity;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.client.discovery.EnableDiscoveryClient;
import org.springframework.kafka.annotation.EnableKafka;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.annotation.EnableScheduling;

/**
 * Ultrana DEX Liquidity Service
 * 
 * Liquidity management functionality including:
 * - Liquidity pool creation and management
 * - Add/remove liquidity operations
 * - Staking rewards calculation and distribution
 * - Yield farming mechanisms
 * - Pool analytics and metrics
 * - Multi-chain liquidity support
 */
@SpringBootApplication
@EnableDiscoveryClient
@EnableKafka
@EnableAsync
@EnableScheduling
public class LiquidityServiceApplication {

    public static void main(String[] args) {
        SpringApplication.run(LiquidityServiceApplication.class, args);
    }
}
