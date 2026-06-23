use axum::{
    routing::{get, post, put, delete},
    Router,
};
use marketplace::{api, AppState};
use std::net::SocketAddr;
use tower_http::cors::{Any, CorsLayer};
use tower_http::trace::TraceLayer;
use tracing_subscriber::EnvFilter;

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::from_default_env())
        .init();

    let state = AppState::new();

    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    let app = Router::new()
        // Health
        .route("/health", get(api::health))
        // Catalog
        .route("/v1/marketplace/products", get(api::list_products))
        .route("/v1/marketplace/products", post(api::create_product))
        .route("/v1/marketplace/products/:id", get(api::get_product))
        .route("/v1/marketplace/products/:id", put(api::update_product))
        .route("/v1/marketplace/products/:id", delete(api::delete_product))
        .route("/v1/marketplace/categories", get(api::list_categories))
        // Orders
        .route("/v1/marketplace/orders", post(api::create_order))
        .route("/v1/marketplace/orders", get(api::list_orders))
        .route("/v1/marketplace/orders/:id", get(api::get_order))
        .route("/v1/marketplace/orders/:id/pay", post(api::initiate_payment))
        .route("/v1/marketplace/orders/:id/confirm", post(api::confirm_payment))
        .route("/v1/marketplace/orders/:id/fulfill", post(api::fulfill_order))
        .route("/v1/marketplace/orders/:id/cancel", post(api::cancel_order))
        // Accounts
        .route("/v1/marketplace/accounts", post(api::register_account))
        .route("/v1/marketplace/accounts/:id", get(api::get_account))
        .route("/v1/marketplace/accounts/:id", put(api::update_account))
        .route("/v1/marketplace/sellers", get(api::list_sellers))
        // Promotions
        .route("/v1/marketplace/promotions", post(api::create_promotion))
        .route("/v1/marketplace/promotions/:code", get(api::get_promotion))
        .route("/v1/marketplace/promotions/validate", post(api::validate_promotion))
        // VAT
        .route("/v1/marketplace/vat/:country", get(api::get_vat_rate))
        .layer(cors)
        .layer(TraceLayer::new_for_http())
        .with_state(state);

    let port: u16 = std::env::var("PORT")
        .ok()
        .and_then(|p| p.parse().ok())
        .unwrap_or(8081);
    let addr = SocketAddr::from(([0, 0, 0, 0], port));
    tracing::info!("marketplace listening on {addr}");
    let listener = tokio::net::TcpListener::bind(addr).await.expect("bind");
    axum::serve(listener, app).await.expect("serve");
}
