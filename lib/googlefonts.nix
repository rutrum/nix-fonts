{ lib, catalog }:

let
  fontDefs = catalog.providers.googlefonts.fonts or {};

  # Default configuration
  defaultSubsets = [ "latin" ];
  defaultFormats = [ "ttf" ];

  # Build download URL from parameters
  # https://gwfh.mranftl.com/api/fonts/{id}?download=zip&subsets={subsets}&formats={formats}
  downloadUrl = { fontId, subsets ? defaultSubsets, formats ? defaultFormats }:
    let
      subsetsStr = lib.concatStringsSep "," subsets;
      formatsStr = lib.concatStringsSep "," formats;
    in
      "https://gwfh.mranftl.com/api/fonts/${fontId}?download=zip&subsets=${subsetsStr}&formats=${formatsStr}";

  # Core function to build a font from a definition
  mkFont = { pkgs, fontDef }:
    pkgs.stdenvNoCC.mkDerivation {
      pname = "googlefonts-${fontDef.url_name}";
      version = fontDef.version or "1.0";

      src = pkgs.fetchzip {
        url = fontDef.download_url;
        hash = fontDef.sha256;
        stripRoot = false;
        extension = "zip";
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

        # Install WOFF/WOFF2 if present
        find . -type f -name "*.woff" -exec install -Dm644 {} -t $out/share/fonts/woff \;
        find . -type f -name "*.woff2" -exec install -Dm644 {} -t $out/share/fonts/woff2 \;

        runHook postInstall
      '';

      meta = {
        description = "Font: ${fontDef.name}";
        homepage = "https://fonts.google.com/specimen/${lib.replaceStrings [" "] ["+"] fontDef.name}";
        license = lib.licenses.ofl;
        platforms = lib.platforms.all;
      };
    };

  # Build a font dynamically (for fonts not in catalog or custom subsets/variants)
  # Usage: mkFontDynamic { inherit pkgs; name = "open-sans"; sha256 = "sha256-..."; }
  # Or with options: mkFontDynamic { inherit pkgs; name = "open-sans"; subsets = ["latin" "cyrillic"]; sha256 = "sha256-..."; }
  mkFontDynamic = { pkgs, name, sha256, subsets ? defaultSubsets, formats ? defaultFormats, version ? "1.0" }:
    mkFont {
      inherit pkgs;
      fontDef = {
        inherit name version sha256;
        url_name = name;
        download_url = downloadUrl { fontId = name; inherit subsets formats; };
      };
    };

in {
  inherit mkFont mkFontDynamic downloadUrl defaultSubsets defaultFormats;

  # Build a font by name from the catalog (uses default subsets/formats)
  mkFontByName = pkgs: name:
    let
      fontDef = fontDefs.${name} or (throw ''
        Font "${name}" not found in nix-fonts Google Fonts catalog.

        Available fonts: ${lib.concatStringsSep ", " (lib.take 10 (builtins.attrNames fontDefs))}...

        To add a Google Font dynamically, use:
          nix-fonts.lib.googlefonts.mkFontDynamic {
            inherit pkgs;
            name = "${name}";
            sha256 = "sha256-...";  # Get with: nix-prefetch-url --unpack "${downloadUrl { fontId = name; }}"
          }

        Or with custom subsets:
          nix-fonts.lib.googlefonts.mkFontDynamic {
            inherit pkgs;
            name = "${name}";
            subsets = [ "latin" "cyrillic" ];
            sha256 = "sha256-...";
          }
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
