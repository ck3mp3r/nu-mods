# CI Module - GitHub Operations

GitHub PR and workflow management via GitHub CLI.

## Requirements

- [GitHub CLI](https://cli.github.com/) (`gh`) installed and authenticated

## GitHub Actions Commands

### `ci github summary`

Add content to GitHub Actions step summary (markdown displayed in workflow run UI).

**Usage:**
```nu
<content> | ci github summary [--newline]
```

**Input:**
- `string` - Single line of content
- `list<string>` - Multiple lines of content

**Options:**
- `--newline (-n)` - Add newlines after each line

**Example:**
```nu
# Add single line
"# Build Summary" | ci github summary

# Add multiple lines
["## Test Results", "- All tests passed", "- Coverage: 95%"] | ci github summary

# Add with newlines
["Line 1", "Line 2"] | ci github summary --newline
```

**Note:** Only works in GitHub Actions environment (requires `GITHUB_STEP_SUMMARY` environment variable).

---

## Pull Request Commands

### `ci github pr check`

Check for existing PRs from current branch.

**Usage:**
```nu
ci github pr check [--target <branch>]
```

**Options:**
- `--target` - Target branch (default: main)

**Returns:**
```nu
# List of PR records
[
  {
    number: int,
    title: string,
    url: string
  }
]
```

**Example:**
```nu
# Check for PRs and get the list
let prs = (ci github pr check)
if ($prs | is-empty) {
  print "No existing PRs found"
} else {
  print $"Found ($prs | length) PR(s)"
}

# Check against specific branch
ci github pr check --target develop
```

---

### `ci github pr create`

Create a new pull request.

**Usage:**
```nu
ci github pr create <title> [body] [--target <branch>] [--draft]
```

**Positional:**
- `title` - PR title
- `body` - PR description (optional)

**Options:**
- `--target` - Target branch (default: main)
- `--draft` - Create as draft PR

**Returns:**
```nu
{
  status: "success" | "error",
  error: string?,           # Error message if status is "error"
  number: int?,            # PR number (null on error)
  url: string?,            # PR URL (null on error)
  title: string,           # PR title
  draft: bool              # Whether created as draft
}
```

**Example:**
```nu
# Create regular PR
let pr = (ci github pr create "feat: add login" "Implements user authentication" --target main)
print $"Created PR #($pr.number): ($pr.url)"

# Create draft PR
ci github pr create "wip: feature" "Work in progress" --draft
```

---

### `ci github pr list`

List pull requests.

**Usage:**
```nu
ci github pr list [--state <state>] [--author <username>] [--limit <n>]
```

**Options:**
- `--state` - Filter by state: open, closed, merged, all (default: open)
- `--author` - Filter by author username
- `--limit` - Maximum number of PRs to list (default: 30)

**Returns:**
```nu
# List of PR records
[
  {
    number: int,
    title: string,
    author: { login: string }
  }
]
```

**Example:**
```nu
# List all open PRs
let prs = (ci github pr list)
print $"Found ($prs | length) open PRs"

# List merged PRs
ci github pr list --state merged

# List PRs by specific author
ci github pr list --author "username"

# List with custom limit
ci github pr list --limit 50
```

---

### `ci github pr info`

Get PR information by branch name or PR number.

**Usage:**
```nu
<identifier> | ci github pr info
ci github pr info  # Uses current branch
```

**Input:**
- `int` - PR number
- `string` - Branch name
- `nothing` - Uses current branch

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
42 | ci github pr info

# Get info by branch name
"feature/my-branch" | ci github pr info

# Use in workflows
let pr = (ci github pr info)
if $pr.status == "success" and $pr.merged {
  print "PR is already merged"
}

# Check if PR is mergeable
let info = (89 | ci github pr info)
if $info.mergeable == "CONFLICTING" {
  print "PR has conflicts!"
}
```

---

### `ci github pr merge`

Merge a pull request (branch deletion handled by repository settings).

**Usage:**
```nu
ci github pr merge <number> [--method <method>] [--auto]
```

**Positional:**
- `number` - PR number to merge

**Options:**
- `--method` - Merge method: squash (default), merge, rebase
- `--auto` - Enable auto-merge (merge when checks pass, default: merge immediately)

**Returns:**
```nu
{
  status: "success" | "failed",
  error: string?,           # Error message if status is "failed"
  pr_number: int           # PR number that was merged
}
```

**Example:**
```nu
# Squash merge immediately (default)
let result = (ci github pr merge 42)
if $result.status == "success" {
  print "PR merged successfully"
}

# Merge commit
ci github pr merge 42 --method merge

# Enable auto-merge (merges when checks pass)
ci github pr merge 42 --auto

# Rebase merge with auto-merge
ci github pr merge 42 --method rebase --auto
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

**Returns:**
```nu
{
  status: "success" | "error" | "failed",
  error: string?,           # Error message if not success
  pr_number: int,          # PR number
  title: string?,          # New title (if provided)
  body: string?            # New body (if provided)
}
```

**Example:**
```nu
# Update title
let result = (ci github pr update 42 --title "feat: improved login")

# Update body
ci github pr update 42 --body "Updated implementation"

# Update both
ci github pr update 42 --title "new title" --body "new body"
```

## Workflow Commands

### `ci github workflow list`

List workflow runs.

**Usage:**
```nu
ci github workflow list [--status <status>] [--limit <n>]
```

**Options:**
- `--status` - Filter by status: success, failure, cancelled, in_progress
- `--limit` - Maximum number of runs to list (default: 20)

**Returns:**
```nu
# List of workflow run records
[
  {
    databaseId: int,
    status: string,          # "completed", "in_progress", etc.
    conclusion: string?,     # "success", "failure", null if in progress
    name: string,           # Workflow name
    headBranch: string      # Branch name
  }
]
```

**Example:**
```nu
# List recent workflow runs
let runs = (ci github workflow list)
print $"Found ($runs | length) workflow runs"

# Filter by status
let failed = (ci github workflow list --status failure)
for run in $failed {
  print $"Failed run #($run.databaseId): ($run.name)"
}
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

**Returns:**
```nu
{
  status: "success" | "error",
  error: string?,          # Error message if status is "error"
  run_id: int,            # Workflow run ID
  name: string?,          # Workflow name
  branch: string?,        # Branch name
  run_status: string?,    # "completed", "in_progress", etc.
  conclusion: string?,    # "success", "failure", null
  created_at: string?,    # ISO 8601 timestamp
  jobs: list              # List of job records
}
```

**Example:**
```nu
# View workflow details
let run = (ci github workflow view 12345)
if $run.status == "success" {
  print $"Workflow: ($run.name)"
  print $"Status: ($run.conclusion)"
  print $"Jobs: ($run.jobs | length)"
}
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

**Returns:**
```nu
{
  status: "success" | "failed",
  error: string?,          # Error message if status is "failed"
  run_id: int             # Workflow run ID
}
```

**Example:**
```nu
# Cancel a workflow
let result = (ci github workflow cancel 12345)
if $result.status == "success" {
  print "Workflow cancelled"
}
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

**Returns:**
```nu
{
  status: "success" | "failed",
  error: string?,          # Error message if status is "failed"
  run_id: int             # Workflow run ID
}
```

**Example:**
```nu
# Re-run a workflow
let result = (ci github workflow rerun 12345)
if $result.status == "success" {
  print "Workflow re-run started"
}
```

## Workflow Examples

### Complete PR Workflow

```nu
# 1. Check for existing PR
let existing = (ci github pr check --target main)

# 2. Create PR if none exists
let pr = if ($existing | is-empty) {
  ci github pr create "feat: new feature" "Detailed description" --target main
} else {
  $existing | first
}

# 3. Get PR info
let info = (ci github pr info $pr.number)
if $info.mergeable == "CONFLICTING" {
  print "PR has conflicts, cannot merge"
  exit 1
}

# 4. Update PR if needed
ci github pr update $pr.number --title "feat: improved feature"

# 5. Merge PR with squash
let merge_result = (ci github pr merge $pr.number)
if $merge_result.status == "success" {
  print "Successfully merged!"
}
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
# List failed workflows and re-run them
let failed = (ci github workflow list --status failure)
for run in $failed {
  print $"Re-running failed workflow: ($run.name) \(#($run.databaseId)\)"
  ci github workflow rerun $run.databaseId
}

# View details of a specific run
let run = (ci github workflow view 12345)
if $run.conclusion == "failure" {
  print $"Workflow failed: ($run.name)"
  print $"Jobs: ($run.jobs | length)"
}

# Get logs (outputs directly to stdout)
ci github workflow logs 12345

# Cancel in-progress runs
let in_progress = (ci github workflow list --status in_progress)
for run in $in_progress {
  ci github workflow cancel $run.databaseId
}
```

## Output and Logging

All functions return structured data (records or lists) for easy integration into workflows.

Informational messages are logged to stderr using `ci log`, which does not interfere with structured output:

```nu
# Example: Use returned data in workflows
let pr = (ci github pr create "feat: new feature" "Description")
if $pr.status == "success" {
  print $"Created PR #($pr.number)"
  ci github pr merge $pr.number
}

# Logs go to stderr, data goes to stdout
let prs = (ci github pr list --state open)  # Returns list of PRs
```

## Error Handling

- Validates `gh` CLI is installed
- Checks for existing PRs before creation
- Provides clear error messages
- Handles GitHub API errors gracefully
