use ../common/help show-help
use provider.nu

# Default AI model for git operations
const DEFAULT_MODEL = "github-copilot/claude-sonnet-4.5"

# AI-powered git commands - show help
export def "ai git" [] {
  show-help "ai git"
}

# Create a new git branch with an AI-generated name based on current changes or user input
export def "ai git branch" [
  --model (-m): string = $DEFAULT_MODEL
  --description (-d): string
  --prefix (-p): string
  --from-current
] {
  git-branch $model ($description | default "") ($prefix | default "") $from_current
}

# Create a pull request with AI-generated title and description based on branch changes
export def "ai git pr" [
  --model (-m): string = $DEFAULT_MODEL
  --prefix (-p): string
  --target (-t): string = "main"
] {
  git-pr $model ($prefix | default "") $target
}

# Generate and apply an AI-written commit message based on staged changes
export def "ai git commit" [
  --model (-m): string = $DEFAULT_MODEL
] {
  git-commit $model
}

# Create a new git branch with an AI-generated name based on current changes or user input
def git-branch [
  model: string # AI model to use for branch name generation
  description: string # Optional description of what you're working on
  prefix: string # Optional prefix for branch name (e.g., ABC-123)
  from_current: bool # Branch from current branch instead of main
] {
  # Check if we're in a git repository
  try {
    git status --porcelain err> /dev/null | ignore
  } catch {
    print "Error: Not in a git repository"
    return
  }

  # Get current changes for context
  let staged_diff = (git diff --cached --name-only | str trim)

  # Determine base branch
  let base_branch = if $from_current {
    git rev-parse --abbrev-ref HEAD | str trim
  } else {
    "main"
  }

  # Build context for AI
  mut context = ""
  if $description != "" {
    $context = $"Working on: ($description)\n"
  }

  if $staged_diff != "" {
    $context = $"($context)Staged files: ($staged_diff)\n"
  }

  if $context == "" {
    $context = "No staged changes detected. General development branch."
  }

  let prompt = make_branch_prompt $context $prefix

  print "Generating branch name..."

  let branch_name = try {
    provider run $prompt $model
  } catch {|err|
    print $"Error generating branch name: ($err.msg)"
    return
  }

  print $"\nSuggested branch name: ($branch_name)\n"
  print "Choose an action: [c]reate, [r]etry, [e]dit, [a]bort\n"
  let choice = (input -n 1 -d a "Enter your choice: ")

  match $choice {
    "c" => {
      create_git_branch $branch_name $base_branch
    }
    "r" => {
      git-branch $model $description $prefix $from_current
    }
    "e" => {
      let edited_name = (input "Enter branch name: ")
      if $edited_name != "" {
        create_git_branch $edited_name $base_branch
      } else {
        print "Operation aborted."
      }
    }
    "a" => {
      print "Operation aborted."
    }
    _ => {
      print "Invalid choice. Operation aborted."
    }
  }
}

