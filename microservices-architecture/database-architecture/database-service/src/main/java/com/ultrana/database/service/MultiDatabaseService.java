package com.ultrana.database.service;

import com.ultrana.database.entity.sql.User;
import com.ultrana.database.entity.sql.Trade;
import com.ultrana.database.entity.sql.Wallet;
import com.ultrana.database.entity.mongo.TradingEvent;
import com.ultrana.database.entity.mongo.PriceHistory;
import com.ultrana.database.entity.mongo.UserActivity;
import com.ultrana.database.repository.sql.UserRepository;
import com.ultrana.database.repository.sql.TradeRepository;
import com.ultrana.database.repository.sql.WalletRepository;
import com.ultrana.database.repository.mongo.TradingEventRepository;
import com.ultrana.database.repository.mongo.PriceHistoryRepository;
import com.ultrana.database.repository.mongo.UserActivityRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.aggregation.Aggregation;
import org.springframework.data.mongodb.core.aggregation.AggregationResults;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.Map;
import java.util.HashMap;

/**
 * Multi-Database Service
 * 
 * Provides unified access to both SQL (PostgreSQL) and NoSQL (MongoDB) databases
 * Implements database routing, caching, and transaction management
 */
@Service
@Transactional
public class MultiDatabaseService {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private TradeRepository tradeRepository;

    @Autowired
    private WalletRepository walletRepository;

    @Autowired
    private TradingEventRepository tradingEventRepository;

    @Autowired
    private PriceHistoryRepository priceHistoryRepository;

    @Autowired
    private UserActivityRepository userActivityRepository;

    @Autowired
    private MongoTemplate mongoTemplate;

    @Autowired
    private MongoTemplate mongoAnalyticsTemplate;

    @Autowired
    private MongoTemplate mongoShardedTemplate;

    // ==================== SQL Database Operations ====================

    /**
     * User Management Operations
     */
    public User createUser(User user) {
        return userRepository.save(user);
    }

    public Optional<User> getUserById(Long id) {
        return userRepository.findById(id);
    }

    public Optional<User> getUserByEmail(String email) {
        return userRepository.findByEmail(email);
    }

    public User updateUser(User user) {
        return userRepository.save(user);
    }

    public void deleteUser(Long id) {
        userRepository.deleteById(id);
    }

    public Page<User> getAllUsers(Pageable pageable) {
        return userRepository.findAll(pageable);
    }

    /**
     * Trading Operations
     */
    public Trade createTrade(Trade trade) {
        return tradeRepository.save(trade);
    }

    public Optional<Trade> getTradeById(Long id) {
        return tradeRepository.findById(id);
    }

    public List<Trade> getTradesByUserId(Long userId) {
        return tradeRepository.findByUserId(userId);
    }

    public List<Trade> getTradesByTradingPair(String tradingPair) {
        return tradeRepository.findByTradingPair(tradingPair);
    }

    public Page<Trade> getTradesByUserId(Long userId, Pageable pageable) {
        return tradeRepository.findByUserId(userId, pageable);
    }

    public List<Trade> getTradesByDateRange(LocalDateTime startDate, LocalDateTime endDate) {
        return tradeRepository.findByCreatedAtBetween(startDate, endDate);
    }

    /**
     * Wallet Operations
     */
    public Wallet createWallet(Wallet wallet) {
        return walletRepository.save(wallet);
    }

    public Optional<Wallet> getWalletById(Long id) {
        return walletRepository.findById(id);
    }

    public List<Wallet> getWalletsByUserId(Long userId) {
        return walletRepository.findByUserId(userId);
    }

    public Wallet updateWallet(Wallet wallet) {
        return walletRepository.save(wallet);
    }

    public void deleteWallet(Long id) {
        walletRepository.deleteById(id);
    }

    // ==================== NoSQL Database Operations ====================

    /**
     * Trading Events (MongoDB)
     */
    public TradingEvent createTradingEvent(TradingEvent event) {
        return tradingEventRepository.save(event);
    }

