package com.ultrana.database.config;

import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;
import org.springframework.data.mongodb.config.AbstractMongoClientConfiguration;
import org.springframework.data.mongodb.repository.config.EnableMongoRepositories;
import org.springframework.orm.jpa.JpaTransactionManager;
import org.springframework.orm.jpa.LocalContainerEntityManagerFactoryBean;
import org.springframework.orm.jpa.vendor.HibernateJpaVendorAdapter;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.EnableTransactionManagement;

import javax.sql.DataSource;
import java.util.Properties;

/**
 * Multi-Database Configuration
 * 
 * Configures both PostgreSQL (SQL) and MongoDB (NoSQL) databases
 * with connection pooling, read replicas, and sharding support
 */
@Configuration
@EnableTransactionManagement
@EnableJpaRepositories(basePackages = "com.ultrana.database.repository.sql")
@EnableMongoRepositories(basePackages = "com.ultrana.database.repository.mongo")
public class DatabaseConfig extends AbstractMongoClientConfiguration {

    // PostgreSQL Configuration
    @Value("${database.postgresql.primary.url}")
    private String postgresPrimaryUrl;

    @Value("${database.postgresql.primary.username}")
    private String postgresUsername;

    @Value("${database.postgresql.primary.password}")
    private String postgresPassword;

    @Value("${database.postgresql.analytics.url}")
    private String postgresAnalyticsUrl;

    @Value("${database.postgresql.reporting.url}")
    private String postgresReportingUrl;

    // MongoDB Configuration
    @Value("${database.mongodb.primary.uri}")
    private String mongoPrimaryUri;

    @Value("${database.mongodb.analytics.uri}")
    private String mongoAnalyticsUri;

    @Value("${database.mongodb.sharded.uri}")
    private String mongoShardedUri;

    /**
     * Primary PostgreSQL DataSource (Write Operations)
     */
    @Bean
    @Primary
    public DataSource postgresPrimaryDataSource() {
        HikariConfig config = new HikariConfig();
        config.setJdbcUrl(postgresPrimaryUrl);
        config.setUsername(postgresUsername);
        config.setPassword(postgresPassword);
        config.setDriverClassName("org.postgresql.Driver");
        
        // Connection Pool Configuration
        config.setMaximumPoolSize(20);
        config.setMinimumIdle(5);
        config.setConnectionTimeout(30000);
        config.setIdleTimeout(600000);
        config.setMaxLifetime(1800000);
        config.setLeakDetectionThreshold(60000);
        
        // Performance Optimizations
        config.addDataSourceProperty("cachePrepStmts", "true");
        config.addDataSourceProperty("prepStmtCacheSize", "250");
        config.addDataSourceProperty("prepStmtCacheSqlLimit", "2048");
        config.addDataSourceProperty("useServerPrepStmts", "true");
        config.addDataSourceProperty("useLocalSessionState", "true");
        config.addDataSourceProperty("rewriteBatchedStatements", "true");
        config.addDataSourceProperty("cacheResultSetMetadata", "true");
        config.addDataSourceProperty("cacheServerConfiguration", "true");
        config.addDataSourceProperty("elideSetAutoCommits", "true");
        config.addDataSourceProperty("maintainTimeStats", "false");
        
        return new HikariDataSource(config);
    }

    /**
     * Analytics PostgreSQL DataSource (Read Operations)
     */
    @Bean
    public DataSource postgresAnalyticsDataSource() {
        HikariConfig config = new HikariConfig();
        config.setJdbcUrl(postgresAnalyticsUrl);
        config.setUsername(postgresUsername);
        config.setPassword(postgresPassword);
        config.setDriverClassName("org.postgresql.Driver");
        
        // Read-Only Configuration
        config.setMaximumPoolSize(15);
        config.setMinimumIdle(3);
        config.setConnectionTimeout(30000);
        config.setIdleTimeout(600000);
        config.setMaxLifetime(1800000);
        config.setLeakDetectionThreshold(60000);
        
        // Read-Only Optimizations
        config.addDataSourceProperty("readOnly", "true");
        config.addDataSourceProperty("cachePrepStmts", "true");
        config.addDataSourceProperty("prepStmtCacheSize", "250");
        config.addDataSourceProperty("prepStmtCacheSqlLimit", "2048");
        
        return new HikariDataSource(config);
    }

    /**
     * Reporting PostgreSQL DataSource (Read Operations)
     */
    @Bean
    public DataSource postgresReportingDataSource() {
        HikariConfig config = new HikariConfig();
        config.setJdbcUrl(postgresReportingUrl);
        config.setUsername(postgresUsername);
        config.setPassword(postgresPassword);
        config.setDriverClassName("org.postgresql.Driver");
        
        // Reporting Configuration
        config.setMaximumPoolSize(10);
        config.setMinimumIdle(2);
        config.setConnectionTimeout(30000);
        config.setIdleTimeout(600000);
        config.setMaxLifetime(1800000);
        config.setLeakDetectionThreshold(60000);
        
        // Reporting Optimizations
        config.addDataSourceProperty("readOnly", "true");
        config.addDataSourceProperty("cachePrepStmts", "true");
        config.addDataSourceProperty("prepStmtCacheSize", "250");
        config.addDataSourceProperty("prepStmtCacheSqlLimit", "2048");
        
        return new HikariDataSource(config);
    }

