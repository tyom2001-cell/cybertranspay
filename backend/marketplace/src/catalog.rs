use crate::domain::{
    CreateProductRequest, Product, ProductFilter, UpdateProductRequest,
};
use chrono::Utc;
use std::{collections::HashMap, sync::Arc};
use tokio::sync::RwLock;
use uuid::Uuid;

#[derive(Clone, Default)]
pub struct CatalogStore {
    inner: Arc<RwLock<HashMap<String, Product>>>,
}

impl CatalogStore {
    pub fn new() -> Self {
        Self::default()
    }

    pub async fn insert(&self, req: CreateProductRequest) -> Product {
        let now = Utc::now();
        let product = Product {
            id: Uuid::new_v4().to_string(),
            seller_id: req.seller_id,
            title: req.title,
            description: req.description,
            category: req.category,
            tags: req.tags,
            price_eur: req.price_eur,
            stock: req.stock,
            image_url: req.image_url,
            active: true,
            created_at: now,
            updated_at: now,
        };
        self.inner
            .write()
            .await
            .insert(product.id.clone(), product.clone());
        product
    }

    pub async fn get(&self, id: &str) -> Option<Product> {
        self.inner.read().await.get(id).cloned()
    }

    pub async fn update(&self, id: &str, req: UpdateProductRequest) -> Option<Product> {
        let mut store = self.inner.write().await;
        let product = store.get_mut(id)?;
        if let Some(v) = req.title {
            product.title = v;
        }
        if let Some(v) = req.description {
            product.description = v;
        }
        if let Some(v) = req.category {
            product.category = v;
        }
        if let Some(v) = req.tags {
            product.tags = v;
        }
        if let Some(v) = req.price_eur {
            product.price_eur = v;
        }
        if let Some(v) = req.stock {
            product.stock = v;
        }
        if let Some(v) = req.image_url {
            product.image_url = Some(v);
        }
        if let Some(v) = req.active {
            product.active = v;
        }
        product.updated_at = Utc::now();
        Some(product.clone())
    }

    pub async fn delete(&self, id: &str) -> bool {
        self.inner.write().await.remove(id).is_some()
    }

    pub async fn list(&self, filter: &ProductFilter) -> Vec<Product> {
        let store = self.inner.read().await;
        store
            .values()
            .filter(|p| {
                if !p.active {
                    return false;
                }
                if let Some(ref cat) = filter.category {
                    if !p.category.eq_ignore_ascii_case(cat) {
                        return false;
                    }
                }
                if let Some(ref sid) = filter.seller_id {
                    if p.seller_id != *sid {
                        return false;
                    }
                }
                if let Some(ref q) = filter.query {
                    let q_lower = q.to_lowercase();
                    if !p.title.to_lowercase().contains(&q_lower)
                        && !p.description.to_lowercase().contains(&q_lower)
                        && !p.tags.iter().any(|t| t.to_lowercase().contains(&q_lower))
                    {
                        return false;
                    }
                }
                if let Some(min) = filter.min_price_eur {
                    if p.price_eur < min {
                        return false;
                    }
                }
                if let Some(max) = filter.max_price_eur {
                    if p.price_eur > max {
                        return false;
                    }
                }
                if let Some(in_stock) = filter.in_stock {
                    if in_stock && p.stock == 0 {
                        return false;
                    }
                }
                true
            })
            .cloned()
            .collect()
    }

    pub async fn categories(&self) -> Vec<String> {
        let store = self.inner.read().await;
        let mut cats: Vec<String> = store
            .values()
            .filter(|p| p.active)
            .map(|p| p.category.clone())
            .collect::<std::collections::HashSet<_>>()
            .into_iter()
            .collect();
        cats.sort();
        cats
    }
}
