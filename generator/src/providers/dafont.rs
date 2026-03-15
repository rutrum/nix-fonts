use anyhow::{Context, Result};
use async_trait::async_trait;
use reqwest::Client;

use super::FontProvider;
use crate::catalog::FontEntry;
use crate::hash::hash_response_stream;

const DOWNLOAD_BASE: &str = "https://dl.dafont.com/dl/";

#[derive(Clone)]
pub struct DaFontProvider {
    client: Client,
}

impl DaFontProvider {
    pub fn new() -> Self {
        let client = Client::builder()
            .user_agent("nix-fonts-gen/0.1.0")
            .build()
            .expect("Failed to build HTTP client");

        Self { client }
    }

    /// Convert a font name to DaFont's URL format
    /// "Danish Cookies" -> "danish_cookies"
    fn to_url_name(name: &str) -> String {
        name.to_lowercase().replace([' ', '-'], "_")
    }

    fn download_url(url_name: &str) -> String {
        format!("{}?f={}", DOWNLOAD_BASE, url_name)
    }
}

impl Default for DaFontProvider {
    fn default() -> Self {
        Self::new()
    }
}

#[async_trait]
impl FontProvider for DaFontProvider {
    fn name(&self) -> &'static str {
        "DaFont"
    }

    /// DaFont has no public API for listing fonts.
    /// Returns an empty list - users must provide font names manually.
    async fn list_families(&self) -> Result<Vec<String>> {
        // DaFont doesn't have a public API for listing fonts.
        // Scraping would be required, but for now return empty.
        // Users can still fetch individual fonts by name.
        Ok(vec![])
    }

    async fn fetch_font_with_hash(&self, url_name: &str) -> Result<FontEntry> {
        let normalized = Self::to_url_name(url_name);
        let download_url = Self::download_url(&normalized);

        let response = self
            .client
            .get(&download_url)
            .send()
            .await
            .with_context(|| format!("Failed to download font '{}'", url_name))?;

        if !response.status().is_success() {
            anyhow::bail!(
                "Font download for '{}' failed with status: {}",
                url_name,
                response.status()
            );
        }

        let (sha256, file_size) = hash_response_stream(response)
            .await
            .with_context(|| format!("Failed to compute hash for '{}'", url_name))?;

        Ok(FontEntry {
            name: url_name.to_string(),
            url_name: normalized.clone(),
            download_url: Self::download_url(&normalized),
            sha256,
            license: None, // DaFont fonts have varied licenses
            classification: None,
            version: None,
            file_size: Some(file_size),
        })
    }

    fn clone_box(&self) -> Box<dyn FontProvider> {
        Box::new(self.clone())
    }
}