# Create a pull request with AI-generated title and description based on branch changes
def git-pr [
  model: string # AI model to use for PR generation
  prefix: string # Optional prefix for PR title (e.g., ABC-123)
  target: string # Target branch for the PR
] {
  # Check if we're in a git repository
  try {
    git status --porcelain err> /dev/null | ignore
  } catch {
    print "Error: Not in a git repository"
    return
  }

  # Get current branch
  let current_branch = (git rev-parse --abbrev-ref HEAD | str trim)
  if $current_branch == $target {
    print $"Error: Cannot create PR from ($target) to ($target)"
    return
  }

  # Check for existing PR first
  print $"Checking for existing PRs for branch '($current_branch)' -> '($target)'..."
  let existing_pr = try {
    gh pr list --head $current_branch --base $target --json number,title | str trim
  } catch {
    "[]"
  }

  if $existing_pr != "[]" {
    let pr_data = ($existing_pr | from json | first)
    let pr_number = $pr_data.number
    print $"✓ Found existing PR #($pr_number): ($pr_data.title)"
    print $"→ Will update this PR with new content\n"
  } else {
    print "✓ No existing PR found"
    print $"→ Will create new PR\n"
  }

  # Get changes between current branch and target
  let diff = (git diff $"($target)...HEAD" | str trim)
  let commit_messages = (git log $"($target)..HEAD" --oneline | str trim)
  let changed_files = (git diff $"($target)...HEAD" --name-only | str trim)

  if $diff == "" {
    print $"No changes found between ($current_branch) and ($target)"
    return
  }

  # Build context for AI
  let context = {
    branch: $current_branch
    target: $target
    commits: $commit_messages
    files: $changed_files
    diff: $diff
  }

  let pr_content = make_pr_prompt $context $prefix

  print "Generating PR title and description..."

  let generated_clean = try {
    provider run $pr_content $model
  } catch {|err|
    print $"Error generating PR: ($err.msg)"
    return
  }

  # Parse title and description from generated content
  let lines = ($generated_clean | lines)
  let title = ($lines | first)
  let description = ($lines | skip 1 | str join "\n" | str trim)

  print $"\nGenerated PR:\n"
  print $"Title: ($title)"
  print $"Description:\n($description)\n"
  print "Choose an action: [c]reate, [r]etry, [e]dit title, [a]bort\n"
  let choice = (input -n 1 -d a "Enter your choice: ")

  match $choice {
    "c" => {
      create_or_update_github_pr $title $description $target
    }
    "r" => {
      git-pr $model $prefix $target
    }
    "e" => {
      let edited_title = (input "Edit title: ")
      if $edited_title != "" {
        print $"\nUpdated PR:\n"
        print $"Title: ($edited_title)"
        print $"Description:\n($description)\n"
        create_or_update_github_pr $edited_title $description $target
      } else {
        print "Operation aborted."
      }
    }

    "a" => {
      print "Operation aborted."
    }
    _ => {
      print "Invalid choice. Operation aborted."
    }
  }
}

# Generate and apply an AI-written commit message based on staged changes
def git-commit [
  model: string # AI model to use for commit message generation
] {
  let branch = (git rev-parse --abbrev-ref HEAD | str trim)
  let prefix = ($branch | parse -r '(?P<id>[A-Za-z]+-[0-9]+)' | get id.0? | default "")
  let diff = (git diff --cached | str trim)

  if $diff == "" {
    print "No changes staged!"
    return
  }

  let prompt = make_commit_prompt $diff

  print "Generating commit message..."

  mut message = try {
    provider run $prompt $model
  } catch {|err|
    print $"Error generating commit message: ($err.msg)"
    return
  }

  if $prefix != "" {
    $message = $"($prefix): ($message)"
  }

  print "\nGenerated Commit Message:\n"
  print $message

  print "\nChoose an action: [c]ommit, [r]etry, [a]bort\n"
  let choice = (input -n 1 -d a "Enter your choice: ")

  match $choice {
    "c" => {
      commit_with_message $message
    }
    "r" => {
      git-commit $model
    }
    "a" => {
      print "Operation aborted."
    }
    _ => {
      print "Invalid choice. Operation aborted."
    }
  }
}

def make_commit_prompt [diff: string] {
  $"
You are an expert in writing Git commit messages following Conventional Commits specification.

Your task is to generate a commit message based on the provided diff. The commit message must:
1. Use a clear, descriptive title in imperative mood \(50 characters max\)
2. Include bullet points for significant changes only
3. Use technical, precise language
4. Skip minor changes \(formatting, imports, trivial refactors\)
5. Avoid redundant information between title and bullets

Important:
- Return just the commit message, no additional text or explanation
- Do not include labels like 'Title:' or 'Commit Message:'
- Do not use markdown code blocks
- Analyze the entire diff and capture only major changes

Output Format:
Concise title

- Key change 1
- Key change 2

Diff:($diff)"
}

def commit_with_message [message: string] {
  let commit_msg_file = $"/tmp/commit-msg-(random uuid).tmp"

  $message | save -f $commit_msg_file

  $env.GIT_EDITOR = ($env.EDITOR? | default "vim")
  git commit --edit --file $commit_msg_file

  rm $commit_msg_file
}

