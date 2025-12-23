# Test wrappers for CI tests
# These wrap external commands to use the nu-mock framework
# Import this BEFORE importing the module under test

use ../../modules/nu-mock *

# Wrapped nix command
export def --env --wrapped nix [...args] {
  # Check if this is a 'copy' command - it uses | complete
  if ($args | first) == 'copy' {
    let expectation = (mock get-expectation 'nix' $args)
    mock record-call 'nix' $args

    # Return complete-like record for copy commands
    {
      exit_code: ($expectation | get -o exit_code | default 0)
      stdout: ($expectation | get -o stdout | default "")
      stderr: ($expectation | get -o stderr | default "")
    }
  } else {
    # Regular mock call for other commands
    mock call 'nix' $args
  }
}

# Wrapped cachix command - returns complete-like record
export def --env --wrapped cachix [...args] {
  let expectation = (mock get-expectation 'cachix' $args)
  mock record-call 'cachix' $args

  # Return complete-like record
  {
    exit_code: ($expectation | get -o exit_code | default 0)
    stdout: ($expectation | get -o stdout | default "")
    stderr: ($expectation | get -o stderr | default ($expectation.returns))
  }
}

# Wrapped git command
export def --env --wrapped git [...args] {
  mock call 'git' $args
}

# Wrapped gh command
export def --env --wrapped gh [...args] {
  mock call 'gh' $args
}
