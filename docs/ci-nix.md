# CI Module - Nix Operations

Pipeline-friendly Nix flake and cache management operations.

## Philosophy

All commands are designed for **pipeline composition**:
- Accept input from stdin (list of flake paths or store paths)
- Output structured tables for filtering
- Default to current directory `["."]` if no input provided
- Continue on failures, report status in output table

## Requirements

- Nix with flakes enabled

## Commands

### `ci nix flakes`

Filter paths to only include flake directories (containing `flake.nix`).

**Input:**
- `list<string>` - List of directory paths

**Output:**
- `list<string>` - List of paths that contain `flake.nix`

**Examples:**
```nu
# Filter arbitrary paths to find flakes
["." "../backend" "../docs" "../frontend"] | ci nix flakes
# Output: ["." "../backend" "../frontend"]

# Find all subdirectories that are flakes
ls | where type == "dir" | get name | ci nix flakes

# Chain with other commands
ls | where type == "dir" | get name | ci nix flakes | ci nix check
```

---

### `ci nix check`

Check flakes for issues.

**Input:**
- `list<string>` - List of flake paths
- `string` - Single flake path
- `nothing` - Defaults to `["."]`

**Flags:**
- `--impure` - Allow impure evaluation
- `--args <string>` - Additional arguments to pass to nix flake check (e.g., "--verbose --option cores 4")

**Output Table:**
```
┌───────┬─────────┬───────┐
│ flake │ status  │ error │
├───────┼─────────┼───────┤
│ .     │ success │ null  │
└───────┴─────────┴───────┘
```

**Examples:**
```nu
# Check single flake (current directory)
ci nix check

# Check specific flake
"../myflake" | ci nix check

# Check multiple flakes
["." "../backend" "../frontend"] | ci nix check

# Check with impure evaluation
ci nix check --impure

# Check with additional arguments
ci nix check --args "--verbose --option cores 4"

# Filter failures
["." "../backend"] | ci nix check | where status == "failed"
```

---

### `ci nix update`

Update flake inputs.

**Input:**
- `list<string>` - List of flake paths
- `string` - Single flake path
- `nothing` - Defaults to `["."]`

**Args:**
- `[input]` - Specific input to update (optional, updates all if omitted)

**Output Table:**
```
┌───────┬─────────┬─────────┬───────┐
│ flake │ input   │ status  │ error │
├───────┼─────────┼─────────┼───────┤
│ .     │ nixpkgs │ success │ null  │
└───────┴─────────┴─────────┴───────┘
```

**Examples:**
```nu
# Update all inputs in current flake
ci nix update

# Update specific input
ci nix update nixpkgs

# Update multiple flakes
["." "../backend"] | ci nix update

# Update specific input in multiple flakes
["." "../backend"] | ci nix update nixpkgs

# Check which updates failed
["." "../backend"] | ci nix update | where status == "failed"
```

---

### `ci nix packages`

List packages from flakes.

**Input:**
- `list<string>` - List of flake paths
- `string` - Single flake path
- `nothing` - Defaults to `["."]`

**Output Table:**
```
┌───────┬──────────┬───────────────┐
│ flake │ name     │ system        │
├───────┼──────────┼───────────────┤
│ .     │ myapp    │ x86_64-linux  │
│ .     │ frontend │ x86_64-linux  │
└───────┴──────────┴───────────────┘
```

**Examples:**
```nu
# List packages in current flake
ci nix packages

# List packages in multiple flakes
["." "../backend"] | ci nix packages

# Filter by system
ci nix packages | where system == "aarch64-darwin"

# Get package names only
ci nix packages | get name

# Find packages across multiple flakes
["." "../backend" "../frontend"] | ci nix packages | where name =~ "web"
```

---

### `ci nix build`

Build packages from flakes.

**Input:**
- `list<string>` - List of flake paths
- `string` - Single flake path
- `nothing` - Defaults to `["."]`

**Args:**
- `[...packages]` - Specific packages to build (optional, builds all if omitted)

**Flags:**
- `--impure` - Allow impure evaluation
- `--args <string>` - Additional arguments to pass to nix build (e.g., "--option cores 8")

