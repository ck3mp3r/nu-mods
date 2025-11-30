# Nu Mods Documentation

Succinct documentation for all available Nushell modules.

## Modules

- **[AI Module](ai.md)** - AI-powered git operations for intelligent workflow automation
- **[CI Module](ci.md)** - CI/CD utilities for SCM, GitHub, and Nix operations
  - [SCM Operations](ci-scm.md) - Standardized branch management
  - [GitHub Operations](ci-github.md) - PR and workflow management
  - [Nix Operations](ci-nix.md) - Flake and cache management

## Quick Start

### Installation

```nu
# Install all modules via Nix
nix profile install github:ck3mp3r/nu-mods

# Add to config.nu
const NU_LIB_DIRS = [
    "/nix/var/nix/profiles/default/share/nushell/modules"
]
```

### Usage

```nu
# Import modules
use ai
use ci

# Use commands
ai git commit
ci scm branch "add feature" --feature
ci github pr create "feat: add" "description"
ci nix flake build
```

## Development

```bash
# Run tests
nu run_tests.nu

# Check syntax
nix develop -c check

# Format code
nix develop -c fmt
```

## Environment Variables

- `NU_LOG_LEVEL` - Set logging level (DEBUG, INFO, WARN, ERROR)
- `NU_TEST_MODE` - Enable test mode with mocked commands
