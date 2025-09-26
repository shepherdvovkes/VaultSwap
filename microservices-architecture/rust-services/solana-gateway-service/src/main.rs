use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    response::Json,
    routing::{get, post},
    Router,
};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;
use tower::ServiceBuilder;
use tower_http::{
    cors::CorsLayer,
    trace::TraceLayer,
};
use tracing::{info, warn};

mod config;
mod database;
mod metrics;
mod solana_client;
mod handlers;

use config::Config;
use database::Database;
use metrics::Metrics;
use solana_client::SolanaClient;

#[derive(Clone)]
pub struct AppState {
    pub config: Config,
    pub database: Arc<Database>,
    pub solana_client: Arc<SolanaClient>,
    pub metrics: Arc<Metrics>,
}

#[derive(Serialize, Deserialize)]
pub struct HealthResponse {
    pub status: String,
    pub timestamp: String,
    pub version: String,
}

#[derive(Serialize, Deserialize)]
pub struct SolanaAccountInfo {
    pub address: String,
    pub balance: u64,
    pub owner: String,
    pub executable: bool,
    pub rent_epoch: u64,
}

#[derive(Serialize, Deserialize)]
pub struct TransactionRequest {
    pub from: String,
    pub to: String,
    pub amount: u64,
    pub memo: Option<String>,
}

#[derive(Serialize, Deserialize)]
pub struct TransactionResponse {
    pub signature: String,
    pub status: String,
    pub slot: u64,
}

#[derive(Serialize, Deserialize)]
pub struct TokenBalance {
    pub mint: String,
    pub amount: u64,
    pub decimals: u8,
    pub ui_amount: f64,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Initialize tracing
    tracing_subscriber::fmt()
        .with_env_filter("solana_gateway_service=debug,tower_http=debug")
        .init();

    info!("Starting Solana Gateway Service");

    // Load configuration
    let config = Config::load()?;
    info!("Configuration loaded successfully");

    // Initialize database
    let database = Arc::new(Database::new(&config.database_url).await?);
    info!("Database connection established");

    // Initialize Solana client
    let solana_client = Arc::new(SolanaClient::new(&config.solana_rpc_url)?);
    info!("Solana client initialized");

    // Initialize metrics
    let metrics = Arc::new(Metrics::new()?);
    info!("Metrics initialized");

    // Create application state
    let state = AppState {
        config,
        database,
        solana_client,
        metrics,
    };

    // Build the application router
    let app = Router::new()
        .route("/health", get(health_check))
        .route("/metrics", get(handlers::metrics::get_metrics))
        .route("/api/v1/accounts/:address", get(get_account_info))
        .route("/api/v1/accounts/:address/balance", get(get_account_balance))
        .route("/api/v1/accounts/:address/tokens", get(get_token_balances))
        .route("/api/v1/transactions", post(create_transaction))
        .route("/api/v1/transactions/:signature", get(get_transaction))
        .route("/api/v1/tokens/:mint", get(get_token_info))
        .route("/api/v1/pools", get(get_pools))
        .route("/api/v1/pools/:pool_id", get(get_pool_info))
        .route("/api/v1/swap", post(execute_swap))
        .layer(
            ServiceBuilder::new()
                .layer(TraceLayer::new_for_http())
                .layer(CorsLayer::permissive())
        )
        .with_state(state);

    // Start the server
    let listener = tokio::net::TcpListener::bind("0.0.0.0:8080").await?;
    info!("Solana Gateway Service listening on 0.0.0.0:8080");

    axum::serve(listener, app).await?;

    Ok(())
}

async fn health_check() -> Json<HealthResponse> {
    Json(HealthResponse {
        status: "healthy".to_string(),
        timestamp: chrono::Utc::now().to_rfc3339(),
        version: env!("CARGO_PKG_VERSION").to_string(),
    })
}

async fn get_account_info(
    State(state): State<AppState>,
    Path(address): Path<String>,
) -> Result<Json<SolanaAccountInfo>, StatusCode> {
    match state.solana_client.get_account_info(&address).await {
        Ok(account_info) => Ok(Json(account_info)),
        Err(e) => {
            warn!("Failed to get account info for {}: {}", address, e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}

async fn get_account_balance(
    State(state): State<AppState>,
    Path(address): Path<String>,
) -> Result<Json<u64>, StatusCode> {
    match state.solana_client.get_balance(&address).await {
        Ok(balance) => Ok(Json(balance)),
        Err(e) => {
            warn!("Failed to get balance for {}: {}", address, e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}

async fn get_token_balances(
    State(state): State<AppState>,
    Path(address): Path<String>,
) -> Result<Json<Vec<TokenBalance>>, StatusCode> {
    match state.solana_client.get_token_balances(&address).await {
        Ok(balances) => Ok(Json(balances)),
        Err(e) => {
            warn!("Failed to get token balances for {}: {}", address, e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}

async fn create_transaction(
    State(state): State<AppState>,
    Json(request): Json<TransactionRequest>,
) -> Result<Json<TransactionResponse>, StatusCode> {
    match state.solana_client.create_transaction(&request).await {
        Ok(response) => Ok(Json(response)),
        Err(e) => {
            warn!("Failed to create transaction: {}", e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}

async fn get_transaction(
    State(state): State<AppState>,
    Path(signature): Path<String>,
) -> Result<Json<TransactionResponse>, StatusCode> {
    match state.solana_client.get_transaction(&signature).await {
        Ok(transaction) => Ok(Json(transaction)),
        Err(e) => {
            warn!("Failed to get transaction {}: {}", signature, e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}

async fn get_token_info(
    State(state): State<AppState>,
    Path(mint): Path<String>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    match state.solana_client.get_token_info(&mint).await {
        Ok(token_info) => Ok(Json(token_info)),
        Err(e) => {
            warn!("Failed to get token info for {}: {}", mint, e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}

async fn get_pools(
    State(state): State<AppState>,
    Query(params): Query<HashMap<String, String>>,
) -> Result<Json<Vec<serde_json::Value>>, StatusCode> {
    let limit = params.get("limit").and_then(|s| s.parse().ok()).unwrap_or(50);
    let offset = params.get("offset").and_then(|s| s.parse().ok()).unwrap_or(0);

    match state.solana_client.get_pools(limit, offset).await {
        Ok(pools) => Ok(Json(pools)),
        Err(e) => {
            warn!("Failed to get pools: {}", e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}

async fn get_pool_info(
    State(state): State<AppState>,
    Path(pool_id): Path<String>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    match state.solana_client.get_pool_info(&pool_id).await {
        Ok(pool_info) => Ok(Json(pool_info)),
        Err(e) => {
            warn!("Failed to get pool info for {}: {}", pool_id, e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}

async fn execute_swap(
    State(state): State<AppState>,
    Json(request): Json<serde_json::Value>,
) -> Result<Json<TransactionResponse>, StatusCode> {
    match state.solana_client.execute_swap(&request).await {
        Ok(response) => Ok(Json(response)),
        Err(e) => {
            warn!("Failed to execute swap: {}", e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}