    public List<TradingEvent> getTradingEventsByUserId(String userId) {
        return tradingEventRepository.findByUserId(userId);
    }

    public List<TradingEvent> getTradingEventsByTradingPair(String tradingPair) {
        return tradingEventRepository.findByTradingPair(tradingPair);
    }

    public List<TradingEvent> getTradingEventsByDateRange(LocalDateTime startDate, LocalDateTime endDate) {
        return tradingEventRepository.findByTimestampBetween(startDate, endDate);
    }

    public Page<TradingEvent> getTradingEvents(Pageable pageable) {
        return tradingEventRepository.findAll(pageable);
    }

    /**
     * Price History (MongoDB)
     */
    public PriceHistory createPriceHistory(PriceHistory priceHistory) {
        return priceHistoryRepository.save(priceHistory);
    }

    public List<PriceHistory> getPriceHistoryBySymbol(String symbol) {
        return priceHistoryRepository.findBySymbol(symbol);
    }

    public List<PriceHistory> getPriceHistoryBySymbolAndDateRange(String symbol, LocalDateTime startDate, LocalDateTime endDate) {
        return priceHistoryRepository.findBySymbolAndTimestampBetween(symbol, startDate, endDate);
    }

    public PriceHistory getLatestPrice(String symbol) {
        return priceHistoryRepository.findTopBySymbolOrderByTimestampDesc(symbol);
    }

    /**
     * User Activity (MongoDB)
     */
    public UserActivity createUserActivity(UserActivity activity) {
        return userActivityRepository.save(activity);
    }

    public List<UserActivity> getUserActivityByUserId(String userId) {
        return userActivityRepository.findByUserId(userId);
    }

    public List<UserActivity> getUserActivityByActivityType(String activityType) {
        return userActivityRepository.findByActivityType(activityType);
    }

    public List<UserActivity> getUserActivityByDateRange(LocalDateTime startDate, LocalDateTime endDate) {
        return userActivityRepository.findByTimestampBetween(startDate, endDate);
    }

    // ==================== Analytics Operations ====================

    /**
     * Trading Analytics
     */
    public Map<String, Object> getTradingAnalytics(String userId, LocalDateTime startDate, LocalDateTime endDate) {
        Aggregation aggregation = Aggregation.newAggregation(
            Aggregation.match(Criteria.where("userId").is(userId)
                .and("timestamp").gte(startDate).lte(endDate)),
            Aggregation.group("tradingPair")
                .sum("volume").as("totalVolume")
                .count().as("tradeCount")
                .avg("price").as("averagePrice"),
            Aggregation.sort(org.springframework.data.domain.Sort.Direction.DESC, "totalVolume")
        );

        AggregationResults<Map> results = mongoAnalyticsTemplate.aggregate(
            aggregation, "trading_events", Map.class);

        Map<String, Object> analytics = new HashMap<>();
        analytics.put("tradingPairs", results.getMappedResults());
        analytics.put("totalTrades", results.getMappedResults().size());
        analytics.put("dateRange", Map.of("start", startDate, "end", endDate));

        return analytics;
    }

    /**
     * User Activity Analytics
     */
    public Map<String, Object> getUserActivityAnalytics(String userId, LocalDateTime startDate, LocalDateTime endDate) {
        Aggregation aggregation = Aggregation.newAggregation(
            Aggregation.match(Criteria.where("userId").is(userId)
                .and("timestamp").gte(startDate).lte(endDate)),
            Aggregation.group("activityType")
                .count().as("activityCount"),
            Aggregation.sort(org.springframework.data.domain.Sort.Direction.DESC, "activityCount")
        );

        AggregationResults<Map> results = mongoAnalyticsTemplate.aggregate(
            aggregation, "user_activities", Map.class);

        Map<String, Object> analytics = new HashMap<>();
        analytics.put("activityTypes", results.getMappedResults());
        analytics.put("totalActivities", results.getMappedResults().size());
        analytics.put("dateRange", Map.of("start", startDate, "end", endDate));

        return analytics;
    }

