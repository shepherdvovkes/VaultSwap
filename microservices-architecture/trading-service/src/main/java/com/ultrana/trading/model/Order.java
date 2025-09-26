package com.ultrana.trading.model;

import jakarta.persistence.*;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import lombok.Builder;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

/**
 * Order entity representing trading orders in the DEX
 */
@Entity
@Table(name = "orders", indexes = {
    @Index(name = "idx_orders_user_id", columnList = "user_id"),
    @Index(name = "idx_orders_token_pair", columnList = "token_pair"),
    @Index(name = "idx_orders_status", columnList = "status"),
    @Index(name = "idx_orders_created_at", columnList = "created_at")
})
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Order {
    
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;
    
    @NotNull
    @Column(name = "user_id", nullable = false)
    private UUID userId;
    
    @NotNull
    @Column(name = "token_pair", length = 20, nullable = false)
    private String tokenPair;
    
    @NotNull
    @Enumerated(EnumType.STRING)
    @Column(name = "order_type", nullable = false)
    private OrderType orderType;
    
    @NotNull
    @Enumerated(EnumType.STRING)
    @Column(name = "side", nullable = false)
    private OrderSide side;
    
    @NotNull
    @Positive
    @DecimalMin(value = "0.000000000000000001")
    @Column(name = "amount", precision = 36, scale = 18, nullable = false)
    private BigDecimal amount;
    
    @DecimalMin(value = "0.000000000000000001")
    @Column(name = "price", precision = 36, scale = 18)
    private BigDecimal price;
    
    @NotNull
    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false)
    private OrderStatus status;
    
    @Column(name = "filled_amount", precision = 36, scale = 18)
    private BigDecimal filledAmount;
    
    @Column(name = "remaining_amount", precision = 36, scale = 18)
    private BigDecimal remainingAmount;
    
    @Column(name = "fee", precision = 36, scale = 18)
    private BigDecimal fee;
    
    @Column(name = "chain_id")
    private Long chainId;
    
    @Column(name = "transaction_hash", length = 66)
    private String transactionHash;
    
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;
    
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;
    
    @Column(name = "expires_at")
    private LocalDateTime expiresAt;
    
    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        updatedAt = LocalDateTime.now();
        if (remainingAmount == null) {
            remainingAmount = amount;
        }
    }
    
    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
    
    public enum OrderType {
        LIMIT, MARKET, STOP_LOSS, STOP_LIMIT
    }
    
    public enum OrderSide {
        BUY, SELL
    }
    
    public enum OrderStatus {
        PENDING, PARTIALLY_FILLED, FILLED, CANCELLED, EXPIRED, REJECTED
    }
}

