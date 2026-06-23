pub mod accounts;
pub mod api;
pub mod catalog;
pub mod domain;
pub mod orders;
pub mod promotions;
pub mod vat;

use accounts::AccountStore;
use catalog::CatalogStore;
use orders::OrderStore;
use promotions::PromotionStore;

#[derive(Clone)]
pub struct AppState {
    pub catalog: CatalogStore,
    pub orders: OrderStore,
    pub accounts: AccountStore,
    pub promotions: PromotionStore,
}

impl AppState {
    pub fn new() -> Self {
        Self {
            catalog: CatalogStore::new(),
            orders: OrderStore::new(),
            accounts: AccountStore::new(),
            promotions: PromotionStore::new(),
        }
    }
}

impl Default for AppState {
    fn default() -> Self {
        Self::new()
    }
}
