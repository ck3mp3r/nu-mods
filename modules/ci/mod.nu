use ../common/help show-help

# Custom help command to handle --help flag
export def help [...rest] {
  if ($rest | is-empty) {
    show-help "ci"
  } else {
    let target = ($rest | str join " ")
    show-help $target
  }
}

# CI utilities for SCM flows
# NOTE: To use subcommands, import with: use ci *
export def main [] {
  show-help "ci"
}

# Re-export all scm commands from scm.nu
export use ./scm.nu *

# Re-export all github commands from github.nu
export use ./github.nu *

# Re-export all nix commands from nix.nu
export use ./nix.nu *
