use ../std/help show-help

export def main [] {
  show-help "ai"
}

export module git {
  use ./git.nu *
  use ../std/help show-help

  export def main [] {
    show-help "ai git"
  }

  # Create a new git branch with an AI-generated name based on current changes or user input
  export def 'branch' [
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
  export def pr [
    --model (-m): string = "gpt-4.1"
    --prefix (-p): string
    --target (-t): string = "main"
  ] {
    git-pr --model $model --prefix $prefix --target $target
  }

  # Generate and apply an AI-written commit message based on staged changes
  export def commit [
    --model (-m): string = "gpt-4.1"
  ] {
    git-commit --model $model
  }
}
