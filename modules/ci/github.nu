use ../common/help show-help
use log.nu *

# GitHub operations - show help
export def "ci github" [] {
  show-help "ci github"
}

# Add content to GitHub Actions step summary
export def "ci github summary" [
  --newline (-n) # Add newlines after each line of content
]: [
  string -> nothing
  list<string> -> nothing
] {
  let content = $in

  # Check if we're in a GitHub Actions environment
  let summary_file = $env.GITHUB_STEP_SUMMARY? | default ""

  if ($summary_file | is-empty) {
    "Not in a GitHub Actions environment (GITHUB_STEP_SUMMARY not set)" | ci log error
    return
  }

  # Handle both string and list of strings
  let lines = if ($content | describe | str starts-with "list") {
    $content
  } else {
    [$content]
  }

  # Write to summary file
  try {
    for line in $lines {
      if $newline {
        $"($line)\n" | save --append $summary_file
      } else {
        $line | save --append $summary_file
      }
    }
    "Added content to GitHub step summary" | ci log info
  } catch {|err|
    $"Failed to write to step summary: ($err.msg)" | ci log error
  }
}

# GitHub PR operations - show help
export def "ci github pr" [] {
  show-help "ci github pr"
}

# Check for existing PR for current branch
export def "ci github pr check" [
  --target: string = "main" # Target branch to check against
]: [
  nothing -> list
] {
  let current_branch = try {
    git rev-parse --abbrev-ref HEAD | str trim
  } catch {
    "Not in a git repository" | ci log error
    return []
  }

  $"Checking for existing PRs: ($current_branch) -> ($target)" | ci log info

  let existing_prs = try {
    gh pr list --head $current_branch --base $target --json number,title,url | str trim
  } catch {|err|
    $"Failed to list PRs for ($current_branch) -> ($target): ($err.msg)" | ci log error
    "[]"
  }

  if $existing_prs != "[]" {
    let prs = ($existing_prs | from json)
    for pr in $prs {
      $"Found PR #($pr.number): ($pr.title)" | ci log info
      $"  URL: ($pr.url)" | ci log info
    }
    $prs
  } else {
    $"No existing PR found for ($current_branch) -> ($target)" | ci log info
    []
  }
}

# Get PR information by branch name or PR number
export def "ci github pr info" []: [
  nothing -> record
  string -> record
  int -> record
] {
  let identifier = $in

  # Determine what we're looking up
  let lookup = if ($identifier | is-empty) {
    # Get current branch
    let current_branch = try {
      git rev-parse --abbrev-ref HEAD | str trim
    } catch {
      $"Failed to get current branch" | ci log error
      return {
        status: "error"
        error: "Not in a git repository"
        number: null
        title: null
        state: null
        merged: null
        mergeable: null
        url: null
        head_branch: null
        base_branch: null
      }
    }
    {type: "branch" value: $current_branch}
  } else if (($identifier | describe) == "int") {
    # It's a PR number (integer)
    {type: "number" value: $identifier}
  } else {
    # It's a branch name (string)
    {type: "branch" value: $identifier}
  }

  $"Getting PR info for ($lookup.type): ($lookup.value)" | ci log info

  # Get PR information
  if $lookup.type == "branch" {
    # Find PR by branch name
    let prs = try {
      gh pr list --head $lookup.value --json number,title,state,mergedAt,mergeable,url,headRefName,baseRefName | from json
    } catch {|err|
      $"Failed to get PR info: ($err.msg)" | ci log error
      return {
        status: "error"
        error: $err.msg
        number: null
        title: null
        state: null
        merged: null
        mergeable: null
        url: null
        head_branch: null
        base_branch: null
      }
    }

    if ($prs | is-empty) {
      $"No PR found for branch: ($lookup.value)" | ci log error
      return {
        status: "not_found"
        error: $"No PR found for branch: ($lookup.value)"
        number: null
        title: null
        state: null
        merged: null
        mergeable: null
        url: null
        head_branch: null
        base_branch: null
      }
    }

    let pr = $prs | first
    {
      status: "success"
      error: null
      number: $pr.number
      title: $pr.title
      state: $pr.state
      merged: ($pr.mergedAt != null)
      mergeable: $pr.mergeable
      url: $pr.url
      head_branch: $pr.headRefName
      base_branch: $pr.baseRefName
    }
  } else {
    # Get PR by number
    let pr = try {
      gh pr view $lookup.value --json number,title,state,mergedAt,mergeable,url,headRefName,baseRefName | from json
    } catch {|err|
      $"Failed to get PR info: ($err.msg)" | ci log error
      return {
        status: "error"
        error: $err.msg
        number: null
        title: null
        state: null
        merged: null
        mergeable: null
        url: null
        head_branch: null
        base_branch: null
      }
    }

    # Check if PR was found
    if ($pr | is-empty) {
      $"No PR found for number: ($lookup.value)" | ci log error
      return {
        status: "not_found"
        error: $"PR #($lookup.value) not found"
        number: null
        title: null
        state: null
        merged: null
        mergeable: null
        url: null
        head_branch: null
        base_branch: null
      }
    }

    {
      status: "success"
      error: null
      number: $pr.number
      title: $pr.title
      state: $pr.state
      merged: ($pr.mergedAt != null)
      mergeable: $pr.mergeable
      url: $pr.url
      head_branch: $pr.headRefName
      base_branch: $pr.baseRefName
    }
  }
}

