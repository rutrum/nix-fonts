# Build a Google Font from catalog and verify TTF files exist
{ pkgs, ... }:

let
  catalog = builtins.fromJSON (builtins.readFile ../catalog.json);
  googlefonts = import ../lib/googlefonts.nix { inherit (pkgs) lib; inherit catalog; };
  roboto = googlefonts.mkFontByName pkgs "roboto";
in
pkgs.runCommand "googlefonts-catalog" { } ''
  # Verify font package built
  test -d ${roboto}/share/fonts/truetype

  # Verify TTF files exist
  find ${roboto}/share/fonts/truetype -name "*.ttf" | grep -q .

  mkdir $out
''
