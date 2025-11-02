# Nu Mods

A collection of Nushell modules for extending shell functionality with AI-powered automation and utilities.

## About

This repository contains various Nushell modules that provide additional commands and utilities for the Nu shell environment. Currently includes AI-powered git operations for intelligent workflow automation.

## Installation

### Nix Flake (Recommended)

Install via Nix flakes for easy management and automatic updates:

```bash
# Install all modules
nix profile install github:ck3mp3r/nu-mods

# Install just the AI module
nix profile install github:ck3mp3r/nu-mods#ai
```

Then add to your Nushell `config.nu`:

```nu
const NU_LIB_DIRS = [
    "/nix/var/nix/profiles/default/share/nushell/modules"
]
```

### Manual Installation

#### Method 1: Environment Variable
Set the `NU_LIB_DIRS` environment variable to include this directory:

```bash
export NU_LIB_DIRS="/path/to/nu-mods/modules"
```

#### Method 2: Config File
Add this directory to your `config.nu` file:

```nu
const NU_LIB_DIRS = [
    "/path/to/nu-mods/modules"
]
```

## Available Modules

### AI Module
AI-powered git operations for intelligent workflow automation.

**Installation**: `nix profile install github:ck3mp3r/nu-mods#ai`

**Commands**:
- `ai git commit` - Generate conventional commit messages from staged changes
- `ai git create branch` - Create branches with AI-generated names
- `ai git create pr` - Generate PR titles and descriptions

**Features**:
- Support for ticket prefixes (ABC-123 format)
- Interactive workflows with create/retry/edit/abort options
- Configurable AI models via `--model` flag
- Requires [mods CLI](https://github.com/charmbracelet/mods) for AI integration

## Usage

Once installed, import modules in your Nushell session:

```nu
# Import the AI module
use ai

# Use AI commands
ai git commit
ai git create branch --prefix "JIRA-123" --description "Add login feature"
ai git create pr --target "develop"
```

## Development

This project uses Nix flakes with devenv for development:

```bash
# Enter development environment
nix develop

# Available commands
check    # Check Nushell syntax
test     # Run tests (placeholder)
fmt      # Format code (placeholder)
```

## Package Structure

```
/nix/store/.../share/nushell/
├── modules/
│   └── ai/
│       ├── git.nu    # AI git operations
│       └── mod.nu    # Module exports
└── README.md
```

## Contributing

Feel free to contribute additional modules or improvements to existing ones. Follow the established patterns for new modules:

1. Create module directory under `modules/`
2. Add package definition to `flake.nix`
3. Include in global package bundle
4. Update README with module documentation