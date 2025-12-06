use ../common/help show-help
use log.nu *

# SCM flow operations - show help
export def "ci scm" [] {
  show-help "ci scm"
}

# Configure git user name and email
export def "ci scm config" [
  --name (-n): string # Git user name (default: derived from email)
  --global (-g) # Set globally instead of repository-only
]: [
  string -> record
] {
  # Parse email from stdin
  let email = $in | str trim

  if $email == "" {
    "Email is required" | ci log error
    return {status: "error" error: "Email is required"}
  }

  # Validate email format
  if not ($email | str contains "@") {
    "Invalid email format" | ci log error
    return {status: "error" error: "Invalid email format"}
  }

  # Derive name from email if not provided
  let user_name = if ($name | is-not-empty) {
    $name
  } else {
    # Extract username part before @ and capitalize
    let username = ($email | split row "@" | first)
    $username
    | str replace --all "." " "
    | str replace --all "_" " "
    | str replace --all "-" " "
  }

  # Determine scope
  let scope = if $global { "global" } else { "local" }
  let scope_flag = if $global { "--global" } else { "--local" }

  # Set git config
  $"Setting git user.name to '($user_name)' \(($scope)\)" | ci log info
  try {
    git config $scope_flag user.name $user_name
  } catch {|err|
    $"Failed to set user.name: ($err.msg)" | ci log error
    return {status: "error" error: $"Failed to set user.name: ($err.msg)"}
  }

  $"Setting git user.email to '($email)' \(($scope)\)" | ci log info
  try {
    git config $scope_flag user.email $email
  } catch {|err|
    $"Failed to set user.email: ($err.msg)" | ci log error
    return {status: "error" error: $"Failed to set user.email: ($err.msg)"}
  }

  {status: "success" error: null name: $user_name email: $email scope: $scope}
}

# Create a new git branch with standardized naming convention based on SCM flow types
export def "ci scm branch" [
  description?: string # Description for the branch
  --release # Create a release branch
  --fix # Create a fix branch
  --hotfix # Create a hotfix branch
  --chore # Create a chore branch
  --feature # Create a feature branch (default)
  --from: string = "main" # Base branch to branch from
  --no-checkout # Create but don't checkout
]: [
  string -> record
  nothing -> record
] {

  # Parse input - prefix can come from stdin or be empty
  let prefix = if ($in | describe) == "string" {
    $in | str trim
  } else {
    ""
  }

  # Get description from argument
  let desc = $description | default ""

  if $desc == "" {
    "Description is required" | ci log error
    return {status: "error" error: "Description is required" branch: null}
  }

  # Verify we're in a git repository
  try {
    git status --porcelain | ignore
  } catch {|err|
    "Not in a git repository" | ci log error
    return {status: "error" error: $"Not in a git repository: ($err.msg)" branch: null}
  }

  # Determine flow type (default to feature)
  let flow = match [$release $fix $hotfix $chore] {
    [true _ _ _] => "release"
    [_ true _ _] => "fix"
    [_ _ true _] => "hotfix"
    [_ _ _ true] => "chore"
    _ => "feature"
  }

  # Sanitize description: lowercase, replace spaces with hyphens, remove special chars
  let clean_desc = (
    $desc
    | str downcase
    | str replace --all ' ' '-'
    | str replace --all --regex '[^a-z0-9\-\.]' ''
  )

  # Construct branch name
  let branch_name = if $prefix != "" {
    $"($prefix)/($flow)/($clean_desc)"
  } else {
    $"($flow)/($clean_desc)"
  }

  # Get current branch for context
  let current_branch = (git rev-parse --abbrev-ref HEAD | str trim)

  # Prepare base branch
  if $current_branch != $from {
    $"Switching to base branch: ($from)" | ci log info
    try {
      git checkout $from
    } catch {|err|
      $"Failed to checkout base branch ($from): ($err.msg)" | ci log error
      return {status: "error" error: $"Failed to checkout base branch: ($err.msg)" branch: null}
    }
  }

  # Pull latest changes
  $"Updating base branch: ($from)" | ci log info
  try {
    git pull
  } catch {|err|
    $"Failed to pull latest changes: ($err.msg)" | ci log warning
  }

  # Create and optionally checkout branch
  if $no_checkout {
    $"Creating branch: ($branch_name) from ($from)" | ci log info
    try {
      git branch $branch_name
      print $"✅ Created branch: ($branch_name) from ($from)"
      {status: "success" error: null branch: $branch_name}
    } catch {|err|
      $"Failed to create branch: ($err.msg)" | ci log error
      {status: "error" error: $"Failed to create branch: ($err.msg)" branch: null}
    }
  } else {
    $"Creating branch: ($branch_name) from ($from)" | ci log info
    try {
      git checkout -b $branch_name
      print $"✅ Successfully created and switched to branch: ($branch_name) from ($from)"
      {status: "success" error: null branch: $branch_name}
    } catch {|err|
      $"Failed to create branch: ($err.msg)" | ci log error
      {status: "error" error: $"Failed to create branch: ($err.msg)" branch: null}
    }
  }
}

