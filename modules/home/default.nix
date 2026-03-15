# Home Manager module for declarative font installation
{ config, lib, pkgs, ... }:

let
  cfg = config.nix-fonts;

  # Load catalog and providers
  catalog = builtins.fromJSON (builtins.readFile ../../catalog.json);
  dafont = import ../../lib/dafont.nix { inherit lib catalog; };
  googlefonts = import ../../lib/googlefonts.nix { inherit lib catalog; };

  # Type for DaFont font definitions
  dafontFontType = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Font name as it appears on DaFont (e.g., 'Danish Cookies')";
      };
      sha256 = lib.mkOption {
        type = lib.types.str;
        description = "SHA256 hash. Get with: nix-prefetch-url --unpack 'https://dl.dafont.com/dl/?f=font_name'";
      };
      version = lib.mkOption {
        type = lib.types.str;
        default = "1.0";
        description = "Font version (optional)";
      };
    };
  };

  # Type for Google Fonts definitions (attrset form)
  googleFontAttrType = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Font ID as it appears in Google Fonts (e.g., 'open-sans', 'roboto')";
      };
      subsets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "latin" ];
        description = "Character subsets to include (e.g., 'latin', 'cyrillic', 'greek')";
      };
      formats = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "ttf" ];
        description = "Font formats to include (e.g., 'ttf', 'woff', 'woff2')";
      };
      sha256 = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "SHA256 hash. Required if using non-default subsets/formats or font not in catalog.";
      };
    };
  };

  # Normalize Google Font entry (string or attrset) to attrset
  normalizeGoogleFont = entry:
    if builtins.isString entry
    then { name = entry; subsets = [ "latin" ]; formats = [ "ttf" ]; sha256 = null; }
    else entry;

  # Build a Google Font package from normalized entry
  buildGoogleFont = entry:
    let
      normalized = normalizeGoogleFont entry;
      isDefault = normalized.subsets == [ "latin" ] && normalized.formats == [ "ttf" ];
      inCatalog = googlefonts.hasFont normalized.name;
    in
      if isDefault && inCatalog
      then googlefonts.mkFontByName pkgs normalized.name
      else if normalized.sha256 != null
      then googlefonts.mkFontDynamic {
        inherit pkgs;
        inherit (normalized) name subsets formats sha256;
      }
      else throw ''
        Google Font "${normalized.name}" requires sha256 hash because:
        ${if !inCatalog then "- Font not found in catalog" else ""}
        ${if !isDefault then "- Using non-default subsets or formats" else ""}

        Get the hash with:
          nix-prefetch-url --unpack "${googlefonts.downloadUrl {
            fontId = normalized.name;
            inherit (normalized) subsets formats;
          }}"
      '';

in {
  options.nix-fonts = {
    enable = lib.mkEnableOption "nix-fonts font management";

    googleFonts = lib.mkOption {
      type = lib.types.listOf (lib.types.either lib.types.str googleFontAttrType);
      default = [];
      example = lib.literalExpression ''
        [
          "roboto"  # Simple: uses catalog defaults (latin, ttf)
          { name = "open-sans"; subsets = [ "latin" "cyrillic" ]; sha256 = "sha256-..."; }
          { name = "noto-sans"; subsets = [ "latin" "greek" ]; sha256 = "sha256-..."; }
        ]
      '';
      description = ''
        List of Google Fonts to install. Can be either:
        - A string (font ID) for fonts in the catalog with default settings
        - An attrset with name, optional subsets/formats, and sha256 (required for non-defaults)
      '';
    };

    dafont = lib.mkOption {
      type = lib.types.listOf dafontFontType;
      default = [];
      example = lib.literalExpression ''
        [
          { name = "Danish Cookies"; sha256 = "sha256-..."; }
          { name = "Pacifico"; sha256 = "sha256-..."; }
        ]
      '';
      description = ''
        List of DaFont fonts to install. Each font requires a name and sha256 hash.
        Get the hash with: nix-prefetch-url --unpack 'https://dl.dafont.com/dl/?f=font_name'
      '';
    };

    extraFonts = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      description = ''
        Additional font packages to install.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages =
      # Google Fonts
      (map buildGoogleFont cfg.googleFonts)
      # DaFont fonts
      ++ (map (font: dafont.mkFontDynamic {
        inherit pkgs;
        inherit (font) name sha256;
        version = font.version or "1.0";
      }) cfg.dafont)
      ++ cfg.extraFonts;
  };
}
