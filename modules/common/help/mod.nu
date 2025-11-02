# Helper function to show help with subcommands
export def show-help [module_name: string] {
  # Get command info from scope
  let cmd_results = (scope commands | where name == $module_name)
  if ($cmd_results | is-empty) {
    print $"No help found for '($module_name)'"
    return
  }
  let cmd_info = ($cmd_results | first)

  # Print description
  if ($cmd_info.description | is-not-empty) {
    print $cmd_info.description
    print ""
  }

  # Print usage
  print "Usage:"
  print $"  > ($module_name | split row ' ' | last) "
  print ""

  # Print flags
  print "Flags:"
  print "  -h, --help: Display the help message for this command"
  print ""

  # Print input/output types
  if ($cmd_info.signatures | is-not-empty) {
    print "Input/output types:"
    print $cmd_info.signatures
    print ""
  }

  # Get and print subcommands
  let commands = (scope commands | where name =~ $"^($module_name)" | select name description)

  let subcommands = (
    $commands
    | where name != $module_name
    | where name =~ $"^($module_name) [^ ]+$"
    | where name !~ " help$" # Filter out help command
    | each {|cmd|
      let parts = ($cmd.name | split words)
      {
        name: ($parts | last)
        description: $cmd.description
      }
    }
  )

  if ($subcommands | length) > 0 {
    print ""
    print $"(ansi green)Subcommands:(ansi reset)"
    for cmd in $subcommands {
      let desc = if ($cmd.description | is-empty) { "" } else { $cmd.description }
      print $"  ($cmd.name) - ($desc)"
    }
  }
}
