# Helper function to show help with subcommands
export def show-help [module_name: string] {
  # First show the normal help output
  help $module_name

  # Then add subcommands if any
  let commands = (scope commands | where name =~ $"^($module_name)" | select name description)

  # Get subcommands (one level deep)
  let subcommands = (
    $commands
    | where name != $module_name
    | where name =~ $"^($module_name) [^ ]+$"
    | each {|cmd|
      let parts = ($cmd.name | split words)
      {
        name: ($parts | last)
        description: $cmd.description
      }
    }
  )

  # Print subcommands if any
  if ($subcommands | length) > 0 {
    print ""
    print $"(ansi green)Subcommands:(ansi reset)"
    for cmd in $subcommands {
      let desc = if ($cmd.description | is-empty) { "" } else { $cmd.description }
      print $"  ($cmd.name) - ($desc)"
    }
  }
}
