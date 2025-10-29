# Create a new git branch with an AI-generated name based on current changes or user input
export def 'ai git create branch' [] { }

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

export def 'ai git' [] {
  help ai git
}
