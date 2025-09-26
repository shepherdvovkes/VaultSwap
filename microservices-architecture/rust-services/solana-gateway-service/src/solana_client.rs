use crate::config::Config;
use anyhow::Result;
use serde::{Deserialize, Serialize};
use solana_client::rpc_client::RpcClient;
use solana_sdk::{
    commitment_config::CommitmentConfig,
    pubkey::Pubkey,
    signature::Signature,
    transaction::Transaction,
};
use std::str::FromStr;

#[derive(Clone)]
pub struct SolanaClient {
    rpc_client: RpcClient,
}

#[derive(Serialize, Deserialize)]
pub struct AccountInfo {
    pub address: String,
    pub balance: u64,
    pub owner: String,
    pub executable: bool,
    pub rent_epoch: u64,
}

#[derive(Serialize, Deserialize)]
pub struct TokenBalance {
    pub mint: String,
    pub amount: u64,
    pub decimals: u8,
    pub ui_amount: f64,
}

#[derive(Serialize, Deserialize)]
pub struct TransactionInfo {
    pub signature: String,
    pub status: String,
    pub slot: u64,
}

impl SolanaClient {
    pub fn new(rpc_url: &str) -> Result<Self> {
        let rpc_client = RpcClient::new_with_commitment(
            rpc_url.to_string(),
            CommitmentConfig::confirmed(),
        );

        Ok(Self { rpc_client })
    }

    pub async fn get_account_info(&self, address: &str) -> Result<AccountInfo> {
        let pubkey = Pubkey::from_str(address)?;
        let account = self.rpc_client.get_account(&pubkey)?;

        Ok(AccountInfo {
            address: address.to_string(),
            balance: account.lamports,
            owner: account.owner.to_string(),
            executable: account.executable,
            rent_epoch: account.rent_epoch,
        })
    }

    pub async fn get_balance(&self, address: &str) -> Result<u64> {
        let pubkey = Pubkey::from_str(address)?;
        let balance = self.rpc_client.get_balance(&pubkey)?;
        Ok(balance)
    }

    pub async fn get_token_balances(&self, address: &str) -> Result<Vec<TokenBalance>> {
        let pubkey = Pubkey::from_str(address)?;
        
        // Get all token accounts for the address
        let token_accounts = self.rpc_client.get_token_accounts_by_owner(
            &pubkey,
            solana_client::rpc_request::TokenAccountsFilter::ProgramId(
                spl_token::id(),
            ),
        )?;

        let mut balances = Vec::new();
        
        for account in token_accounts {
            if let Ok(account_data) = spl_token::state::Account::unpack(&account.account.data) {
                balances.push(TokenBalance {
                    mint: account_data.mint.to_string(),
                    amount: account_data.amount,
                    decimals: 0, // Would need to fetch from mint account
                    ui_amount: account_data.amount as f64 / 10_f64.powi(0), // Would use actual decimals
                });
            }
        }

        Ok(balances)
    }

    pub async fn create_transaction(&self, request: &crate::TransactionRequest) -> Result<TransactionInfo> {
        // This is a simplified implementation
        // In a real implementation, you would:
        // 1. Create a proper Solana transaction
        // 2. Sign it with the appropriate keypair
        // 3. Send it to the network
        // 4. Return the transaction signature

        let signature = Signature::new_unique();
        
        Ok(TransactionInfo {
            signature: signature.to_string(),
            status: "pending".to_string(),
            slot: 0, // Would get from transaction confirmation
        })
    }

    pub async fn get_transaction(&self, signature: &str) -> Result<TransactionInfo> {
        let sig = Signature::from_str(signature)?;
        let transaction = self.rpc_client.get_transaction(&sig, solana_client::rpc_config::RpcTransactionConfig::default())?;

        Ok(TransactionInfo {
            signature: signature.to_string(),
            status: if transaction.meta.as_ref().map_or(false, |m| m.err.is_none()) {
                "confirmed".to_string()
            } else {
                "failed".to_string()
            },
            slot: transaction.slot,
        })
    }

    pub async fn get_token_info(&self, mint: &str) -> Result<serde_json::Value> {
        let pubkey = Pubkey::from_str(mint)?;
        let account = self.rpc_client.get_account(&pubkey)?;
        
        if let Ok(mint_data) = spl_token::state::Mint::unpack(&account.data) {
            Ok(serde_json::json!({
                "mint": mint,
                "supply": mint_data.supply,
                "decimals": mint_data.decimals,
                "mint_authority": mint_data.mint_authority.map(|p| p.to_string()),
                "freeze_authority": mint_data.freeze_authority.map(|p| p.to_string()),
            }))
        } else {
            Err(anyhow::anyhow!("Invalid mint account"))
        }
    }

    pub async fn get_pools(&self, limit: usize, offset: usize) -> Result<Vec<serde_json::Value>> {
        // This would typically query a DEX program for available pools
        // For now, return mock data
        Ok(vec![
            serde_json::json!({
                "id": "pool_1",
                "token_a": "So11111111111111111111111111111111111111112",
                "token_b": "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",
                "liquidity": 1000000,
                "volume_24h": 50000
            })
        ])
    }

    pub async fn get_pool_info(&self, pool_id: &str) -> Result<serde_json::Value> {
        // This would query the specific pool
        Ok(serde_json::json!({
            "id": pool_id,
            "token_a": "So11111111111111111111111111111111111111112",
            "token_b": "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",
            "liquidity": 1000000,
            "volume_24h": 50000,
            "fees_24h": 1000
        }))
    }

    pub async fn execute_swap(&self, request: &serde_json::Value) -> Result<TransactionInfo> {
        // This would execute a swap transaction
        let signature = Signature::new_unique();
        
        Ok(TransactionInfo {
            signature: signature.to_string(),
            status: "pending".to_string(),
            slot: 0,
        })
    }
}
