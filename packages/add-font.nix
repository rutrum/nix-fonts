# Add a font - shows config snippet, fetches hash if needed
{ pkgs, ... }:

let
  catalog = ../catalog.json;
in
pkgs.writeShellScriptBin "add-font" ''
  set -euo pipefail

  CATALOG="${catalog}"

  usage() {
    echo "Usage: add-font <provider> <font-id>"
    echo ""
    echo "Get the configuration snippet to add a font to your NixOS/Home Manager config."
    echo "If the font is in the catalog, shows the simple config."
    echo "If not, fetches the hash and shows the full config with sha256."
    echo ""
    echo "Providers:"
    echo "  googlefonts    Google Fonts (via gwfh.mranftl.com)"
    echo "  dafont         DaFont.com"
    echo ""
    echo "Examples:"
    echo "  add-font googlefonts roboto"
    echo "  add-font googlefonts open-sans"
    echo "  add-font dafont \"comic sans\""
    echo ""
    echo "Options:"
    echo "  --subsets SUBSETS    Comma-separated subsets (googlefonts only, default: latin)"
    echo "  --formats FORMATS    Comma-separated formats (googlefonts only, default: ttf)"
  }

  if [[ $# -lt 2 ]]; then
    usage
    exit 1
  fi

  PROVIDER=""
  FONT_ID=""
  SUBSETS="latin"
  FORMATS="ttf"

  while [[ $# -gt 0 ]]; do
    case $1 in
      --subsets)
        SUBSETS="$2"
        shift 2
        ;;
      --formats)
        FORMATS="$2"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      -*)
        echo "Unknown option: $1"
        usage
        exit 1
        ;;
      *)
        if [[ -z "$PROVIDER" ]]; then
          PROVIDER="$1"
        elif [[ -z "$FONT_ID" ]]; then
          FONT_ID="$1"
        fi
        shift
        ;;
    esac
  done

  if [[ -z "$PROVIDER" || -z "$FONT_ID" ]]; then
    usage
    exit 1
  fi

  # Normalize font ID (lowercase, spaces to hyphens)
  FONT_ID_NORMALIZED=$(echo "$FONT_ID" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

  case "$PROVIDER" in
    googlefonts)
      # Check if in catalog with default settings
      IN_CATALOG=$(${pkgs.jq}/bin/jq -r --arg id "$FONT_ID_NORMALIZED" '.providers.googlefonts.fonts[$id] // empty' "$CATALOG")

      IS_DEFAULT_SETTINGS=false
      if [[ "$SUBSETS" == "latin" && "$FORMATS" == "ttf" ]]; then
        IS_DEFAULT_SETTINGS=true
      fi

      if [[ -n "$IN_CATALOG" && "$IS_DEFAULT_SETTINGS" == "true" ]]; then
        FONT_NAME=$(echo "$IN_CATALOG" | ${pkgs.jq}/bin/jq -r '.name')
        echo ""
        echo "✓ Found \"$FONT_NAME\" in catalog!"
        echo ""
        echo "Add to your configuration:"
        echo ""
        echo "  nix-fonts.googleFonts = ["
        echo "    \"$FONT_ID_NORMALIZED\""
        echo "  ];"
        echo ""
      else
        # Need to fetch hash
        DOWNLOAD_URL="https://gwfh.mranftl.com/api/fonts/$FONT_ID_NORMALIZED?download=zip&subsets=$SUBSETS&formats=$FORMATS"

        echo "Fetching hash for \"$FONT_ID_NORMALIZED\"..."
        echo "URL: $DOWNLOAD_URL"
        echo ""

        # Use curl + unzip + nix hash path to match fetchzip behavior
        # (nix-prefetch-url --unpack strips root for single-file archives, but fetchzip with stripRoot=false doesn't)
        TEMP_DIR=$(mktemp -d)
        trap "rm -rf $TEMP_DIR" EXIT

        if ! ${pkgs.curl}/bin/curl -sL "$DOWNLOAD_URL" -o "$TEMP_DIR/$FONT_ID_NORMALIZED.zip"; then
          echo "✗ Failed to fetch font. Check that the font ID is correct."
          echo ""
          echo "You can search for fonts with: nix run .#search-fonts -- <query>"
          echo "Or browse Google Fonts at: https://fonts.google.com"
          exit 1
        fi

        mkdir -p "$TEMP_DIR/unpacked"
        if ! ${pkgs.unzip}/bin/unzip -q "$TEMP_DIR/$FONT_ID_NORMALIZED.zip" -d "$TEMP_DIR/unpacked" 2>/dev/null; then
          echo "✗ Failed to unzip font. The archive may be corrupt or the font ID may be incorrect."
          exit 1
        fi

        SRI_HASH=$(${pkgs.nix}/bin/nix hash path "$TEMP_DIR/unpacked")

        echo "✓ Successfully fetched font!"
        echo ""
        echo "Add to your configuration:"
        echo ""
        if [[ "$IS_DEFAULT_SETTINGS" == "true" ]]; then
          echo "  nix-fonts.googleFonts = ["
          echo "    { name = \"$FONT_ID_NORMALIZED\"; sha256 = \"$SRI_HASH\"; }"
          echo "  ];"
        else
          SUBSETS_NIX=$(echo "$SUBSETS" | tr ',' '\n' | sed 's/.*/"&"/' | tr '\n' ' ')
          FORMATS_NIX=$(echo "$FORMATS" | tr ',' '\n' | sed 's/.*/"&"/' | tr '\n' ' ')
          echo "  nix-fonts.googleFonts = ["
          echo "    { name = \"$FONT_ID_NORMALIZED\"; subsets = [ $SUBSETS_NIX]; formats = [ $FORMATS_NIX]; sha256 = \"$SRI_HASH\"; }"
          echo "  ];"
        fi
        echo ""
      fi
      ;;

    dafont)
      # DaFont always requires hash (no catalog support yet)
      # DaFont URLs use underscores (dl/?f=texas_tango) but page URLs use hyphens (dafont.com/texas-tango.font)
      # Convert both spaces and hyphens to underscores for the download URL
      FONT_URL_NAME=$(echo "$FONT_ID" | tr '[:upper:]' '[:lower:]' | tr ' -' '_')
      DOWNLOAD_URL="https://dl.dafont.com/dl/?f=$FONT_URL_NAME"

      echo "Fetching hash for \"$FONT_ID\" from DaFont..."
      echo "URL: $DOWNLOAD_URL"
      echo ""

      # DaFont uses fetchzip in Nix, so we need to use nix-prefetch-url with special handling
      # First download the file, then compute the unpacked hash using nix hash path
      TEMP_DIR=$(mktemp -d)
      trap "rm -rf $TEMP_DIR" EXIT

      HTTP_CODE=$(${pkgs.curl}/bin/curl -sL -w "%{http_code}" "$DOWNLOAD_URL" -o "$TEMP_DIR/$FONT_URL_NAME.zip")
      if [[ "$HTTP_CODE" != "200" ]]; then
        echo "✗ Font not found (HTTP $HTTP_CODE). Check that the font name is correct."
        echo ""
        echo "Browse DaFont at: https://www.dafont.com"
        exit 1
      fi

      # Unzip and compute hash of contents
      mkdir -p "$TEMP_DIR/unpacked"
      if ! ${pkgs.unzip}/bin/unzip -q "$TEMP_DIR/$FONT_URL_NAME.zip" -d "$TEMP_DIR/unpacked" 2>/dev/null; then
        echo "✗ Font not found. The server returned an invalid response."
        echo ""
        echo "Browse DaFont at: https://www.dafont.com"
        exit 1
      fi

      SRI_HASH=$(${pkgs.nix}/bin/nix hash path "$TEMP_DIR/unpacked")

      echo "✓ Successfully fetched font!"
      echo ""
      echo "Add to your configuration:"
      echo ""
      echo "  nix-fonts.dafont = ["
      echo "    { name = \"$FONT_ID\"; sha256 = \"$SRI_HASH\"; }"
      echo "  ];"
      echo ""
      ;;

    *)
      echo "Unknown provider: $PROVIDER"
      echo ""
      echo "Available providers: googlefonts, dafont"
      exit 1
      ;;
  esac
''
