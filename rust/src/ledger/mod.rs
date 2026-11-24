use serde::{Deserialize, Serialize};
use thiserror::Error;
use uuid::Uuid;

#[derive(Error, Debug, PartialEq, Eq)]
pub enum LedgerError {
    #[error("Transaction is unbalanced: sum of postings is {0}, expected 0")]
    UnbalancedTransaction(i64),
    #[error("Transaction must have at least 2 postings")]
    InsufficientPostings,
    #[error("Account not found: {0}")]
    AccountNotFound(Uuid),
    #[error("Duplicate account name: {0}")]
    DuplicateAccount(String),
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum AccountType {
    Asset,
    Liability,
    Equity,
    Income,
    Expense,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Account {
    pub id: Uuid,
    pub name: String,
    pub account_type: AccountType,
    pub currency: String, // ISO 4217 (e.g., "USD", "EUR")
    pub parent_id: Option<Uuid>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct Posting {
    pub account_id: Uuid,
    /// Amount in minor currency units (e.g. cents).
    /// Positive = Debit, Negative = Credit.
    pub amount: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Transaction {
    pub id: Uuid,
    pub timestamp_ms: i64,
    pub description: String,
    pub postings: Vec<Posting>,
    pub receipt_hashes: Vec<String>,
}

impl Transaction {
    /// Constructs and validates a double-entry transaction.
    /// Invariant: sum(postings.amount) == 0.
    pub fn new(
        description: String,
        timestamp_ms: i64,
        postings: Vec<Posting>,
        receipt_hashes: Vec<String>,
    ) -> Result<Self, LedgerError> {
        if postings.len() < 2 {
            return Err(LedgerError::InsufficientPostings);
        }

        let sum: i64 = postings.iter().map(|p| p.amount).sum();
        if sum != 0 {
            return Err(LedgerError::UnbalancedTransaction(sum));
        }

        Ok(Self {
            id: Uuid::new_v4(),
            timestamp_ms,
            description,
            postings,
            receipt_hashes,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_balanced_transaction() {
        let checking_id = Uuid::new_v4();
        let groceries_id = Uuid::new_v4();

        // Spend $50 at grocery store:
        // Debit Groceries Expense: +5000 cents
        // Credit Checking Account: -5000 cents
        let postings = vec![
            Posting { account_id: groceries_id, amount: 5000 },
            Posting { account_id: checking_id, amount: -5000 },
        ];

        let tx = Transaction::new("Supermarket".into(), 1700000000, postings, vec![]);
        assert!(tx.is_ok());
    }

    #[test]
    fn test_unbalanced_transaction_rejected() {
        let checking_id = Uuid::new_v4();
        let groceries_id = Uuid::new_v4();

        let postings = vec![
            Posting { account_id: groceries_id, amount: 5000 },
            Posting { account_id: checking_id, amount: -4000 }, // Off by $10
        ];

        let tx = Transaction::new("Supermarket".into(), 1700000000, postings, vec![]);
        assert_eq!(tx.unwrap_err(), LedgerError::UnbalancedTransaction(1000));
    }
}