# Create a new pull request
export def "ci github pr create" [
  title: string # PR title
  description?: string # PR description (body)
  --target: string = "main" # Target branch
  --draft # Create as draft PR
]: [
  nothing -> record
] {
  let body = $description | default ""

  $"Creating PR: ($title)" | ci log info

  let result = if $draft {
    try {
      gh pr create --title $title --body $body --base $target --draft
    } catch {|err|
      $"Failed to create draft PR: ($err.msg)" | ci log error
      return {
        status: "error"
        error: $err.msg
        number: null
        url: null
        title: $title
        draft: $draft
      }
    }
  } else {
    try {
      gh pr create --title $title --body $body --base $target
    } catch {|err|
      $"Failed to create PR: ($err.msg)" | ci log error
      return {
        status: "error"
        error: $err.msg
        number: null
        url: null
        title: $title
        draft: $draft
      }
    }
  }

  # Extract PR number and URL from result
  let url = $result | str trim

  # Parse PR number from URL (e.g., https://github.com/owner/repo/pull/82)
  # Handle cases where URL might have extra text/newlines
  let parsed = ($url | parse --regex '.*github\.com/[^/]+/[^/]+/pull/(?<number>\d+)')
  let pr_number = if ($parsed | is-empty) {
    null
  } else {
    $parsed | get number.0
  }

  if $draft {
    $"Created draft PR #($pr_number)" | ci log info
  } else {
    $"Created PR #($pr_number)" | ci log info
  }
  $"  ($url)" | ci log info

  {
    status: "success"
    error: null
    number: (if $pr_number != null { $pr_number | into int } else { null })
    url: $url
    title: $title
    draft: $draft
  }
}

# Update an existing pull request
export def "ci github pr update" [
  pr_number: int # PR number to update
  --title: string # New title
  --body: string # New description
]: [
  nothing -> record
] {
  $"Updating PR #($pr_number)" | ci log info

  # Get repo info
  let repo = try {
    gh repo view --json owner,name | from json
  } catch {|err|
    $"Failed to get repo info: ($err.msg)" | ci log error
    return {
      status: "error"
      error: $err.msg
      pr_number: $pr_number
      title: $title
      body: $body
    }
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

    $"Updated PR #($pr_number)" | ci log info
    {
      status: "success"
      error: null
      pr_number: $pr_number
      title: $title
      body: $body
    }
  } catch {|err|
    $"Failed to update PR: ($err.msg)" | ci log error
    {
      status: "failed"
      error: $err.msg
      pr_number: $pr_number
      title: $title
      body: $body
    }
  }
}

# Merge a pull request
export def "ci github pr merge" [
  pr_number: int # PR number to merge
  --method: string = "squash" # Merge method: squash, merge, rebase
  --auto # Enable auto-merge (merge automatically when checks pass, default: merge immediately)
]: [
  nothing -> record
] {
  $"Merging PR #($pr_number) using ($method)" | ci log info

  # Merge the PR - branch deletion handled by repo settings
  try {
    if $auto {
      match $method {
        "squash" => { gh pr merge $pr_number --squash --auto }
        "merge" => { gh pr merge $pr_number --merge --auto }
        "rebase" => { gh pr merge $pr_number --rebase --auto }
        _ => {
          $"Invalid merge method: ($method). Use squash, merge, or rebase" | ci log error
          error make {msg: $"Invalid merge method: ($method)"}
        }
      }
    } else {
      match $method {
        "squash" => { gh pr merge $pr_number --squash }
        "merge" => { gh pr merge $pr_number --merge }
        "rebase" => { gh pr merge $pr_number --rebase }
        _ => {
          $"Invalid merge method: ($method). Use squash, merge, or rebase" | ci log error
          error make {msg: $"Invalid merge method: ($method)"}
        }
      }
    }
    $"Merged PR #($pr_number)" | ci log info
    {status: "success" error: null pr_number: $pr_number}
  } catch {|err|
    $"Failed to merge PR #($pr_number): ($err.msg)" | ci log error
    {status: "failed" error: $err.msg pr_number: $pr_number}
  }
}

