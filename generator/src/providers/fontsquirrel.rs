use anyhow::{Context, Result};
use async_trait::async_trait;
use reqwest::Client;
use serde::Deserialize;

use super::FontProvider;
use crate::catalog::FontEntry;
use crate::hash::hash_response_stream;

const API_BASE: &str = "https://www.fontsquirrel.com/api";

#[derive(Debug, Deserialize)]
struct FontListItem {
    #[allow(dead_code)]
    family_name: String,
    family_urlname: String,
    #[allow(dead_code)]
    classification: String,
}

#[derive(Debug, Deserialize)]
struct FontInfo {
    family_name: String,
    family_urlname: String,
    classification: String,
}

#[derive(Clone)]
pub struct FontSquirrelProvider {
    client: Client,
}

impl FontSquirrelProvider {
    pub fn new() -> Self {
        let client = Client::builder()
            .user_agent("nix-fonts-gen/0.1.0")
            .build()
            .expect("Failed to build HTTP client");

        Self { client }
    }

    fn download_url(&self, url_name: &str) -> String {
        format!(
            "https://www.fontsquirrel.com/fonts/download/{}",
            url_name
        )
    }

    async fn fetch_font_list(&self) -> Result<Vec<FontListItem>> {
        let url = format!("{}/fontlist/all", API_BASE);
        let response = self
            .client
            .get(&url)
            .send()
            .await
            .context("Failed to fetch font list from FontSquirrel")?;

        if !response.status().is_success() {
            anyhow::bail!(
                "FontSquirrel API request failed with status: {}",
                response.status()
            );
        }

        let fonts: Vec<FontListItem> = response
            .json()
            .await
            .context("Failed to parse FontSquirrel font list JSON")?;

        Ok(fonts)
    }

    async fn fetch_font_info(&self, url_name: &str) -> Result<FontInfo> {
        let url = format!("{}/familyinfo/{}", API_BASE, url_name);
        let response = self
            .client
            .get(&url)
            .send()
            .await
            .with_context(|| format!("Failed to fetch font info for '{}'", url_name))?;

        if !response.status().is_success() {
            anyhow::bail!(
                "FontSquirrel API request for '{}' failed with status: {}",
                url_name,
                response.status()
            );
        }

        // API returns an array with one element
        let mut info: Vec<FontInfo> = response
            .json()
            .await
            .with_context(|| format!("Failed to parse font info JSON for '{}'", url_name))?;

        info.pop()
            .ok_or_else(|| anyhow::anyhow!("Empty response for font '{}'", url_name))
    }
}

impl Default for FontSquirrelProvider {
    fn default() -> Self {
        Self::new()
    }
}

#[async_trait]
impl FontProvider for FontSquirrelProvider {
    fn name(&self) -> &'static str {
        "Font Squirrel"
    }

    async fn list_families(&self) -> Result<Vec<String>> {
        let fonts = self.fetch_font_list().await?;
        Ok(fonts.into_iter().map(|f| f.family_urlname).collect())
    }

    async fn fetch_font_with_hash(&self, url_name: &str) -> Result<FontEntry> {
        // Get font metadata
        let info = self.fetch_font_info(url_name).await?;

        let download_url = self.download_url(url_name);

        // Download and compute hash
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

        let (sha256, _file_size) = hash_response_stream(response)
            .await
            .with_context(|| format!("Failed to compute hash for '{}'", url_name))?;

        Ok(FontEntry {
            name: info.family_name,
            url_name: info.family_urlname,
            download_url,
            sha256,
            license: Some("ofl".to_string()), // Most FontSquirrel fonts are OFL
            classification: Some(info.classification),
            version: None,
            file_size: None,
        })
    }

    fn clone_box(&self) -> Box<dyn FontProvider> {
        Box::new(self.clone())
    }
}
