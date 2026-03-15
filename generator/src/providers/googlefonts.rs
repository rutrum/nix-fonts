use anyhow::{Context, Result};
use async_trait::async_trait;
use reqwest::Client;
use serde::Deserialize;

use super::FontProvider;
use crate::catalog::FontEntry;
use crate::hash::hash_response_stream;

const API_BASE: &str = "https://gwfh.mranftl.com/api/fonts";

/// Font metadata from the google-webfonts-helper API (list endpoint)
#[derive(Debug, Deserialize)]
struct FontListItem {
    id: String,
    #[allow(dead_code)]
    family: String,
    #[allow(dead_code)]
    category: String,
    #[allow(dead_code)]
    version: String,
}

/// Font metadata from the google-webfonts-helper API (individual font endpoint)
/// This has additional fields compared to the list endpoint
#[derive(Debug, Deserialize)]
struct FontInfo {
    id: String,
    family: String,
    category: String,
    version: String,
    // Other fields are ignored
}

#[derive(Clone)]
pub struct GoogleFontsProvider {
    client: Client,
    subsets: Vec<String>,
    formats: Vec<String>,
}

impl GoogleFontsProvider {
    pub fn new() -> Self {
        Self::with_options(vec!["latin".to_string()], vec!["ttf".to_string()])
    }

    pub fn with_options(subsets: Vec<String>, formats: Vec<String>) -> Self {
        let client = Client::builder()
            .user_agent("nix-fonts-gen/0.1.0")
            .build()
            .expect("Failed to build HTTP client");

        Self {
            client,
            subsets,
            formats,
        }
    }

    fn download_url(&self, font_id: &str) -> String {
        let subsets = self.subsets.join(",");
        let formats = self.formats.join(",");
        format!(
            "{}/{}?download=zip&subsets={}&formats={}",
            API_BASE, font_id, subsets, formats
        )
    }

    async fn fetch_font_list(&self) -> Result<Vec<FontListItem>> {
        let response = self
            .client
            .get(API_BASE)
            .send()
            .await
            .context("Failed to fetch Google Fonts list")?;

        if !response.status().is_success() {
            anyhow::bail!(
                "Google Fonts list request failed with status: {}",
                response.status()
            );
        }

        let fonts: Vec<FontListItem> = response
            .json()
            .await
            .context("Failed to parse Google Fonts list JSON")?;

        Ok(fonts)
    }

    async fn fetch_font_info(&self, font_id: &str) -> Result<FontInfo> {
        let url = format!("{}/{}", API_BASE, font_id);
        let response = self
            .client
            .get(&url)
            .send()
            .await
            .with_context(|| format!("Failed to fetch font info for '{}'", font_id))?;

        if !response.status().is_success() {
            anyhow::bail!(
                "Font info request for '{}' failed with status: {}",
                font_id,
                response.status()
            );
        }

        let info: FontInfo = response
            .json()
            .await
            .with_context(|| format!("Failed to parse font info JSON for '{}'", font_id))?;

        Ok(info)
    }
}

impl Default for GoogleFontsProvider {
    fn default() -> Self {
        Self::new()
    }
}

#[async_trait]
impl FontProvider for GoogleFontsProvider {
    fn name(&self) -> &'static str {
        "Google Fonts"
    }

    async fn list_families(&self) -> Result<Vec<String>> {
        let fonts = self.fetch_font_list().await?;
        Ok(fonts.into_iter().map(|f| f.id).collect())
    }

    async fn fetch_font_with_hash(&self, font_id: &str) -> Result<FontEntry> {
        // Get font metadata
        let info = self.fetch_font_info(font_id).await?;

        let download_url = self.download_url(font_id);

        // Download and compute hash
        let response = self
            .client
            .get(&download_url)
            .send()
            .await
            .with_context(|| format!("Failed to download font '{}'", font_id))?;

        if !response.status().is_success() {
            anyhow::bail!(
                "Font download for '{}' failed with status: {}",
                font_id,
                response.status()
            );
        }

        let (sha256, file_size) = hash_response_stream(response)
            .await
            .with_context(|| format!("Failed to compute hash for '{}'", font_id))?;

        Ok(FontEntry {
            name: info.family,
            url_name: info.id,
            download_url,
            sha256,
            license: Some("ofl".to_string()), // Most Google Fonts are OFL
            classification: Some(info.category),
            version: Some(info.version),
            file_size: Some(file_size),
        })
    }

    fn clone_box(&self) -> Box<dyn FontProvider> {
        Box::new(self.clone())
    }
}
