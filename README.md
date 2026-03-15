# nix-fonts

Declarative font installation for NixOS and Home Manager.

## Quick Start

```nix
{
  inputs.nix-fonts.url = "github:rutrum/nix-fonts";

  outputs = { self, nixpkgs, nix-fonts, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        nix-fonts.nixosModules.default
        {
          nix-fonts = {
            enable = true;
            googleFonts = [ "roboto" "open-sans" "fira-code" ];
          };
        }
      ];
    };
  };
}
```

## Installation

### Flake Input

Add nix-fonts to the flake inputs:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-fonts.url = "github:rutrum/nix-fonts";
  };
}
```

### NixOS Module

Import the module and configure fonts:

```nix
{ inputs, ... }:

{
  imports = [ inputs.nix-fonts.nixosModules.default ];

  nix-fonts = {
    enable = true;
    googleFonts = [ "roboto" "inter" "jetbrains-mono" ];
  };
}
```

Fonts are installed system-wide via `fonts.packages`. NixOS automatically configures fontconfig to discover these fonts.

### Home Manager Module

For user-level font installation:

```nix
{ inputs, ... }:

{
  imports = [ inputs.nix-fonts.homeManagerModules.default ];

  nix-fonts = {
    enable = true;
    googleFonts = [ "roboto" "open-sans" ];
  };
}
```

Fonts are installed per-user via `home.packages`. The module automatically enables `fonts.fontconfig.enable` so that fontconfig discovers the fonts in the user profile.

## Usage

### Google Fonts

Fonts in the catalog can be specified by name:

```nix
nix-fonts.googleFonts = [
  "roboto"
  "open-sans"
  "fira-code"
  "jetbrains-mono"
];
```

For fonts not in the catalog, or when using non-default subsets or formats, provide the full configuration with a sha256 hash:

```nix
nix-fonts.googleFonts = [
  "roboto"  # From catalog
  {
    name = "noto-sans";
    subsets = [ "latin" "cyrillic" ];
    sha256 = "sha256-...";
  }
  {
    name = "open-sans";
    formats = [ "woff2" ];
    sha256 = "sha256-...";
  }
];
```

The default configuration uses `latin` subset and `ttf` format. Fonts in the catalog have pre-computed hashes for this configuration.

### DaFont

DaFont fonts always require a sha256 hash:

```nix
nix-fonts.dafont = [
  { name = "pacifico"; sha256 = "sha256-..."; }
  { name = "lobster"; sha256 = "sha256-..."; }
];
```

The font name should match the URL format on dafont.com. For example, `https://www.dafont.com/pacifico.font` uses the name `pacifico`.

### Extra Fonts

Additional font packages can be included via `extraFonts`:

```nix
nix-fonts = {
  enable = true;
  googleFonts = [ "roboto" ];
  extraFonts = [ pkgs.nerdfonts ];
};
```

## CLI Tools

### search-fonts

Search and browse available fonts in the catalog:

```bash
# Search by name
nix run github:rutrum/nix-fonts#search-fonts -- roboto

# List all fonts
nix run github:rutrum/nix-fonts#search-fonts -- --list

# Filter by provider
nix run github:rutrum/nix-fonts#search-fonts -- --provider googlefonts

# Filter by category
nix run github:rutrum/nix-fonts#search-fonts -- --category monospace
```

### add-font

Get the configuration snippet for a font, with automatic hash fetching:

```bash
# Google Fonts (from catalog)
nix run github:rutrum/nix-fonts#add-font -- googlefonts roboto
# Output:
#   nix-fonts.googleFonts = [
#     "roboto"
#   ];

# Google Fonts (not in catalog - fetches hash)
nix run github:rutrum/nix-fonts#add-font -- googlefonts fira-code
# Output:
#   nix-fonts.googleFonts = [
#     { name = "fira-code"; sha256 = "sha256-..."; }
#   ];

# DaFont (always fetches hash)
nix run github:rutrum/nix-fonts#add-font -- dafont pacifico
# Output:
#   nix-fonts.dafont = [
#     { name = "pacifico"; sha256 = "sha256-..."; }
#   ];
```

For Google Fonts with custom subsets or formats:

```bash
nix run github:rutrum/nix-fonts#add-font -- googlefonts noto-sans --subsets latin,cyrillic
```

## Providers

### Google Fonts

The primary and recommended provider. Google Fonts are served via the [google-webfonts-helper](https://gwfh.mranftl.com) API.

- Over 1900 fonts available
- Pre-computed hashes in the catalog for the default configuration (latin subset, ttf format)
- Custom subsets and formats supported with user-provided hash

### DaFont

DaFont provides decorative, novelty, and specialty fonts.

- No catalog support; all fonts require a user-provided sha256 hash
- Use the `add-font` CLI tool to fetch hashes

### FontSquirrel

FontSquirrel downloads are currently blocked by CloudFront WAF protection. The provider code exists but cannot fetch fonts programmatically.

## Advanced Usage

### Library Functions

For direct access to font-building functions:

```nix
let
  inherit (inputs.nix-fonts.lib) googlefonts dafont;
in {
  # Build a font from the catalog
  fonts.packages = [
    (googlefonts.mkFontByName pkgs "roboto")
  ];

  # Build a font dynamically (not in catalog)
  fonts.packages = [
    (googlefonts.mkFontDynamic {
      inherit pkgs;
      name = "my-font";
      sha256 = "sha256-...";
      subsets = [ "latin" "greek" ];
      formats = [ "ttf" ];
    })
  ];

  # DaFont dynamic font
  fonts.packages = [
    (dafont.mkFontDynamic {
      inherit pkgs;
      name = "pacifico";
      sha256 = "sha256-...";
    })
  ];
}
```

## Troubleshooting

### Hash mismatch error

If a font download fails with a hash mismatch, the upstream font may have been updated. Use the `add-font` tool to fetch the current hash:

```bash
nix run github:rutrum/nix-fonts#add-font -- googlefonts <font-name>
```

### Font not found in catalog

For fonts not in the catalog, provide the full configuration with sha256:

```nix
nix-fonts.googleFonts = [
  { name = "uncommon-font"; sha256 = "sha256-..."; }
];
```

Use `add-font` to fetch the hash automatically.

### DaFont download fails

Ensure the font name matches the DaFont URL format. The name should be lowercase with underscores:

- `https://www.dafont.com/my-font.font` → `name = "my_font"`
- `https://www.dafont.com/cool-font.font` → `name = "cool_font"`

### Fonts not appearing after rebuild

Run `fc-cache -f` to refresh the font cache, or log out and back in.

## License

MIT
