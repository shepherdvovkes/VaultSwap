package com.ultrana.security;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.client.discovery.EnableDiscoveryClient;
import org.springframework.kafka.annotation.EnableKafka;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.annotation.EnableScheduling;

/**
 * Ultrana DEX Security Service
 * 
 * Security functionality including:
 * - MEV attack detection and prevention
 * - Flash loan attack protection
 * - Economic attack detection
 * - Oracle manipulation detection
 * - Cross-chain security validation
 * - Real-time security monitoring
 * - Security incident response
 */
@SpringBootApplication
@EnableDiscoveryClient
@EnableKafka
@EnableAsync
@EnableScheduling
public class SecurityServiceApplication {

    public static void main(String[] args) {
        SpringApplication.run(SecurityServiceApplication.class, args);
    }
}
