package com.ultrana.gateway;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.client.discovery.EnableDiscoveryClient;

/**
 * Ultrana DEX API Gateway Application
 * 
 * This is the main entry point for the API Gateway service that provides:
 * - Request routing to microservices
 * - Load balancing
 * - Circuit breaker patterns
 * - Authentication and authorization
 * - Rate limiting
 * - Monitoring and metrics
 */
@SpringBootApplication
@EnableDiscoveryClient
public class ApiGatewayApplication {

    public static void main(String[] args) {
        SpringApplication.run(ApiGatewayApplication.class, args);
    }
}
