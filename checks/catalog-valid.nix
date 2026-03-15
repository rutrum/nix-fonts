# Validate catalog.json structure
{ pkgs, ... }:

pkgs.runCommand "catalog-valid" { } ''
  ${pkgs.jq}/bin/jq -e '.providers.googlefonts.fonts | length > 0' ${../catalog.json}
  ${pkgs.jq}/bin/jq -e '.providers.dafont' ${../catalog.json}
  mkdir $out
''
