package com.ultrana.cache.service;

import com.github.benmanes.caffeine.cache.Cache;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.cache.CacheManager;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.Optional;
import java.util.concurrent.TimeUnit;

/**
 * Multi-Layer Cache Service
 * 
 * Implements cache-aside pattern with L1 (Caffeine) and L2 (Redis) layers
 * Provides automatic fallback and cache warming capabilities
 */
@Service
public class MultiLayerCacheService {

    @Autowired
    private Cache<String, Object> userSessionCache;

    @Autowired
    private Cache<String, Object> tradingDataCache;

    @Autowired
    private Cache<String, Object> priceDataCache;

    @Autowired
    private Cache<String, Object> apiResponseCache;

    @Autowired
    private Cache<String, Object> userProfileCache;

    @Autowired
    private Cache<String, Object> walletDataCache;

    @Autowired
    private Cache<String, Object> analyticsDataCache;

    @Autowired
    private RedisTemplate<String, Object> redisTemplate;

    @Autowired
    private CacheManager cacheManager;

    /**
     * Get data from multi-layer cache
     * L1 (Caffeine) -> L2 (Redis) -> Database
     */
    public <T> Optional<T> get(String key, Class<T> type, CacheLayer preferredLayer) {
        // Try L1 cache first
        if (preferredLayer == CacheLayer.L1 || preferredLayer == CacheLayer.ANY) {
            Object value = getFromL1Cache(key);
            if (value != null) {
                return Optional.of(type.cast(value));
            }
        }

        // Try L2 cache (Redis)
        if (preferredLayer == CacheLayer.L2 || preferredLayer == CacheLayer.ANY) {
            Object value = getFromL2Cache(key);
            if (value != null) {
                // Store in L1 cache for faster access
                putInL1Cache(key, value);
                return Optional.of(type.cast(value));
            }
        }

        return Optional.empty();
    }

    /**
     * Put data in multi-layer cache
     */
    public void put(String key, Object value, CacheLayer layer, Duration ttl) {
        if (layer == CacheLayer.L1 || layer == CacheLayer.ANY) {
            putInL1Cache(key, value);
        }

        if (layer == CacheLayer.L2 || layer == CacheLayer.ANY) {
            putInL2Cache(key, value, ttl);
        }
    }

    /**
     * Get from L1 cache (Caffeine)
     */
    private Object getFromL1Cache(String key) {
        // Try different cache types based on key prefix
        if (key.startsWith("user:session:")) {
            return userSessionCache.getIfPresent(key);
        } else if (key.startsWith("trading:")) {
            return tradingDataCache.getIfPresent(key);
        } else if (key.startsWith("price:")) {
            return priceDataCache.getIfPresent(key);
        } else if (key.startsWith("api:")) {
            return apiResponseCache.getIfPresent(key);
        } else if (key.startsWith("user:profile:")) {
            return userProfileCache.getIfPresent(key);
        } else if (key.startsWith("wallet:")) {
            return walletDataCache.getIfPresent(key);
        } else if (key.startsWith("analytics:")) {
            return analyticsDataCache.getIfPresent(key);
        }
        return null;
    }

    /**
     * Put in L1 cache (Caffeine)
     */
    private void putInL1Cache(String key, Object value) {
        if (key.startsWith("user:session:")) {
            userSessionCache.put(key, value);
        } else if (key.startsWith("trading:")) {
            tradingDataCache.put(key, value);
        } else if (key.startsWith("price:")) {
            priceDataCache.put(key, value);
        } else if (key.startsWith("api:")) {
            apiResponseCache.put(key, value);
        } else if (key.startsWith("user:profile:")) {
            userProfileCache.put(key, value);
        } else if (key.startsWith("wallet:")) {
            walletDataCache.put(key, value);
        } else if (key.startsWith("analytics:")) {
            analyticsDataCache.put(key, value);
        }
    }

    /**
     * Get from L2 cache (Redis)
     */
    private Object getFromL2Cache(String key) {
        return redisTemplate.opsForValue().get(key);
    }

