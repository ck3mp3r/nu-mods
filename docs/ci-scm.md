# CI Module - SCM Operations

Standardized branch management following conventional flow types.

## Commands

### `ci scm config`

Configure git user name and email for commits.

**Usage:**
```nu
<email> | ci scm config [--name <name>] [--global]
```

**Input:**
- Email address (via pipe)

**Options:**
- `--name`, `-n` - Git user name (default: derived from email)
- `--global`, `-g` - Set globally instead of repository-only

**Returns:**
```nu
{
  status: "success" | "error",
  error: string?,           # Error message if status is "error"
  name: string,            # Git user name that was set
  email: string,           # Git user email that was set
  scope: "local" | "global" # Configuration scope
}
```

**Examples:**

```nu
# Auto-derive name from email (john.doe -> "john doe")
"john.doe@example.com" | ci scm config

# Set custom name
"john@example.com" | ci scm config --name "John Doe"

# Set globally (affects all repos)
"bot@ci.example.com" | ci scm config --global

# Use in CI pipeline
"github-actions[bot]@users.noreply.github.com" | ci scm config --name "GitHub Actions"
```

**Name Derivation:**

When `--name` is not provided, the name is automatically derived from the email username:
- Dots (`.`) → spaces
- Underscores (`_`) → spaces  
- Hyphens (`-`) → spaces

Examples:
- `john.doe@example.com` → `john doe`
- `first_last@company.com` → `first last`
- `user-name@domain.com` → `user name`

---

### `ci scm changes`

Get list of changed files since branch was created.

**Usage:**
```nu
ci scm changes [--base <branch>] [--staged]
```

**Options:**
- `--base` - Base branch to compare against (default: main)
- `--staged`, `-s` - Only return staged files

**Returns:** `list<string>` - List of file paths

**Examples:**

```nu
# Get all changes since branch diverged from main
ci scm changes

# Get changes since diverged from develop
ci scm changes --base develop

# Get only staged files
ci scm changes --staged

# Use in workflows
let changed = (ci scm changes)
print $"Changed ($changed | length) files: ($changed | str join ', ')"
```

**Behavior:**

- **Without `--staged`**: Returns ALL files changed since the branch diverged from the base branch (uses `git merge-base` to find divergence point, then `git diff --name-only`)
- **With `--staged`**: Returns only files that are currently staged (uses `git diff --cached --name-only`)

---

### `ci scm branch`

Create standardized branches with flow-based naming.

**Usage:**
```nu
<description> | ci scm branch [flags]
```

**Input:**
- `description` - Branch description via stdin (required, sanitized to kebab-case)

**Flags:**
- `--prefix`, `-p` - Optional prefix for branch name (e.g., ticket number)
- `--feature` - Feature branch (default)
- `--fix` - Bugfix branch
- `--hotfix` - Hotfix branch
- `--release` - Release branch
- `--chore` - Chore/maintenance branch
- `--from <branch>` - Base branch (default: main)
- `--no-checkout` - Create without checking out

**Returns:**
```nu
{
  status: "success" | "error",
  error: string?,          # Error message if status is "error"
  branch: string?          # Branch name that was created
}
```

**Branch Format:**
```
[<prefix>/]<flow>/<description>
```

**Examples:**

```nu
# Feature branch (default)
"add user login" | ci scm branch
# Creates: feature/add-user-login

# With ticket prefix
"add login" | ci scm branch --prefix "JIRA-1234"
# Creates: JIRA-1234/feature/add-login

# Bugfix
"login bug" | ci scm branch --fix
# Creates: fix/login-bug

# Hotfix from production with prefix
"patch vulnerability" | ci scm branch --hotfix --from production --prefix "SEC-999"
# Creates: SEC-999/hotfix/patch-vulnerability

# Release from develop
"v2.1.0" | ci scm branch --release --from develop
# Creates: release/v2.1.0

# Chore without checkout
"update dependencies" | ci scm branch --chore --no-checkout
# Creates: chore/update-dependencies (no checkout)

# Use in workflows
let result = ("add feature" | ci scm branch)
if $result.status == "success" {
  print $"Created branch: ($result.branch)"
}
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

Stage and commit files with optional custom message and push.

**Usage:**
```nu
ci scm commit [files] [--message <msg>] [--push]
```

**Positional:**
- `files` - Files to stage (optional, accepts list via pipe or args)
  - If not provided, stages all changed files

**Options:**
- `--message`, `-m` - Custom commit message
  - If not provided, auto-generates message from changed files
- `--push`, `-p` - Push to remote after successful commit

**Returns:**
```nu
{
  status: "success" | "error" | "no_changes",
  error: string?,          # Error message if status is "error"
  message: string?,        # Commit message if status is "success"
  pushed: bool             # Whether push succeeded
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

# Commit and push in one operation
ci scm commit --message "feat: add new feature" --push
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
