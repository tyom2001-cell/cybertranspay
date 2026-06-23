use crate::domain::{CreatePromotionRequest, Promotion, PromotionKind, ValidatePromotionResponse};
use chrono::Utc;
use std::{collections::HashMap, sync::Arc};
use tokio::sync::RwLock;

#[derive(Clone, Default)]
pub struct PromotionStore {
    inner: Arc<RwLock<HashMap<String, Promotion>>>,
}

impl PromotionStore {
    pub fn new() -> Self {
        Self::default()
    }

    pub async fn create(&self, req: CreatePromotionRequest) -> Result<Promotion, String> {
        if req.value <= 0.0 {
            return Err("promotion value must be greater than zero".into());
        }
        if req.kind == PromotionKind::PercentOff && req.value > 100.0 {
            return Err("percent_off value must be between 0 and 100".into());
        }

        let mut store = self.inner.write().await;
        let code_upper = req.code.trim().to_uppercase();
        if store.contains_key(&code_upper) {
            return Err(format!("promotion code '{}' already exists", code_upper));
        }

        let promo = Promotion {
            code: code_upper.clone(),
            kind: req.kind,
            value: req.value,
            expires_at: req.expires_at,
            max_uses: req.max_uses,
            uses: 0,
            active: true,
            created_at: Utc::now(),
        };
        store.insert(code_upper, promo.clone());
        Ok(promo)
    }

    pub async fn get(&self, code: &str) -> Option<Promotion> {
        self.inner
            .read()
            .await
            .get(&code.trim().to_uppercase())
            .cloned()
    }

    pub async fn validate(&self, code: &str) -> ValidatePromotionResponse {
        let code_upper = code.trim().to_uppercase();
        let store = self.inner.read().await;
        match store.get(&code_upper) {
            None => ValidatePromotionResponse {
                code: code_upper,
                valid: false,
                kind: None,
                value: None,
                reason: Some("code not found".into()),
            },
            Some(promo) => {
                if !promo.active {
                    return ValidatePromotionResponse {
                        code: code_upper,
                        valid: false,
                        kind: None,
                        value: None,
                        reason: Some("promotion is no longer active".into()),
                    };
                }
                if let Some(exp) = promo.expires_at {
                    if Utc::now() > exp {
                        return ValidatePromotionResponse {
                            code: code_upper,
                            valid: false,
                            kind: None,
                            value: None,
                            reason: Some("promotion has expired".into()),
                        };
                    }
                }
                if let Some(max) = promo.max_uses {
                    if promo.uses >= max {
                        return ValidatePromotionResponse {
                            code: code_upper,
                            valid: false,
                            kind: None,
                            value: None,
                            reason: Some("promotion has reached its usage limit".into()),
                        };
                    }
                }
                ValidatePromotionResponse {
                    code: code_upper,
                    valid: true,
                    kind: Some(promo.kind),
                    value: Some(promo.value),
                    reason: None,
                }
            }
        }
    }

    /// Apply the promotion to a subtotal and return the discount amount in EUR.
    pub async fn apply(&self, code: &str, subtotal_eur: f64) -> Option<f64> {
        let validation = self.validate(code).await;
        if !validation.valid {
            return None;
        }
        let discount = match validation.kind? {
            PromotionKind::PercentOff => subtotal_eur * validation.value? / 100.0,
            PromotionKind::FixedEur => validation.value?.min(subtotal_eur),
        };
        // Increment use counter
        let code_upper = code.trim().to_uppercase();
        if let Some(promo) = self.inner.write().await.get_mut(&code_upper) {
            promo.uses += 1;
        }
        Some(discount)
    }
}