    /**
     * Price Analytics
     */
    public Map<String, Object> getPriceAnalytics(String symbol, LocalDateTime startDate, LocalDateTime endDate) {
        Aggregation aggregation = Aggregation.newAggregation(
            Aggregation.match(Criteria.where("symbol").is(symbol)
                .and("timestamp").gte(startDate).lte(endDate)),
            Aggregation.group()
                .avg("price").as("averagePrice")
                .min("price").as("minPrice")
                .max("price").as("maxPrice")
                .count().as("dataPoints")
        );

        AggregationResults<Map> results = mongoAnalyticsTemplate.aggregate(
            aggregation, "price_history", Map.class);

        Map<String, Object> analytics = new HashMap<>();
        if (!results.getMappedResults().isEmpty()) {
            analytics.putAll(results.getMappedResults().get(0));
        }
        analytics.put("symbol", symbol);
        analytics.put("dateRange", Map.of("start", startDate, "end", endDate));

        return analytics;
    }

    // ==================== Cross-Database Operations ====================

    /**
     * Sync User Data Between SQL and NoSQL
     */
    @Transactional
    public void syncUserData(Long userId) {
        Optional<User> user = getUserById(userId);
        if (user.isPresent()) {
            // Create user activity in MongoDB
            UserActivity activity = new UserActivity();
            activity.setUserId(userId.toString());
            activity.setActivityType("SYNC");
            activity.setDescription("User data synchronized");
            activity.setTimestamp(LocalDateTime.now());
            createUserActivity(activity);
        }
    }

    /**
     * Sync Trading Data Between SQL and NoSQL
     */
    @Transactional
    public void syncTradingData(Long tradeId) {
        Optional<Trade> trade = getTradeById(tradeId);
        if (trade.isPresent()) {
            // Create trading event in MongoDB
            TradingEvent event = new TradingEvent();
            event.setUserId(trade.get().getUserId().toString());
            event.setTradingPair(trade.get().getTradingPair());
            event.setEventType("TRADE_CREATED");
            event.setVolume(trade.get().getVolume());
            event.setPrice(trade.get().getPrice());
            event.setTimestamp(LocalDateTime.now());
            createTradingEvent(event);
        }
    }

    /**
     * Get User Dashboard Data
     */
    public Map<String, Object> getUserDashboard(Long userId) {
        Map<String, Object> dashboard = new HashMap<>();

        // SQL Data
        Optional<User> user = getUserById(userId);
        List<Trade> trades = getTradesByUserId(userId);
        List<Wallet> wallets = getWalletsByUserId(userId);

        // NoSQL Data
        List<TradingEvent> events = getTradingEventsByUserId(userId.toString());
        List<UserActivity> activities = getUserActivityByUserId(userId.toString());

        dashboard.put("user", user.orElse(null));
        dashboard.put("trades", trades);
        dashboard.put("wallets", wallets);
        dashboard.put("events", events);
        dashboard.put("activities", activities);

        return dashboard;
    }

    // ==================== Database Health Checks ====================

    /**
     * Check SQL Database Health
     */
    public boolean isSqlDatabaseHealthy() {
        try {
            userRepository.count();
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * Check NoSQL Database Health
     */
    public boolean isNoSqlDatabaseHealthy() {
        try {
            tradingEventRepository.count();
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * Get Database Statistics
     */
    public Map<String, Object> getDatabaseStatistics() {
        Map<String, Object> stats = new HashMap<>();

        // SQL Statistics
        stats.put("sqlUsers", userRepository.count());
        stats.put("sqlTrades", tradeRepository.count());
        stats.put("sqlWallets", walletRepository.count());

        // NoSQL Statistics
        stats.put("mongoEvents", tradingEventRepository.count());
        stats.put("mongoPrices", priceHistoryRepository.count());
        stats.put("mongoActivities", userActivityRepository.count());

        return stats;
    }
}
