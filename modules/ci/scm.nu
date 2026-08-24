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

# Get the latest git tag, stripping the 'v' prefix
export def "ci scm latest-tag" []: [
  nothing -> string
] {
  # Get all tags sorted by semantic version, take the newest
  let tags = (
    try {
      git tag --sort=-version:refname
    } catch {|err|
      "Failed to get git tags" | ci log error
      return ""
    }
    | lines
  )

  if ($tags | is-empty) {
    "No tags found" | ci log info
    return ""
  }

  # Take the first tag (newest) and strip the 'v' prefix if present
  let latest = ($tags | first | str trim)
  $"Latest tag: ($latest)" | ci log info

  if ($latest | str starts-with "v") {
    $latest | str replace --regex '^v' ''
  } else {
    $latest
  }
}

# Calculate the next semantic version
export def "ci scm semver" [
  latest_tag: string # Latest git tag (X.Y.Z format, may be empty)
  current_version: string # Current version from Cargo.toml (X.Y.Z format)
]: [
  nothing -> string
] {
  if $latest_tag == "" {
    "No tag, keeping current version" | ci log info
    return $current_version
  }

  let tag_parts = ($latest_tag | split row "." | each {|p| $p | into int })
  let current_parts = ($current_version | split row "." | each {|p| $p | into int })

  let tag_major = $tag_parts.0
  let tag_minor = $tag_parts.1
  let tag_patch = $tag_parts.2

  let cur_major = $current_parts.0
  let cur_minor = $current_parts.1
  let cur_patch = $current_parts.2

  # If major or minor differ, current version is ahead -> keep it
  if ($tag_major != $cur_major) or ($tag_minor != $cur_minor) {
    "Major/minor differ, keeping current version" | ci log info
    return $current_version
  }

  # Same major/minor: if patch is behind or equal, increment patch
  if ($cur_patch > $tag_patch) {
    "Patch ahead of tag, keeping current version" | ci log info
    return $current_version
  }

  let next_patch = ($tag_patch + 1)
  $"Incrementing patch to ($cur_major).($cur_minor).($next_patch)" | ci log info
  $"($cur_major).($cur_minor).($next_patch)"
}

