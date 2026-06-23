use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

// ── Product ──────────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Product {
    pub id: String,
    pub seller_id: String,
    pub title: String,
    pub description: String,
    pub category: String,
    pub tags: Vec<String>,
    pub price_eur: f64,
    pub stock: u32,
    pub image_url: Option<String>,
    pub active: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct CreateProductRequest {
    pub seller_id: String,
    pub title: String,
    pub description: String,
    pub category: String,
    #[serde(default)]
    pub tags: Vec<String>,
    pub price_eur: f64,
    pub stock: u32,
    pub image_url: Option<String>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct UpdateProductRequest {
    pub title: Option<String>,
    pub description: Option<String>,
    pub category: Option<String>,
    pub tags: Option<Vec<String>>,
    pub price_eur: Option<f64>,
    pub stock: Option<u32>,
    pub image_url: Option<String>,
    pub active: Option<bool>,
}

#[derive(Debug, Clone, Deserialize, Default)]
pub struct ProductFilter {
    pub category: Option<String>,
    pub seller_id: Option<String>,
    pub query: Option<String>,
    pub min_price_eur: Option<f64>,
    pub max_price_eur: Option<f64>,
    pub in_stock: Option<bool>,
}

// ── Order ─────────────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum OrderStatus {
    Pending,
    PaymentInitiated,
    Settled,
    Fulfilled,
    Cancelled,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OrderItem {
    pub product_id: String,
    pub title: String,
    pub quantity: u32,
    pub unit_price_eur: f64,
    pub line_total_eur: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Order {
    pub id: String,
    pub buyer_id: String,
    pub items: Vec<OrderItem>,
    pub subtotal_eur: f64,
    pub discount_eur: f64,
    pub vat_eur: f64,
    pub total_eur: f64,
    pub currency: String,
    pub status: OrderStatus,
    pub quote_id: Option<String>,
    pub transfer_id: Option<String>,
    pub promotion_code: Option<String>,
    pub buyer_country: String,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct CreateOrderRequest {
    pub buyer_id: String,
    pub items: Vec<CartItem>,
    pub promotion_code: Option<String>,
    pub buyer_country: String,
    /// ISO 4217 currency code the buyer wants to pay in (e.g. "EUR", "USDT")
    #[serde(default = "default_currency")]
    pub currency: String,
}

fn default_currency() -> String {
    "EUR".into()
}

#[derive(Debug, Clone, Deserialize)]
pub struct CartItem {
    pub product_id: String,
    pub quantity: u32,
}

#[derive(Debug, Clone, Deserialize)]
pub struct InitiatePaymentRequest {
    /// quote_id returned by the routing-engine /v1/routes/quote endpoint
    pub quote_id: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct ConfirmPaymentRequest {
    /// transfer_id returned by the routing-engine /v1/transfers endpoint
    pub transfer_id: String,
}

// ── Account ───────────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AccountKind {
    Buyer,
    Seller,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum KycStatus {
    Pending,
    Approved,
    Rejected,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Account {
    pub id: String,
    pub email: String,
    pub name: String,
    pub kind: AccountKind,
    /// ISO 3166-1 alpha-2 country code (e.g. "DE", "FR")
    pub country: String,
    pub kyc_status: KycStatus,
    /// Payment wallet address or bank IBAN (optional at registration)
    pub payment_ref: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct RegisterAccountRequest {
    pub email: String,
    pub name: String,
    pub kind: AccountKind,
    pub country: String,
    pub payment_ref: Option<String>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct UpdateAccountRequest {
    pub name: Option<String>,
    pub country: Option<String>,
    pub payment_ref: Option<String>,
    pub kyc_status: Option<KycStatus>,
}

// ── Promotion ─────────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum PromotionKind {
    /// Percentage discount (value is 0–100)
    PercentOff,
    /// Fixed EUR amount off
    FixedEur,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Promotion {
    pub code: String,
    pub kind: PromotionKind,
    pub value: f64,
    pub expires_at: Option<DateTime<Utc>>,
    pub max_uses: Option<u32>,
    pub uses: u32,
    pub active: bool,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct CreatePromotionRequest {
    pub code: String,
    pub kind: PromotionKind,
    pub value: f64,
    pub expires_at: Option<DateTime<Utc>>,
    pub max_uses: Option<u32>,
}

#[derive(Debug, Clone, Serialize)]
pub struct ValidatePromotionResponse {
    pub code: String,
    pub valid: bool,
    pub kind: Option<PromotionKind>,
    pub value: Option<f64>,
    pub reason: Option<String>,
}

// ── VAT ───────────────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize)]
pub struct VatRateResponse {
    pub country_code: String,
    pub rate: f64,
    pub rate_percent: f64,
}
