# Rust CLI tool for generating font catalogs
{ pkgs, inputs, system, ... }:

let
  inherit (pkgs) lib;
  craneLib = inputs.crane.mkLib pkgs;

  # Filter to only Rust-relevant files
  src = lib.cleanSourceWith {
    src = ../generator;
    filter = path: type:
      (craneLib.filterCargoSources path type)
      || (builtins.match ".*\\.toml$" path != null);
  };

  # Common arguments for all builds
  commonArgs = {
    inherit src;
    strictDeps = true;

    buildInputs = with pkgs; [
      openssl
      pkg-config
    ] ++ lib.optionals pkgs.stdenv.isDarwin [
      pkgs.libiconv
      pkgs.darwin.apple_sdk.frameworks.Security
      pkgs.darwin.apple_sdk.frameworks.SystemConfiguration
    ];

    nativeBuildInputs = with pkgs; [
      pkg-config
    ];
  };

  # Build dependencies separately for caching
  cargoArtifacts = craneLib.buildDepsOnly commonArgs;

in craneLib.buildPackage (commonArgs // {
  inherit cargoArtifacts;

  meta = with lib; {
    description = "Font catalog generator for nix-fonts";
    license = licenses.mit;
    mainProgram = "nix-fonts-gen";
  };
})
