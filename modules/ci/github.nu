use ../common/help show-help
use std/log

# GitHub operations - show help
export def "ci github" [] {
  show-help "ci github"
}

# ============================================================================
# PR COMMANDS
# ============================================================================

# GitHub PR operations - show help
export def "ci github pr" [] {
  show-help "ci github pr"
}

# Check for existing PR for current branch
export def "ci github pr check" [
  --target: string = "main" # Target branch to check against
]: [
  nothing -> nothing
] {
  let current_branch = try {
    git rev-parse --abbrev-ref HEAD | str trim
  } catch {
    log error "Not in a git repository"
    return
  }

  log info $"Checking for existing PRs: ($current_branch) -> ($target)"

  let existing_prs = try {
    gh pr list --head $current_branch --base $target --json number,title,url | str trim
  } catch {
    "[]"
  }

  if $existing_prs != "[]" {
    let prs = ($existing_prs | from json)
    for pr in $prs {
      print $"✓ Found PR #($pr.number): ($pr.title)"
      print $"  URL: ($pr.url)"
    }
  } else {
    print $"No existing PR found for ($current_branch) -> ($target)"
  }
}

# Create a new pull request
export def "ci github pr create" [
  title: string # PR title
  description?: string # PR description (body)
  --target: string = "main" # Target branch
  --draft # Create as draft PR
]: [
  nothing -> nothing
] {
  let body = $description | default ""

  log info $"Creating PR: ($title)"

  let result = if $draft {
    try {
      gh pr create --title $title --body $body --base $target --draft
    } catch {|err|
      log error $"Failed to create draft PR: ($err.msg)"
      return
    }
  } else {
    try {
      gh pr create --title $title --body $body --base $target
    } catch {|err|
      log error $"Failed to create PR: ($err.msg)"
      return
    }
  }

  # Extract PR number from URL
  let pr_number = ($result | parse "pull/{number}" | get number.0? | default "")

  if $draft {
    print $"✓ Created draft PR #($pr_number)"
  } else {
    print $"✓ Created PR #($pr_number)"
  }
  print $"  ($result)"
}

# Update an existing pull request
export def "ci github pr update" [
  pr_number: int # PR number to update
  --title: string # New title
  --body: string # New description
]: [
  nothing -> nothing
] {
  log info $"Updating PR #($pr_number)"

  # Get repo info
  let repo = try {
    gh repo view --json owner,name | from json
  } catch {|err|
    log error $"Failed to get repo info: ($err.msg)"
    return
  }

  let owner = $repo.owner.login
  let name = $repo.name

  # Build API call
  try {
    if ($title | is-not-empty) and ($body | is-not-empty) {
      gh api -X PATCH $"/repos/($owner)/($name)/pulls/($pr_number)" -f $"title=($title)" -f $"body=($body)" | ignore
    } else if ($title | is-not-empty) {
      gh api -X PATCH $"/repos/($owner)/($name)/pulls/($pr_number)" -f $"title=($title)" | ignore
    } else if ($body | is-not-empty) {
      gh api -X PATCH $"/repos/($owner)/($name)/pulls/($pr_number)" -f $"body=($body)" | ignore
    }

    print $"✓ Updated PR #($pr_number)"
  } catch {|err|
    log error $"Failed to update PR: ($err.msg)"
  }
}

# List pull requests
export def "ci github pr list" [
  --state: string = "open" # PR state: open, closed, merged, all
  --author: string # Filter by author
  --limit: int = 30 # Max number of PRs to list
]: [
  nothing -> nothing
] {
  let state_msg = $"Listing PRs \(state: ($state)\)"
  log info $state_msg

  let prs = try {
    if ($author | is-not-empty) {
      gh pr list --state $state --author $author --json number,title,author --limit $limit | from json
    } else {
      gh pr list --state $state --json number,title,author --limit $limit | from json
    }
  } catch {|err|
    log error $"Failed to list PRs: ($err.msg)"
    return
  }

  if ($prs | is-empty) {
    print $"No PRs found \(state: ($state)\)"
  } else {
    for pr in $prs {
      print $"#($pr.number) ($pr.title) - @($pr.author.login)"
    }
  }
}

# ============================================================================
# WORKFLOW COMMANDS
# ============================================================================

# GitHub workflow operations - show help
export def "ci github workflow" [] {
  show-help "ci github workflow"
}

# List workflow runs
export def "ci github workflow list" [
  --status: string # Filter by status: success, failure, in_progress, completed
  --limit: int = 20 # Max number of runs to list
]: [
  nothing -> nothing
] {
  log info "Listing workflow runs"

  let runs = try {
    if ($status | is-not-empty) {
      gh run list --status $status --json databaseId,status,conclusion,name,headBranch --limit $limit | from json
    } else {
      gh run list --json databaseId,status,conclusion,name,headBranch --limit $limit | from json
    }
  } catch {|err|
    log error $"Failed to list workflow runs: ($err.msg)"
    return
  }

  if ($runs | is-empty) {
    print "No workflow runs found"
  } else {
    for run in $runs {
      let status_icon = match $run.conclusion {
        "success" => "✓"
        "failure" => "✗"
        _ => "○"
      }
      print $"($status_icon) Run #($run.databaseId) - ($run.name) (($run.headBranch)) - ($run.status)"
    }
  }
}

# View specific workflow run details
export def "ci github workflow view" [
  run_id: int # Workflow run ID
]: [
  nothing -> nothing
] {
  log info $"Viewing workflow run #($run_id)"

  let run = try {
    gh run view $run_id --json databaseId,status,conclusion,name,headBranch,createdAt,jobs | from json
  } catch {|err|
    log error $"Failed to view workflow run: ($err.msg)"
    return
  }

  print $"Run #($run.databaseId): ($run.name)"
  print $"  Branch: ($run.headBranch)"
  print $"  Status: ($run.status)"
  print $"  Conclusion: ($run.conclusion)"
  print $"  Created: ($run.createdAt)"

  if ($run.jobs | is-not-empty) {
    print "\nJobs:"
    for job in $run.jobs {
      let job_icon = match $job.conclusion {
        "success" => "✓"
        "failure" => "✗"
        _ => "○"
      }
      print $"  ($job_icon) ($job.name) - ($job.status)"
    }
  }
}

# Get workflow run logs
export def "ci github workflow logs" [
  run_id: int # Workflow run ID
]: [
  nothing -> nothing
] {
  log info $"Fetching logs for workflow run #($run_id)"

  try {
    gh run view $run_id --log
  } catch {|err|
    log error $"Failed to fetch logs: ($err.msg)"
  }
}

# Cancel a workflow run
export def "ci github workflow cancel" [
  run_id: int # Workflow run ID to cancel
]: [
  nothing -> nothing
] {
  log info $"Canceling workflow run #($run_id)"

  try {
    gh run cancel $run_id
    print $"✓ Canceled workflow run #($run_id)"
  } catch {|err|
    log error $"Failed to cancel workflow run: ($err.msg)"
  }
}

# Re-run a workflow
export def "ci github workflow rerun" [
  run_id: int # Workflow run ID to rerun
]: [
  nothing -> nothing
] {
  log info $"Re-running workflow #($run_id)"

  try {
    gh run rerun $run_id
    print $"✓ Re-running workflow #($run_id)"
  } catch {|err|
    log error $"Failed to rerun workflow: ($err.msg)"
  }
}
