package com.ultrana.messagerelay.config;

import org.apache.kafka.clients.admin.AdminClientConfig;
import org.apache.kafka.clients.admin.NewTopic;
import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.common.serialization.StringDeserializer;
import org.apache.kafka.common.serialization.StringSerializer;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.annotation.EnableKafka;
import org.springframework.kafka.config.ConcurrentKafkaListenerContainerFactory;
import org.springframework.kafka.core.*;
import org.springframework.kafka.listener.ContainerProperties;
import org.springframework.kafka.support.serializer.JsonDeserializer;
import org.springframework.kafka.support.serializer.JsonSerializer;

import java.util.HashMap;
import java.util.Map;

/**
 * Kafka Configuration for Message Relay Service
 * 
 * Configures:
 * - Producer and Consumer factories
 * - Topic creation
 * - Serialization/Deserialization
 * - Error handling and retry policies
 * - Dead letter queue configuration
 */
@Configuration
@EnableKafka
public class KafkaConfig {

    @Value("${spring.kafka.bootstrap-servers}")
    private String bootstrapServers;

    @Value("${spring.kafka.consumer.group-id}")
    private String groupId;

    // Producer Configuration
    @Bean
    public ProducerFactory<String, Object> producerFactory() {
        Map<String, Object> configProps = new HashMap<>();
        configProps.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
        configProps.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class);
        configProps.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, JsonSerializer.class);
        configProps.put(ProducerConfig.ACKS_CONFIG, "all");
        configProps.put(ProducerConfig.RETRIES_CONFIG, 3);
        configProps.put(ProducerConfig.ENABLE_IDEMPOTENCE_CONFIG, true);
        configProps.put(ProducerConfig.MAX_IN_FLIGHT_REQUESTS_PER_CONNECTION, 1);
        configProps.put(ProducerConfig.COMPRESSION_TYPE_CONFIG, "snappy");
        configProps.put(ProducerConfig.BATCH_SIZE_CONFIG, 16384);
        configProps.put(ProducerConfig.LINGER_MS_CONFIG, 5);
        return new DefaultKafkaProducerFactory<>(configProps);
    }

    @Bean
    public KafkaTemplate<String, Object> kafkaTemplate() {
        return new KafkaTemplate<>(producerFactory());
    }

    // Consumer Configuration
    @Bean
    public ConsumerFactory<String, Object> consumerFactory() {
        Map<String, Object> props = new HashMap<>();
        props.put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
        props.put(ConsumerConfig.GROUP_ID_CONFIG, groupId);
        props.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class);
        props.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, JsonDeserializer.class);
        props.put(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, "earliest");
        props.put(ConsumerConfig.ENABLE_AUTO_COMMIT_CONFIG, false);
        props.put(ConsumerConfig.MAX_POLL_RECORDS_CONFIG, 500);
        props.put(ConsumerConfig.SESSION_TIMEOUT_MS_CONFIG, 30000);
        props.put(ConsumerConfig.HEARTBEAT_INTERVAL_MS_CONFIG, 10000);
        props.put(JsonDeserializer.TRUSTED_PACKAGES, "*");
        return new DefaultKafkaConsumerFactory<>(props);
    }

    @Bean
    public ConcurrentKafkaListenerContainerFactory<String, Object> kafkaListenerContainerFactory() {
        ConcurrentKafkaListenerContainerFactory<String, Object> factory = 
            new ConcurrentKafkaListenerContainerFactory<>();
        factory.setConsumerFactory(consumerFactory());
        factory.setConcurrency(3);
        factory.getContainerProperties().setAckMode(ContainerProperties.AckMode.MANUAL_IMMEDIATE);
        factory.setCommonErrorHandler(new KafkaErrorHandler());
        return factory;
    }

    // Topic Configuration
    @Bean
    public KafkaAdmin kafkaAdmin() {
        Map<String, Object> configs = new HashMap<>();
        configs.put(AdminClientConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
        return new KafkaAdmin(configs);
    }

    // Trading Events Topics
    @Bean
    public NewTopic tradingEventsTopic() {
        return new NewTopic("trading-events", 3, (short) 1);
    }

    @Bean
    public NewTopic tradingEventsDlqTopic() {
        return new NewTopic("trading-events-dlq", 3, (short) 1);
    }

    // Wallet Events Topics
    @Bean
    public NewTopic walletEventsTopic() {
        return new NewTopic("wallet-events", 3, (short) 1);
    }

    @Bean
    public NewTopic walletEventsDlqTopic() {
        return new NewTopic("wallet-events-dlq", 3, (short) 1);
    }

    // User Events Topics
    @Bean
    public NewTopic userEventsTopic() {
        return new NewTopic("user-events", 3, (short) 1);
    }

    @Bean
    public NewTopic userEventsDlqTopic() {
        return new NewTopic("user-events-dlq", 3, (short) 1);
    }

    // Notification Events Topics
    @Bean
    public NewTopic notificationEventsTopic() {
        return new NewTopic("notification-events", 3, (short) 1);
    }

    @Bean
    public NewTopic notificationEventsDlqTopic() {
        return new NewTopic("notification-events-dlq", 3, (short) 1);
    }

    // Security Events Topics
    @Bean
    public NewTopic securityEventsTopic() {
        return new NewTopic("security-events", 3, (short) 1);
    }

    @Bean
    public NewTopic securityEventsDlqTopic() {
        return new NewTopic("security-events-dlq", 3, (short) 1);
    }

    // MEV Protection Events Topics
    @Bean
    public NewTopic mevProtectionEventsTopic() {
        return new NewTopic("mev-protection-events", 3, (short) 1);
    }

    @Bean
    public NewTopic mevProtectionEventsDlqTopic() {
        return new NewTopic("mev-protection-events-dlq", 3, (short) 1);
    }

    // Economic Analysis Events Topics
    @Bean
    public NewTopic economicAnalysisEventsTopic() {
        return new NewTopic("economic-analysis-events", 3, (short) 1);
    }

    @Bean
    public NewTopic economicAnalysisEventsDlqTopic() {
        return new NewTopic("economic-analysis-events-dlq", 3, (short) 1);
    }

    // Solana Gateway Events Topics
    @Bean
    public NewTopic solanaGatewayEventsTopic() {
        return new NewTopic("solana-gateway-events", 3, (short) 1);
    }

    @Bean
    public NewTopic solanaGatewayEventsDlqTopic() {
        return new NewTopic("solana-gateway-events-dlq", 3, (short) 1);
    }

    // Cross-Chain Events Topics
    @Bean
    public NewTopic crossChainEventsTopic() {
        return new NewTopic("cross-chain-events", 3, (short) 1);
    }

    @Bean
    public NewTopic crossChainEventsDlqTopic() {
        return new NewTopic("cross-chain-events-dlq", 3, (short) 1);
    }

    // Oracle Events Topics
    @Bean
    public NewTopic oracleEventsTopic() {
        return new NewTopic("oracle-events", 3, (short) 1);
    }

    @Bean
    public NewTopic oracleEventsDlqTopic() {
        return new NewTopic("oracle-events-dlq", 3, (short) 1);
    }

    // Analytics Events Topics
    @Bean
    public NewTopic analyticsEventsTopic() {
        return new NewTopic("analytics-events", 3, (short) 1);
    }

    @Bean
    public NewTopic analyticsEventsDlqTopic() {
        return new NewTopic("analytics-events-dlq", 3, (short) 1);
    }
}
