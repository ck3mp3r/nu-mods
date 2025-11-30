# CI Module - Nix Operations

Nix flake and cache management operations.

## Requirements

- Nix with flakes enabled

## Flake Commands

### `ci nix flake check`

Check flake for issues.

**Usage:**
```nu
ci nix flake check [--flake <path>]
```

**Options:**
- `--flake` - Path to flake (default: current directory)

**Example:**
```nu
ci nix flake check
ci nix flake check --flake ../myflake
ci nix flake check --flake /path/to/flake
```

---

### `ci nix flake update`

Update flake inputs.

**Usage:**
```nu
ci nix flake update [input] [--flake <path>]
```

**Positional:**
- `input` - Specific input to update (optional, updates all if omitted)

**Options:**
- `--flake` - Path to flake (default: current directory)

**Example:**
```nu
# Update all inputs
ci nix flake update

# Update specific input
ci nix flake update nixpkgs
ci nix flake update home-manager
```

---

### `ci nix flake show`

Show flake outputs in YAML format.

**Usage:**
```nu
ci nix flake show [--flake <path>]
```

**Options:**
- `--flake` - Path to flake (default: current directory)

**Example:**
```nu
ci nix flake show
ci nix flake show --flake ../myflake
```

---

### `ci nix flake list-packages`

List all buildable packages in the flake.

**Usage:**
```nu
ci nix flake list-packages [--flake <path>]
```

**Options:**
- `--flake` - Path to flake (default: current directory)

**Output:**
```
x86_64-linux:
  - package1
  - package2

aarch64-darwin:
  - package1
```

**Example:**
```nu
ci nix flake list-packages
ci nix flake list-packages --flake ../myflake
```

---

### `ci nix flake build`

Build flake packages.

**Usage:**
```nu
ci nix flake build [package] [--flake <path>]
```

**Positional:**
- `package` - Specific package to build (optional, builds all if omitted)

**Options:**
- `--flake` - Path to flake (default: current directory)

**Features:**
- Auto-detects current system (Darwin/Linux, aarch64/x86_64)
- Builds all packages for current system when no package specified
- Returns store paths

**Example:**
```nu
# Build specific package
ci nix flake build mypackage

# Build all packages for current system
ci nix flake build

# Build from different flake
ci nix flake build mypackage --flake ../otherflake
```

## Cache Commands

### `ci nix cache push`

Push store paths to binary cache.

**Usage:**
```nu
ci nix cache push <paths...> --cache <uri>
```

**Positional:**
- `paths...` - One or more Nix store paths to push

**Options:**
- `--cache` - Cache URI (required)

**Cache URI Formats:**
- S3: `s3://bucket-name`
- File: `file:///path/to/cache`
- HTTP: `https://cache.example.com`

**Example:**
```nu
# Push single path to S3
ci nix cache push /nix/store/abc-pkg --cache s3://mybucket

# Push multiple paths
ci nix cache push /nix/store/abc /nix/store/def --cache s3://mybucket

# Push to file cache
ci nix cache push /nix/store/pkg --cache file:///var/cache/nix

# Push build output
let path = (ci nix flake build mypackage | last)
ci nix cache push $path --cache s3://mybucket
```

## Workflow Examples

### Build and Push to Cache

```nu
# Build all packages
ci nix flake build

# Build and push specific package
let path = (ci nix flake build mypackage | last)
ci nix cache push $path --cache s3://mybucket
```

### Update and Verify Flake

```nu
# Update all inputs
ci nix flake update

# Check for issues
ci nix flake check

# List what's buildable
ci nix flake list-packages

# Build to verify
ci nix flake build
```

### Cross-Flake Operations

```nu
# Check multiple flakes
ci nix flake check --flake ./backend
ci nix flake check --flake ./frontend

# Update specific input in multiple flakes
ci nix flake update nixpkgs --flake ./backend
ci nix flake update nixpkgs --flake ./frontend
```

## System Detection

The module automatically detects your system:

| OS | Architecture | Nix System |
|----|--------------|------------|
| macOS | ARM64 | aarch64-darwin |
| macOS | x86_64 | x86_64-darwin |
| Linux | ARM64 | aarch64-linux |
| Linux | x86_64 | x86_64-linux |

When building all packages, it builds only for your current system.

## Logging

Uses `std/log` for operation logging:

```nu
$env.NU_LOG_LEVEL = "DEBUG"  # All operations
$env.NU_LOG_LEVEL = "INFO"   # Important steps
$env.NU_LOG_LEVEL = "ERROR"  # Errors only
```

## Error Handling

- Validates flake exists
- Checks cache URI provided
- Handles Nix errors gracefully
- Provides clear error messages
- Shows which operations failed
