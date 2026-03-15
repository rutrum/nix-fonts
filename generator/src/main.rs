mod catalog;
mod hash;
mod providers;

use anyhow::Result;
use clap::{Parser, Subcommand};
use indicatif::{MultiProgress, ProgressBar, ProgressStyle};
use std::path::PathBuf;
use tracing_subscriber::EnvFilter;

use crate::catalog::Catalog;
use crate::providers::{FontProvider, dafont::DaFontProvider, fontsquirrel::FontSquirrelProvider, googlefonts::GoogleFontsProvider};

#[derive(Parser)]
#[command(name = "nix-fonts-gen")]
#[command(about = "Generate font catalog for nix-fonts flake")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Generate a font catalog from providers
    Generate {
        /// Output JSON file path (will merge if file exists)
        #[arg(short, long, default_value = "catalog.json")]
        output: PathBuf,

        /// Provider to fetch from
        #[arg(long, default_value = "fontsquirrel")]
        provider: String,

        /// Maximum number of fonts to process (useful for testing)
        #[arg(long)]
        limit: Option<usize>,

        /// Number of concurrent downloads
        #[arg(long, default_value = "4")]
        parallel: usize,

        /// Create a fresh catalog instead of merging with existing
        #[arg(long)]
        fresh: bool,
    },

    /// List available providers
    List,
}

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize logging
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::from_default_env())
        .init();

    let cli = Cli::parse();

    match cli.command {
        Commands::Generate {
            output,
            provider,
            limit,
            parallel,
            fresh,
        } => {
            generate_catalog(&output, &provider, limit, parallel, fresh).await?;
        }
        Commands::List => {
            println!("Available providers:");
            println!("  - fontsquirrel: Font Squirrel (https://www.fontsquirrel.com) [blocked by WAF]");
            println!("  - dafont: DaFont (https://www.dafont.com)");
            println!("  - googlefonts: Google Fonts (https://fonts.google.com) via gwfh.mranftl.com");
        }
    }

    Ok(())
}

async fn generate_catalog(
    output: &PathBuf,
    provider_name: &str,
    limit: Option<usize>,
    parallel: usize,
    fresh: bool,
) -> Result<()> {
    let provider: Box<dyn FontProvider> = match provider_name {
        "fontsquirrel" => Box::new(FontSquirrelProvider::new()),
        "dafont" => Box::new(DaFontProvider::new()),
        "googlefonts" => Box::new(GoogleFontsProvider::new()),
        _ => anyhow::bail!("Unknown provider: {}", provider_name),
    };

    // Load existing catalog or create new one
    let mut catalog = if !fresh && output.exists() {
        let content = tokio::fs::read_to_string(output).await?;
        let existing: Catalog = serde_json::from_str(&content)?;
        println!("Loaded existing catalog from {}", output.display());
        existing
    } else {
        Catalog::new()
    };

    println!("Fetching font list from {}...", provider.name());

    let families = provider.list_families().await?;

    // Filter out fonts already in catalog
    let existing_fonts: std::collections::HashSet<_> = catalog
        .providers
        .get(provider_name)
        .map(|p| p.fonts.keys().cloned().collect())
        .unwrap_or_default();

    let new_families: Vec<_> = families
        .into_iter()
        .filter(|f| !existing_fonts.contains(f))
        .collect();

    let total = if let Some(limit) = limit {
        new_families.len().min(limit)
    } else {
        new_families.len()
    };

    println!(
        "Found {} new fonts (skipping {} already in catalog), processing {}...",
        new_families.len(),
        existing_fonts.len(),
        total
    );

    if total == 0 {
        println!("No new fonts to process.");
        return Ok(());
    }

    let multi_progress = MultiProgress::new();
    let progress_bar = multi_progress.add(ProgressBar::new(total as u64));
    progress_bar.set_style(
        ProgressStyle::default_bar()
            .template("{spinner:.green} [{elapsed_precise}] [{bar:40.cyan/blue}] {pos}/{len} ({eta})")?
            .progress_chars("#>-"),
    );

    let families_to_process: Vec<_> = new_families.into_iter().take(total).collect();

    // Process fonts with bounded concurrency
    let semaphore = std::sync::Arc::new(tokio::sync::Semaphore::new(parallel));
    let results = std::sync::Arc::new(tokio::sync::Mutex::new(Vec::new()));

    let mut handles = Vec::new();

    for family in families_to_process {
        let provider = provider.clone_box();
        let semaphore = semaphore.clone();
        let results = results.clone();
        let progress_bar = progress_bar.clone();

        let handle = tokio::spawn(async move {
            let _permit = semaphore.acquire().await.unwrap();

            match provider.fetch_font_with_hash(&family).await {
                Ok(font_entry) => {
                    let mut results = results.lock().await;
                    results.push((family, font_entry));
                }
                Err(e) => {
                    tracing::warn!("Failed to fetch font '{}': {}", family, e);
                }
            }

            progress_bar.inc(1);
        });

        handles.push(handle);
    }

    // Wait for all tasks
    for handle in handles {
        handle.await?;
    }

    progress_bar.finish_with_message("Done!");

    // Merge results into catalog
    let results = std::sync::Arc::try_unwrap(results)
        .unwrap()
        .into_inner();

    let new_count = results.len();
    for (name, font_entry) in results {
        catalog.add_font(provider_name, &name, font_entry);
    }

    // Update timestamp
    catalog.generated_at = chrono::Utc::now();

    // Write output
    let json = serde_json::to_string_pretty(&catalog)?;
    tokio::fs::write(output, json).await?;

    println!("Added {} fonts to catalog, written to {}", new_count, output.display());

    Ok(())
}