# Get list of changed files since branch was created
export def "ci scm changes" [
  --base: string = "main" # Base branch to compare against
  --staged (-s) # Only return staged files
]: [
  nothing -> list<string>
] {
  # Verify we're in a git repository
  try {
    git status --porcelain | ignore
  } catch {|err|
    "Not in a git repository" | ci log error
    error make {msg: $"Not in a git repository: ($err.msg)"}
  }

  if $staged {
    # Return only staged files
    $"Getting staged files" | ci log info
    try {
      git diff --cached --name-only | lines | where {|line| $line | is-not-empty }
    } catch {|err|
      $"Failed to get staged files: ($err.msg)" | ci log error
      []
    }
  } else {
    # Return all changed files since branch diverged from base
    $"Getting all changes since divergence from ($base)" | ci log info
    try {
      # Find merge base (where branch diverged)
      let merge_base = (git merge-base HEAD $base | str trim)

      # Get all changed files since merge base
      git diff --name-only $merge_base | lines | where {|line| $line | is-not-empty }
    } catch {|err|
      $"Failed to get changes: ($err.msg)" | ci log error
      []
    }
  }
}

# Commit files to git with optional message
export def "ci scm commit" [
  --message (-m): string # Commit message (default: enumerate changed files)
  --push (-p) # Push to remote after commit
]: [
  list<string> -> record
  string -> record
  nothing -> record
] {
  # Parse input files
  let files = $in | if ($in | describe | str starts-with "list") {
    $in
  } else if ($in | describe) == "string" {
    [$in]
  } else {
    []
  }

  # Verify we're in a git repository
  try {
    git status --porcelain | ignore
  } catch {|err|
    "Not in a git repository" | ci log error
    error make {msg: $"Not in a git repository: ($err.msg)"}
  }

  # Stage files
  if ($files | is-not-empty) {
    $"Staging ($files | length) files" | ci log info
    try {
      git add ...$files
    } catch {|err|
      $"Failed to stage files: ($err.msg)" | ci log error
      return {status: "failed" error: $err.msg message: null pushed: false}
    }
  } else {
    # No files specified, stage all changed files
    "Staging all changed files" | ci log info
    try {
      git add -A
    } catch {|err|
      $"Failed to stage files: ($err.msg)" | ci log error
      return {status: "failed" error: $err.msg message: null pushed: false}
    }
  }

  # Generate commit message if not provided
  let commit_message = if ($message | is-not-empty) {
    $message
  } else {
    # Get list of staged files
    let staged = (git diff --cached --name-only | lines)

    if ($staged | is-empty) {
      "No changes to commit" | ci log warning
      return {status: "success" error: null message: "No changes to commit" pushed: false}
    }

    # Enumerate changed files
    let file_list = ($staged | str join ", ")
    $"chore: update ($staged | length) files\n\nChanged files:\n- ($staged | str join '\n- ')"
  }

  # Commit
  $"Creating commit" | ci log info
  try {
    git commit -m $commit_message
  } catch {|err|
    $"Failed to commit: ($err.msg)" | ci log error
    return {status: "failed" error: $err.msg message: null pushed: false}
  }

  # Push if requested
  if $push {
    # Get current branch name
    let current_branch = try {
      git rev-parse --abbrev-ref HEAD | str trim
    } catch {
      "HEAD"
    }

    $"Pushing to origin ($current_branch)" | ci log info
    try {
      git push origin $current_branch
      {status: "success" error: null message: $commit_message pushed: true}
    } catch {|err|
      $"Failed to push: ($err.msg)" | ci log error
      {status: "success" error: $"Push failed: ($err.msg)" message: $commit_message pushed: false}
    }
  } else {
    {status: "success" error: null message: $commit_message pushed: false}
  }
}
