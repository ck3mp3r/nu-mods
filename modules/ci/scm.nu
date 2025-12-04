use ../common/help show-help
use log.nu *

# SCM flow operations - show help
export def "ci scm" [] {
  show-help "ci scm"
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
  string -> nothing
  nothing -> nothing
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
    return
  }

  # Verify we're in a git repository
  try {
    git status --porcelain | ignore
  } catch {|err|
    "Not in a git repository" | ci log error
    error make {msg: $"Not in a git repository: ($err.msg)"}
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
      return
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
    } catch {|err|
      $"Failed to create branch: ($err.msg)" | ci log error
      return
    }
  } else {
    $"Creating branch: ($branch_name) from ($from)" | ci log info
    try {
      git checkout -b $branch_name
      print $"✅ Successfully created and switched to branch: ($branch_name) from ($from)"
    } catch {|err|
      $"Failed to create branch: ($err.msg)" | ci log error
      return
    }
  }
}