def make_branch_prompt [context: string prefix: string] {
  mut prompt_text = $"
You are an expert in creating concise, descriptive Git branch names following best practices.

Generate a short, descriptive branch name based on the context provided. The branch name should:
1. Be lowercase with hyphens as separators
2. Be concise but descriptive \(2-4 words max\)
3. Follow conventional patterns like: feature/, fix/, docs/, refactor/, etc.
4. Avoid special characters except hyphens
5. Be under 50 characters total

Context: ($context)"

  if $prefix != "" {
    $prompt_text = $"($prompt_text)
IMPORTANT: The branch name MUST start with '($prefix)/' followed by a conventional prefix.
Example formats: 
- ($prefix)/feature/user-authentication
- ($prefix)/fix/login-bug  
- ($prefix)/docs/api-updates
- ($prefix)/refactor/cleanup-code"
  } else {
    $prompt_text = $"($prompt_text)
Use appropriate prefixes like:
- feature/ for new features
- fix/ for bug fixes  
- docs/ for documentation
- refactor/ for code improvements"
  }

  $prompt_text = $"($prompt_text)
Return ONLY the branch name, no additional text or explanation."

  $prompt_text
}

def create_git_branch [branch_name: string base_branch: string] {
  print $"Creating branch: ($branch_name) from ($base_branch)"

  # First checkout the base branch if not already on it
  if $base_branch != "main" or (git rev-parse --abbrev-ref HEAD | str trim) != $base_branch {
    try {
      git checkout $base_branch
    } catch {|err|
      print $"❌ Failed to checkout base branch ($base_branch): ($err.msg)"
      return
    }
  }

  try {
    git checkout -b $branch_name
    print $"✅ Successfully created and switched to branch: ($branch_name) from ($base_branch)"
  } catch {|err|
    print $"❌ Failed to create branch: ($err.msg)"
  }
}

def make_pr_prompt [context: record prefix: string] {
  mut prompt_text = $"
You are an expert in creating GitHub Pull Request titles and descriptions.

Your task is to generate a PR title and description based on the changes provided.

PR Title Guidelines:
1. Be clear and descriptive \(under 60 characters\)
2. Use imperative mood \(Add, Fix, Update, etc.\)
3. Focus on the main change"

  if $prefix != "" {
    $prompt_text = $"($prompt_text)
4. MUST start with '($prefix): '"
  } else {
    $prompt_text = $"($prompt_text)
4. Use conventional prefixes like 'feat:', 'fix:', 'docs:', etc."
  }

  $prompt_text = $"($prompt_text)

PR Description Guidelines:
1. Start with a 1-2 sentence summary
2. List key technical changes as bullet points
3. Focus on facts, not assumptions

Important:
- Return just the PR content, no additional text or explanation
- Do not include labels like 'Title:' or 'Description:'
- Do not use markdown code blocks or headers

Branch: ($context.branch) → ($context.target)
Commits:($context.commits)
Files:($context.files)

Output Format:
Title line
Summary sentence.

- Technical change 1
- Technical change 2

Diff:($context.diff)"

  $prompt_text
}

def create_or_update_github_pr [title: string description: string target: string] {
  # Check if PR already exists for current branch
  let current_branch = (git rev-parse --abbrev-ref HEAD | str trim)
  let existing_pr = try {
    gh pr list --head $current_branch --base $target --json number,title | str trim
  } catch {
    "[]"
  }

  if $existing_pr != "[]" {
    let pr_data = ($existing_pr | from json | first)
    let pr_number = $pr_data.number

    print $"Updating PR #($pr_number)..."

    let repo = try {
      gh repo view --json owner,name | from json
    } catch {|err|
      print $"❌ Failed to get repo info: ($err.msg)"
      return
    }

    let owner = $repo.owner.login
    let name = $repo.name

    try {
      gh api -X PATCH $"/repos/($owner)/($name)/pulls/($pr_number)" -f $"title=($title)" -f $"body=($description)" | ignore
      print $"✅ Successfully updated PR #($pr_number)"
      gh pr view $pr_number --web
    } catch {|err|
      print $"❌ Failed to update PR: ($err.msg)"
    }
  } else {
    print $"Creating new PR..."

    try {
      let result = (gh pr create --title $title --body $description --base $target)
      print $"✅ Successfully created PR: ($result)"
    } catch {|err|
      print $"❌ Failed to create PR: ($err.msg)"
    }
  }
}
