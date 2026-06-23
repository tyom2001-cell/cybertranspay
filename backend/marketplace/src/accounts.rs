use crate::domain::{
    Account, AccountKind, KycStatus, RegisterAccountRequest, UpdateAccountRequest,
};
use chrono::Utc;
use std::{collections::HashMap, sync::Arc};
use tokio::sync::RwLock;
use uuid::Uuid;

#[derive(Clone, Default)]
pub struct AccountStore {
    inner: Arc<RwLock<HashMap<String, Account>>>,
}

impl AccountStore {
    pub fn new() -> Self {
        Self::default()
    }

    pub async fn register(&self, req: RegisterAccountRequest) -> Account {
        let now = Utc::now();
        let account = Account {
            id: Uuid::new_v4().to_string(),
            email: req.email,
            name: req.name,
            kind: req.kind,
            country: req.country.to_uppercase(),
            kyc_status: KycStatus::Pending,
            payment_ref: req.payment_ref,
            created_at: now,
            updated_at: now,
        };
        self.inner
            .write()
            .await
            .insert(account.id.clone(), account.clone());
        account
    }

    pub async fn get(&self, id: &str) -> Option<Account> {
        self.inner.read().await.get(id).cloned()
    }

    pub async fn update(&self, id: &str, req: UpdateAccountRequest) -> Option<Account> {
        let mut store = self.inner.write().await;
        let account = store.get_mut(id)?;
        if let Some(v) = req.name {
            account.name = v;
        }
        if let Some(v) = req.country {
            account.country = v.to_uppercase();
        }
        if let Some(v) = req.payment_ref {
            account.payment_ref = Some(v);
        }
        if let Some(v) = req.kyc_status {
            account.kyc_status = v;
        }
        account.updated_at = Utc::now();
        Some(account.clone())
    }

    pub async fn list_by_kind(&self, kind: AccountKind) -> Vec<Account> {
        self.inner
            .read()
            .await
            .values()
            .filter(|a| a.kind == kind)
            .cloned()
            .collect()
    }
}