**Output Table:**
```
┌───────┬─────────┬──────────────┬────────────────────┬─────────┬───────┐
│ flake │ package │ system       │ path               │ status  │ error │
├───────┼─────────┼──────────────┼────────────────────┼─────────┼───────┤
│ .     │ myapp   │ x86_64-linux │ /nix/store/abc-... │ success │ null  │
└───────┴─────────┴──────────────┴────────────────────┴─────────┴───────┘
```

**Examples:**
```nu
# Build all packages in current flake
ci nix build

# Build specific package
ci nix build myapp

# Build multiple specific packages
ci nix build myapp frontend api

# Build with impure evaluation
ci nix build myapp --impure

# Build with additional arguments
ci nix build myapp --args "--option cores 8"

# Build from multiple flakes
["." "../backend"] | ci nix build

# Build specific packages from multiple flakes
["." "../backend"] | ci nix build web-ui api

# Get successful build paths
ci nix build | where status == "success" | get path

# Show only failures
ci nix build | where status == "failed" | select package error
```

---

### `ci nix closure`

Get the full closure (all dependencies) of Nix store paths.

**Input:**
- `list<string>` - List of Nix store paths
- `string` - Single store path

**Output:**
- `list<string>` - List of all paths in the closure (input paths + all dependencies)

**Examples:**
```nu
# Get closure of a single path
'/nix/store/abc-myapp' | ci nix closure

# Get closure of multiple paths
['/nix/store/abc-myapp' '/nix/store/def-api'] | ci nix closure

# Build and get full closure (for pushing to cache)
ci nix build myapp | where status == "success" | get path | ci nix closure

# Build and publish the closures of the successful builds
ci nix build | ci nix publish "https://ck3mp3r.cachix.org"
```

**Use Cases:**
- **Cache population**: Push packages with all dependencies
- **Dependency analysis**: See what a package depends on
- **Offline installations**: Export complete closures

---

### `ci nix publish`

Push the closures of build rows to a binary cache and return one honest row per path.

**Input:**
- `list<record>` - `ci nix build` rows (`{flake, package, system, path, status, error}`); rows with `path: null` are ignored

**Arguments:**
- `cache` - Target cache (required): a cachix name, `https://<name>.cachix.org`, or a store URI (pushed with `nix copy --to`)

**Flags:**
- `--dry-run` - Log the batch plan and push nothing (returns an empty row list)

**Output Table:**
```
┌────────────────────┬──────────┬───────┐
│ path               │ status   │ error │
├────────────────────┼──────────┼───────┤
│ /nix/store/abc-... │ uploaded │ null  │
│ /nix/store/def-... │ skipped  │ null  │
└────────────────────┴──────────┴───────┘
```

