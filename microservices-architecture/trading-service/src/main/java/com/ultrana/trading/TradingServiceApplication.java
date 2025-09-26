package com.ultrana.trading;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.client.discovery.EnableDiscoveryClient;
import org.springframework.kafka.annotation.EnableKafka;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.annotation.EnableScheduling;

/**
 * Ultrana DEX Trading Service
 * 
 * Core trading functionality including:
 * - Order management (limit, market, stop-loss orders)
 * - AMM (Automated Market Maker) integration
 * - Trade execution with slippage protection
 * - Real-time order matching
 * - MEV protection integration
 * - Cross-chain trading support
 */
@SpringBootApplication
@EnableDiscoveryClient
@EnableKafka
@EnableAsync
@EnableScheduling
public class TradingServiceApplication {

    public static void main(String[] args) {
        SpringApplication.run(TradingServiceApplication.class, args);
    }
}

