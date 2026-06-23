use crate::domain::{
    Account, AccountKind, ConfirmPaymentRequest, CreateOrderRequest,
    CreateProductRequest, CreatePromotionRequest, InitiatePaymentRequest, Order,
    Product, ProductFilter, Promotion, RegisterAccountRequest, UpdateAccountRequest,
    UpdateProductRequest, ValidatePromotionResponse, VatRateResponse,
};
use crate::orders::OrderError;
use crate::vat::vat_rate;
use crate::AppState;
use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    response::{IntoResponse, Response},
    Json,
};
use serde::{Deserialize, Serialize};
use thiserror::Error;

// ── Error types ───────────────────────────────────────────────────────────────

#[derive(Error, Debug)]
pub enum ApiError {
    #[error("invalid request: {0}")]
    BadRequest(String),
    #[error("not found: {0}")]
    NotFound(String),
    #[error("conflict: {0}")]
    Conflict(String),
}

#[derive(Serialize)]
struct ErrorBody {
    error: String,
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        let (status, msg) = match &self {
            ApiError::BadRequest(m) => (StatusCode::BAD_REQUEST, m.clone()),
            ApiError::NotFound(m) => (StatusCode::NOT_FOUND, m.clone()),
            ApiError::Conflict(m) => (StatusCode::CONFLICT, m.clone()),
        };
        (status, Json(ErrorBody { error: msg })).into_response()
    }
}

impl From<OrderError> for ApiError {
    fn from(e: OrderError) -> Self {
        match e {
            OrderError::OrderNotFound(_) | OrderError::ProductNotFound(_) => {
                ApiError::NotFound(e.to_string())
            }
            OrderError::InvalidTransition(_, _) => ApiError::BadRequest(e.to_string()),
            _ => ApiError::BadRequest(e.to_string()),
        }
    }
}

// ── Catalog handlers ──────────────────────────────────────────────────────────

#[derive(Serialize)]
pub struct ProductListResponse {
    pub products: Vec<Product>,
    pub count: usize,
}

#[derive(Serialize)]
pub struct CategoriesResponse {
    pub categories: Vec<String>,
}

pub async fn list_products(
    State(state): State<AppState>,
    Query(filter): Query<ProductFilter>,
) -> Json<ProductListResponse> {
    let products = state.catalog.list(&filter).await;
    let count = products.len();
    Json(ProductListResponse { products, count })
}

pub async fn create_product(
    State(state): State<AppState>,
    Json(req): Json<CreateProductRequest>,
) -> Result<(StatusCode, Json<Product>), ApiError> {
    if req.title.trim().is_empty() {
        return Err(ApiError::BadRequest("title is required".into()));
    }
    if req.seller_id.trim().is_empty() {
        return Err(ApiError::BadRequest("seller_id is required".into()));
    }
    if req.price_eur <= 0.0 || !req.price_eur.is_finite() {
        return Err(ApiError::BadRequest("price_eur must be greater than zero".into()));
    }
    if req.category.trim().is_empty() {
        return Err(ApiError::BadRequest("category is required".into()));
    }

    let product = state.catalog.insert(req).await;
    Ok((StatusCode::CREATED, Json(product)))
}

pub async fn get_product(
    State(state): State<AppState>,
    Path(id): Path<String>,
) -> Result<Json<Product>, ApiError> {
    state
        .catalog
        .get(&id)
        .await
        .map(Json)
        .ok_or_else(|| ApiError::NotFound(format!("product '{id}' not found")))
}

pub async fn update_product(
    State(state): State<AppState>,
    Path(id): Path<String>,
    Json(req): Json<UpdateProductRequest>,
) -> Result<Json<Product>, ApiError> {
    if let Some(ref title) = req.title {
        if title.trim().is_empty() {
            return Err(ApiError::BadRequest("title must not be empty".into()));
        }
    }
    if let Some(price) = req.price_eur {
        if price <= 0.0 || !price.is_finite() {
            return Err(ApiError::BadRequest("price_eur must be greater than zero".into()));
        }
    }
    state
        .catalog
        .update(&id, req)
        .await
        .map(Json)
        .ok_or_else(|| ApiError::NotFound(format!("product '{id}' not found")))
}

pub async fn delete_product(
    State(state): State<AppState>,
    Path(id): Path<String>,
) -> Result<StatusCode, ApiError> {
    if state.catalog.delete(&id).await {
        Ok(StatusCode::NO_CONTENT)
    } else {
        Err(ApiError::NotFound(format!("product '{id}' not found")))
    }
}

pub async fn list_categories(State(state): State<AppState>) -> Json<CategoriesResponse> {
    let categories = state.catalog.categories().await;
    Json(CategoriesResponse { categories })
}

// ── Order handlers ────────────────────────────────────────────────────────────

pub async fn create_order(
    State(state): State<AppState>,
    Json(req): Json<CreateOrderRequest>,
) -> Result<(StatusCode, Json<Order>), ApiError> {
    if req.buyer_id.trim().is_empty() {
        return Err(ApiError::BadRequest("buyer_id is required".into()));
    }
    let order = state
        .orders
        .create(req, &state.catalog, &state.promotions)
        .await?;
    Ok((StatusCode::CREATED, Json(order)))
}

pub async fn get_order(
    State(state): State<AppState>,
    Path(id): Path<String>,
) -> Result<Json<Order>, ApiError> {
    state
        .orders
        .get(&id)
        .await
        .map(Json)
        .ok_or_else(|| ApiError::NotFound(format!("order '{id}' not found")))
}