# Create a new git branch with standardized naming convention based on SCM flow types
export def "ci scm branch" [
  --prefix (-p): string # Optional prefix for branch name (e.g., "myproject" -> "myproject/feature/...")
  --release # Create a release branch
  --fix # Create a fix branch
  --hotfix # Create a hotfix branch
  --chore # Create a chore branch
  --feature # Create a feature branch (default)
  --from: string = "main" # Base branch to branch from
  --reuse # If branch exists, checkout and rebase instead of failing
]: string -> record {

  # Get description from stdin
  let description = $in | str trim

  # Get prefix value or default to empty
  let prefix_val = $prefix | default ""

  if $description == "" {
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
    $description
    | str lowercase
    | str replace --all ' ' '-'
    | str replace --all --regex '[^a-z0-9\-\.]' ''
  )

  # Construct branch name
  let branch_name = if $prefix_val != "" {
    $"($prefix_val)/($flow)/($clean_desc)"
  } else {
    $"($flow)/($clean_desc)"
  }

  # Get current branch for context
  let current_branch = (git rev-parse --abbrev-ref HEAD | str trim)

  # Prepare base branch
  if $current_branch != $from {
    $"Switching to base branch: ($from)" | ci log info
    try {
      git switch $from
    } catch {|err|
      $"Failed to checkout base branch ($from): ($err.msg)" | ci log error
      return {status: "error" error: $"Failed to checkout base branch: ($err.msg)" branch: null rebased: false}
    }
  }

  # Pull latest changes
  $"Updating base branch: ($from)" | ci log info
  try {
    git pull
  } catch {|err|
    $"Failed to pull latest changes: ($err.msg)" | ci log warning
  }

  # Check if branch already exists (exit code 0 = exists, non-zero = doesn't exist)
  let branch_exists = try {
    git rev-parse --verify $branch_name | complete | get exit_code
  } catch {|err|
    $"Branch ($branch_name) does not exist: ($err.msg)" | ci log info
    # Branch doesn't exist
    128
  }

  if $branch_exists == 0 {
    if $reuse {
      $"Branch ($branch_name) already exists, checking out and rebasing" | ci log info
      try {
        git switch $branch_name

        # Get the commit hash before rebase
        let before_hash = (git rev-parse HEAD | str trim)

        # Perform rebase
        git pull --rebase origin $branch_name

        # Get the commit hash after rebase
        let after_hash = (git rev-parse HEAD | str trim)

        # If hash changed, we rebased and need force push
        let rebased = $before_hash != $after_hash

        $"Checked out existing branch and rebased: ($branch_name)" | ci log info
        {status: "success" error: null branch: $branch_name rebased: $rebased}
      } catch {|err|
        $"Failed to checkout/rebase branch: ($err.msg)" | ci log error
        {status: "error" error: $"Failed to checkout/rebase branch: ($err.msg)" branch: null rebased: false}
      }
    } else {
      $"Branch ($branch_name) already exists" | ci log error
      {status: "error" error: $"Branch ($branch_name) already exists. Use --reuse to checkout and rebase." branch: null rebased: false}
    }
  } else {
    # Create and switch to branch
    $"Creating branch: ($branch_name) from ($from)" | ci log info
    try {
      git switch -c $branch_name
      $"Successfully created and switched to branch: ($branch_name) from ($from)" | ci log info
      {status: "success" error: null branch: $branch_name rebased: false}
    } catch {|err|
      $"Failed to create branch: ($err.msg)" | ci log error
      {status: "error" error: $"Failed to create branch: ($err.msg)" branch: null rebased: false}
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
    } catch {|err|
      $"Failed to get current branch: ($err.msg)" | ci log error
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

# Squash-merge a release branch into main, commit, push, and delete the branch
export def "ci scm merge-release" [
  version: string # Release version (e.g., "0.1.0" -> branch "release/0.1.0")
]: [
  nothing -> record
] {
  let release_branch = $"release/($version)"

  # Switch to main
  $"Switching to main" | ci log info
  try {
    git checkout main
  } catch {|err|
    $"Failed to checkout main: ($err.msg)" | ci log error
    return {status: "error" error: $"Failed to checkout main: ($err.msg)" committed: false pushed: false branch_deleted: false}
  }

  # Fetch release branch
  $"Fetching origin/($release_branch)" | ci log info
  try {
    git fetch origin $release_branch
  } catch {|err|
    $"Failed to fetch release branch: ($err.msg)" | ci log error
    return {status: "error" error: $"Failed to fetch release branch: ($err.msg)" committed: false pushed: false branch_deleted: false}
  }

  # Squash merge
  $"Squash merging origin/($release_branch) into main" | ci log info
  try {
    git merge --squash $"origin/($release_branch)"
  } catch {|err|
    $"Failed to squash merge: ($err.msg)" | ci log error
    return {status: "error" error: $"Failed to squash merge: ($err.msg)" committed: false pushed: false branch_deleted: false}
  }

  # Check for staged changes (git diff --cached --quiet exits 0 if clean, non-zero if changes)
  let has_changes = try {
    git diff --cached --quiet | ignore
    false
  } catch {|err|
    true
  }

  if not $has_changes {
    "No changes to merge, skipping commit and push" | ci log warning
    return {status: "success" error: null committed: false pushed: false branch_deleted: false}
  }

  # Commit
  let commit_message = $"Release ($version)"
  $"Committing: ($commit_message)" | ci log info
  try {
    git commit -m $commit_message
  } catch {|err|
    $"Failed to commit: ($err.msg)" | ci log error
    return {status: "error" error: $"Failed to commit: ($err.msg)" committed: false pushed: false branch_deleted: false}
  }

  # Push to main
  $"Pushing to origin main" | ci log info
  try {
    git push origin main
  } catch {|err|
    $"Failed to push to main: ($err.msg)" | ci log error
    return {status: "error" error: $"Failed to push to main: ($err.msg)" committed: true pushed: false branch_deleted: false}
  }

  # Delete remote release branch
  $"Deleting remote branch: origin/($release_branch)" | ci log info
  try {
    git push origin --delete $release_branch
  } catch {|err|
    $"Failed to delete remote release branch: ($err.msg)" | ci log error
    return {status: "error" error: $"Failed to delete remote release branch: ($err.msg)" committed: true pushed: true branch_deleted: false}
  }

  {status: "success" error: null committed: true pushed: true branch_deleted: true}
}
