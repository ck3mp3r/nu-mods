use ../common/help show-help

# Custom help command to handle --help flag
export def help [...rest] {
  if ($rest | is-empty) {
    show-help "ai"
  } else {
    let target = ($rest | str join " ")
    show-help $target
  }
}

# AI-powered utilities for git operations
export def main [] {
  show-help "ai"
}

# AI-powered git commands - show help
export def "ai git" [] {
  show-help "ai git"
}

use ./git.nu *

# Create a new git branch with an AI-generated name based on current changes or user input
export def "ai git branch" [
  --model (-m): string = "gpt-4.1"
  --description (-d): string
  --prefix (-p): string
  --from-current
] {
  if $from_current {
    git-branch --model $model --description $description --prefix $prefix --from-current
  } else {
    git-branch --model $model --description $description --prefix $prefix
  }
}

# Create a pull request with AI-generated title and description based on branch changes
export def "ai git pr" [
  --model (-m): string = "gpt-4.1"
  --prefix (-p): string
  --target (-t): string = "main"
] {
  git-pr --model $model --prefix $prefix --target $target
}

# Generate and apply an AI-written commit message based on staged changes
export def "ai git commit" [
  --model (-m): string = "gpt-4.1"
] {
  git-commit --model $model
}
