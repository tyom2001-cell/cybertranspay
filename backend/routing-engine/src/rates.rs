use chrono::{DateTime, Utc};
use serde::Deserialize;
use std::collections::HashMap;
use std::sync::Arc;
use std::time::Duration;
use thiserror::Error;
use tokio::sync::RwLock;

const CACHE_TTL: Duration = Duration::from_secs(60);
const USER_AGENT: &str = "CyberTransPay-routing-engine/0.1.0 (+https://github.com/tyom2001-cell/cybertranspay)";

#[derive(Debug, Clone)]
pub struct SpotRate {
    pub rate: f64,
    pub source: String,
    pub fetched_at: DateTime<Utc>,
}

#[derive(Error, Debug)]
pub enum RateError {
    #[error("unsupported asset pair: {from} -> {to}")]
    UnsupportedPair { from: String, to: String },
    #[error("upstream rate provider failed: {0}")]
    Upstream(String),
}

#[derive(Clone)]
pub struct LiveRates {
    client: reqwest::Client,
    cache: Arc<RwLock<Option<CachedRates>>>,
    mock_rate: Option<f64>,
}

struct CachedRates {
    expires_at: std::time::Instant,
    fiat: HashMap<String, HashMap<String, f64>>,
    crypto_usd: HashMap<String, f64>,
    rate_source: String,
}

#[derive(Deserialize)]
struct FrankfurterResponse {
    rates: HashMap<String, f64>,
}

#[derive(Deserialize)]
struct CoinGeckoResponse {
    #[serde(flatten)]
    coins: HashMap<String, HashMap<String, f64>>,
}

impl LiveRates {
    pub fn new() -> Self {
        Self {
            client: reqwest::Client::builder()
                .timeout(Duration::from_secs(10))
                .user_agent(USER_AGENT)
                .build()
                .expect("http client"),
            cache: Arc::new(RwLock::new(None)),
            mock_rate: None,
        }
    }

    pub fn mock(rate: f64) -> Self {
        Self {
            client: reqwest::Client::new(),
            cache: Arc::new(RwLock::new(None)),
            mock_rate: Some(rate),
        }
    }

    pub fn is_live(&self) -> bool {
        self.mock_rate.is_none()
    }

    pub async fn spot_rate(&self, from: &str, to: &str) -> Result<SpotRate, RateError> {
        let from = from.trim().to_uppercase();
        let to = to.trim().to_uppercase();

        if from == to {
            return Ok(SpotRate {
                rate: 1.0,
                source: "identity".into(),
                fetched_at: Utc::now(),
            });
        }

        if let Some(rate) = self.mock_rate {
            return Ok(SpotRate {
                rate,
                source: "mock".into(),
                fetched_at: Utc::now(),
            });
        }

        self.ensure_cache().await?;

        let cache = self.cache.read().await;
        let cached = cache.as_ref().expect("cache populated");

        let rate = compute_rate(&from, &to, cached)?;
        Ok(SpotRate {
            rate,
            source: cached.rate_source.clone(),
            fetched_at: Utc::now(),
        })
    }

    async fn ensure_cache(&self) -> Result<(), RateError> {
        {
            let guard = self.cache.read().await;
            if let Some(c) = guard.as_ref() {
                if c.expires_at > std::time::Instant::now() {
                    return Ok(());
                }
            }
        }

        let fiat = fetch_fiat_rates(&self.client).await?;
        let (crypto_usd, crypto_source) = match fetch_crypto_rates(&self.client).await {
            Ok(rates) => (rates, "coingecko".to_string()),
            Err(err) => {
                tracing::warn!("CoinGecko unavailable, using stablecoin defaults: {err}");
                (default_crypto_usd(), "stablecoin-default".to_string())
            }
        };

        let rate_source = if crypto_source == "coingecko" {
            "coingecko+frankfurter".into()
        } else {
            "frankfurter+stablecoin-default".into()
        };

        let mut guard = self.cache.write().await;
        *guard = Some(CachedRates {
            expires_at: std::time::Instant::now() + CACHE_TTL,
            fiat,
            crypto_usd,
            rate_source,
        });
        Ok(())
    }
}

fn compute_rate(from: &str, to: &str, cache: &CachedRates) -> Result<f64, RateError> {
    let from_usd = asset_to_usd(from, cache)?;
    let to_usd = asset_to_usd(to, cache)?;
    if from_usd <= 0.0 || to_usd <= 0.0 {
        return Err(RateError::Upstream("invalid zero rate".into()));
    }
    Ok(from_usd / to_usd)
}

