use crate::catalog::CatalogStore;
use crate::domain::{
    CartItem, ConfirmPaymentRequest, CreateOrderRequest, InitiatePaymentRequest, Order, OrderItem,
    OrderStatus,
};
use crate::promotions::PromotionStore;
use crate::vat::calculate_vat;
use chrono::Utc;
use std::{collections::HashMap, sync::Arc};
use thiserror::Error;
use tokio::sync::RwLock;
use uuid::Uuid;

#[derive(Error, Debug)]
pub enum OrderError {
    #[error("product '{0}' not found or inactive")]
    ProductNotFound(String),
    #[error("product '{0}' has insufficient stock (requested {1}, available {2})")]
    InsufficientStock(String, u32, u32),
    #[error("order '{0}' not found")]
    OrderNotFound(String),
    #[error("invalid transition: cannot move from {0:?} to {1:?}")]
    InvalidTransition(OrderStatus, OrderStatus),
    #[error("{0}")]
    Other(String),
}

#[derive(Clone, Default)]
pub struct OrderStore {
    inner: Arc<RwLock<HashMap<String, Order>>>,
}

impl OrderStore {
    pub fn new() -> Self {
        Self::default()
    }

    pub async fn create(
        &self,
        req: CreateOrderRequest,
        catalog: &CatalogStore,
        promotions: &PromotionStore,
    ) -> Result<Order, OrderError> {
        if req.items.is_empty() {
            return Err(OrderError::Other("order must contain at least one item".into()));
        }

        let mut order_items: Vec<OrderItem> = Vec::new();
        let mut subtotal = 0.0_f64;

        for cart_item in &req.items {
            self.validate_cart_item(cart_item, catalog, &mut order_items, &mut subtotal)
                .await?;
        }

        // Apply promotion discount
        let discount = if let Some(ref code) = req.promotion_code {
            promotions.apply(code, subtotal).await.unwrap_or(0.0)
        } else {
            0.0
        };

        let net = (subtotal - discount).max(0.0);
        let vat = calculate_vat(net, &req.buyer_country);
        let total = net + vat;

        let now = Utc::now();
        let order = Order {
            id: Uuid::new_v4().to_string(),
            buyer_id: req.buyer_id,
            items: order_items,
            subtotal_eur: round2(subtotal),
            discount_eur: round2(discount),
            vat_eur: round2(vat),
            total_eur: round2(total),
            currency: req.currency.to_uppercase(),
            status: OrderStatus::Pending,
            quote_id: None,
            transfer_id: None,
            promotion_code: req.promotion_code,
            buyer_country: req.buyer_country.to_uppercase(),
            created_at: now,
            updated_at: now,
        };

        self.inner
            .write()
            .await
            .insert(order.id.clone(), order.clone());
        Ok(order)
    }

    pub async fn get(&self, id: &str) -> Option<Order> {
        self.inner.read().await.get(id).cloned()
    }

    pub async fn list_by_buyer(&self, buyer_id: &str) -> Vec<Order> {
        self.inner
            .read()
            .await
            .values()
            .filter(|o| o.buyer_id == buyer_id)
            .cloned()
            .collect()
    }

    /// Record that payment has been initiated; attach the routing-engine quote_id.
    pub async fn initiate_payment(
        &self,
        order_id: &str,
        req: InitiatePaymentRequest,
    ) -> Result<Order, OrderError> {
        self.transition(order_id, OrderStatus::PaymentInitiated, |o| {
            o.quote_id = Some(req.quote_id);
        })
        .await
    }

    /// Confirm settlement; attach the routing-engine transfer_id.
    pub async fn confirm_payment(
        &self,
        order_id: &str,
        req: ConfirmPaymentRequest,
    ) -> Result<Order, OrderError> {
        self.transition(order_id, OrderStatus::Settled, |o| {
            o.transfer_id = Some(req.transfer_id);
        })
        .await
    }

    /// Mark an order as fulfilled (goods shipped / service delivered).
    pub async fn fulfill(&self, order_id: &str) -> Result<Order, OrderError> {
        self.transition(order_id, OrderStatus::Fulfilled, |_| {}).await
    }

    /// Cancel a pending or payment-initiated order.
    pub async fn cancel(&self, order_id: &str) -> Result<Order, OrderError> {
        self.transition(order_id, OrderStatus::Cancelled, |_| {}).await
    }

    // ── private helpers ──────────────────────────────────────────────────────

    async fn validate_cart_item(
        &self,
        cart_item: &CartItem,
        catalog: &CatalogStore,
        order_items: &mut Vec<OrderItem>,
        subtotal: &mut f64,
    ) -> Result<(), OrderError> {
        if cart_item.quantity == 0 {
            return Err(OrderError::Other(format!(
                "quantity for product '{}' must be at least 1",
                cart_item.product_id
            )));
        }
        let product = catalog
            .get(&cart_item.product_id)
            .await
            .ok_or_else(|| OrderError::ProductNotFound(cart_item.product_id.clone()))?;

        if !product.active {
            return Err(OrderError::ProductNotFound(cart_item.product_id.clone()));
        }
        if product.stock < cart_item.quantity {
            return Err(OrderError::InsufficientStock(
                cart_item.product_id.clone(),
                cart_item.quantity,
                product.stock,
            ));
        }

        let line_total = product.price_eur * cart_item.quantity as f64;
        *subtotal += line_total;
        order_items.push(OrderItem {
            product_id: product.id,
            title: product.title,
            quantity: cart_item.quantity,
            unit_price_eur: product.price_eur,
            line_total_eur: round2(line_total),
        });
        Ok(())
    }

    async fn transition(
        &self,
        order_id: &str,
        next: OrderStatus,
        mutate: impl FnOnce(&mut Order),
    ) -> Result<Order, OrderError> {
        let mut store = self.inner.write().await;
        let order = store
            .get_mut(order_id)
            .ok_or_else(|| OrderError::OrderNotFound(order_id.to_string()))?;

        validate_transition(order.status, next)?;
        order.status = next;
        order.updated_at = Utc::now();
        mutate(order);
        Ok(order.clone())
    }
}

fn validate_transition(from: OrderStatus, to: OrderStatus) -> Result<(), OrderError> {
    let ok = matches!(
        (from, to),
        (OrderStatus::Pending, OrderStatus::PaymentInitiated)
            | (OrderStatus::Pending, OrderStatus::Cancelled)
            | (OrderStatus::PaymentInitiated, OrderStatus::Settled)
            | (OrderStatus::PaymentInitiated, OrderStatus::Cancelled)
            | (OrderStatus::Settled, OrderStatus::Fulfilled)
    );
    if ok {
        Ok(())
    } else {
        Err(OrderError::InvalidTransition(from, to))
    }
}

fn round2(v: f64) -> f64 {
    (v * 100.0).round() / 100.0
}