**Fields:**
- `status` - `uploaded` (parsed from cachix's per-path output), `skipped` (the rest of a successful batch - cachix skips server side), or `failed` (the rest of a batch that failed twice)
- `error` - Failure text from the failed batch, `null` otherwise

**Contract:** the command exits `0` iff no row is `failed` after the batch retry, and `1` otherwise, so it gates CI directly. Paths are deduped, derivations (`.drv`) dropped and sorted; pushes run in serial batches under a ~200 KB argv budget. Every batch logs its outcome: index/total, path count, argv size, exit code and the uploaded/skipped/failed counts.

**Cache URI Formats:**
- Cachix: `cachix` (default cachix config) or `https://<name>.cachix.org`
- S3: `s3://bucket-name`
- File: `file:///path/to/cache`
- HTTP: `https://cache.example.com`

**Examples:**
```nu
# Build rows in, honest rows out
let results = (ci nix build)
$results | ci nix publish "https://ck3mp3r.cachix.org"

# Count what actually uploaded
$results | ci nix publish "https://ck3mp3r.cachix.org" | where status == "uploaded" | length

# Inspect failures
$results | ci nix publish "https://ck3mp3r.cachix.org" | where status == "failed"

# Push to a store URI instead
$results | ci nix publish "s3://mybucket"

# Plan only: no cachix or nix copy process is spawned
$results | ci nix publish "https://ck3mp3r.cachix.org" --dry-run
```

## Pipeline Patterns

### Build → Publish

```nu
# Build all, publish the closures of the successful builds
ci nix build | ci nix publish "https://ck3mp3r.cachix.org"

# Count uploaded vs skipped
ci nix build
  | ci nix publish "https://ck3mp3r.cachix.org"
  | where status == "uploaded"
  | length

# Build specific packages, publish to two caches
ci nix build web api
  | tee { ci nix publish "https://ck3mp3r.cachix.org" }
  | ci nix publish "s3://backup"
```

A failed push fails the command (exit 1), so the pipeline gates CI without an extra check.

### Multi-Flake Operations

```nu
# Check multiple flakes, show failures
["." "../backend" "../frontend"] 
  | ci nix check 
  | where status == "failed"

# Update and check multiple flakes
["." "../backend"]
  | ci nix update nixpkgs
  | get flake
  | ci nix check

# List all packages across flakes
["." "../backend" "../frontend"]
  | ci nix packages
  | group-by system
```

### Complex Workflows

```nu
# Update → Check → Build → Push
def deploy-all [] {
  let flakes = ["." "../backend" "../frontend"]
  
  # Update all flakes
  $flakes | ci nix update
  
  # Check all flakes
  let check_results = ($flakes | ci nix check)
  
  # Only build flakes that passed checks
  $check_results 
    | where status == "success"
    | get flake
    | ci nix build
    | ci nix publish "https://ck3mp3r.cachix.org"
}

# Conditional build based on package discovery
def build-web-packages [] {
  ci nix packages
    | where name =~ "web"
    | get name
    | each {|pkg| ci nix build $pkg}
    | flatten
    | where status == "success"
}
```

### Filtering and Selection

```nu
# Build only for specific system
ci nix packages
  | where system == "aarch64-darwin"
  | get name
  | ci nix build

# Get build paths as list
let paths = (ci nix build | where status == "success" | get path)

# Show build summary
ci nix build
  | group-by status
  | transpose status count
```

## System Detection

The module automatically detects your system architecture:

| OS    | Architecture | Nix System       |
|-------|--------------|------------------|
| macOS | ARM64        | aarch64-darwin   |
| macOS | x86_64       | x86_64-darwin    |
| Linux | ARM64        | aarch64-linux    |
| Linux | x86_64       | x86_64-linux     |

**Fallback Behavior:**
- If system detection fails, uses first available system from flake
- Logs warning when using fallback
- Particularly useful in test/CI environments

## Error Handling

All commands follow consistent error handling:

1. **Continue on Failure**: Processing continues for remaining items
2. **Status in Output**: Each result includes `status` field (`success`/`failed`)
3. **Error Details**: Failed results include `error` field with message
4. **Filter Results**: Use `where status == "failed"` to inspect failures

**Examples:**
```nu
# See all errors
ci nix build | where status == "failed" | select package error

# Count failures
ci nix build | where status == "failed" | length

# Retry failures
ci nix build 
  | where status == "failed" 
  | get package 
  | ci nix build
```

## Logging

Uses `std/log` for operation logging:

```nu
$env.NU_LOG_LEVEL = "DEBUG"  # All operations
$env.NU_LOG_LEVEL = "INFO"   # Important steps (default)
$env.NU_LOG_LEVEL = "WARN"   # Warnings only
$env.NU_LOG_LEVEL = "ERROR"  # Errors only
```

## Deterministic Builds

All build and evaluation commands use `--no-update-lock-file` to ensure:
- Lock files are never modified during builds
- Builds are reproducible across different machines
- CI/CD pipelines remain deterministic
- Flake lock files only update via explicit `ci nix update` commands

This prevents unexpected lock file changes that can occur with:
- Subdirectory flakes (`?dir=`)
- Git shallow clones in CI
- Transitive dependency resolution

## Best Practices

1. **Use pipelines for composition:**
   ```nu
   ci nix check | get flake | ci nix build
   ```

2. **Publish only what built:**
   ```nu
   ci nix build | ci nix publish "https://ck3mp3r.cachix.org"
   ```

3. **Gate CI on the push:**
   ```nu
   ci nix build | ci nix publish "https://ck3mp3r.cachix.org" | where status == "uploaded" | length
   ```

4. **Operate on multiple flakes at once:**
   ```nu
   ["." "../backend"] | ci nix update | ci nix check | ci nix build
   ```

5. **Inspect failures:**
   ```nu
   ci nix build | where status == "failed" | select package error
   ```

6. **Save intermediate results:**
   ```nu
   let results = (ci nix build)
   $results | where status == "success" | get path | save successful_paths.txt
   $results | where status == "failed" | save failures.json
   ```
