# CI Module

CI/CD utilities for SCM workflows, GitHub operations, and Nix management.

## Installation

```bash
nix profile install github:ck3mp3r/nu-mods#ci
```

## Sub-modules

The CI module consists of three main components:

### 1. SCM Operations
Standardized branch management with flow-based naming.

📖 [Full SCM Documentation](ci-scm.md)

**Quick Example:**
```nu
"JIRA-1234" | ci scm branch "add login" --feature
```

### 2. GitHub Operations
PR and workflow management via GitHub CLI.

📖 [Full GitHub Documentation](ci-github.md)

**Quick Example:**
```nu
ci github pr create "feat: add feature" "Description" --target main
ci github workflow list --status failure
```

### 3. Nix Operations
Pipeline-friendly flake and cache management.

📖 [Full Nix Documentation](ci-nix.md)

**Quick Example:**
```nu
# Pipeline composition
ci nix build | ci nix publish "https://ck3mp3r.cachix.org"

# Multi-flake operations
["." "../backend"] | ci nix check | ci nix update | ci nix build
```

## Complete Workflow Example

### Feature Development Flow

```nu
# 1. Create feature branch
"PROJ-123" | ci scm branch "add authentication" --feature

# 2. Make changes, then build and test with Nix
ci nix check
let build_results = (ci nix build)

# 3. Publish the closures of the successful builds
$build_results | ci nix publish "s3://mybucket"

# 4. Create PR
ci github pr create "feat: add authentication" "Implements user auth" --target main

# 5. Monitor workflow
ci github workflow list
ci github workflow view 12345
```

### Hotfix Flow

```nu
# 1. Create hotfix branch from production
"SEC-999" | ci scm branch "fix vulnerability" --hotfix --from production

# 2. Verify fix
ci nix check
ci nix build

# 3. Create urgent PR
ci github pr create "hotfix: security patch" "Critical fix" --target production

# 4. Monitor deployment
ci github workflow list --status in_progress
```

### Release Flow

```nu
# 1. Create release branch
ci scm branch "v2.1.0" --release --from develop

# 2. Update dependencies
ci nix update

# 3. Build all packages and publish the closures
ci nix build | ci nix publish "s3://releases"

# 5. Create release PR
ci github pr create "release: v2.1.0" "Release notes..." --target main
```

## Requirements

### Per Sub-module

| Module | Requirements |
|--------|-------------|
| SCM | Git |
| GitHub | GitHub CLI (`gh`) |
| Nix | Nix with flakes enabled |

### Environment Variables

- `NU_LOG_LEVEL` - Set logging level (DEBUG, INFO, WARN, ERROR)

## Common Patterns

### Branch → Build → PR

```nu
# Create branch and build in one flow
"TICKET-123" | ci scm branch "new feature" --feature
ci nix build | ci nix publish "https://ck3mp3r.cachix.org"
ci github pr create "feat: new feature" "Description"
```

### Update → Check → Build → Publish

```nu
# Update, verify, build, and publish - all in pipeline
ci nix update 
  | get flake 
  | ci nix check 
  | where status == "success"
  | get flake
  | ci nix build
  | ci nix publish "https://ck3mp3r.cachix.org"
```

### List → View → Logs

```nu
# Debug workflow issues
ci github workflow list --status failure
ci github workflow view 12345
ci github workflow logs 12345
```

## Best Practices

1. **Always check before committing:**
   ```nu
   ci nix check
   ```

2. **Use ticket prefixes consistently:**
   ```nu
   "PROJ-123" | ci scm branch "description" --feature
   ```

3. **Use pipelines for build → publish:**
   ```nu
   ci nix build | ci nix publish "https://ck3mp3r.cachix.org"
   ```

4. **Monitor workflows after PR:**
   ```nu
   ci github workflow list --status failure
   ```

5. **Operate on multiple flakes:**
   ```nu
   ["." "../backend" "../frontend"] | ci nix check | ci nix build
   ```

## Error Handling

All CI commands:
- Validate required tools are installed
- Check current state before operations
- Provide clear error messages
- Use `std/log` for debugging (set `NU_LOG_LEVEL`)

## See Also

- [SCM Operations](ci-scm.md) - Detailed SCM documentation
- [GitHub Operations](ci-github.md) - Detailed GitHub documentation
- [Nix Operations](ci-nix.md) - Detailed Nix documentation
- [AI Module](ai.md) - AI-powered git operations