    /**
     * Put in L2 cache (Redis)
     */
    private void putInL2Cache(String key, Object value, Duration ttl) {
        redisTemplate.opsForValue().set(key, value, ttl);
    }

    /**
     * Cache with automatic fallback
     */
    public <T> T getOrElse(String key, Class<T> type, java.util.function.Supplier<T> supplier, CacheLayer layer, Duration ttl) {
        Optional<T> cached = get(key, type, layer);
        if (cached.isPresent()) {
            return cached.get();
        }

        T value = supplier.get();
        if (value != null) {
            put(key, value, layer, ttl);
        }
        return value;
    }

    /**
     * Invalidate cache
     */
    public void invalidate(String key, CacheLayer layer) {
        if (layer == CacheLayer.L1 || layer == CacheLayer.ANY) {
            invalidateL1Cache(key);
        }

        if (layer == CacheLayer.L2 || layer == CacheLayer.ANY) {
            invalidateL2Cache(key);
        }
    }

    /**
     * Invalidate L1 cache
     */
    private void invalidateL1Cache(String key) {
        if (key.startsWith("user:session:")) {
            userSessionCache.invalidate(key);
        } else if (key.startsWith("trading:")) {
            tradingDataCache.invalidate(key);
        } else if (key.startsWith("price:")) {
            priceDataCache.invalidate(key);
        } else if (key.startsWith("api:")) {
            apiResponseCache.invalidate(key);
        } else if (key.startsWith("user:profile:")) {
            userProfileCache.invalidate(key);
        } else if (key.startsWith("wallet:")) {
            walletDataCache.invalidate(key);
        } else if (key.startsWith("analytics:")) {
            analyticsDataCache.invalidate(key);
        }
    }

    /**
     * Invalidate L2 cache
     */
    private void invalidateL2Cache(String key) {
        redisTemplate.delete(key);
    }

    /**
     * Batch operations
     */
    public void putAll(java.util.Map<String, Object> entries, CacheLayer layer, Duration ttl) {
        if (layer == CacheLayer.L1 || layer == CacheLayer.ANY) {
            entries.forEach((key, value) -> putInL1Cache(key, value));
        }

        if (layer == CacheLayer.L2 || layer == CacheLayer.ANY) {
            redisTemplate.opsForValue().multiSet(entries);
            // Set TTL for all keys
            entries.keySet().forEach(key -> redisTemplate.expire(key, ttl));
        }
    }

    /**
     * Cache warming
     */
    public void warmCache(String key, Object value, CacheLayer layer, Duration ttl) {
        put(key, value, layer, ttl);
    }

    /**
     * Get cache statistics
     */
    public CacheStats getCacheStats() {
        return CacheStats.builder()
                .l1UserSessionStats(userSessionCache.stats())
                .l1TradingDataStats(tradingDataCache.stats())
                .l1PriceDataStats(priceDataCache.stats())
                .l1ApiResponseStats(apiResponseCache.stats())
                .l1UserProfileStats(userProfileCache.stats())
                .l1WalletDataStats(walletDataCache.stats())
                .l1AnalyticsDataStats(analyticsDataCache.stats())
                .build();
    }

    /**
     * Cache layer enumeration
     */
    public enum CacheLayer {
        L1, L2, ANY
    }

    /**
     * Cache statistics
     */
    @lombok.Builder
    @lombok.Data
    public static class CacheStats {
        private com.github.benmanes.caffeine.cache.stats.CacheStats l1UserSessionStats;
        private com.github.benmanes.caffeine.cache.stats.CacheStats l1TradingDataStats;
        private com.github.benmanes.caffeine.cache.stats.CacheStats l1PriceDataStats;
        private com.github.benmanes.caffeine.cache.stats.CacheStats l1ApiResponseStats;
        private com.github.benmanes.caffeine.cache.stats.CacheStats l1UserProfileStats;
        private com.github.benmanes.caffeine.cache.stats.CacheStats l1WalletDataStats;
        private com.github.benmanes.caffeine.cache.stats.CacheStats l1AnalyticsDataStats;
    }
}
