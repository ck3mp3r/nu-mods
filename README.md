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

### CI Module
CI/CD utilities for SCM workflows and GitHub operations.

**Installation**: `nix profile install github:ck3mp3r/nu-mods#ci`

**SCM Commands**:
- `ci scm branch` - Create standardized branches with flow-based naming

**GitHub PR Commands**:
- `ci github pr check` - Check for existing PRs
- `ci github pr create` - Create a new pull request
- `ci github pr list` - List pull requests
- `ci github pr update` - Update existing PR (title/body)

**GitHub Workflow Commands**:
- `ci github workflow list` - List workflow runs
- `ci github workflow view` - View specific run details
- `ci github workflow logs` - Get workflow run logs
- `ci github workflow cancel` - Cancel a running workflow
- `ci github workflow rerun` - Re-run a workflow

**Nix Flake Commands**:
- `ci nix flake check` - Check flake for issues
- `ci nix flake update` - Update flake inputs (all or specific)
- `ci nix flake show` - Show flake outputs
- `ci nix flake list-packages` - List all buildable packages
- `ci nix flake build` - Build packages (all or specific)

**Nix Cache Commands**:
- `ci nix cache push` - Push store paths to binary cache

**Features**:
- Standardized branch naming: `<prefix>/<flow-type>/<description>`
- Flow types: `--feature`, `--fix`, `--hotfix`, `--release`, `--chore`
- Pipe prefix from stdin: `"JIRA-123" | ci scm branch "description"`
- Complete GitHub PR management
- Workflow run inspection and control
- Built-in logging with `std/log` (controlled by `NU_LOG_LEVEL`)

## Usage

Once installed, import modules in your Nushell session:

```nu
# Import the AI module
use ai

# Use AI commands
ai git commit
ai git create branch --prefix "JIRA-123" --description "Add login feature"
ai git create pr --target "develop"

# Import the CI module
use ci

# SCM branch management
"JIRA-1234" | ci scm branch "add user login" --feature
ci scm branch "v2.1.0" --release --from develop
"SEC-999" | ci scm branch "patch vulnerability" --hotfix --from production
ci scm branch "update dependencies" --chore --no-checkout

# GitHub PR operations
ci github pr check --target main
ci github pr create "feat: add feature" "Description here" --target main
ci github pr list --state open
ci github pr update 42 --title "New title"

# GitHub workflow operations
ci github workflow list
ci github workflow list --status failure
ci github workflow view 12345
ci github workflow logs 12345
ci github workflow cancel 12345
ci github workflow rerun 12345

# Nix operations
ci nix flake check
ci nix flake check --flake ../myflake
ci nix flake update
ci nix flake update nixpkgs
ci nix flake show
ci nix flake list-packages
ci nix flake build
ci nix flake build mypackage
ci nix cache push /nix/store/abc-pkg --cache s3://mybucket
ci nix cache push /nix/store/abc /nix/store/def --cache file:///cache
```

## Development

This project uses Nix flakes with devenv for development:

```bash
# Enter development environment
nix develop

# Available commands
check    # Check Nushell syntax
test     # Run tests
fmt      # Format code (placeholder)
```

### Testing

Tests use Nushell's testing framework with `--no-config-file` and mocked external commands:

```bash
# Run all tests
nu run_tests.nu

# Run a specific test file
nu --no-config-file tests/ai/test_provider.nu

# Run tests with specific mock values
MOCK_git_status_--porcelain="clean" nu --no-config-file tests/ai/test_git.nu
```

**Mock Pattern**: Tests use `--wrapped` functions that check for `MOCK_<command>_<args>` environment variables:
- `MOCK_git_status_--porcelain="?? file.txt"` - Mock `git status --porcelain`
- `MOCK_git_diff_--cached="changes"` - Mock `git diff --cached`
- `MOCK_opencode_run_--model_gpt-4_prompt="response"` - Mock `opencode run --model gpt-4 prompt`

This allows tests to run without actual external dependencies like `git`, `gh`, or `opencode`.

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