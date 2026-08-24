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
CI/CD utilities for SCM workflows, GitHub operations, Nix builds, Cargo versioning, Homebrew formulas, and artifact publishing.

**Installation**: `nix profile install github:ck3mp3r/nu-mods#ci`

The CI module is split into submodules: `scm`, `github`, `nix`, `cargo`, `homebrew`, `artifacts`, and `log`. All are re-exported from `modules/ci/mod.nu` and are available via `use ci *`.

#### ci scm
SCM workflow operations.

- `ci scm branch` - Create standardized branches with flow-based naming
  - Flags: `--prefix`, `--release`, `--fix`, `--hotfix`, `--chore`, `--feature`, `--from`, `--reuse`, `--version`, `--push`
  - `--version` uses the raw version as the branch suffix for release branches (e.g. `release/0.1.0`)
  - `--push` pushes the branch to origin after creation
  - Usage: `"JIRA-1234" | ci scm branch "add login" --feature --push`
- `ci scm commit` - Commit files to git with optional message
  - Flags: `--message (-m)`, `--push (-p)`, `--force-push`
  - `--force-push` uses `git push --force-with-lease` when `--push` is set
  - Usage: `"file.txt" | ci scm commit -m "feat: add feature" --push`
- `ci scm latest-tag` - Get the latest git tag, stripping the `v` prefix. Returns `""` if no tags.
  - Usage: `ci scm latest-tag`
- `ci scm semver` - Calculate the next semantic version from a latest tag and current version.
  - Accepts pre-release suffixed versions (e.g. `1.0.0-abc1234`); the semver core is extracted and the output is always clean `X.Y.Z`
  - Usage: `ci scm semver "1.0.0" "1.0.0"` (returns `1.0.1`)
  - Usage: `ci scm semver "1.0.0-abc1234" "1.0.0"` (returns `1.0.1`)
- `ci scm merge` - Merge a source branch into a target branch. Squash is the DEFAULT merge strategy.
  - Flags: `--message (-m)`, `--no-squash`, `--delete-remote`, `--target` (default `main`), `--push`
  - `--message` is required with the default squash merge; `--no-squash` uses a regular merge (auto-commits, no message needed)
  - Guards against empty commits when the squash merge produces no staged changes
  - Usage: `ci scm merge "release/0.1.0" -m "Release 0.1.0" --push --delete-remote`
- `ci scm config` - Configure git user name and email
- `ci scm changes` - Get list of changed files since branch was created

#### ci github
GitHub operations.

- `ci github pr check` - Check for existing PRs
- `ci github pr create` - Create a new pull request
- `ci github pr info` - Get PR information by branch name or PR number
- `ci github pr list` - List pull requests
- `ci github pr update` - Update existing PR (title/body)
- `ci github pr merge` - Merge a pull request
- `ci github release create` - Create a GitHub release with auto-generated changelog
  - Flags: `--prerelease (-p)`, `--target`, `--suffix`
  - `--prerelease` marks the release as a pre-release and appends a suffix to the tag (`v0.1.0-<sha>`)
  - `--suffix` overrides the default short-SHA suffix for pre-release tags (e.g. `--suffix nightly`)
  - `--target` targets a branch or commit SHA for the tag (works with or without `--prerelease`)
  - Usage: `ci github release create "0.1.0"`
  - Usage: `ci github release create "0.1.0" --prerelease --target "release/0.1.0" --suffix "nightly"`
- `ci github release upload` - Upload artifacts to a release tag via stdin
  - Usage: `["file1.tgz" "file2.tgz"] | ci github release upload "v0.1.0"`
  - Usage: `["file1.tgz"] | ci github release upload "v0.1.0-abc1234"` (pre-release tag)
- `ci github workflow list` - List workflow runs
- `ci github workflow view` - View specific run details
- `ci github workflow logs` - Get workflow run logs
- `ci github workflow cancel` - Cancel a running workflow
- `ci github workflow rerun` - Re-run a workflow
- `ci github summary` - Add content to GitHub Actions step summary

#### ci nix
Nix operations (pipeline-friendly).

- `ci nix check` - Check flakes for issues
- `ci nix update` - Update flake inputs (all or specific)
- `ci nix packages` - List packages from flakes
- `ci nix build` - Build packages (all or specific)
- `ci nix closure` - Get recursive dependencies of store paths
- `ci nix cache` - Check cache status or push store paths to a binary cache
- `ci nix publish` - Build a flake, get its closure, check upstream and cachix caches, and push missing paths
  - Flags: `--flake` (default `.`), `--upstream` (default `https://cache.nixos.org`)
  - Usage: `ci nix publish mycache --flake ".#myapp"`
- `ci nix missing-paths` - Filter cache-status records to paths missing from all caches
  - Usage: `[{path: "..." in_upstream: false in_cachix: false}] | ci nix missing-paths mycache`

#### ci cargo
Cargo operations.

- `ci cargo update-version` - Update the version in `Cargo.toml` and refresh `Cargo.lock` via `cargo check`
  - Handles both `workspace.package.version` (workspace root) and `package.version` (single crate)
  - Usage: `ci cargo update-version "0.2.0"`

