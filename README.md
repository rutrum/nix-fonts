# nix-fonts

A Nix flake for easily downloading fonts from sources like FontSquirrel.

## Status: Work In Progress

**Current state:** Core infrastructure is complete and verified working. Font hosting solution needed.

### What's Working

- Flake structure using [numtide/blueprint](https://github.com/numtide/blueprint)
- `lib.fontSquirrel.mkFont` and `lib.fontSquirrel.mkFontByName` functions
- NixOS and Home Manager modules
- Rust CLI generator (builds but can't fetch from FontSquirrel directly)
- Dev shell for contributors
- **Font packaging verified working** with 3 test fonts (Open Sans, Raleway, Source Code Pro)

### What's Blocked

FontSquirrel's API and download endpoints are protected by CloudFront WAF. Automated tools (`curl`, Nix's `fetchzip`) receive empty responses or HTTP 202 "Accepted" errors. **Browser downloads work fine** - the protection only blocks programmatic access.

### Next Step: Host Fonts Somewhere

The flake works correctly when fonts are served from an accessible URL. Options:

1. **GitHub Releases** (recommended): Upload font ZIPs to releases in this repo
2. **Self-hosted mirror**: Any static file server (S3, Cloudflare R2, etc.)
3. **Existing archive**: [Jolg42/FontSquirrel-Fonts](https://github.com/Jolg42/FontSquirrel-Fonts) (outdated, 2016)

### Manual Testing Workflow

To verify the system works locally:

```bash
# 1. Download fonts via browser from fontsquirrel.com/fonts/{name}
# 2. Save ZIPs to a directory (e.g., ~/fonts/)
# 3. Serve them locally
cd ~/fonts && python3 -m http.server 8765

# 4. Update catalog.json URLs to http://localhost:8765/{name}.zip
# 5. Build with sandbox disabled
nix build .#open-sans --option sandbox false
```

## Project Structure

```
nix-fonts/
├── flake.nix                 # Blueprint-based flake
├── catalog.json              # Font metadata (placeholder, needs real hashes)
├── lib/
│   ├── default.nix           # Main lib exports
│   └── fontSquirrel.nix      # mkFont, mkFontByName helpers
├── packages/
│   ├── nix-fonts-gen.nix     # Rust CLI package
│   ├── open-sans.nix         # Example font packages
│   ├── raleway.nix
│   └── source-code-pro.nix
├── modules/
│   ├── nixos/default.nix     # NixOS module
│   └── home/default.nix      # Home Manager module
├── devshells/default.nix     # Development environment
└── generator/                # Rust catalog generator
    ├── Cargo.toml
    └── src/
```

## Intended Usage (Once Complete)

### Direct package access
```nix
{
  inputs.nix-fonts.url = "github:rutrum/nix-fonts";

  # In your NixOS config:
  fonts.packages = [
    inputs.nix-fonts.packages.${system}.open-sans
    inputs.nix-fonts.packages.${system}.raleway
  ];
}
```

### Using the NixOS module
```nix
{
  imports = [ inputs.nix-fonts.nixosModules.default ];

  nix-fonts = {
    enable = true;
    fonts = [ "open-sans" "fira-code" "raleway" ];
  };
}
```

### Using the Home Manager module
```nix
{
  imports = [ inputs.nix-fonts.homeManagerModules.default ];

  nix-fonts = {
    enable = true;
    fonts = [ "open-sans" "fira-code" ];
  };
}
```

### Custom fonts via lib
```nix
let
  myFont = inputs.nix-fonts.lib.fontSquirrel.mkFont {
    inherit pkgs;
    fontDef = {
      name = "My Font";
      url_name = "my-font";
      download_url = "https://example.com/my-font.zip";
      sha256 = "sha256-...";
    };
  };
in { fonts.packages = [ myFont ]; }
```

## Development

```bash
# Enter dev shell
nix develop

# Build the generator
cd generator && cargo build

# Run generator (currently blocked by FontSquirrel WAF)
cargo run -- generate --limit 5 --output ../catalog.json

# Check flake
nix flake check
```

## License

MIT
