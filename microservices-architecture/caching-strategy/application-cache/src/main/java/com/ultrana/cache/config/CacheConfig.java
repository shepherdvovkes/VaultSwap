package com.ultrana.cache.config;

import com.github.benmanes.caffeine.cache.Cache;
import com.github.benmanes.caffeine.cache.Caffeine;
import org.springframework.cache.CacheManager;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.cache.caffeine.CaffeineCacheManager;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.cache.RedisCacheManager;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.serializer.GenericJackson2JsonRedisSerializer;
import org.springframework.data.redis.serializer.StringRedisSerializer;

import java.time.Duration;
import java.util.HashMap;
import java.util.Map;

/**
 * Multi-Layer Cache Configuration
 * 
 * Implements L1 (Caffeine) and L2 (Redis) caching layers
 * with different TTL and eviction policies for different data types
 */
@Configuration
@EnableCaching
public class CacheConfig {

    // L1 Cache Configuration (Caffeine - In-Memory)
    @Bean
    public CacheManager caffeineCacheManager() {
        CaffeineCacheManager cacheManager = new CaffeineCacheManager();
        cacheManager.setCaffeine(Caffeine.newBuilder()
                .maximumSize(10000)
                .expireAfterWrite(Duration.ofMinutes(15))
                .recordStats());
        return cacheManager;
    }

    // L2 Cache Configuration (Redis - Distributed)
    @Bean
    public CacheManager redisCacheManager(RedisConnectionFactory connectionFactory) {
        RedisCacheManager.Builder builder = RedisCacheManager
                .RedisCacheManagerBuilder
                .fromConnectionFactory(connectionFactory)
                .cacheDefaults(org.springframework.data.redis.cache.RedisCacheConfiguration
                        .defaultCacheConfig()
                        .entryTtl(Duration.ofHours(1)));

        // Configure different TTL for different cache names
        Map<String, org.springframework.data.redis.cache.RedisCacheConfiguration> cacheConfigurations = new HashMap<>();
        
        // User sessions - 30 minutes
        cacheConfigurations.put("user-sessions", 
            org.springframework.data.redis.cache.RedisCacheConfiguration
                .defaultCacheConfig()
                .entryTtl(Duration.ofMinutes(30)));

        // Trading data - 5 minutes
        cacheConfigurations.put("trading-data", 
            org.springframework.data.redis.cache.RedisCacheConfiguration
                .defaultCacheConfig()
                .entryTtl(Duration.ofMinutes(5)));

        // Price data - 1 minute
        cacheConfigurations.put("price-data", 
            org.springframework.data.redis.cache.RedisCacheConfiguration
                .defaultCacheConfig()
                .entryTtl(Duration.ofMinutes(1)));

        // Static assets - 24 hours
        cacheConfigurations.put("static-assets", 
            org.springframework.data.redis.cache.RedisCacheConfiguration
                .defaultCacheConfig()
                .entryTtl(Duration.ofHours(24)));

        // API responses - 15 minutes
        cacheConfigurations.put("api-responses", 
            org.springframework.data.redis.cache.RedisCacheConfiguration
                .defaultCacheConfig()
                .entryTtl(Duration.ofMinutes(15)));

        // User profiles - 1 hour
        cacheConfigurations.put("user-profiles", 
            org.springframework.data.redis.cache.RedisCacheConfiguration
                .defaultCacheConfig()
                .entryTtl(Duration.ofHours(1)));

        // Wallet data - 10 minutes
        cacheConfigurations.put("wallet-data", 
            org.springframework.data.redis.cache.RedisCacheConfiguration
                .defaultCacheConfig()
                .entryTtl(Duration.ofMinutes(10)));

        // Analytics data - 1 hour
        cacheConfigurations.put("analytics-data", 
            org.springframework.data.redis.cache.RedisCacheConfiguration
                .defaultCacheConfig()
                .entryTtl(Duration.ofHours(1)));

        builder.withInitialCacheConfigurations(cacheConfigurations);
        
        return builder.build();
    }

    // Redis Template Configuration
    @Bean
    public RedisTemplate<String, Object> redisTemplate(RedisConnectionFactory connectionFactory) {
        RedisTemplate<String, Object> template = new RedisTemplate<>();
        template.setConnectionFactory(connectionFactory);
        
        // Use String serializer for keys
        template.setKeySerializer(new StringRedisSerializer());
        template.setHashKeySerializer(new StringRedisSerializer());
        
        // Use JSON serializer for values
        template.setValueSerializer(new GenericJackson2JsonRedisSerializer());
        template.setHashValueSerializer(new GenericJackson2JsonRedisSerializer());
        
        template.afterPropertiesSet();
        return template;
    }

    // Specialized Caches for Different Data Types
    @Bean
    public Cache<String, Object> userSessionCache() {
        return Caffeine.newBuilder()
                .maximumSize(50000)
                .expireAfterWrite(Duration.ofMinutes(30))
                .expireAfterAccess(Duration.ofMinutes(15))
                .recordStats()
                .build();
    }

    @Bean
    public Cache<String, Object> tradingDataCache() {
        return Caffeine.newBuilder()
                .maximumSize(100000)
                .expireAfterWrite(Duration.ofMinutes(5))
                .expireAfterAccess(Duration.ofMinutes(2))
                .recordStats()
                .build();
    }

    @Bean
    public Cache<String, Object> priceDataCache() {
        return Caffeine.newBuilder()
                .maximumSize(200000)
                .expireAfterWrite(Duration.ofMinutes(1))
                .expireAfterAccess(Duration.ofSeconds(30))
                .recordStats()
                .build();
    }

    @Bean
    public Cache<String, Object> apiResponseCache() {
        return Caffeine.newBuilder()
                .maximumSize(25000)
                .expireAfterWrite(Duration.ofMinutes(15))
                .expireAfterAccess(Duration.ofMinutes(5))
                .recordStats()
                .build();
    }

    @Bean
    public Cache<String, Object> userProfileCache() {
        return Caffeine.newBuilder()
                .maximumSize(10000)
                .expireAfterWrite(Duration.ofHours(1))
                .expireAfterAccess(Duration.ofMinutes(30))
                .recordStats()
                .build();
    }

    @Bean
    public Cache<String, Object> walletDataCache() {
        return Caffeine.newBuilder()
                .maximumSize(50000)
                .expireAfterWrite(Duration.ofMinutes(10))
                .expireAfterAccess(Duration.ofMinutes(5))
                .recordStats()
                .build();
    }

    @Bean
    public Cache<String, Object> analyticsDataCache() {
        return Caffeine.newBuilder()
                .maximumSize(15000)
                .expireAfterWrite(Duration.ofHours(1))
                .expireAfterAccess(Duration.ofMinutes(15))
                .recordStats()
                .build();
    }
}