#### ci homebrew
Homebrew formula operations.

- `ci homebrew update-formula` - Update version and per-architecture sha256 hashes in a Homebrew formula (pure string transformation via stdin)
  - Usage: `open Formula/context.rb | ci homebrew update-formula "0.2.0" "context" [{name: "aarch64-darwin" hash: "abc123"}] | save Formula/context.rb`

#### ci artifacts
Artifact platform data generation.

- `ci artifacts platform-data` - Generate per-arch JSON files in `data/` from downloaded artifacts and hash files
  - Flags: `--archive-ext`, `--hash-suffix`, `--tag`
  - `--tag` overrides the download URL release tag (default: `v$version`)
  - Usage: `ci artifacts platform-data "0.1.0" "./artifacts" "context"`
  - Usage: `ci artifacts platform-data "0.1.0" "./artifacts" "context" --tag "v0.1.0-abc1234"` (pre-release)
- `ci artifacts platform-data-for` - Checkout the release branch, generate platform data, and return created JSON files
  - Flags: `--tag` (passed through to `platform-data`)
  - Usage: `ci artifacts platform-data-for "0.1.0" "context"`
  - Usage: `ci artifacts platform-data-for "0.1.0" "context" --tag "v0.1.0-abc1234"`

#### ci log
Enhanced logging.

- `ci log debug` / `ci log info` / `ci log warning` / `ci log error` / `ci log critical` - Pipe-only logging with custom icons
  - Usage: `"message" | ci log info`

**Features**:
- Standardized branch naming: `<prefix>/<flow-type>/<description>`
- Flow types: `--feature`, `--fix`, `--hotfix`, `--release`, `--chore`
- Complete GitHub PR and workflow management
- GitHub release creation with auto-generated changelogs
- Nix flake build/cache/publish pipeline
- Cargo version bumping with `cargo check`
- Homebrew formula updates with per-arch sha256 hashes
- Per-arch artifact platform data generation
- Built-in logging with `std/log` (controlled by `NU_LOG_LEVEL`)

## Usage

Once installed, import modules in your Nushell session:

```nu
# Import the AI module
use ai *

# Use AI commands
ai git commit
ai git create branch --prefix "JIRA-123" --description "Add login feature"
ai git create pr --target "develop"

# Import the CI module
use ci *

# SCM branch management
"JIRA-1234" | ci scm branch "add user login" --feature
ci scm branch "v2.1.0" --release --from develop
"SEC-999" | ci scm branch "patch vulnerability" --hotfix --from production
ci scm branch "update dependencies" --chore --no-checkout

# SCM version and merge
ci scm latest-tag
ci scm semver "1.0.0" "1.0.0"
ci scm merge "release/0.1.0" -m "Release 0.1.0" --push --delete-remote

# GitHub PR operations
ci github pr check --target main
ci github pr create "feat: add feature" "Description here" --target main
ci github pr list --state open
ci github pr update 42 --title "New title"

# GitHub release operations
ci github release create "0.1.0"
ci github release create "0.1.0" --prerelease --target "release/0.1.0" --suffix "nightly"
["file1.tgz" "file2.tgz"] | ci github release upload "v0.1.0"
["file1.tgz"] | ci github release upload "v0.1.0-abc1234"

# GitHub workflow operations
ci github workflow list
ci github workflow list --status failure
ci github workflow view 12345
ci github workflow logs 12345
ci github workflow cancel 12345
ci github workflow rerun 12345

# Nix operations (pipeline-friendly)
ci nix check
ci nix check --impure
ci nix update nixpkgs
ci nix packages
ci nix build
ci nix build mypackage --impure
ci nix build | where status == "success" | get path | ci nix cache --cache cachix
["." "../backend"] | ci nix build | ci nix cache --cache s3://bucket
ci nix publish mycache --flake ".#myapp"

# Cargo version bump
ci cargo update-version "0.2.0"

# Homebrew formula update
open Formula/context.rb | ci homebrew update-formula "0.2.0" "context" [{name: "aarch64-darwin" hash: "abc123"}]

# Artifact platform data
ci artifacts platform-data "0.1.0" "./artifacts" "context"
ci artifacts platform-data "0.1.0" "./artifacts" "context" --tag "v0.1.0-abc1234"
ci artifacts platform-data-for "0.1.0" "context"
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

### Pre-push Hooks (prek)

[prek](https://prek.j178.dev/) runs two local hooks before `git push` reaches the remote:

- `nu-check` — `nu --ide-check 100` on every changed `.nu` file (syntax guard)
- `nu-tests` — `nu run_tests.nu` over the full test suite (regression guard)

Both are declared in [`prek.toml`](./prek.toml) with `default_install_hook_types = ["pre-push"]`, so the git shim is installed once per clone:

```bash
nix develop       # provides prek on PATH
prek install      # writes .git/hooks/pre-push shim
```

Run the same checks on demand:

```bash
prek run --stage pre-push        # only the pre-push hooks
prek run --all-files             # every hook against all tracked files
prek run nu-check --all-files    # a single hook
```

To bypass the hooks for a single push, use `git push --no-verify`. Remove the shims with `prek uninstall`.

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