fn asset_to_usd(asset: &str, cache: &CachedRates) -> Result<f64, RateError> {
    match asset {
        "USD" => Ok(1.0),
        "USDT" | "USDC" => Ok(cache.crypto_usd.get(asset).copied().unwrap_or(1.0)),
        "BTC" | "ETH" => cache
            .crypto_usd
            .get(asset)
            .copied()
            .ok_or_else(|| RateError::UnsupportedPair {
                from: asset.into(),
                to: "USD".into(),
            }),
        other if crate::assets::is_fiat(other) => {
            let table = cache
                .fiat
                .get("USD")
                .ok_or_else(|| RateError::Upstream("USD fiat table missing".into()))?;
            let per_usd = table.get(other).ok_or_else(|| RateError::UnsupportedPair {
                from: "USD".into(),
                to: other.into(),
            })?;
            Ok(1.0 / per_usd)
        }
        other => Err(RateError::UnsupportedPair {
            from: other.into(),
            to: "USD".into(),
        }),
    }
}

async fn fetch_fiat_rates(
    client: &reqwest::Client,
) -> Result<HashMap<String, HashMap<String, f64>>, RateError> {
    let url = "https://api.frankfurter.app/latest?from=USD";
    let resp: FrankfurterResponse = client
        .get(url)
        .send()
        .await
        .map_err(|e| RateError::Upstream(e.to_string()))?
        .error_for_status()
        .map_err(|e| RateError::Upstream(e.to_string()))?
        .json()
        .await
        .map_err(|e| RateError::Upstream(e.to_string()))?;

    let mut usd_table = HashMap::new();
    usd_table.insert("USD".to_string(), 1.0);
    for (currency, rate) in resp.rates {
        usd_table.insert(currency, rate);
    }

    let mut out = HashMap::new();
    out.insert("USD".to_string(), usd_table);
    Ok(out)
}

async fn fetch_crypto_rates(client: &reqwest::Client) -> Result<HashMap<String, f64>, RateError> {
    let url =
        "https://api.coingecko.com/api/v3/simple/price?ids=tether,usd-coin,bitcoin,ethereum&vs_currencies=usd";
    let mut request = client.get(url).header("Accept", "application/json");

    if let Ok(key) = std::env::var("COINGECKO_API_KEY") {
        if !key.is_empty() {
            request = request.header("x-cg-demo-api-key", key);
        }
    }

    let resp: CoinGeckoResponse = request
        .send()
        .await
        .map_err(|e| RateError::Upstream(e.to_string()))?
        .error_for_status()
        .map_err(|e| RateError::Upstream(e.to_string()))?
        .json()
        .await
        .map_err(|e| RateError::Upstream(e.to_string()))?;

    let mut usd = HashMap::new();

    if let Some(t) = resp.coins.get("tether") {
        if let Some(v) = t.get("usd") {
            usd.insert("USDT".into(), *v);
        }
    }
    if let Some(c) = resp.coins.get("usd-coin") {
        if let Some(v) = c.get("usd") {
            usd.insert("USDC".into(), *v);
        }
    }
    if let Some(b) = resp.coins.get("bitcoin") {
        if let Some(v) = b.get("usd") {
            usd.insert("BTC".into(), *v);
        }
    }
    if let Some(e) = resp.coins.get("ethereum") {
        if let Some(v) = e.get("usd") {
            usd.insert("ETH".into(), *v);
        }
    }

    if usd.is_empty() {
        return Err(RateError::Upstream("empty coingecko response".into()));
    }

    Ok(usd)
}

fn default_crypto_usd() -> HashMap<String, f64> {
    HashMap::from([
        ("USDT".into(), 1.0),
        ("USDC".into(), 1.0),
    ])
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn mock_rate_returns_configured_value() {
        let rates = LiveRates::mock(1.08);
        let spot = rates.spot_rate("USDT", "EUR").await.unwrap();
        assert!((spot.rate - 1.08).abs() < f64::EPSILON);
    }

    #[test]
    fn default_crypto_usd_pegs_stables() {
        let defaults = default_crypto_usd();
        assert_eq!(defaults.get("USDT"), Some(&1.0));
        assert_eq!(defaults.get("USDC"), Some(&1.0));
    }

    #[test]
    fn compute_rate_converts_via_usd() {
        let cache = CachedRates {
            expires_at: std::time::Instant::now(),
            fiat: HashMap::from([(
                "USD".into(),
                HashMap::from([("USD".into(), 1.0), ("EUR".into(), 0.92)]),
            )]),
            crypto_usd: HashMap::from([("USDT".into(), 1.0)]),
            rate_source: "test".into(),
        };
        let rate = compute_rate("USDT", "EUR", &cache).unwrap();
        assert!((rate - 0.92).abs() < 0.001);
    }
}
