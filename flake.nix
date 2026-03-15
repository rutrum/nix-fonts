{
  description = "Nix flake for distributing fonts from FontSquirrel and other sources";

  inputs = {
    blueprint.url = "github:numtide/blueprint";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    crane.url = "github:ipetkov/crane";
    systems.url = "github:nix-systems/default";
  };

  outputs = inputs: inputs.blueprint {
    inherit inputs;
    systems = import inputs.systems;
  };
}
