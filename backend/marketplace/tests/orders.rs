use axum::{
    routing::{get, post},
    Router,
};
use http_body_util::BodyExt;
use marketplace::{api, AppState};
use tower::ServiceExt;

async fn body_json(r: axum::response::Response) -> serde_json::Value {
    let bytes = r.into_body().collect().await.unwrap().to_bytes();
    serde_json::from_slice(&bytes).unwrap()
}

/// Seed a product and return its id.
async fn seed_product(state: &AppState) -> String {
    let body = r#"{"seller_id":"seller-1","title":"Test Book","description":"A great book","category":"Books","price_eur":25.0,"stock":100}"#;
    let app = Router::new()
        .route("/v1/marketplace/products", post(api::create_product))
        .with_state(state.clone());
    let res = app
        .oneshot(
            axum::http::Request::builder()
                .method("POST")
                .uri("/v1/marketplace/products")
                .header("content-type", "application/json")
                .body(axum::body::Body::from(body))
                .unwrap(),
        )
        .await
        .unwrap();
    let json = body_json(res).await;
    json["id"].as_str().unwrap().to_string()
}

fn order_app(state: AppState) -> Router {
    Router::new()
        .route("/v1/marketplace/products", post(api::create_product))
        .route("/v1/marketplace/orders", post(api::create_order))
        .route("/v1/marketplace/orders", get(api::list_orders))
        .route("/v1/marketplace/orders/:id", get(api::get_order))
        .route("/v1/marketplace/orders/:id/pay", post(api::initiate_payment))
        .route("/v1/marketplace/orders/:id/confirm", post(api::confirm_payment))
        .route("/v1/marketplace/orders/:id/fulfill", post(api::fulfill_order))
        .route("/v1/marketplace/orders/:id/cancel", post(api::cancel_order))
        .with_state(state)
}

