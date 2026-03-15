pub mod dafont;
pub mod fontsquirrel;
pub mod googlefonts;

use anyhow::Result;
use async_trait::async_trait;

use crate::catalog::FontEntry;

/// Trait for font providers (FontSquirrel, Google Fonts, etc.)
#[async_trait]
pub trait FontProvider: Send + Sync {
    /// Human-readable name
    fn name(&self) -> &'static str;

    /// List all available font family URL names
    async fn list_families(&self) -> Result<Vec<String>>;

    /// Fetch font info and compute hash
    async fn fetch_font_with_hash(&self, url_name: &str) -> Result<FontEntry>;

    /// Clone into a boxed trait object
    fn clone_box(&self) -> Box<dyn FontProvider>;
}
