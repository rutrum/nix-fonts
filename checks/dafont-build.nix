# Build a DaFont font dynamically and verify font files exist
{ pkgs, ... }:

let
  catalog = builtins.fromJSON (builtins.readFile ../catalog.json);
  dafont = import ../lib/dafont.nix { inherit (pkgs) lib; inherit catalog; };
  # Use a small, stable DaFont font for testing
  testFont = dafont.mkFontDynamic {
    inherit pkgs;
    name = "texas-tango";
    sha256 = "sha256-FaeVTLLGRysyzp1M5sleKHCBcsl58f+IzaNR9ZUMNKE=";
  };
in
pkgs.runCommand "dafont-build" { } ''
  test -d ${testFont}/share/fonts
  find ${testFont}/share/fonts -name "*.ttf" -o -name "*.otf" | grep -q .
  mkdir $out
''
