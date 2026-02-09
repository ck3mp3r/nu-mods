# Calculator CLI - Entry point
#
# This demonstrates the Nushell CLI subcommand pattern
# Usage: use calculator *
#        main basic add 5 3

export def main [] {
  help main
}

# Re-export all submodules
export use ./basic.nu *
export use ./scientific.nu *
