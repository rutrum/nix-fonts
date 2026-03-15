# Build a Google Font NOT in catalog (requires sha256) and verify TTF files exist
{ pkgs, ... }:

let
  catalog = builtins.fromJSON (builtins.readFile ../catalog.json);
  googlefonts = import ../lib/googlefonts.nix { inherit (pkgs) lib; inherit catalog; };
  # tiny5 is a small font not in the catalog - tests dynamic fetching
  tiny5 = googlefonts.mkFontDynamic {
    inherit pkgs;
    name = "tiny5";
    sha256 = "sha256-K2OIO+7/Epc1JhQv/Oe1IeH5OMR+yXa1wUibmT7CtK8=";
  };
in
pkgs.runCommand "googlefonts-dynamic" { } ''
  # Verify font package built
  test -d ${tiny5}/share/fonts/truetype

  # Verify TTF files exist
  find ${tiny5}/share/fonts/truetype -name "*.ttf" | grep -q .

  mkdir $out
''
