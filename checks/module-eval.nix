# Verify NixOS and Home Manager modules can be evaluated without errors
# This is a simpler check that just verifies the module files can be imported
{ pkgs, ... }:

let
  # Import and check the modules can be loaded
  nixosModule = import ../modules/nixos/default.nix;
  homeModule = import ../modules/home/default.nix;

  # Verify modules are functions (standard NixOS module format)
  nixosIsFunction = builtins.isFunction nixosModule;
  homeIsFunction = builtins.isFunction homeModule;
in
pkgs.runCommand "module-eval" { } ''
  echo "NixOS module is function: ${builtins.toJSON nixosIsFunction}"
  echo "Home module is function: ${builtins.toJSON homeIsFunction}"

  # Fail if either is not a function
  ${if nixosIsFunction then "" else "echo 'NixOS module is not a function'; exit 1"}
  ${if homeIsFunction then "" else "echo 'Home module is not a function'; exit 1"}

  mkdir $out
''
