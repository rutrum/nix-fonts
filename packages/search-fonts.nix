# Search available fonts in the catalog
{ pkgs, ... }:

let
  catalog = ../catalog.json;
in
pkgs.writeShellScriptBin "search-fonts" ''
  set -euo pipefail

  CATALOG="${catalog}"

  usage() {
    echo "Usage: search-fonts [OPTIONS] [QUERY]"
    echo ""
    echo "Search for fonts in the nix-fonts catalog."
    echo ""
    echo "Options:"
    echo "  -p, --provider PROVIDER  Filter by provider (googlefonts, dafont)"
    echo "  -c, --category CATEGORY  Filter by category (sans-serif, serif, monospace, etc.)"
    echo "  -l, --list               List all available fonts"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  search-fonts roboto           # Search for fonts matching 'roboto'"
    echo "  search-fonts -l               # List all fonts"
    echo "  search-fonts -p googlefonts   # List all Google Fonts"
    echo "  search-fonts -c monospace     # List all monospace fonts"
  }

  PROVIDER=""
  CATEGORY=""
  LIST_ALL=false
  QUERY=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      -p|--provider)
        PROVIDER="$2"
        shift 2
        ;;
      -c|--category)
        CATEGORY="$2"
        shift 2
        ;;
      -l|--list)
        LIST_ALL=true
        shift
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
        QUERY="$1"
        shift
        ;;
    esac
  done

  if [[ -z "$QUERY" && "$LIST_ALL" == "false" && -z "$PROVIDER" && -z "$CATEGORY" ]]; then
    usage
    exit 1
  fi

  # Build jq filter
  JQ_FILTER='.providers | to_entries[] | .key as $provider | .value.fonts | to_entries[] | {provider: $provider, id: .key, name: .value.name, category: .value.classification, version: .value.version}'

  # Apply filters
  FILTERS=""
  if [[ -n "$PROVIDER" ]]; then
    FILTERS="$FILTERS | select(.provider == \"$PROVIDER\")"
  fi
  if [[ -n "$CATEGORY" ]]; then
    FILTERS="$FILTERS | select(.category == \"$CATEGORY\")"
  fi
  if [[ -n "$QUERY" ]]; then
    QUERY_LOWER=$(echo "$QUERY" | tr '[:upper:]' '[:lower:]')
    FILTERS="$FILTERS | select((.id | ascii_downcase | contains(\"$QUERY_LOWER\")) or (.name | ascii_downcase | contains(\"$QUERY_LOWER\")))"
  fi

  # Format output
  FORMAT='"\(.provider)\t\(.id)\t\(.name // .id)\t\(.category // "-")\t\(.version // "-")"'

  RESULT=$(${pkgs.jq}/bin/jq -r "[$JQ_FILTER $FILTERS] | sort_by(.name) | .[] | $FORMAT" "$CATALOG")

  if [[ -z "$RESULT" ]]; then
    echo "No fonts found matching your criteria."
    exit 0
  fi

  # Print header and results
  printf "%-12s %-25s %-30s %-15s %s\n" "PROVIDER" "ID" "NAME" "CATEGORY" "VERSION"
  printf "%-12s %-25s %-30s %-15s %s\n" "--------" "--" "----" "--------" "-------"
  echo "$RESULT" | while IFS=$'\t' read -r provider id name category version; do
    printf "%-12s %-25s %-30s %-15s %s\n" "$provider" "$id" "$name" "$category" "$version"
  done

  COUNT=$(echo "$RESULT" | wc -l)
  echo ""
  echo "Found $COUNT font(s)"
''