#[derive(Deserialize)]
pub struct BuyerQuery {
    pub buyer_id: String,
}

#[derive(Serialize)]
pub struct OrderListResponse {
    pub orders: Vec<Order>,
    pub count: usize,
}

pub async fn list_orders(
    State(state): State<AppState>,
    Query(q): Query<BuyerQuery>,
) -> Json<OrderListResponse> {
    let orders = state.orders.list_by_buyer(&q.buyer_id).await;
    let count = orders.len();
    Json(OrderListResponse { orders, count })
}

pub async fn initiate_payment(
    State(state): State<AppState>,
    Path(id): Path<String>,
    Json(req): Json<InitiatePaymentRequest>,
) -> Result<Json<Order>, ApiError> {
    if req.quote_id.trim().is_empty() {
        return Err(ApiError::BadRequest("quote_id is required".into()));
    }
    let order = state.orders.initiate_payment(&id, req).await?;
    Ok(Json(order))
}

pub async fn confirm_payment(
    State(state): State<AppState>,
    Path(id): Path<String>,
    Json(req): Json<ConfirmPaymentRequest>,
) -> Result<Json<Order>, ApiError> {
    if req.transfer_id.trim().is_empty() {
        return Err(ApiError::BadRequest("transfer_id is required".into()));
    }
    let order = state.orders.confirm_payment(&id, req).await?;
    Ok(Json(order))
}

pub async fn fulfill_order(
    State(state): State<AppState>,
    Path(id): Path<String>,
) -> Result<Json<Order>, ApiError> {
    let order = state.orders.fulfill(&id).await?;
    Ok(Json(order))
}

pub async fn cancel_order(
    State(state): State<AppState>,
    Path(id): Path<String>,
) -> Result<Json<Order>, ApiError> {
    let order = state.orders.cancel(&id).await?;
    Ok(Json(order))
}

// ── Account handlers ──────────────────────────────────────────────────────────

pub async fn register_account(
    State(state): State<AppState>,
    Json(req): Json<RegisterAccountRequest>,
) -> Result<(StatusCode, Json<Account>), ApiError> {
    if req.email.trim().is_empty() {
        return Err(ApiError::BadRequest("email is required".into()));
    }
    if req.name.trim().is_empty() {
        return Err(ApiError::BadRequest("name is required".into()));
    }
    if req.country.trim().is_empty() {
        return Err(ApiError::BadRequest("country is required".into()));
    }
    let account = state.accounts.register(req).await;
    Ok((StatusCode::CREATED, Json(account)))
}

pub async fn get_account(
    State(state): State<AppState>,
    Path(id): Path<String>,
) -> Result<Json<Account>, ApiError> {
    state
        .accounts
        .get(&id)
        .await
        .map(Json)
        .ok_or_else(|| ApiError::NotFound(format!("account '{id}' not found")))
}

pub async fn update_account(
    State(state): State<AppState>,
    Path(id): Path<String>,
    Json(req): Json<UpdateAccountRequest>,
) -> Result<Json<Account>, ApiError> {
    state
        .accounts
        .update(&id, req)
        .await
        .map(Json)
        .ok_or_else(|| ApiError::NotFound(format!("account '{id}' not found")))
}

#[derive(Deserialize)]
pub struct KindQuery {
    pub kind: AccountKind,
}

#[derive(Serialize)]
pub struct AccountListResponse {
    pub accounts: Vec<Account>,
    pub count: usize,
}

pub async fn list_sellers(State(state): State<AppState>) -> Json<AccountListResponse> {
    let accounts = state.accounts.list_by_kind(AccountKind::Seller).await;
    let count = accounts.len();
    Json(AccountListResponse { accounts, count })
}

// ── Promotion handlers ────────────────────────────────────────────────────────

pub async fn create_promotion(
    State(state): State<AppState>,
    Json(req): Json<CreatePromotionRequest>,
) -> Result<(StatusCode, Json<Promotion>), ApiError> {
    if req.code.trim().is_empty() {
        return Err(ApiError::BadRequest("code is required".into()));
    }
    state
        .promotions
        .create(req)
        .await
        .map(|p| (StatusCode::CREATED, Json(p)))
        .map_err(ApiError::Conflict)
}

pub async fn get_promotion(
    State(state): State<AppState>,
    Path(code): Path<String>,
) -> Result<Json<Promotion>, ApiError> {
    state
        .promotions
        .get(&code)
        .await
        .map(Json)
        .ok_or_else(|| ApiError::NotFound(format!("promotion '{code}' not found")))
}

#[derive(Deserialize)]
pub struct ValidateBody {
    pub code: String,
}

pub async fn validate_promotion(
    State(state): State<AppState>,
    Json(body): Json<ValidateBody>,
) -> Json<ValidatePromotionResponse> {
    Json(state.promotions.validate(&body.code).await)
}

// ── VAT handler ───────────────────────────────────────────────────────────────

pub async fn get_vat_rate(Path(country): Path<String>) -> Json<VatRateResponse> {
    let rate = vat_rate(&country);
    Json(VatRateResponse {
        country_code: country.to_uppercase(),
        rate,
        rate_percent: rate * 100.0,
    })
}

// ── Health ────────────────────────────────────────────────────────────────────

#[derive(Serialize)]
pub struct HealthResponse {
    pub status: &'static str,
    pub service: &'static str,
    pub version: &'static str,
}

pub async fn health() -> Json<HealthResponse> {
    Json(HealthResponse {
        status: "ok",
        service: "marketplace",
        version: env!("CARGO_PKG_VERSION"),
    })
}
