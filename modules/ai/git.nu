# Create a new git branch with an AI-generated name based on current changes or user input
export def 'git-branch' [
  --model (-m): string = "gpt-4.1" # AI model to use for branch name generation
  --description (-d): string # Optional description of what you're working on
  --prefix (-p): string # Optional prefix for branch name (e.g., ABC-123)
  --from-current # Branch from current branch instead of main
] {
  # Check if we're in a git repository
  let git_status = (git status --porcelain 2>/dev/null | complete)
  if $git_status.exit_code != 0 {
    print "Error: Not in a git repository"
    return
  }

  # Get current changes for context
  let staged_diff = (git diff --cached --name-only | str trim)
  let unstaged_diff = (git diff --name-only | str trim)
  let untracked_files = (git ls-files --others --exclude-standard | str trim)

  # Determine base branch
  let base_branch = if $from_current {
    git rev-parse --abbrev-ref HEAD | str trim
  } else {
    "main"
  }

  # Build context for AI
  mut context = ""
  if $description != null {
    $context = $"Working on: ($description)\n"
  }

  if $staged_diff != "" {
    $context = $"($context)Staged files: ($staged_diff)\n"
  }

  if $unstaged_diff != "" {
    $context = $"($context)Modified files: ($unstaged_diff)\n"
  }

  if $untracked_files != "" {
    $context = $"($context)New files: ($untracked_files)\n"
  }

  if $context == "" {
    $context = "No specific changes detected. General development branch."
  }

  let prompt = make_branch_prompt $context ($prefix | default "")

  print "Generating branch name..."

  let branch_name = (mods --model $model --quiet --raw --no-cache $prompt | str trim)

  print $"\nSuggested branch name: ($branch_name)\n"
  print "Choose an action: [c]reate, [r]etry, [e]dit, [a]bort\n"
  let choice = (input -n 1 -d a "Enter your choice: ")

  match $choice {
    "c" => {
      create_git_branch $branch_name $base_branch
    }
    "r" => {
      print "Retry by running the command again"
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
export def 'git-pr' [
  --model (-m): string = "gpt-4.1" # AI model to use for PR generation
  --prefix (-p): string # Optional prefix for PR title (e.g., ABC-123)
  --target (-t): string = "main" # Target branch for the PR
] {
  # Check if we're in a git repository
  let git_status = (git status --porcelain 2>/dev/null | complete)
  if $git_status.exit_code != 0 {
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
  let existing_pr = (gh pr list --head $current_branch --base $target --json number,title | complete)

  if $existing_pr.exit_code == 0 and ($existing_pr.stdout | str trim) != "[]" {
    let pr_data = ($existing_pr.stdout | from json | first)
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

  let pr_content = make_pr_prompt $context ($prefix | default "")

  print "Generating PR title and description..."

  let generated = (mods --model $model --quiet --raw --no-cache $pr_content | str trim)
  let generated_clean = ($generated | split row "</think>" | last | str trim)

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
      print "Retry by running the command again"
    }
    "e" => {
      let edited_title = (input $"Edit title [($title)]: ")
      let final_title = if $edited_title != "" { $edited_title } else { $title }
      print $"\nUpdated PR:\n"
      print $"Title: ($final_title)"
      print $"Description:\n($description)\n"
      print "Choose an action: [c]reate, [r]etry, [e]dit title, [a]bort\n"
      let choice2 = (input -n 1 -d a "Enter your choice: ")
      match $choice2 {
        "c" => { create_or_update_github_pr $final_title $description $target }
        "r" => { print "Retry by running the command again" }
        "e" => { print "Retry by running the command again" }
        "a" => { print "Operation aborted." }
        _ => { print "Invalid choice. Operation aborted." }
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
export def 'git-commit' [
  --model (-m): string = "gpt-4.1" # AI model to use for commit message generation
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

  mut message = ""
  if $prefix != "" {
    $message = $"($prefix): (mods --model $model --quiet --raw --no-cache $prompt)"
  } else {
    $message = (mods --model $model --quiet --raw --no-cache $prompt)
  }

  $message = ($message | split row "</think>" | last | str trim)

  print "\nGenerated Commit Message:\n"
  print $message

  print "\nChoose an action: [c]ommit, [r]etry, [a]bort\n"
  let choice = (input -n 1 -d a "Enter your choice: ")

  match $choice {
    "c" => {
      commit_with_message $message
    }
    "r" => {
      print "Retry by running the command again"
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
You are an expert in writing high-quality Git commit messages that strictly follow the [Conventional Commit]\(https://www.conventionalcommits.org/\) specification. You will be given a staged Git diff.

Your ONLY task is to generate a well-structured commit message based on the provided diff. The commit message must:
1. Use a clear, descriptive title in the imperative mood \(50 characters max\)
2. Provide a detailed explanation of changes in bullet points
3. Focus solely on the technical changes in the code
4. Don't focus on differences in markdown files
5. Use present tense and be specific about modifications

Key Guidelines:
- Don't use any git MCP functionality as the diff will be provided.
- Analyze the entire diff comprehensively, consider added and removed code respectively
- Capture the essence of only MAJOR changes
- Use technical, precise languages
- Avoid generic or vague descriptions
- Avoid quoting any word or sentences
- Avoid adding description for minor changes with not much context
- Return just the commit message, no additional text
- Don't return more bullet points than required
- Generate a single commit message

Output Format:
Concise Title Summarizing Changes

- Specific change descriptions as bullet points

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
    let checkout_result = (git checkout $base_branch | complete)
    if $checkout_result.exit_code != 0 {
      print $"❌ Failed to checkout base branch ($base_branch): ($checkout_result.stderr)"
      return
    }
  }

  let result = (git checkout -b $branch_name | complete)

  if $result.exit_code == 0 {
    print $"✅ Successfully created and switched to branch: ($branch_name) from ($base_branch)"
  } else {
    print $"❌ Failed to create branch: ($result.stderr)"
  }
}

def make_pr_prompt [context: record prefix: string] {
  mut prompt_text = $"
You are an expert in creating high-quality GitHub Pull Request titles and descriptions.

Generate a concise PR title and detailed description based on the changes provided.

PR Title Guidelines:
1. Be clear and descriptive \(under 60 characters\)
2. Use imperative mood \(Add, Fix, Update, Remove, etc.\)
3. Focus on the main change or feature"

  if $prefix != "" {
    $prompt_text = $"($prompt_text)4. MUST start with '($prefix): ' \(note the colon and space\)
Example: ($prefix): Add user authentication system"
  } else {
    $prompt_text = $"($prompt_text)4. Use conventional prefixes like 'feat:', 'fix:', 'docs:', etc."
  }

  $prompt_text = $"($prompt_text)

PR Description Guidelines:
1. Start with a succinct 1-2 sentence summary
2. Add a blank line
3. Follow with detailed information at the bottom

Branch: ($context.branch) → ($context.target)
Recent commits:($context.commits)

Changed files:($context.files)

Output Format:
Title line here
Brief succinct summary of what this PR accomplishes in 1-2 sentences.

## Details
- Specific implementation details
- Technical changes made
- Files modified and why
- Any architectural decisions

## Context
Additional background information, motivation, or considerations if relevant.

Changes diff:($context.diff)"

  $prompt_text
}

def create_or_update_github_pr [title: string description: string target: string] {
  # Check if PR already exists for current branch
  let current_branch = (git rev-parse --abbrev-ref HEAD | str trim)
  let existing_pr = (gh pr list --head $current_branch --base $target --json number,title | complete)

  if $existing_pr.exit_code == 0 and ($existing_pr.stdout | str trim) != "[]" {
    let pr_data = ($existing_pr.stdout | from json | first)
    let pr_number = $pr_data.number

    print $"Updating PR #($pr_number)..."

    let update_result = (gh pr edit $pr_number --title $title --body $description | complete)

    if $update_result.exit_code == 0 {
      print $"✅ Successfully updated PR #($pr_number)"
      gh pr view $pr_number --web
    } else {
      print $"❌ Failed to update PR: ($update_result.stderr)"
    }
  } else {
    print $"Creating new PR..."

    let result = (gh pr create --title $title --body $description --base $target | complete)

    if $result.exit_code == 0 {
      print $"✅ Successfully created PR: ($result.stdout)"
    } else {
      print $"❌ Failed to create PR: ($result.stderr)"
    }
  }
}
