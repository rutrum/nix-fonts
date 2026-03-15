use anyhow::Result;
use futures_util::StreamExt;
use reqwest::Response;
use sha2::{Digest, Sha256};

/// Compute SHA256 hash of a response body without writing to disk.
/// Returns (nix_hash, byte_count) where nix_hash is in "sha256-base64" format
pub async fn hash_response_stream(response: Response) -> Result<(String, u64)> {
    let mut hasher = Sha256::new();
    let mut byte_count: u64 = 0;

    let mut stream = response.bytes_stream();

    while let Some(chunk_result) = stream.next().await {
        let chunk = chunk_result?;
        hasher.update(&chunk);
        byte_count += chunk.len() as u64;
    }

    let hash = hasher.finalize();

    // Format as Nix-style SRI hash: sha256-<base64>
    let base64_hash = base64_encode(&hash);
    let nix_hash = format!("sha256-{}", base64_hash);

    Ok((nix_hash, byte_count))
}

fn base64_encode(bytes: &[u8]) -> String {
    use base64::{engine::general_purpose::STANDARD, Engine};
    STANDARD.encode(bytes)
}

// Add base64 to dependencies