    /**
     * Primary EntityManagerFactory for PostgreSQL
     */
    @Bean
    @Primary
    public LocalContainerEntityManagerFactoryBean postgresEntityManagerFactory() {
        LocalContainerEntityManagerFactoryBean em = new LocalContainerEntityManagerFactoryBean();
        em.setDataSource(postgresPrimaryDataSource());
        em.setPackagesToScan("com.ultrana.database.entity.sql");
        em.setJpaVendorAdapter(new HibernateJpaVendorAdapter());
        
        Properties properties = new Properties();
        properties.setProperty("hibernate.dialect", "org.hibernate.dialect.PostgreSQLDialect");
        properties.setProperty("hibernate.hbm2ddl.auto", "validate");
        properties.setProperty("hibernate.show_sql", "false");
        properties.setProperty("hibernate.format_sql", "true");
        properties.setProperty("hibernate.use_sql_comments", "true");
        properties.setProperty("hibernate.jdbc.batch_size", "20");
        properties.setProperty("hibernate.order_inserts", "true");
        properties.setProperty("hibernate.order_updates", "true");
        properties.setProperty("hibernate.jdbc.batch_versioned_data", "true");
        properties.setProperty("hibernate.connection.provider_disables_autocommit", "true");
        properties.setProperty("hibernate.cache.use_second_level_cache", "true");
        properties.setProperty("hibernate.cache.use_query_cache", "true");
        properties.setProperty("hibernate.cache.region.factory_class", "org.hibernate.cache.jcache.JCacheRegionFactory");
        properties.setProperty("hibernate.javax.cache.provider", "org.ehcache.jsr107.EhcacheCachingProvider");
        
        em.setJpaProperties(properties);
        return em;
    }

    /**
     * Analytics EntityManagerFactory for PostgreSQL
     */
    @Bean
    public LocalContainerEntityManagerFactoryBean postgresAnalyticsEntityManagerFactory() {
        LocalContainerEntityManagerFactoryBean em = new LocalContainerEntityManagerFactoryBean();
        em.setDataSource(postgresAnalyticsDataSource());
        em.setPackagesToScan("com.ultrana.database.entity.analytics");
        em.setJpaVendorAdapter(new HibernateJpaVendorAdapter());
        
        Properties properties = new Properties();
        properties.setProperty("hibernate.dialect", "org.hibernate.dialect.PostgreSQLDialect");
        properties.setProperty("hibernate.hbm2ddl.auto", "validate");
        properties.setProperty("hibernate.show_sql", "false");
        properties.setProperty("hibernate.format_sql", "true");
        properties.setProperty("hibernate.use_sql_comments", "true");
        properties.setProperty("hibernate.jdbc.batch_size", "20");
        properties.setProperty("hibernate.order_inserts", "true");
        properties.setProperty("hibernate.order_updates", "true");
        properties.setProperty("hibernate.jdbc.batch_versioned_data", "true");
        properties.setProperty("hibernate.connection.provider_disables_autocommit", "true");
        properties.setProperty("hibernate.cache.use_second_level_cache", "true");
        properties.setProperty("hibernate.cache.use_query_cache", "true");
        properties.setProperty("hibernate.cache.region.factory_class", "org.hibernate.cache.jcache.JCacheRegionFactory");
        properties.setProperty("hibernate.javax.cache.provider", "org.ehcache.jsr107.EhcacheCachingProvider");
        
        em.setJpaProperties(properties);
        return em;
    }

    /**
     * Transaction Manager for PostgreSQL
     */
    @Bean
    @Primary
    public PlatformTransactionManager postgresTransactionManager() {
        JpaTransactionManager transactionManager = new JpaTransactionManager();
        transactionManager.setEntityManagerFactory(postgresEntityManagerFactory().getObject());
        return transactionManager;
    }

    /**
     * Analytics Transaction Manager for PostgreSQL
     */
    @Bean
    public PlatformTransactionManager postgresAnalyticsTransactionManager() {
        JpaTransactionManager transactionManager = new JpaTransactionManager();
        transactionManager.setEntityManagerFactory(postgresAnalyticsEntityManagerFactory().getObject());
        return transactionManager;
    }

    /**
     * MongoDB Configuration
     */
    @Override
    protected String getDatabaseName() {
        return "ultrana_dex";
    }

    @Override
    protected String getMongoClientUri() {
        return mongoPrimaryUri;
    }

    /**
     * MongoDB Analytics Configuration
     */
    @Bean
    public MongoClient mongoAnalyticsClient() {
        return MongoClients.create(mongoAnalyticsUri);
    }

    /**
     * MongoDB Sharded Configuration
     */
    @Bean
    public MongoClient mongoShardedClient() {
        return MongoClients.create(mongoShardedUri);
    }

    /**
     * MongoDB Template for Primary Database
     */
    @Bean
    @Primary
    public MongoTemplate mongoTemplate() {
        return new MongoTemplate(mongoClient(), getDatabaseName());
    }

    /**
     * MongoDB Template for Analytics Database
     */
    @Bean
    public MongoTemplate mongoAnalyticsTemplate() {
        return new MongoTemplate(mongoAnalyticsClient(), "ultrana_analytics");
    }

    /**
     * MongoDB Template for Sharded Database
     */
    @Bean
    public MongoTemplate mongoShardedTemplate() {
        return new MongoTemplate(mongoShardedClient(), "ultrana_sharded");
    }
}
