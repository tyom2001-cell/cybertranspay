use axum::{
    routing::{delete, get, post, put},
    Router,
};
use http_body_util::BodyExt;
use marketplace::{api, AppState};
use tower::ServiceExt;

fn app() -> Router {
    Router::new()
        .route("/v1/marketplace/products", get(api::list_products))
        .route("/v1/marketplace/products", post(api::create_product))
        .route("/v1/marketplace/products/:id", get(api::get_product))
        .route("/v1/marketplace/products/:id", put(api::update_product))
        .route("/v1/marketplace/products/:id", delete(api::delete_product))
        .route("/v1/marketplace/categories", get(api::list_categories))
        .with_state(AppState::new())
}

async fn body_json(r: axum::response::Response) -> serde_json::Value {
    let bytes = r.into_body().collect().await.unwrap().to_bytes();
    serde_json::from_slice(&bytes).unwrap()
}

#[tokio::test]
async fn create_and_get_product() {
    let app = app();

    let body = r#"{
        "seller_id": "seller-1",
        "title": "Wireless Headphones",
        "description": "Over-ear noise-cancelling headphones",
        "category": "Electronics",
        "tags": ["audio", "wireless"],
        "price_eur": 149.99,
        "stock": 50
    }"#;

    let create_res = app
        .clone()
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

    assert_eq!(create_res.status(), axum::http::StatusCode::CREATED);
    let json = body_json(create_res).await;
    assert_eq!(json["title"], "Wireless Headphones");
    assert_eq!(json["category"], "Electronics");
    assert!((json["price_eur"].as_f64().unwrap() - 149.99).abs() < 1e-9);
    assert_eq!(json["active"], true);

    let id = json["id"].as_str().unwrap().to_string();

    // GET the product back
    let get_res = app
        .oneshot(
            axum::http::Request::builder()
                .method("GET")
                .uri(format!("/v1/marketplace/products/{id}"))
                .body(axum::body::Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(get_res.status(), axum::http::StatusCode::OK);
    let json2 = body_json(get_res).await;
    assert_eq!(json2["id"], id);
}

#[tokio::test]
async fn list_products_with_filter() {
    let state = AppState::new();

    // Seed two products in different categories
    let app = Router::new()
        .route("/v1/marketplace/products", post(api::create_product))
        .route("/v1/marketplace/products", get(api::list_products))
        .with_state(state);

    for (title, cat, price) in [
        ("Laptop", "Electronics", 999.0),
        ("Office Chair", "Furniture", 299.0),
    ] {
        let body = format!(
            r#"{{"seller_id":"s1","title":"{title}","description":"desc","category":"{cat}","price_eur":{price},"stock":10}}"#
        );
        app.clone()
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
    }

    // Filter by category=Electronics
    let res = app
        .oneshot(
            axum::http::Request::builder()
                .method("GET")
                .uri("/v1/marketplace/products?category=Electronics")
                .body(axum::body::Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(res.status(), axum::http::StatusCode::OK);
    let json = body_json(res).await;
    let products = json["products"].as_array().unwrap();
    assert_eq!(products.len(), 1);
    assert_eq!(products[0]["category"], "Electronics");
}

#[tokio::test]
async fn create_product_validates_required_fields() {
    let app = app();

    let body = r#"{"seller_id":"s1","title":"","description":"d","category":"C","price_eur":10.0,"stock":5}"#;
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
    assert_eq!(res.status(), axum::http::StatusCode::BAD_REQUEST);
}

#[tokio::test]
async fn get_nonexistent_product_returns_404() {
    let app = app();
    let res = app
        .oneshot(
            axum::http::Request::builder()
                .method("GET")
                .uri("/v1/marketplace/products/no-such-id")
                .body(axum::body::Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(res.status(), axum::http::StatusCode::NOT_FOUND);
}

#[tokio::test]
async fn delete_product() {
    let state = AppState::new();
    let app = Router::new()
        .route("/v1/marketplace/products", post(api::create_product))
        .route("/v1/marketplace/products/:id", delete(api::delete_product))
        .with_state(state);

    let body = r#"{"seller_id":"s1","title":"Widget","description":"d","category":"C","price_eur":5.0,"stock":100}"#;
    let res = app
        .clone()
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
    let id = json["id"].as_str().unwrap().to_string();

    let del_res = app
        .oneshot(
            axum::http::Request::builder()
                .method("DELETE")
                .uri(format!("/v1/marketplace/products/{id}"))
                .body(axum::body::Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(del_res.status(), axum::http::StatusCode::NO_CONTENT);
}
