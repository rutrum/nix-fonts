# FontSquirrel provider - currently blocked by WAF, kept for potential future use
{ lib, catalog }:

let
  fontDefs = catalog.providers.fontsquirrel.fonts or {};

  # Build download URL
  downloadUrl = urlName: "https://www.fontsquirrel.com/fonts/download/${urlName}";

  # Core function to build a font from a definition
  mkFont = { pkgs, fontDef }:
    pkgs.stdenvNoCC.mkDerivation {
      pname = "fontsquirrel-${fontDef.url_name}";
      version = "1.0";

      src = pkgs.fetchzip {
        url = fontDef.download_url;
        hash = fontDef.sha256;
        stripRoot = false;
      };

      dontBuild = true;

      installPhase = ''
        runHook preInstall

        mkdir -p $out/share/fonts/{truetype,opentype}

        # Install TTF fonts
        find . -type f -name "*.ttf" -exec install -Dm644 {} -t $out/share/fonts/truetype \;
        find . -type f -name "*.TTF" -exec install -Dm644 {} -t $out/share/fonts/truetype \;

        # Install OTF fonts
        find . -type f -name "*.otf" -exec install -Dm644 {} -t $out/share/fonts/opentype \;
        find . -type f -name "*.OTF" -exec install -Dm644 {} -t $out/share/fonts/opentype \;

        runHook postInstall
      '';

      meta = {
        description = "Font: ${fontDef.name}";
        homepage = "https://www.fontsquirrel.com/fonts/${fontDef.url_name}";
        platforms = lib.platforms.all;
      };
    };

in {
  inherit mkFont downloadUrl;

  # Build a font by name from the catalog
  mkFontByName = pkgs: name:
    let
      fontDef = fontDefs.${name} or (throw ''
        Font "${name}" not found in nix-fonts FontSquirrel catalog.
        Note: FontSquirrel downloads are currently blocked by WAF.
      '');
    in mkFont { inherit pkgs fontDef; };

  # Build all fonts from the catalog
  allFonts = pkgs:
    builtins.mapAttrs (name: fontDef: mkFont { inherit pkgs fontDef; }) fontDefs;

  # List available font names
  availableFonts = builtins.attrNames fontDefs;

  # Check if a font exists in the catalog
  hasFont = name: fontDefs ? ${name};

  # Get font metadata without building
  getFontDef = name: fontDefs.${name} or null;
}