#[tokio::test]
async fn create_order_and_full_lifecycle() {
    let state = AppState::new();
    let product_id = seed_product(&state).await;

    let app = order_app(state);

    // Create order
    let body = format!(
        r#"{{"buyer_id":"buyer-1","items":[{{"product_id":"{product_id}","quantity":2}}],"buyer_country":"DE","currency":"EUR"}}"#
    );
    let res = app
        .clone()
        .oneshot(
            axum::http::Request::builder()
                .method("POST")
                .uri("/v1/marketplace/orders")
                .header("content-type", "application/json")
                .body(axum::body::Body::from(body))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(res.status(), axum::http::StatusCode::CREATED);
    let json = body_json(res).await;
    assert_eq!(json["status"], "pending");
    assert_eq!(json["buyer_country"], "DE");
    // 2 × 25 EUR = 50 EUR subtotal; 19% VAT = 9.5 EUR; total = 59.5 EUR
    let subtotal = json["subtotal_eur"].as_f64().unwrap();
    let vat = json["vat_eur"].as_f64().unwrap();
    let total = json["total_eur"].as_f64().unwrap();
    assert!((subtotal - 50.0).abs() < 0.01);
    assert!((vat - 9.5).abs() < 0.01);
    assert!((total - 59.5).abs() < 0.01);

    let order_id = json["id"].as_str().unwrap().to_string();

    // Initiate payment
    let pay_body = r#"{"quote_id":"quote-abc-123"}"#;
    let res = app
        .clone()
        .oneshot(
            axum::http::Request::builder()
                .method("POST")
                .uri(format!("/v1/marketplace/orders/{order_id}/pay"))
                .header("content-type", "application/json")
                .body(axum::body::Body::from(pay_body))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(res.status(), axum::http::StatusCode::OK);
    let json = body_json(res).await;
    assert_eq!(json["status"], "payment_initiated");
    assert_eq!(json["quote_id"], "quote-abc-123");

    // Confirm payment
    let confirm_body = r#"{"transfer_id":"transfer-xyz-456"}"#;
    let res = app
        .clone()
        .oneshot(
            axum::http::Request::builder()
                .method("POST")
                .uri(format!("/v1/marketplace/orders/{order_id}/confirm"))
                .header("content-type", "application/json")
                .body(axum::body::Body::from(confirm_body))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(res.status(), axum::http::StatusCode::OK);
    let json = body_json(res).await;
    assert_eq!(json["status"], "settled");
    assert_eq!(json["transfer_id"], "transfer-xyz-456");

    // Fulfill
    let res = app
        .clone()
        .oneshot(
            axum::http::Request::builder()
                .method("POST")
                .uri(format!("/v1/marketplace/orders/{order_id}/fulfill"))
                .body(axum::body::Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(res.status(), axum::http::StatusCode::OK);
    let json = body_json(res).await;
    assert_eq!(json["status"], "fulfilled");
}

#[tokio::test]
async fn cancel_pending_order() {
    let state = AppState::new();
    let product_id = seed_product(&state).await;
    let app = order_app(state);

    let body = format!(
        r#"{{"buyer_id":"buyer-2","items":[{{"product_id":"{product_id}","quantity":1}}],"buyer_country":"FR","currency":"EUR"}}"#
    );
    let res = app
        .clone()
        .oneshot(
            axum::http::Request::builder()
                .method("POST")
                .uri("/v1/marketplace/orders")
                .header("content-type", "application/json")
                .body(axum::body::Body::from(body))
                .unwrap(),
        )
        .await
        .unwrap();
    let json = body_json(res).await;
    let order_id = json["id"].as_str().unwrap().to_string();

    let res = app
        .oneshot(
            axum::http::Request::builder()
                .method("POST")
                .uri(format!("/v1/marketplace/orders/{order_id}/cancel"))
                .body(axum::body::Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(res.status(), axum::http::StatusCode::OK);
    let json = body_json(res).await;
    assert_eq!(json["status"], "cancelled");
}

#[tokio::test]
async fn invalid_state_transition_returns_400() {
    let state = AppState::new();
    let product_id = seed_product(&state).await;
    let app = order_app(state);

    let body = format!(
        r#"{{"buyer_id":"buyer-3","items":[{{"product_id":"{product_id}","quantity":1}}],"buyer_country":"NL","currency":"EUR"}}"#
    );
    let res = app
        .clone()
        .oneshot(
            axum::http::Request::builder()
                .method("POST")
                .uri("/v1/marketplace/orders")
                .header("content-type", "application/json")
                .body(axum::body::Body::from(body))
                .unwrap(),
        )
        .await
        .unwrap();
    let json = body_json(res).await;
    let order_id = json["id"].as_str().unwrap().to_string();

    // Try to fulfill a PENDING order (invalid — must go through payment first)
    let res = app
        .oneshot(
            axum::http::Request::builder()
                .method("POST")
                .uri(format!("/v1/marketplace/orders/{order_id}/fulfill"))
                .body(axum::body::Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(res.status(), axum::http::StatusCode::BAD_REQUEST);
}

#[tokio::test]
async fn order_with_unknown_product_returns_404() {
    let state = AppState::new();
    let app = order_app(state);

    let body = r#"{"buyer_id":"buyer-4","items":[{"product_id":"ghost-product","quantity":1}],"buyer_country":"IT","currency":"EUR"}"#;
    let res = app
        .oneshot(
            axum::http::Request::builder()
                .method("POST")
                .uri("/v1/marketplace/orders")
                .header("content-type", "application/json")
                .body(axum::body::Body::from(body))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(res.status(), axum::http::StatusCode::NOT_FOUND);
}

#[tokio::test]
async fn promotion_discount_applied_to_order() {
    let state = AppState::new();
    let product_id = seed_product(&state).await;

    // Create a 10% off promotion
    let promo_app = Router::new()
        .route("/v1/marketplace/promotions", post(api::create_promotion))
        .with_state(state.clone());
    let promo_body = r#"{"code":"SAVE10","kind":"percent_off","value":10}"#;
    promo_app
        .oneshot(
            axum::http::Request::builder()
                .method("POST")
                .uri("/v1/marketplace/promotions")
                .header("content-type", "application/json")
                .body(axum::body::Body::from(promo_body))
                .unwrap(),
        )
        .await
        .unwrap();

    let app = order_app(state);
    let body = format!(
        r#"{{"buyer_id":"buyer-5","items":[{{"product_id":"{product_id}","quantity":4}}],"buyer_country":"ES","currency":"EUR","promotion_code":"SAVE10"}}"#
    );
    let res = app
        .oneshot(
            axum::http::Request::builder()
                .method("POST")
                .uri("/v1/marketplace/orders")
                .header("content-type", "application/json")
                .body(axum::body::Body::from(body))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(res.status(), axum::http::StatusCode::CREATED);
    let json = body_json(res).await;
    // 4 × 25 = 100 EUR subtotal; 10% off = 10 EUR discount; net = 90; 21% VAT (ES) = 18.9; total = 108.9
    let subtotal = json["subtotal_eur"].as_f64().unwrap();
    let discount = json["discount_eur"].as_f64().unwrap();
    let total = json["total_eur"].as_f64().unwrap();
    assert!((subtotal - 100.0).abs() < 0.01);
    assert!((discount - 10.0).abs() < 0.01);
    assert!((total - 108.9).abs() < 0.01);
}
