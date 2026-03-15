{ inputs, ... }:

let
  inherit (inputs.nixpkgs) lib;

  # Load catalog at evaluation time
  catalog = builtins.fromJSON (builtins.readFile ../catalog.json);

  # Import provider-specific helpers
  dafont = import ./dafont.nix { inherit lib catalog; };
  googlefonts = import ./googlefonts.nix { inherit lib catalog; };

  # FontSquirrel is kept for internal/development use only
  # (blocked by CloudFront WAF for automated downloads)
  _fontSquirrel = import ./fontSquirrel.nix { inherit lib catalog; };

in {
  # Public providers
  inherit dafont googlefonts;

  # Catalog data
  inherit catalog;

  # Internal/development only (not for public use)
  _internal = {
    fontSquirrel = _fontSquirrel;
  };
}
