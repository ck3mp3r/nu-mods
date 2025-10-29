# Create a new git branch with an AI-generated name based on current changes or user input
export def 'ai git create branch' [
  --model (-m): string = "gpt-4.1" # AI model to use for branch name generation
  --description (-d): string # Optional description of what you're working on
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

  # Get current branch for prefix extraction
  let current_branch = (git rev-parse --abbrev-ref HEAD | str trim)
  let prefix = ($current_branch | parse -r '(?P<id>[A-Za-z]+-[0-9]+)' | get id.0? | default "")

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

  let prompt = make_branch_prompt $context $prefix

  print "Generating branch name..."

  let branch_name = (mods --model $model --quiet --raw --no-cache $prompt | str trim)

  print $"\nSuggested branch name: ($branch_name)\n"
  print "Choose an action: [c]reate, [r]etry, [e]dit, [a]bort\n"
  let choice = (input -n 1 -d a "Enter your choice: ")

  match $choice {
    "c" => {
      create_git_branch $branch_name
    }
    "r" => {
      ai git create branch --model $model --description $description
    }
    "e" => {
      let edited_name = (input "Enter branch name: ")
      if $edited_name != "" {
        create_git_branch $edited_name
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
export def 'ai git create pr' [] { }

# Generate and apply an AI-written commit message based on staged changes
export def 'ai git commit' [
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
      ai git commit --model $model
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
IMPORTANT: The branch name MUST start with '($prefix)/' (including the slash).
Example format: ($prefix)/your-branch-name"
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

def create_git_branch [branch_name: string] {
  print $"Creating branch: ($branch_name)"

  let result = (git checkout -b $branch_name | complete)

  if $result.exit_code == 0 {
    print $"✅ Successfully created and switched to branch: ($branch_name)"
  } else {
    print $"❌ Failed to create branch: ($result.stderr)"
  }
}

export def 'ai git' [] {
  help ai git
}
