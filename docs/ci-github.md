# CI Module - GitHub Operations

GitHub PR and workflow management via GitHub CLI.

## Requirements

- [GitHub CLI](https://cli.github.com/) (`gh`) installed and authenticated

## Pull Request Commands

### `ci github pr check`

Check for existing PRs from current branch.

**Usage:**
```nu
ci github pr check [--target <branch>]
```

**Options:**
- `--target` - Target branch (default: main)

**Example:**
```nu
ci github pr check
ci github pr check --target develop
```

---

### `ci github pr create`

Create a new pull request.

**Usage:**
```nu
ci github pr create <title> <body> [--target <branch>] [--draft]
```

**Positional:**
- `title` - PR title
- `body` - PR description

**Options:**
- `--target` - Target branch (default: main)
- `--draft` - Create as draft PR

**Example:**
```nu
ci github pr create "feat: add login" "Implements user authentication" --target main
ci github pr create "wip: feature" "Work in progress" --draft
```

---

### `ci github pr list`

List pull requests.

**Usage:**
```nu
ci github pr list [--state <state>]
```

**Options:**
- `--state` - Filter by state: open, closed, merged, all (default: open)

**Example:**
```nu
ci github pr list
ci github pr list --state merged
ci github pr list --state all
```

---

### `ci github pr info`

Get PR information by branch name or PR number.

**Usage:**
```nu
ci github pr info [identifier]
```

**Positional:**
- `identifier` - Branch name or PR number (optional, default: current branch)

**Returns:**
```nu
{
  status: "success" | "error" | "not_found",
  error: string?,          # Error message if not success
  number: int,            # PR number
  title: string,          # PR title
  state: string,          # PR state: OPEN, CLOSED, MERGED
  merged: bool,           # Whether PR is merged
  mergeable: string,      # Merge status: MERGEABLE, CONFLICTING, UNKNOWN
  url: string,            # PR URL
  head_branch: string,    # Source branch
  base_branch: string     # Target branch
}
```

**Example:**
```nu
# Get info for current branch's PR
ci github pr info

# Get info by PR number
ci github pr info 42

# Get info by branch name
ci github pr info "feature/my-branch"

# Use in workflows
let pr = (ci github pr info)
if $pr.status == "success" and $pr.merged {
  print "PR is already merged"
}
```

---

### `ci github pr merge`

Merge a pull request with auto squash and optional branch deletion.

**Usage:**
```nu
ci github pr merge <number> [--method <method>] [--delete-branch|--no-delete-branch]
```

**Positional:**
- `number` - PR number to merge

**Options:**
- `--method` - Merge method: squash (default), merge, rebase
- `--delete-branch` - Delete branch after merge (default)
- `--no-delete-branch` - Keep branch after merge

**Returns:**
```nu
{
  status: "success" | "error",
  error: string?,           # Error message if status is "error"
  pr_number: int,          # PR number that was merged
  branch_deleted: bool     # Whether branch was deleted
}
```

**Example:**
```nu
# Squash merge with branch deletion (default)
ci github pr merge 42

# Merge commit without deleting branch
ci github pr merge 42 --method merge --no-delete-branch

# Rebase merge with branch deletion
ci github pr merge 42 --method rebase
```

---

### `ci github pr update`

Update existing pull request.

**Usage:**
```nu
ci github pr update <number> [--title <title>] [--body <body>]
```

**Positional:**
- `number` - PR number

**Options:**
- `--title` - New title
- `--body` - New description

**Example:**
```nu
ci github pr update 42 --title "feat: improved login"
ci github pr update 42 --body "Updated implementation"
ci github pr update 42 --title "new title" --body "new body"
```

## Workflow Commands

### `ci github workflow list`

List workflow runs.

**Usage:**
```nu
ci github workflow list [--status <status>]
```

**Options:**
- `--status` - Filter by status: success, failure, cancelled, in_progress

**Output:**
- Status icons: ✓ (success), ✗ (failure), ○ (in_progress/other)

**Example:**
```nu
ci github workflow list
ci github workflow list --status failure
```

---

### `ci github workflow view`

View specific workflow run details.

**Usage:**
```nu
ci github workflow view <run_id>
```

**Positional:**
- `run_id` - Workflow run ID

**Example:**
```nu
ci github workflow view 12345
```

---

### `ci github workflow logs`

Get workflow run logs.

**Usage:**
```nu
ci github workflow logs <run_id>
```

**Positional:**
- `run_id` - Workflow run ID

**Example:**
```nu
ci github workflow logs 12345
```

---

### `ci github workflow cancel`

Cancel a running workflow.

**Usage:**
```nu
ci github workflow cancel <run_id>
```

**Positional:**
- `run_id` - Workflow run ID

**Example:**
```nu
ci github workflow cancel 12345
```

---

### `ci github workflow rerun`

Re-run a workflow.

**Usage:**
```nu
ci github workflow rerun <run_id>
```

**Positional:**
- `run_id` - Workflow run ID

**Example:**
```nu
ci github workflow rerun 12345
```

## Workflow Examples

### Complete PR Workflow

```nu
# 1. Check for existing PR
ci github pr check --target main

# 2. Create PR if none exists
ci github pr create "feat: new feature" "Detailed description" --target main

# 3. List all open PRs
ci github pr list

# 4. Update PR if needed
ci github pr update 5 --title "feat: improved feature"

# 5. Merge PR with squash and delete branch
ci github pr merge 5
```

### Automated Flake Update Workflow

```nu
# Update flake.lock, create PR, and auto-merge
ci nix update
ci scm commit flake.lock --message "chore: update flake.lock"
let pr = (ci github pr create "chore: update flake.lock" "Automated flake update")
ci github pr merge $pr.number
```

### Workflow Management

```nu
# List failed workflows
ci github workflow list --status failure

# View details
ci github workflow view 12345

# Get logs
ci github workflow logs 12345

# Re-run if needed
ci github workflow rerun 12345
```

## Logging

Uses `std/log` for operation logging. Set `NU_LOG_LEVEL`:

```nu
$env.NU_LOG_LEVEL = "INFO"   # Show operations
$env.NU_LOG_LEVEL = "ERROR"  # Errors only
```

## Error Handling

- Validates `gh` CLI is installed
- Checks for existing PRs before creation
- Provides clear error messages
- Handles GitHub API errors gracefully
