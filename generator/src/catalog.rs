use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Root catalog structure
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Catalog {
    pub version: String,
    pub generated_at: DateTime<Utc>,
    pub generator_version: String,
    pub providers: HashMap<String, ProviderCatalog>,
}

impl Catalog {
    pub fn new() -> Self {
        Self {
            version: "1.0.0".to_string(),
            generated_at: Utc::now(),
            generator_version: env!("CARGO_PKG_VERSION").to_string(),
            providers: HashMap::new(),
        }
    }

    pub fn add_font(&mut self, provider: &str, name: &str, font: FontEntry) {
        let provider_catalog = self
            .providers
            .entry(provider.to_string())
            .or_default();

        provider_catalog.fonts.insert(name.to_string(), font);
    }
}

impl Default for Catalog {
    fn default() -> Self {
        Self::new()
    }
}

/// Per-provider catalog
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProviderCatalog {
    pub fonts: HashMap<String, FontEntry>,
}

impl ProviderCatalog {
    pub fn new() -> Self {
        Self {
            fonts: HashMap::new(),
        }
    }
}

impl Default for ProviderCatalog {
    fn default() -> Self {
        Self::new()
    }
}

/// Individual font entry
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FontEntry {
    pub name: String,
    pub url_name: String,
    pub download_url: String,
    pub sha256: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub license: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub classification: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub version: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub file_size: Option<u64>,
}
