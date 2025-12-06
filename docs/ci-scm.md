# CI Module - SCM Operations

Standardized branch management following conventional flow types.

## Commands

### `ci scm branch`

Create standardized branches with flow-based naming.

**Usage:**
```nu
ci scm branch <description> [flags]
```

**Positional:**
- `description` - Branch description (sanitized to kebab-case)

**Flags:**
- `--feature` - Feature branch (default)
- `--fix` - Bugfix branch
- `--hotfix` - Hotfix branch
- `--release` - Release branch
- `--chore` - Chore/maintenance branch
- `--from <branch>` - Base branch (default: main)
- `--no-checkout` - Create without checking out

**Branch Format:**
```
[<prefix>/]<flow>/<description>
```

**Examples:**

```nu
# Feature branch (default)
ci scm branch "add user login"
# Creates: feature/add-user-login

# With ticket prefix from stdin
"JIRA-1234" | ci scm branch "add login" --feature
# Creates: JIRA-1234/feature/add-login

# Bugfix
ci scm branch "login bug" --fix
# Creates: fix/login-bug

# Hotfix from production
"SEC-999" | ci scm branch "patch vulnerability" --hotfix --from production
# Creates: SEC-999/hotfix/patch-vulnerability

# Release from develop
ci scm branch "v2.1.0" --release --from develop
# Creates: release/v2.1.0

# Chore without checkout
ci scm branch "update dependencies" --chore --no-checkout
# Creates: chore/update-dependencies-and-cleanup (no checkout)
```

## Flow Types

| Flag | Prefix | Use Case |
|------|--------|----------|
| `--feature` | `feature/` | New features (default) |
| `--fix` | `fix/` | Bug fixes |
| `--hotfix` | `hotfix/` | Critical production fixes |
| `--release` | `release/` | Release preparation |
| `--chore` | `chore/` | Maintenance tasks |

## Behavior

1. **Validation:** Checks if in a git repository
2. **Base Branch:** Switches to and updates base branch
3. **Sanitization:** Converts description to kebab-case
4. **Creation:** Creates new branch from base
5. **Checkout:** Checks out new branch (unless `--no-checkout`)

## Logging

Set `NU_LOG_LEVEL` environment variable:

```nu
$env.NU_LOG_LEVEL = "DEBUG"  # Show all operations
$env.NU_LOG_LEVEL = "INFO"   # Show important steps
$env.NU_LOG_LEVEL = "ERROR"  # Show errors only
```

## Error Handling

- Validates git repository exists
- Checks if base branch exists
- Handles git errors gracefully
- Provides clear error messages

---

### `ci scm commit`

Stage and commit files with optional custom message.

**Usage:**
```nu
ci scm commit [files] [--message <msg>]
```

**Positional:**
- `files` - Files to stage (optional, accepts list via pipe or args)
  - If not provided, stages all changed files

**Options:**
- `--message`, `-m` - Custom commit message
  - If not provided, auto-generates message from changed files

**Returns:**
```nu
{
  status: "success" | "error" | "no_changes",
  error: string?,          # Error message if status is "error"
  message: string?         # Commit message if status is "success"
}
```

**Examples:**

```nu
# Commit all changed files with auto-generated message
ci scm commit

# Commit specific file with custom message
ci scm commit file.txt --message "fix: update config"

# Commit multiple files via pipe
["src/main.nu" "tests/test.nu"] | ci scm commit -m "feat: add new feature"

# Commit multiple files as arguments
ci scm commit file1.txt file2.txt --message "chore: update files"
```

**Auto-generated Messages:**

When no message is provided, the commit message is generated from changed files:

```nu
# Single file
ci scm commit README.md
# Generates: "chore: update README.md"

# Multiple files
ci scm commit file1.txt file2.txt
# Generates: "chore: update file1.txt, file2.txt"

# All changes
ci scm commit
# Generates: "chore: update <file1>, <file2>, ..."
```
