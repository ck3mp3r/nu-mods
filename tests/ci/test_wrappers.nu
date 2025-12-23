# Test wrappers for CI tests
# These wrap external commands to use the nu-mock framework
# Import this BEFORE importing the module under test

use ../../modules/nu-mock *

# Wrapped nix command - just calls mock, errors bubble up via try/catch
export def --env --wrapped nix [...args] {
  mock call 'nix' $args
}

# Wrapped cachix command - just calls mock, errors bubble up via try/catch
export def --env --wrapped cachix [...args] {
  mock call 'cachix' $args
}

# Wrapped git command
export def --env --wrapped git [...args] {
  mock call 'git' $args
}

# Wrapped gh command
export def --env --wrapped gh [...args] {
  mock call 'gh' $args
}
