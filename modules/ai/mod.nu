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

# Re-export all git commands from git.nu
export use ./git.nu *

# Export provider module for AI interactions
export use ./provider.nu *