# List pull requests
export def "ci github pr list" [
  --state: string = "open" # PR state: open, closed, merged, all
  --author: string # Filter by author
  --limit: int = 30 # Max number of PRs to list
]: [
  nothing -> list
] {
  $"Listing PRs \(state: ($state)\)" | ci log info

  let prs = try {
    if ($author | is-not-empty) {
      gh pr list --state $state --author $author --json number,title,author --limit $limit | from json
    } else {
      gh pr list --state $state --json number,title,author --limit $limit | from json
    }
  } catch {|err|
    $"Failed to list PRs: ($err.msg)" | ci log error
    return []
  }

  if ($prs | is-empty) {
    $"No PRs found \(state: ($state)\)" | ci log info
  } else {
    for pr in $prs {
      $"#($pr.number) ($pr.title) - @($pr.author.login)" | ci log info
    }
  }

  $prs
}

# GitHub workflow operations - show help
export def "ci github workflow" [] {
  show-help "ci github workflow"
}

# List workflow runs
export def "ci github workflow list" [
  --status: string # Filter by status: success, failure, in_progress, completed
  --limit: int = 20 # Max number of runs to list
]: [
  nothing -> list
] {
  "Listing workflow runs" | ci log info

  let runs = try {
    if ($status | is-not-empty) {
      gh run list --status $status --json databaseId,status,conclusion,name,headBranch --limit $limit | from json
    } else {
      gh run list --json databaseId,status,conclusion,name,headBranch --limit $limit | from json
    }
  } catch {|err|
    $"Failed to list workflow runs: ($err.msg)" | ci log error
    return []
  }

  if ($runs | is-empty) {
    "No workflow runs found" | ci log info
  } else {
    for run in $runs {
      let status_icon = match $run.conclusion {
        "success" => "✓"
        "failure" => "✗"
        _ => "○"
      }
      $"($status_icon) Run #($run.databaseId) - ($run.name) (($run.headBranch)) - ($run.status)" | ci log info
    }
  }

  $runs
}

# View specific workflow run details
export def "ci github workflow view" [
  run_id: int # Workflow run ID
]: [
  nothing -> record
] {
  $"Viewing workflow run #($run_id)" | ci log info

  let run = try {
    gh run view $run_id --json databaseId,status,conclusion,name,headBranch,createdAt,jobs | from json
  } catch {|err|
    $"Failed to view workflow run: ($err.msg)" | ci log error
    return {
      status: "error"
      error: $err.msg
      run_id: $run_id
      name: null
      branch: null
      run_status: null
      conclusion: null
      created_at: null
      jobs: []
    }
  }

  $"Run #($run.databaseId): ($run.name)" | ci log info
  $"  Branch: ($run.headBranch)" | ci log info
  $"  Status: ($run.status)" | ci log info
  $"  Conclusion: ($run.conclusion)" | ci log info
  $"  Created: ($run.createdAt)" | ci log info

  if ($run.jobs | is-not-empty) {
    "\nJobs:" | ci log info
    for job in $run.jobs {
      let job_icon = match $job.conclusion {
        "success" => "✓"
        "failure" => "✗"
        _ => "○"
      }
      $"  ($job_icon) ($job.name) - ($job.status)" | ci log info
    }
  }

  {
    status: "success"
    error: null
    run_id: $run.databaseId
    name: $run.name
    branch: $run.headBranch
    run_status: $run.status
    conclusion: $run.conclusion
    created_at: $run.createdAt
    jobs: $run.jobs
  }
}

# Get workflow run logs
export def "ci github workflow logs" [
  run_id: int # Workflow run ID
]: [
  nothing -> nothing
] {
  $"Fetching logs for workflow run #($run_id)" | ci log info

  try {
    gh run view $run_id --log
  } catch {|err|
    $"Failed to fetch logs: ($err.msg)" | ci log error
  }
}

# Cancel a workflow run
export def "ci github workflow cancel" [
  run_id: int # Workflow run ID to cancel
]: [
  nothing -> record
] {
  $"Canceling workflow run #($run_id)" | ci log info

  try {
    gh run cancel $run_id
    $"✓ Canceled workflow run #($run_id)" | ci log info
    {status: "success" error: null run_id: $run_id}
  } catch {|err|
    $"Failed to cancel workflow run: ($err.msg)" | ci log error
    {status: "failed" error: $err.msg run_id: $run_id}
  }
}

# Re-run a workflow
export def "ci github workflow rerun" [
  run_id: int # Workflow run ID to rerun
]: [
  nothing -> record
] {
  $"Re-running workflow #($run_id)" | ci log info

  try {
    gh run rerun $run_id
    $"✓ Re-running workflow #($run_id)" | ci log info
    {status: "success" error: null run_id: $run_id}
  } catch {|err|
    $"Failed to rerun workflow: ($err.msg)" | ci log error
    {status: "failed" error: $err.msg run_id: $run_id}
  }
}
