{ lib, catalog }:

let
  fontDefs = catalog.providers.dafont.fonts or {};

  # Convert a name to DaFont URL format: "Danish Cookies" -> "danish_cookies"
  toUrlName = name:
    lib.toLower (builtins.replaceStrings [" " "-"] ["_" "_"] name);

  # Build download URL from url_name
  downloadUrl = urlName: "https://dl.dafont.com/dl/?f=${urlName}";

  # Core function to build a font from a definition
  mkFont = { pkgs, fontDef }:
    pkgs.stdenvNoCC.mkDerivation {
      pname = "dafont-${fontDef.url_name}";
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

        runHook postInstall
      '';

      meta = {
        description = "Font: ${fontDef.name}";
        homepage = "https://www.dafont.com/${fontDef.url_name}.font";
        platforms = lib.platforms.all;
      };
    };

  # Build a font dynamically by name (for fonts not in catalog)
  # Usage: mkFontDynamic { inherit pkgs; name = "Danish Cookies"; sha256 = "sha256-..."; }
  mkFontDynamic = { pkgs, name, sha256, version ? "1.0" }:
    let
      urlName = toUrlName name;
    in mkFont {
      inherit pkgs;
      fontDef = {
        inherit name version sha256;
        url_name = urlName;
        download_url = downloadUrl urlName;
      };
    };

in {
  inherit mkFont mkFontDynamic toUrlName downloadUrl;

  # Build a font by name from the catalog
  mkFontByName = pkgs: name:
    let
      fontDef = fontDefs.${name} or (throw ''
        Font "${name}" not found in nix-fonts DaFont catalog.

        Available fonts: ${lib.concatStringsSep ", " (lib.take 10 (builtins.attrNames fontDefs))}...

        To add a DaFont font dynamically, use:
          nix-fonts.lib.dafont.mkFontDynamic {
            inherit pkgs;
            name = "${name}";
            sha256 = "sha256-...";  # Get with: nix-prefetch-url --unpack "https://dl.dafont.com/dl/?f=${toUrlName name}"
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
