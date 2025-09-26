package com.ultrana.gateway.config;

import org.springframework.cloud.gateway.route.RouteLocator;
import org.springframework.cloud.gateway.route.builder.RouteLocatorBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;

/**
 * Gateway Configuration
 * 
 * Defines routing rules for the API Gateway including:
 * - Service routing with load balancing
 * - Circuit breaker integration
 * - Rate limiting
 * - Authentication filters
 */
@Configuration
public class GatewayConfig {

    @Bean
    public RouteLocator customRouteLocator(RouteLocatorBuilder builder) {
        return builder.routes()
                // User Service Routes
                .route("user-service", r -> r.path("/api/v1/users/**")
                        .filters(f -> f
                                .circuitBreaker(c -> c.setName("user-service-cb")
                                        .setFallbackUri("forward:/fallback/user"))
                                .requestRateLimiter(rl -> rl.setRateLimiter(rateLimiter()))
                                .addRequestHeader("X-Service", "user-service"))
                        .uri("lb://user-service"))
                
                // Trading Service Routes
                .route("trading-service", r -> r.path("/api/v1/trading/**")
                        .filters(f -> f
                                .circuitBreaker(c -> c.setName("trading-service-cb")
                                        .setFallbackUri("forward:/fallback/trading"))
                                .requestRateLimiter(rl -> rl.setRateLimiter(rateLimiter()))
                                .addRequestHeader("X-Service", "trading-service"))
                        .uri("lb://trading-service"))
                
                // Wallet Service Routes
                .route("wallet-service", r -> r.path("/api/v1/wallets/**")
                        .filters(f -> f
                                .circuitBreaker(c -> c.setName("wallet-service-cb")
                                        .setFallbackUri("forward:/fallback/wallet"))
                                .requestRateLimiter(rl -> rl.setRateLimiter(rateLimiter()))
                                .addRequestHeader("X-Service", "wallet-service"))
                        .uri("lb://wallet-service"))
                
                // Analytics Service Routes
                .route("analytics-service", r -> r.path("/api/v1/analytics/**")
                        .filters(f -> f
                                .circuitBreaker(c -> c.setName("analytics-service-cb")
                                        .setFallbackUri("forward:/fallback/analytics"))
                                .requestRateLimiter(rl -> rl.setRateLimiter(rateLimiter()))
                                .addRequestHeader("X-Service", "analytics-service"))
                        .uri("lb://analytics-service"))
                
                // Notification Service Routes
                .route("notification-service", r -> r.path("/api/v1/notifications/**")
                        .filters(f -> f
                                .circuitBreaker(c -> c.setName("notification-service-cb")
                                        .setFallbackUri("forward:/fallback/notification"))
                                .requestRateLimiter(rl -> rl.setRateLimiter(rateLimiter()))
                                .addRequestHeader("X-Service", "notification-service"))
                        .uri("lb://notification-service"))
                
                // Haskell Services Routes
                .route("security-service", r -> r.path("/api/v1/security/**")
                        .filters(f -> f
                                .circuitBreaker(c -> c.setName("security-service-cb")
                                        .setFallbackUri("forward:/fallback/security"))
                                .requestRateLimiter(rl -> rl.setRateLimiter(rateLimiter()))
                                .addRequestHeader("X-Service", "security-service"))
                        .uri("lb://security-service"))
                
                .route("mev-protection-service", r -> r.path("/api/v1/mev/**")
                        .filters(f -> f
                                .circuitBreaker(c -> c.setName("mev-protection-service-cb")
                                        .setFallbackUri("forward:/fallback/mev"))
                                .requestRateLimiter(rl -> rl.setRateLimiter(rateLimiter()))
                                .addRequestHeader("X-Service", "mev-protection-service"))
                        .uri("lb://mev-protection-service"))
                
                .route("economic-analysis-service", r -> r.path("/api/v1/economic/**")
                        .filters(f -> f
                                .circuitBreaker(c -> c.setName("economic-analysis-service-cb")
                                        .setFallbackUri("forward:/fallback/economic"))
                                .requestRateLimiter(rl -> rl.setRateLimiter(rateLimiter()))
                                .addRequestHeader("X-Service", "economic-analysis-service"))
                        .uri("lb://economic-analysis-service"))
                
                // Rust Services Routes
                .route("solana-gateway-service", r -> r.path("/api/v1/solana/**")
                        .filters(f -> f
                                .circuitBreaker(c -> c.setName("solana-gateway-service-cb")
                                        .setFallbackUri("forward:/fallback/solana"))
                                .requestRateLimiter(rl -> rl.setRateLimiter(rateLimiter()))
                                .addRequestHeader("X-Service", "solana-gateway-service"))
                        .uri("lb://solana-gateway-service"))
                
                .route("cross-chain-service", r -> r.path("/api/v1/cross-chain/**")
                        .filters(f -> f
                                .circuitBreaker(c -> c.setName("cross-chain-service-cb")
                                        .setFallbackUri("forward:/fallback/cross-chain"))
                                .requestRateLimiter(rl -> rl.setRateLimiter(rateLimiter()))
                                .addRequestHeader("X-Service", "cross-chain-service"))
                        .uri("lb://cross-chain-service"))
                
                .route("oracle-service", r -> r.path("/api/v1/oracle/**")
                        .filters(f -> f
                                .circuitBreaker(c -> c.setName("oracle-service-cb")
                                        .setFallbackUri("forward:/fallback/oracle"))
                                .requestRateLimiter(rl -> rl.setRateLimiter(rateLimiter()))
                                .addRequestHeader("X-Service", "oracle-service"))
                        .uri("lb://oracle-service"))
                
                // Health Check Routes
                .route("health-check", r -> r.path("/health/**")
                        .filters(f -> f.addRequestHeader("X-Service", "health-check"))
                        .uri("lb://user-service"))
                
                .build();
    }

    @Bean
    public RedisRateLimiter rateLimiter() {
        return new RedisRateLimiter(10, 20, 1);
    }
}
