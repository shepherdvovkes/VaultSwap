package com.ultrana.messagerelay;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.client.discovery.EnableDiscoveryClient;
import org.springframework.kafka.annotation.EnableKafka;

/**
 * Ultrana DEX Message Relay Application
 * 
 * This service handles:
 * - Event streaming with Apache Kafka
 * - Message routing between microservices
 * - Event sourcing and CQRS patterns
 * - Dead letter queue handling
 * - Message persistence and replay
 */
@SpringBootApplication
@EnableDiscoveryClient
@EnableKafka
public class MessageRelayApplication {

    public static void main(String[] args) {
        SpringApplication.run(MessageRelayApplication.class, args);
    }
}
