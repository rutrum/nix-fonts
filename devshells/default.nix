# Development shell for nix-fonts contributors
{ pkgs, inputs, ... }:

pkgs.mkShell {
  name = "nix-fonts-dev";

  buildInputs = with pkgs; [
    # Rust toolchain
    rustc
    cargo
    rustfmt
    clippy
    rust-analyzer

    # Build dependencies
    pkg-config
    openssl

    # Utilities
    jq
    curl
  ] ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
    pkgs.libiconv
    pkgs.darwin.apple_sdk.frameworks.Security
    pkgs.darwin.apple_sdk.frameworks.SystemConfiguration
  ];

  shellHook = ''
    echo "nix-fonts development shell"
    echo ""
    echo "Commands:"
    echo "  cd generator && cargo build    - Build the generator"
    echo "  cargo run -- generate --limit 5 - Generate catalog with 5 fonts (test)"
    echo "  cargo run -- list              - List available providers"
  '';
}
