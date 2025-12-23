# Helper functions to reduce boilerplate in tests

# Create a standard wrapped command that uses the mock registry
# This eliminates the need to write the same pattern over and over
export def "mock create-wrapped" [
  cmd_name: string # Command name (e.g., "git", "gh")
  --error-prefix: string = "" # Custom error prefix (default: command name)
]: nothing -> string {
  let error_msg_prefix = if ($error_prefix | is-empty) {
    $cmd_name | str capitalize
  } else {
    $error_prefix
  }

  # Generate the wrapped function code
  $"
export def --wrapped ($cmd_name) [...args] {
    use ../modules/nu-mock *
    
    let expectation = \(mock get-expectation '($cmd_name)' $args\)
    
    # Handle exit codes
    let exit_code = \($expectation | get -i exit_code | default 0\)
    if $exit_code != 0 {
        let output = \($expectation.returns\)
        error make {msg: $\"($error_msg_prefix) error: \($output\)\"}
    }
    
    # Return the mocked value
    $expectation.returns
}"
}

# Helper to register a simple mock with just args and return value
export def "mock simple" [
  fn_name: string
  args: list
  returns: any
  --exit-code: int = 0
] {
  use mod.nu

  mock register $fn_name {
    args: $args
    returns: $returns
    exit_code: $exit_code
  }
}

# Helper to register a mock that matches any arguments
export def "mock any-args" [
  fn_name: string
  returns: any
  --exit-code: int = 0
] {
  use mod.nu

  mock register $fn_name {
    args: any
    returns: $returns
    exit_code: $exit_code
  }
}
